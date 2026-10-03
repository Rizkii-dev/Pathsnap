#!/usr/bin/env node
/**
 * Export Bandung data from local WSL Postgres (`pathsnap`) into
 * `src/data/mockData.ts`, keeping the existing Destination/Accommodation/Attraction shapes.
 *
 * Usage: node scripts/export-bandung-data.mjs
 */
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, '..');
const OUT = join(ROOT, 'src', 'data', 'mockData.ts');

function psql(sql) {
  const out = execFileSync(
    'wsl',
    ['-d', 'Ubuntu', '-u', 'root', '--', 'sudo', '-u', 'postgres', 'psql', '-d', 'pathsnap', '-t', '-A', '-v', 'ON_ERROR_STOP=1', '-c', sql],
    { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
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

function priceForAccommodation(type, starClass) {
  const base = {
    hotel: 45,
    hostel: 18,
    resort: 90,
    apartment: 60,
  }[type] ?? 45;
  if (starClass) return Math.round(base * (0.7 + starClass * 0.15) * 10) / 10;
  return base;
}

function fallbackDescription(name, address, categoryName, country) {
  if (address) return `${name} in Bandung, Indonesia — ${address}.`;
  return `${name} is a ${categoryName || 'hidden gem'} in Bandung, Indonesia.`;
}

function stableRating(id) {
  // Deterministic 4.0–4.9 placeholder when DB has no rating
  return Math.round((4 + ((id * 37) % 10) / 10) * 10) / 10;
}

const places = psql(`
  SELECT coalesce(json_agg(json_build_object(
    'id', p.id,
    'slug', p.slug,
    'name', p.name,
    'description', p.description,
    'address', p.address,
    'category_id', p.category_id,
    'category_slug', c.slug,
    'category_name', c.name,
    'latitude', p.latitude,
    'longitude', p.longitude,
    'rating_avg', p.rating_avg,
    'price_level', p.price_level,
    'is_hidden_gem', p.is_hidden_gem
  ) ORDER BY p.id), '[]'::json)
  FROM places p
  LEFT JOIN categories c ON c.id = p.category_id
  WHERE p.is_active
`);

const accommodations = psql(`
  SELECT coalesce(json_agg(json_build_object(
    'id', a.id,
    'slug', a.slug,
    'name', a.name,
    'description', a.description,
    'type', a.type::text,
    'star_class', a.star_class,
    'address', a.address,
    'latitude', a.latitude,
    'longitude', a.longitude,
    'rating_avg', a.rating_avg,
    'price_per_night_min', a.price_per_night_min,
    'price_per_night_max', a.price_per_night_max,
    'price_level', a.price_level::text,
    'amenities', (
      SELECT coalesce(json_agg(am.name ORDER BY am.name), '[]'::json)
      FROM accommodation_amenities aa
      JOIN amenities am ON am.id = aa.amenity_id
      WHERE aa.accommodation_id = a.id
    )
  ) ORDER BY a.id), '[]'::json)
  FROM accommodations a
  WHERE a.is_active
`);

console.log(`Loaded ${places.length} places, ${accommodations.length} accommodations`);

const placeCoords = places.map((p) => [Number(p.latitude), Number(p.longitude)]);

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
  const lat = Number(p.latitude) ?? -6.9175;
  const lng = Number(p.longitude) ?? 107.6191;
  return {
    id: `dest-${p.id}`,
    name: p.name,
    country: 'Indonesia',
    description:
      (p.description && String(p.description).trim()) ||
      fallbackDescription(p.name, p.address, p.category_name, 'Indonesia'),
    image: CATEGORY_IMAGE[p.category_slug] || CATEGORY_IMAGE.other,
    rating: p.rating_avg != null ? Number(p.rating_avg) : stableRating(p.id),
    region: 'Asia',
    climate: 'Tropical',
    priceRange: mapPriceRange(p.price_level),
    coordinates: [lat, lng],
    // extras kept out of TS type but useful later
    _category: p.category_name || 'Other',
    _address: p.address || '',
    _hiddenGem: Boolean(p.is_hidden_gem),
  };
});

const accommodationOut = accommodations.map((a) => {
  const lat = Number(a.latitude) ?? -6.9175;
  const lng = Number(a.longitude) ?? 107.6191;
  const type = mapAccommodationType(a.type);
  const nearest = nearestPlace([lat, lng], null, 1);
  const destinationId = nearest[0] ? `dest-${nearest[0].id}` : 'dest-1';
  const amenities =
    Array.isArray(a.amenities) && a.amenities.length > 0
      ? a.amenities
      : type === 'hostel'
        ? ['Wi-Fi', 'Shared kitchen', 'Lockers']
        : type === 'resort'
          ? ['Pool', 'Restaurant', 'Wi-Fi']
          : type === 'apartment'
            ? ['Kitchen', 'Wi-Fi', 'Laundry']
            : ['Wi-Fi', 'Parking', 'Air conditioning'];

  return {
    id: `acc-${a.id}`,
    name: a.name,
    description:
      (a.description && String(a.description).trim()) ||
      `${a.name} is a ${type} in Bandung, Indonesia${a.address ? ` (${a.address})` : ''}.`,
    image: ACC_IMAGE[type] || ACC_IMAGE.default,
    price:
      a.price_per_night_min != null
        ? Number(a.price_per_night_min)
        : priceForAccommodation(type, a.star_class),
    rating: a.rating_avg != null ? Number(a.rating_avg) : stableRating(a.id + 1000),
    type,
    amenities,
    coordinates: [lat, lng],
    destinationId,
  };
});

// For each destination, expose ~5 nearby other places as attractions ("things to do").
const attractions = [];
for (let i = 0; i < places.length; i++) {
  const dest = places[i];
  const destId = `dest-${dest.id}`;
  const from = [Number(dest.latitude), Number(dest.longitude)];
  const nearby = nearestPlace(from, dest.id, 5);
  for (const n of nearby) {
    const p = places[n.index];
    attractions.push({
      id: `attr-${dest.id}-${p.id}`,
      name: p.name,
      description:
        (p.description && String(p.description).trim()) ||
        fallbackDescription(p.name, p.address, p.category_name, 'Indonesia'),
      image: CATEGORY_IMAGE[p.category_slug] || CATEGORY_IMAGE.other,
      type: mapAttractionType(p.category_slug),
      rating: p.rating_avg != null ? Number(p.rating_avg) : stableRating(p.id + 2000),
      price: null,
      coordinates: [Number(p.latitude), Number(p.longitude)],
      destinationId: destId,
    });
  }
}

function tsString(v) {
  return JSON.stringify(v ?? '');
}

function tsCoord(c) {
  return `[${Number(c[0])}, ${Number(c[1])}]`;
}

function tsNumber(v) {
  return Number.isFinite(v) ? String(v) : '0';
}

function tsStringArray(arr) {
  return `[${arr.map((x) => tsString(x)).join(', ')}]`;
}

function tsPriceRange(v) {
  return String(v);
}

const destLines = destinations.map((d) => `  {
    id: ${tsString(d.id)},
    name: ${tsString(d.name)},
    country: ${tsString(d.country)},
    description: ${tsString(d.description)},
    image: ${tsString(d.image)},
    rating: ${tsNumber(d.rating)},
    region: ${tsString(d.region)},
    climate: ${tsString(d.climate)},
    priceRange: ${tsPriceRange(d.priceRange)} as const,
    coordinates: ${tsCoord(d.coordinates)}
  }`);

const accLines = accommodationOut.map((a) => `  {
    id: ${tsString(a.id)},
    name: ${tsString(a.name)},
    description: ${tsString(a.description)},
    image: ${tsString(a.image)},
    price: ${tsNumber(a.price)},
    rating: ${tsNumber(a.rating)},
    type: ${tsString(a.type)},
    amenities: ${tsStringArray(a.amenities)},
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
    price: null,
    coordinates: ${tsCoord(a.coordinates)},
    destinationId: ${tsString(a.destinationId)}
  }`);

const content = `import { Destination, Accommodation, Attraction } from '../types';

/**
 * Real Bandung data exported from PostgreSQL (pathsnap DB).
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
