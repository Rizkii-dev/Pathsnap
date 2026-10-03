#!/usr/bin/env node
/**
 * Local MCP-style tool backend: query_travel_places.
 * Runs a ranking SQL against WSL Postgres (`pathsnap`), then enriches
 * prices/ratings from mockData when the DB columns are empty.
 *
 * Usage: node server/queryTravelPlaces.mjs
 * POST /api/query-travel-places
 *   { budgetUsd, userLocation, travelArea, days }
 */
import pg from 'pg';
import { createServer } from 'node:http';
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const { Pool } = pg;
const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const PORT = Number(process.env.QUERY_TOOL_PORT || 8787);

/** Free OSM geocoder for addresses not present in the local DB. */
const NOMINATIM_URL = 'https://nominatim.openstreetmap.org/search';
const geocodeCache = new Map();
let lastGeocodeAt = 0;
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false,
  }
});

async function queryDatabase(sql, params = []) {
  const result = await pool.query(sql, params);
  return result.rows;
}

const sql = `
  SELECT * FROM places
  LIMIT 100`;

try {
  const rows = await queryDatabase(sql);

  conse.log(rows); 
} catch (error) {
  console.error('Error querying the database:', error);
} finally {
  await pool.end();
}

/**
 * Geocode a free-text address via Nominatim (OpenStreetMap).
 * No API key. Cached in-memory. 1 req/sec per their usage policy.
 */
async function geocodeAddress(query, { areaHint } = {}) {
  const key = `${String(query).trim().toLowerCase()}|${String(areaHint || '').toLowerCase()}`;
  if (geocodeCache.has(key)) return geocodeCache.get(key);

  const q = areaHint ? `${query}, ${areaHint}` : query;
  const url = new URL(NOMINATIM_URL);
  url.searchParams.set('q', q);
  url.searchParams.set('format', 'json');
  url.searchParams.set('limit', '1');
  url.searchParams.set('addressdetails', '0');

  // Nominatim usage policy: max 1 request/second.
  const waitMs = 1000 - (Date.now() - lastGeocodeAt);
  if (waitMs > 0) await new Promise((r) => setTimeout(r, waitMs));
  lastGeocodeAt = Date.now();

  const response = await fetch(url, {
    headers: {
      // Required by Nominatim policy — identify the app.
      'User-Agent': 'PathsnapTripPlanner/0.1 (local-dev; query_travel_places)',
      Accept: 'application/json',
    },
    signal: AbortSignal.timeout(4000),
  });

  if (!response.ok) {
    throw new Error(`Geocoder failed with status ${response.status}`);
  }

  const results = await response.json();
  const hit = Array.isArray(results) && results[0]
    ? {
        lat: Number(results[0].lat),
        lon: Number(results[0].lon),
        displayName: results[0].display_name,
      }
    : null;

  geocodeCache.set(key, hit);
  return hit;
}

/** Escape a value for use inside a single-quoted psql literal. */
function sqlLiteral(value) {
  return `'${String(value ?? '').replace(/'/g, "''")}'`;
}

function psql(sql) {
  const out = execFileSync(
    'wsl',
    ['-d', 'Ubuntu', '-u', 'root', '--', 'sudo', '-u', 'postgres', 'psql', '-d', 'pathsnap', '-t', '-A', '-v', 'ON_ERROR_STOP=1', '-c', sql],
    { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 },
  );
  return JSON.parse(out.trim() || '[]');
}

function haversineKm(a, b) {
  const R = 6371;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(b[0] - a[0]);
  const dLon = toRad(b[1] - a[1]);
  const lat1 = toRad(a[0]);
  const lat2 = toRad(b[0]);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/**
 * Load price/rating fallbacks from the generated mockData module.
 * The live DB currently has names + coordinates only for Bandung rows.
 */
function loadMockIndex() {
  const file = join(ROOT, 'src', 'data', 'mockData.ts');
  const text = readFileSync(file, 'utf8');

  const destSection = text.slice(
    text.indexOf('export const destinations'),
    text.indexOf('export const accommodations'),
  );
  const accSection = text.slice(
    text.indexOf('export const accommodations'),
    text.indexOf('export const attractions'),
  );

  const destByName = new Map();
  const destRe = /\{\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)",[\s\S]*?rating:\s*([0-9.]+),[\s\S]*?coordinates:\s*\[([^\]]+)\]/g;
  let m;
  while ((m = destRe.exec(destSection))) {
    const coords = m[4].split(',').map((v) => Number(v.trim()));
    destByName.set(m[2].toLowerCase(), {
      id: m[1],
      name: m[2],
      rating: Number(m[3]),
      coordinates: [coords[0], coords[1]],
    });
  }

  const accByDest = new Map();
  const accRe = /\{\s*id:\s*"([^"]+)",\s*name:\s*"([^"]+)",[\s\S]*?price:\s*([0-9.]+),[\s\S]*?destinationId:\s*"([^"]+)"/g;
  while ((m = accRe.exec(accSection))) {
    const list = accByDest.get(m[4]) || [];
    list.push({ name: m[2], price: Number(m[3]) });
    accByDest.set(m[4], list);
  }

  return { destByName, accByDest };
}

const mockIndex = loadMockIndex();

function enrichFromMock(row) {
  const dest = mockIndex.destByName.get(String(row.name).toLowerCase());
  if (!dest) return row;

  const accs = mockIndex.accByDest.get(dest.id) || [];
  const avgAcc =
    row.avg_accommodation_price != null
      ? Number(row.avg_accommodation_price)
      : accs.length > 0
        ? accs.reduce((s, a) => s + a.price, 0) / accs.length
        : null;

  // Nearby-place attractions in the export are free (price: null).
  const avgAttr =
    row.avg_attraction_price != null ? Number(row.avg_attraction_price) : 0;
  const totalAttr =
    row.total_attraction_price != null ? Number(row.total_attraction_price) : 0;

  return {
    ...row,
    rating: row.rating != null ? Number(row.rating) : dest.rating,
    avg_accommodation_price: avgAcc,
    avg_attraction_price: avgAttr,
    total_attraction_price: totalAttr,
    _mockCoords: dest.coordinates,
    _mockDestId: dest.id,
  };
}

/**
 * Normalize a street address so "Jln Apple No 3", "Jl. Apple, 3",
 * and "Jalan Apple No. 3" compare equal.
 */
function normalizeAddress(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/\bjln\b\.?/g, 'jalan')
    .replace(/\bjl\b\.?/g, 'jalan')
    .replace(/\bst\b\.?/g, 'street')
    .replace(/\bno\b\.?/g, ' ')
    .replace(/\bnomor\b/g, ' ')
    .replace(/#/g, ' ')
    .replace(/[.,/\\|_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

const GENERIC_ADDRESS_TOKENS = new Set([
  'jalan', 'street', 'jln', 'jl', 'bandung', 'kota', 'kec', 'kecamatan',
  'lantai', 'floor', 'no', 'nomor', 'jl', 'depan', 'belakang', 'samping',
  'indonesia', 'jawa', 'barat', 'utara', 'selatan', 'timur', 'barat',
  'blok', 'block', 'unit', 'gedung', 'building',
]);

function addressTokens(value) {
  return normalizeAddress(value).split(' ').filter(Boolean);
}

function distinctiveTokens(tokens) {
  return tokens.filter((t) => !GENERIC_ADDRESS_TOKENS.has(t) && !/^\d+$/.test(t));
}

/** Score how well `candidate` address matches `query` (0 = no match). */
function addressMatchScore(query, candidate) {
  const qNorm = normalizeAddress(query);
  const cNorm = normalizeAddress(candidate);
  if (!qNorm || !cNorm) return 0;
  if (qNorm === cNorm) return 100;

  const qTokens = addressTokens(query);
  const cTokenSet = new Set(addressTokens(candidate));
  if (qTokens.length === 0) return 0;

  const qDistinctive = distinctiveTokens(qTokens);
  // Need a real street/place name token, not just "jalan" + a number.
  if (qDistinctive.length === 0) return 0;

  const distinctiveHits = qDistinctive.filter((t) => cTokenSet.has(t));
  if (distinctiveHits.length === 0) return 0;

  const allHits = qTokens.filter((t) => cTokenSet.has(t)).length;
  const coverage = allHits / qTokens.length;
  const distinctiveCoverage = distinctiveHits.length / qDistinctive.length;

  // Street name must largely match.
  if (distinctiveCoverage < 0.5) return 0;

  const qNumbers = qTokens.filter((t) => /^\d+$/.test(t));
  const cNumbers = new Set(addressTokens(candidate).filter((t) => /^\d+$/.test(t)));
  const numberHits = qNumbers.filter((t) => cNumbers.has(t)).length;
  const numberBonus =
    qNumbers.length > 0 && numberHits === qNumbers.length ? 15 : qNumbers.length > 0 ? -10 : 0;

  if (cNorm.includes(qNorm) || qNorm.includes(cNorm)) {
    return Math.min(100, 90 + numberBonus);
  }
  return Math.min(100, 55 + distinctiveCoverage * 25 + numberBonus);
}

function loadAddressIndex() {
  const sql = `
    SELECT coalesce(json_agg(sub), '[]'::json)
    FROM (
      SELECT p.name, p.address, p.latitude, p.longitude, 'place' AS kind
      FROM places p
      WHERE p.is_active AND p.address IS NOT NULL AND btrim(p.address) <> ''
      UNION ALL
      SELECT a.name, a.address, a.latitude, a.longitude, 'accommodation' AS kind
      FROM accommodations a
      WHERE a.is_active AND a.address IS NOT NULL AND btrim(a.address) <> ''
    ) sub
  `;
  return psql(sql);
}

async function resolveUserAnchor(userLocation, rows, { areaHint } = {}) {
  const needle = String(userLocation || '').trim().toLowerCase();
  if (!needle) return null;

  // 1) Place name (exact, then partial) among shortlisted rows.
  const hit =
    rows.find((r) => String(r.name).toLowerCase() === needle) ||
    rows.find((r) => String(r.name).toLowerCase().includes(needle));
  if (hit && hit.latitude != null && hit.longitude != null) {
    return { kind: 'coords', coords: [Number(hit.latitude), Number(hit.longitude)], label: hit.name, matchedBy: 'place-name' };
  }
  if (hit?._mockCoords) {
    return { kind: 'coords', coords: hit._mockCoords, label: hit.name, matchedBy: 'place-name' };
  }

  // 2) Street address among shortlisted rows (e.g. "Jln Apple No 3").
  let best = { score: 0, coords: null, label: null };
  for (const row of rows) {
    const score = addressMatchScore(needle, row.address || '');
    if (score > best.score && row.latitude != null && row.longitude != null) {
      best = {
        score,
        coords: [Number(row.latitude), Number(row.longitude)],
        label: row.address || row.name,
      };
    }
  }
  if (best.score >= 70 && best.coords) {
    return { kind: 'coords', coords: best.coords, label: best.label, matchedBy: 'address', score: best.score };
  }

  // 3) Street address anywhere in the DB (places + accommodations).
  try {
    const index = loadAddressIndex();
    let bestAddr = { score: 0, coords: null, label: null };
    for (const row of index) {
      const score = addressMatchScore(needle, row.address || '');
      if (score > bestAddr.score && row.latitude != null && row.longitude != null) {
        bestAddr = {
          score,
          coords: [Number(row.latitude), Number(row.longitude)],
          label: `${row.name} (${row.address})`,
        };
      }
    }
    if (bestAddr.score >= 70 && bestAddr.coords) {
      return {
        kind: 'coords',
        coords: bestAddr.coords,
        label: bestAddr.label,
        matchedBy: 'db-address',
        score: bestAddr.score,
      };
    }
    if (bestAddr.score > best.score) best = bestAddr;
  } catch (err) {
    console.warn('[query_travel_places] address index lookup failed:', err.message);
  }

  // 4) External geocoder (OSM Nominatim) for addresses not in the local DB.
  try {
    const geo = await geocodeAddress(userLocation, { areaHint });
    if (geo && Number.isFinite(geo.lat) && Number.isFinite(geo.lon)) {
      return {
        kind: 'coords',
        coords: [geo.lat, geo.lon],
        label: geo.displayName,
        matchedBy: 'geocoder',
      };
    }
  } catch (err) {
    console.warn('[query_travel_places] geocoder fallback failed:', err.message);
  }

  // 5) District / city name match on the SQL row.
  const areaHit = rows.find(
    (r) =>
      String(r.district || '').toLowerCase() === needle ||
      String(r.city || '').toLowerCase() === needle,
  );
  if (areaHit) {
    return {
      kind: 'area',
      district: areaHit.district || null,
      city: areaHit.city || null,
      label: userLocation,
    };
  }

  return { kind: 'text', label: userLocation, weakMatch: best.score > 0 ? best : undefined };
}

function rankPlaces(rows, { budgetUsd, userLocation }, anchor) {
  const budget = Number(budgetUsd);
  const hasBudget = Number.isFinite(budget) && budget > 0;
  const resolvedAnchor = anchor;

  const enriched = rows.map(enrichFromMock).map((row) => {
    const coords =
      row.latitude != null && row.longitude != null
        ? [Number(row.latitude), Number(row.longitude)]
        : row._mockCoords || null;

    let sameArea = false;
    let distanceKm = null;

    if (resolvedAnchor?.kind === 'coords' && coords) {
      distanceKm = haversineKm(resolvedAnchor.coords, coords);
      // "Same district/city" proxy: within ~5 km of the user's anchor.
      sameArea = distanceKm <= 5;
    } else if (resolvedAnchor?.kind === 'area') {
      sameArea =
        (resolvedAnchor.district && row.district && resolvedAnchor.district === row.district) ||
        (resolvedAnchor.city && row.city && resolvedAnchor.city === row.city) ||
        // DB often lacks district_id; treat travel-area city as shared area.
        (!resolvedAnchor.district && !row.district && resolvedAnchor.city && row.city && resolvedAnchor.city === row.city);
    }

    const totalAttr = Number(row.total_attraction_price ?? 0);
    const affordableAttractions = !hasBudget || totalAttr <= budget;

    return {
      name: row.name,
      avgAccommodationPrice:
        row.avg_accommodation_price != null ? Math.round(Number(row.avg_accommodation_price) * 100) / 100 : null,
      avgAttractionPrice:
        row.avg_attraction_price != null ? Math.round(Number(row.avg_attraction_price) * 100) / 100 : null,
      totalAttractionPrice: Math.round(totalAttr * 100) / 100,
      avgTotalPrice:
        row.avg_accommodation_price != null || row.avg_attraction_price != null
          ? Math.round((Number(row.avg_accommodation_price || 0) + Number(row.avg_attraction_price || 0)) * 100) / 100
          : null,
      rating: row.rating != null ? Math.round(Number(row.rating) * 10) / 10 : null,
      district: row.district || null,
      city: row.city || null,
      sameArea,
      distanceKm: distanceKm != null ? Math.round(distanceKm * 100) / 100 : null,
      affordableAttractions,
    };
  });

  // Prioritize: can afford all attractions → same area (closest) → else highest rating.
  enriched.sort((a, b) => {
    if (a.affordableAttractions !== b.affordableAttractions) {
      return a.affordableAttractions ? -1 : 1;
    }
    if (a.sameArea !== b.sameArea) {
      return a.sameArea ? -1 : 1;
    }
    if (a.sameArea && b.sameArea) {
      const da = a.distanceKm ?? Number.POSITIVE_INFINITY;
      const db = b.distanceKm ?? Number.POSITIVE_INFINITY;
      if (da !== db) return da - db;
    }
    const ra = a.rating ?? -1;
    const rb = b.rating ?? -1;
    if (ra !== rb) return rb - ra;
    return a.name.localeCompare(b.name);
  });

  return enriched;
}

async function queryTravelPlaces({ budgetUsd, userLocation, travelArea, days }) {
  const area = String(travelArea || '').trim();
  const areaFilter = area
    ? `AND (
        p.name ILIKE '%' || ${sqlLiteral(area)} || '%'
        OR c.name ILIKE '%' || ${sqlLiteral(area)} || '%'
        OR d.name ILIKE '%' || ${sqlLiteral(area)} || '%'
      )`
    : '';

  const sql = `
    SELECT coalesce(json_agg(sub), '[]'::json)
    FROM (
      SELECT
        p.id::text AS id,
        p.name,
        p.address,
        p.latitude,
        p.longitude,
        p.rating_avg::float8 AS rating,
        c.name AS city,
        d.name AS district,
        (
          SELECT AVG(a.price_per_night_min)::float8
          FROM accommodations a
          WHERE a.is_active
            AND a.price_per_night_min IS NOT NULL
            AND ST_DWithin(a.location, p.location, 5000)
        ) AS avg_accommodation_price,
        (
          SELECT COALESCE(SUM(p2.price_min), 0)::float8
          FROM places p2
          WHERE p2.is_active
            AND p2.id <> p.id
            AND p2.price_min IS NOT NULL
            AND ST_DWithin(p2.location, p.location, 5000)
        ) AS total_attraction_price,
        (
          SELECT AVG(p2.price_min)::float8
          FROM places p2
          WHERE p2.is_active
            AND p2.id <> p.id
            AND p2.price_min IS NOT NULL
            AND ST_DWithin(p2.location, p.location, 5000)
        ) AS avg_attraction_price
      FROM places p
      LEFT JOIN cities c ON c.id = p.city_id
      LEFT JOIN districts d ON d.id = p.district_id
      WHERE p.is_active
        ${areaFilter}
      ORDER BY p.rating_avg DESC NULLS LAST, p.name
      LIMIT 80
    ) sub
  `;

  const rows = psql(sql);
  const anchor = await resolveUserAnchor(userLocation, rows, { areaHint: area || travelArea });
  const ranked = rankPlaces(rows, { budgetUsd, userLocation }, anchor);

  return {
    query: { budgetUsd, userLocation, travelArea, days },
    count: ranked.length,
    anchor,
    places: ranked.slice(0, 15),
  };
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        const raw = Buffer.concat(chunks).toString('utf8').replace(/^\uFEFF/, '');
        resolve(raw ? JSON.parse(raw) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload, null, 2);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  });
  res.end(body);
}

const server = createServer(async (req, res) => {
  if (req.method === 'OPTIONS') {
    sendJson(res, 204, {});
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    sendJson(res, 200, { ok: true });
    return;
  }

  if (req.method === 'POST' && req.url === '/api/query-travel-places') {
    try {
      const body = await readBody(req);
      console.log('[query_travel_places] args:', body);
      const result = await queryTravelPlaces(body);
      console.log('[query_travel_places] returned', result.count, 'places (top 15 kept)');
      sendJson(res, 200, result);
    } catch (err) {
      console.error('[query_travel_places] failed:', err);
      sendJson(res, 500, { error: err instanceof Error ? err.message : 'Query failed' });
    }
    return;
  }

  sendJson(res, 404, { error: 'Not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
});
