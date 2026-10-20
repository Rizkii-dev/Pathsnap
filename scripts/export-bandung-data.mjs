#!/usr/bin/env node
/**
 * Export Bandung data from `src/data/new_data.sql` (pg_dump) into
 * `src/data/mockData.ts`, keeping the existing Destination/Accommodation/Attraction shapes.
 *
 * Uses real rating_avg / rating_count / price data from the dump — no synthetic fallbacks.
 *
 * Usage: node scripts/export-bandung-data.mjs
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const SQL_FILE = join(ROOT, 'src', 'data', 'new_data.sql');
const OUT = join(ROOT, 'src', 'data', 'mockData.ts');

// ── helpers ──────────────────────────────────────────────────────────────────

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

/** Decode PostGIS hex-WKB Point(4326) → [lng, lat] */
function decodeWkbPoint(hex) {
  if (!hex || hex === '\\N' || hex.length < 50) return null;
  // Skip 18 hex chars (9 bytes: byte-order + type + SRID)
  const xHex = hex.slice(18, 34); // longitude, double LE
  const yHex = hex.slice(34, 50); // latitude, double LE
  const bufX = Buffer.from(xHex, 'hex');
  const bufY = Buffer.from(yHex, 'hex');
  return [bufX.readDoubleLE(0), bufY.readDoubleLE(0)];
}

function parseVal(v) {
  if (v === '\\N' || v === '') return null;
  return v;
}

function parseNum(v) {
  const s = parseVal(v);
  if (s == null) return null;
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

function parseInt(v) {
  const s = parseVal(v);
  if (s == null) return null;
  const n = Number(s);
  return Number.isFinite(n) ? Math.trunc(n) : null;
}

// ── SQL dump parser ──────────────────────────────────────────────────────────

function parseCopyBlock(sql, tableName) {
  const re = new RegExp(`COPY public\\.${tableName} \\([^)]+\\) FROM stdin;\\n([\\s\\S]*?)\\n\\\\\\.`, 'm');
  const m = sql.match(re);
  if (!m) return [];
  return m[1].split('\n').filter((l) => l.trim() !== '');
}

function parseColumns(sql, tableName) {
  const re = new RegExp(`COPY public\\.${tableName} \\(([^)]+)\\) FROM stdin;`, 'm');
  const m = sql.match(re);
  if (!m) return [];
  return m[1].split(',').map((c) => c.trim());
}

function rowsToObjects(sql, tableName) {
  const cols = parseColumns(sql, tableName);
  const lines = parseCopyBlock(sql, tableName);
  return lines.map((line) => {
    const fields = line.split('\t');
    const obj = {};
    for (let i = 0; i < cols.length; i++) {
      obj[cols[i]] = fields[i] ?? '\\N';
    }
    return obj;
  });
}

// ── category / type mapping (same as before) ─────────────────────────────────

const CATEGORY_IMAGE = {
  waterfall: 'https://images.pexels.com/photos/1450353/pexels-photo-1450353.jpeg',
  viewpoint: 'https://images.pexels.com/photos/1485894/pexels-photo-1485894.jpeg',
  cave: 'https://images.pexels.com/photos/240040/pexels-photo-240040.jpeg',
  hot_spring: 'https://images.pexels.com/photos/1450353/pexels-photo-1450353.jpeg',
  camp_site: 'https://images.pexels.com/photos/2662116/pexels-photo-2662116.jpeg',
  nature_reserve: 'https://images.pexels.com/photos/1671325/pexels-photo-1671325.jpeg',
  crater: 'https://images.pexels.com/photos/240040/pexels-photo-240040.jpeg',
  tea_plantation: 'https://images.pexels.com/photos/158607/cairn-fog-mountain-mystical-158607.jpeg',
  other: 'https://images.pexels.com/photos/2166559/pexels-photo-2166559.jpeg',
  culinary: 'https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg',
  culture: 'https://images.pexels.com/photos/1440476/pexels-photo-1440476.jpeg',
  shopping: 'https://images.pexels.com/photos/264636/pexels-photo-264636.jpeg',
};

const ACC_IMAGE = {
  hotel: 'https://images.pexels.com/photos/271624/pexels-photo-271624.jpeg',
  hostel: 'https://images.pexels.com/photos/271639/pexels-photo-271639.jpeg',
  resort: 'https://images.pexels.com/photos/1449729/pexels-photo-1449729.jpeg',
  apartment: 'https://images.pexels.com/photos/271624/pexels-photo-271624.jpeg',
  default: 'https://images.pexels.com/photos/164595/pexels-photo-164595.jpeg',
};

function mapAttractionType(slug) {
  switch (slug) {
    case 'waterfall':
    case 'viewpoint':
    case 'cave':
    case 'hot_spring':
    case 'camp_site':
    case 'nature_reserve':
    case 'crater':
    case 'tea_plantation':
      return 'natural';
    case 'shopping':
    case 'culinary':
      return 'entertainment';
    case 'culture':
      return 'cultural';
    default:
      return 'cultural';
  }
}

function mapAccommodationType(t) {
  switch (t) {
    case 'hostel':
      return 'hostel';
    case 'villa':
    case 'resort':
      return 'resort';
    case 'apartment':
      return 'apartment';
    default:
      return 'hotel';
  }
}

function mapPriceRange(level) {
  switch (level) {
    case 'free':
    case 'budget':
      return 1;
    case 'moderate':
      return 2;
    case 'expensive':
    case 'luxury':
      return 3;
    default:
      return 2;
  }
}

function fallbackDescription(name, address, categoryName) {
  if (address) return `${name} in Bandung, Indonesia — ${address}.`;
  return `${name} is a ${categoryName || 'hidden gem'} in Bandung, Indonesia.`;
}

// ── load SQL dump ────────────────────────────────────────────────────────────

// new_data.sql is UTF-16 LE (pg_dump on Windows); detect via BOM
const rawBuf = readFileSync(SQL_FILE);
let sql = rawBuf[0] === 0xff && rawBuf[1] === 0xfe
  ? rawBuf.toString('utf16le').replace(/^\uFEFF/, '')
  : rawBuf.toString('utf8');
// Normalize Windows line endings
sql = sql.replace(/\r\n/g, '\n');

const categoryRows = rowsToObjects(sql, 'categories');
const categoryMap = {};
for (const c of categoryRows) {
  const id = parseInt(c.id);
  categoryMap[id] = { name: parseVal(c.name), slug: parseVal(c.slug) };
}

const placeRows = rowsToObjects(sql, 'places');
const accRows = rowsToObjects(sql, 'accommodations');

console.log(`Parsed ${placeRows.length} places, ${accRows.length} accommodations, ${categoryRows.length} categories from new_data.sql`);

// ── build places ─────────────────────────────────────────────────────────────

const places = placeRows.map((r) => {
  const coords = decodeWkbPoint(r.location);
  const cat = categoryMap[parseInt(r.category_id)] || { name: 'Other', slug: 'other' };
  return {
    id: parseInt(r.id),
    slug: parseVal(r.slug),
    name: parseVal(r.name),
    description: parseVal(r.description),
    address: parseVal(r.address),
    category_id: parseInt(r.category_id),
    category_slug: cat.slug,
    category_name: cat.name,
    latitude: coords ? coords[1] : null,
    longitude: coords ? coords[0] : null,
    rating_avg: parseNum(r.rating_avg),
    rating_count: parseInt(r.rating_count) ?? 0,
    price_min: parseNum(r.price_min),
    price_max: parseNum(r.price_max),
    price_level: parseVal(r.price_level),
    is_hidden_gem: parseVal(r.is_hidden_gem) === 't',
  };
});

const placeCoords = places.map((p) => [p.latitude, p.longitude]);

function nearestPlace(fromCoord, excludeId, limit) {
  const scored = [];
  for (let i = 0; i < places.length; i++) {
    const p = places[i];
    if (p.id === excludeId) continue;
    if (placeCoords[i][0] == null || placeCoords[i][1] == null) continue;
    const d = haversineKm(fromCoord, placeCoords[i]);
    scored.push({ id: p.id, dist: d, index: i });
  }
  scored.sort((a, b) => a.dist - b.dist);
  return scored.slice(0, limit);
}

const destinations = places.map((p) => {
  const lat = p.latitude ?? -6.9175;
  const lng = p.longitude ?? 107.6191;
  return {
    id: `dest-${p.id}`,
    name: p.name,
    country: 'Indonesia',
    description:
      (p.description && String(p.description).trim()) ||
      fallbackDescription(p.name, p.address, p.category_name),
    image: CATEGORY_IMAGE[p.category_slug] || CATEGORY_IMAGE.other,
    rating: p.rating_avg ?? 0,
    ratingCount: p.rating_count,
    region: 'Asia',
    climate: 'Tropical',
    priceRange: mapPriceRange(p.price_level),
    coordinates: [lat, lng],
  };
});

// ── build accommodations ─────────────────────────────────────────────────────

const accommodationOut = accRows.map((a) => {
  const coords = decodeWkbPoint(a.location);
  const lat = coords ? coords[1] : -6.9175;
  const lng = coords ? coords[0] : 107.6191;
  const type = mapAccommodationType(a.type);
  const nearest = nearestPlace([lat, lng], null, 1);
  const destinationId = nearest[0] ? `dest-${nearest[0].id}` : 'dest-1';

  return {
    id: `acc-${a.id}`,
    name: parseVal(a.name),
    description:
      (a.description && String(a.description).trim()) ||
      `${a.name} is a ${type} in Bandung, Indonesia${a.address ? ` (${a.address})` : ''}.`,
    image: ACC_IMAGE[type] || ACC_IMAGE.default,
    price: parseNum(a.price_per_night_min) ?? 0,
    rating: parseNum(a.rating_avg) ?? 0,
    ratingCount: parseInt(a.rating_count) ?? 0,
    type,
    amenities: ['Wi-Fi', 'Parking', 'Air conditioning'],
    coordinates: [lat, lng],
    destinationId,
  };
});

// ── build attractions ────────────────────────────────────────────────────────

const attractions = [];
for (let i = 0; i < places.length; i++) {
  const dest = places[i];
  const destId = `dest-${dest.id}`;
  const from = [dest.latitude, dest.longitude];
  if (from[0] == null || from[1] == null) continue;
  const nearby = nearestPlace(from, dest.id, 5);
  for (const n of nearby) {
    const p = places[n.index];
    attractions.push({
      id: `attr-${dest.id}-${p.id}`,
      name: p.name,
      description:
        (p.description && String(p.description).trim()) ||
        fallbackDescription(p.name, p.address, p.category_name),
      image: CATEGORY_IMAGE[p.category_slug] || CATEGORY_IMAGE.other,
      type: mapAttractionType(p.category_slug),
      rating: p.rating_avg ?? 0,
      ratingCount: p.rating_count,
      price: p.price_min ?? null,
      coordinates: [p.latitude, p.longitude],
      destinationId: destId,
    });
  }
}

// ── emit TypeScript ──────────────────────────────────────────────────────────

function tsString(v) {
  return JSON.stringify(v ?? '');
}

function tsCoord(c) {
  return `[${Number(c[0])}, ${Number(c[1])}]`;
}

function tsNumber(v) {
  return Number.isFinite(v) ? String(v) : '0';
}

const destLines = destinations.map((d) => `  {
    id: ${tsString(d.id)},
    name: ${tsString(d.name)},
    country: ${tsString(d.country)},
    description: ${tsString(d.description)},
    image: ${tsString(d.image)},
    rating: ${tsNumber(d.rating)},
    ratingCount: ${tsNumber(d.ratingCount)},
    region: ${tsString(d.region)},
    climate: ${tsString(d.climate)},
    priceRange: ${d.priceRange} as const,
    coordinates: ${tsCoord(d.coordinates)}
  }`);

const accLines = accommodationOut.map((a) => `  {
    id: ${tsString(a.id)},
    name: ${tsString(a.name)},
    description: ${tsString(a.description)},
    image: ${tsString(a.image)},
    price: ${tsNumber(a.price)},
    rating: ${tsNumber(a.rating)},
    ratingCount: ${tsNumber(a.ratingCount)},
    type: ${tsString(a.type)},
    amenities: [${a.amenities.map((x) => tsString(x)).join(', ')}],
    coordinates: ${tsCoord(a.coordinates)},
    destinationId: ${tsString(a.destinationId)}
  }`);

const attrLines = attractions.map((a) => `  {
    id: ${tsString(a.id)},
    name: ${tsString(a.name)},
    description: ${tsString(a.description)},
    image: ${tsString(a.image)},
    type: ${tsString(a.type)},
    rating: ${tsNumber(a.rating)},
    ratingCount: ${tsNumber(a.ratingCount)},
    price: ${a.price != null ? tsNumber(a.price) : 'null'},
    coordinates: ${tsCoord(a.coordinates)},
    destinationId: ${tsString(a.destinationId)}
  }`);

const content = `import { Destination, Accommodation, Attraction } from '../types';

/**
 * Real Bandung data exported from new_data.sql (PostgreSQL dump).
 * Generated by scripts/export-bandung-data.mjs — do not edit by hand.
 */

export const destinations: Destination[] = [
${destLines.join(',\n')}
];

export const accommodations: Accommodation[] = [
${accLines.join(',\n')}
];

export const attractions: Attraction[] = [
${attrLines.join(',\n')}
];
`;

writeFileSync(OUT, content, 'utf8');
console.log(`Wrote ${OUT}`);
console.log(
  `destinations=${destinations.length} accommodations=${accommodationOut.length} attractions=${attractions.length}`,
);
