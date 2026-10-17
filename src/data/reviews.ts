import { Review } from '../types';

/**
 * Dummy review data for local development.
 * Handcrafted for a few popular spots; the rest are generated deterministically
 * so every destination has stable sample reviews without a live backend.
 */

const AUTHORS = [
  'Ayu Prameswari',
  'Budi Santoso',
  'Clara Wijaya',
  'Dimas Pratama',
  'Eka Rahmawati',
  'Farhan Nugraha',
  'Gita Lestari',
  'Hendra Gunawan',
  'Indah Permata',
  'Joko Susilo',
  'Kartika Dewi',
  'Lukman Hakim',
];

const POSITIVE_COMMENTS = [
  'Great spot to spend an hour or two. Clean, well-kept, and easy to reach.',
  'Really enjoyed the atmosphere here. Worth adding to your Bandung route.',
  'Nice place for photos and a short walk. Staff were friendly.',
  'One of the highlights of our trip. Would come back with friends.',
  'Affordable and interesting. Good stop if you are exploring the city center.',
  'The kids loved it. Plenty of shade and space to relax.',
  'Well organized and not too crowded on weekdays.',
  'Beautiful surroundings and a calm vibe. Perfect morning visit.',
];

const MIXED_COMMENTS = [
  'Solid visit overall, though it gets busy on weekends.',
  'Interesting place, but facilities could use a bit of upkeep.',
  'Good for a quick stop. Nothing fancy, but worth seeing.',
  'Nice enough for a short visit. Parking was a bit tight.',
  'Enjoyable, just plan around the midday heat.',
  'Worth a look if you are nearby. Manage your expectations on a short visit.',
];

/** Deterministic hash so each destination always gets the same dummy reviews. */
const hashId = (id: string): number => {
  let hash = 0;
  for (let i = 0; i < id.length; i += 1) {
    hash = (hash * 31 + id.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
};

/** Hand-picked reviews for well-known places (keyed by destination id). */
const CURATED_REVIEWS: Record<string, Array<Pick<Review, 'author' | 'rating' | 'comment' | 'date'>>> = {
  'dest-29': [
    { author: 'Sarah Mitchell', rating: 5, comment: 'Iconic landmark. The museum inside is small but informative, and the architecture is stunning.', date: '2025-11-12' },
    { author: 'Rizky Ramadhan', rating: 4, comment: 'Must-visit when in Bandung. Go early to avoid the tour groups.', date: '2025-10-03' },
    { author: 'Emily Chen', rating: 4, comment: 'Beautiful building and nice photo spots around the lawn.', date: '2025-09-18' },
  ],
  'dest-92': [
    { author: 'Andi Kurniawan', rating: 5, comment: 'The view from the front lawn is classic Bandung. Great for sunset.', date: '2025-11-01' },
    { author: 'Maya Putri', rating: 4, comment: 'Free to walk around the exterior. Very photogenic.', date: '2025-08-22' },
  ],
  'dest-122': [
    { author: 'Tom Bradley', rating: 4, comment: 'Lively city square. Synthetic grass is surprisingly comfortable for a picnic.', date: '2025-10-27' },
    { author: 'Nadia Safitri', rating: 5, comment: 'Perfect place to people-watch and try street snacks nearby.', date: '2025-09-05' },
    { author: 'Bagus Setiawan', rating: 4, comment: 'Kids had fun running around. Bring a hat — shade is limited at noon.', date: '2025-07-14' },
  ],
  'dest-125': [
    { author: 'Laura Nguyen', rating: 3, comment: 'Classic zoo experience. Some enclosures feel dated, but the grounds are green and spacious.', date: '2025-10-10' },
    { author: 'Fajar Nugroho', rating: 4, comment: 'Good half-day outing with children. Affordable tickets.', date: '2025-08-30' },
    { author: 'Siti Aminah', rating: 4, comment: 'Lots of trees and walking paths. Weekday mornings are best.', date: '2025-06-21' },
  ],
  'dest-129': [
    { author: 'Dr. Rina Hartono', rating: 5, comment: 'Excellent geology collection. The mineral hall alone is worth the trip.', date: '2025-11-08' },
    { author: 'Kevin O\'Brien', rating: 4, comment: 'Educational and well laid out. English labels on most exhibits.', date: '2025-09-29' },
    { author: 'Dewi Lestari', rating: 4, comment: 'A quiet, fascinating museum away from the main tourist crowds.', date: '2025-05-16' },
  ],
  'dest-42': [
    { author: 'Chris Morgan', rating: 5, comment: 'Sunday car-free day is amazing — food stalls, music, and the whole street comes alive.', date: '2025-11-16' },
    { author: 'Putri Handayani', rating: 4, comment: 'So much energy. Come hungry and try the local snacks.', date: '2025-10-06' },
  ],
};

const generateReviews = (destinationId: string, name: string): Review[] => {
  const curated = CURATED_REVIEWS[destinationId];
  if (curated) {
    return curated.map((review, index) => ({
      id: `${destinationId}-review-${index + 1}`,
      destinationId,
      ...review,
    }));
  }

  const seed = hashId(destinationId);
  const count = 3 + (seed % 3); // 3–5 reviews
  const reviews: Review[] = [];

  for (let i = 0; i < count; i += 1) {
    const author = AUTHORS[(seed + i * 7) % AUTHORS.length];
    const usePositive = (seed + i) % 3 !== 0;
    const pool = usePositive ? POSITIVE_COMMENTS : MIXED_COMMENTS;
    const comment = pool[(seed + i * 3) % pool.length];
    const rating = usePositive ? 4 + ((seed + i) % 2) : 3 + ((seed + i) % 2);
    const month = 1 + ((seed + i * 5) % 12);
    const day = 1 + ((seed + i * 3) % 28);

    reviews.push({
      id: `${destinationId}-review-${i + 1}`,
      destinationId,
      author,
      rating,
      comment: `${comment} (${name})`,
      date: `2025-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`,
    });
  }

  return reviews;
};

const reviewCache = new Map<string, Review[]>();

/** Dummy reviews for a destination — stable across reloads. */
export const getReviews = (destinationId: string, name = 'this place'): Review[] => {
  const cached = reviewCache.get(destinationId);
  if (cached) return cached;
  const reviews = generateReviews(destinationId, name);
  reviewCache.set(destinationId, reviews);
  return reviews;
};

/** Average of dummy review ratings (falls back to the place rating). */
export const getReviewSummary = (destinationId: string, name?: string, fallbackRating?: number) => {
  const reviews = getReviews(destinationId, name);
  const average = reviews.length > 0
    ? reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length
    : (fallbackRating ?? 0);
  return {
    average: Math.round(average * 10) / 10,
    count: reviews.length,
    reviews,
  };
};
