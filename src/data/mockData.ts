import { Destination, Accommodation, Attraction } from '../types';

export const destinations: Destination[] = [
  {
    id: "dest-1",
    name: "Bali",
    country: "Indonesia",
    description: "A beautiful island known for its beaches, volcanic mountains, and rich culture.",
    image: "https://images.pexels.com/photos/2166559/pexels-photo-2166559.jpeg",
    rating: 4.7,
    region: "Asia",
    climate: "Tropical",
    priceRange: 2,
    coordinates: [-8.4095, 115.1889]
  },
  {
    id: "dest-2",
    name: "Paris",
    country: "France",
    description: "The City of Light, known for the Eiffel Tower, art, fashion, and cuisine.",
    image: "https://images.pexels.com/photos/699466/pexels-photo-699466.jpeg",
    rating: 4.5,
    region: "Europe",
    climate: "Temperate",
    priceRange: 3,
    coordinates: [48.8566, 2.3522]
  },
  {
    id: "dest-3",
    name: "New York",
    country: "USA",
    description: "The Big Apple, a vibrant metropolis with iconic skyscrapers and diverse culture.",
    image: "https://images.pexels.com/photos/802024/pexels-photo-802024.jpeg",
    rating: 4.6,
    region: "North America",
    climate: "Seasonal",
    priceRange: 3,
    coordinates: [40.7128, -74.0060]
  },
  {
    id: "dest-4",
    name: "Kyoto",
    country: "Japan",
    description: "A city known for its classical Buddhist temples, gardens, and imperial palaces.",
    image: "https://images.pexels.com/photos/1440476/pexels-photo-1440476.jpeg",
    rating: 4.8,
    region: "Asia",
    climate: "Seasonal",
    priceRange: 2,
    coordinates: [35.0116, 135.7681]
  },
  {
    id: "dest-5",
    name: "Cairo",
    country: "Egypt",
    description: "Home to the ancient Pyramids of Giza and the Egyptian Museum.",
    image: "https://images.pexels.com/photos/3290075/pexels-photo-3290075.jpeg",
    rating: 4.3,
    region: "Africa",
    climate: "Desert",
    priceRange: 1,
    coordinates: [30.0444, 31.2357]
  },
  {
    id: "dest-6",
    name: "Sydney",
    country: "Australia",
    description: "Famous for its Opera House, harbor, and beautiful beaches.",
    image: "https://images.pexels.com/photos/1878293/pexels-photo-1878293.jpeg",
    rating: 4.7,
    region: "Oceania",
    climate: "Temperate",
    priceRange: 3,
    coordinates: [-33.8688, 151.2093]
  }
];

export const accommodations: Accommodation[] = [
  {
    id: "acc-1",
    name: "Bali Beach Resort",
    description: "Luxury beachfront resort with stunning ocean views.",
    image: "https://images.pexels.com/photos/1449729/pexels-photo-1449729.jpeg",
    price: 250,
    rating: 4.8,
    type: "resort",
    amenities: ["Pool", "Spa", "Restaurant", "Beach access"],
    coordinates: [-8.4105, 115.1901],
    destinationId: "dest-1"
  },
  {
    id: "acc-2",
    name: "Ubud Jungle Retreat",
    description: "Peaceful retreat surrounded by lush jungle and rice terraces.",
    image: "https://images.pexels.com/photos/731082/pexels-photo-731082.jpeg",
    price: 180,
    rating: 4.6,
    type: "resort",
    amenities: ["Pool", "Restaurant", "Yoga classes", "Spa"],
    coordinates: [-8.5069, 115.2625],
    destinationId: "dest-1"
  },
  {
    id: "acc-3",
    name: "Le Petit Hôtel",
    description: "Charming boutique hotel in the heart of Paris.",
    image: "https://images.pexels.com/photos/2029719/pexels-photo-2029719.jpeg",
    price: 300,
    rating: 4.5,
    type: "hotel",
    amenities: ["Breakfast", "Wi-Fi", "Concierge", "Room service"],
    coordinates: [48.8632, 2.3518],
    destinationId: "dest-2"
  },
  {
    id: "acc-4",
    name: "Manhattan Suites",
    description: "Modern apartments in downtown Manhattan.",
    image: "https://images.pexels.com/photos/271624/pexels-photo-271624.jpeg",
    price: 350,
    rating: 4.4,
    type: "apartment",
    amenities: ["Kitchen", "Gym", "Wi-Fi", "Laundry"],
    coordinates: [40.7135, -74.0068],
    destinationId: "dest-3"
  },
  {
    id: "acc-5",
    name: "Traditional Ryokan",
    description: "Experience traditional Japanese hospitality in this peaceful ryokan.",
    image: "https://images.pexels.com/photos/6492397/pexels-photo-6492397.jpeg",
    price: 220,
    rating: 4.9,
    type: "hotel",
    amenities: ["Onsen", "Traditional meals", "Garden", "Tatami rooms"],
    coordinates: [35.0123, 135.7675],
    destinationId: "dest-4"
  }
];

export const attractions: Attraction[] = [
  {
    id: "attr-1",
    name: "Tanah Lot Temple",
    description: "Ancient sea temple perched on a rock formation.",
    image: "https://images.pexels.com/photos/2166553/pexels-photo-2166553.jpeg",
    type: "cultural",
    rating: 4.7,
    price: 10,
    coordinates: [-8.6213, 115.0868],
    destinationId: "dest-1"
  },
  {
    id: "attr-2",
    name: "Ubud Monkey Forest",
    description: "Natural sanctuary home to over 700 monkeys.",
    image: "https://images.pexels.com/photos/3428860/pexels-photo-3428860.jpeg",
    type: "natural",
    rating: 4.5,
    price: 15,
    coordinates: [-8.5189, 115.2589],
    destinationId: "dest-1"
  },
  {
    id: "attr-3",
    name: "Eiffel Tower",
    description: "Iconic wrought-iron lattice tower on the Champ de Mars.",
    image: "https://images.pexels.com/photos/699466/pexels-photo-699466.jpeg",
    type: "historical",
    rating: 4.8,
    price: 25,
    coordinates: [48.8584, 2.2945],
    destinationId: "dest-2"
  },
  {
    id: "attr-4",
    name: "Louvre Museum",
    description: "World's largest art museum and historic monument.",
    image: "https://images.pexels.com/photos/2363/france-landmark-lights-night.jpg",
    type: "cultural",
    rating: 4.9,
    price: 20,
    coordinates: [48.8606, 2.3376],
    destinationId: "dest-2"
  },
  {
    id: "attr-5",
    name: "Central Park",
    description: "Urban park in Manhattan known for its landscape design.",
    image: "https://images.pexels.com/photos/2860705/pexels-photo-2860705.jpeg",
    type: "natural",
    rating: 4.8,
    price: null,
    coordinates: [40.7812, -73.9665],
    destinationId: "dest-3"
  },
  {
    id: "attr-6",
    name: "Fushimi Inari Shrine",
    description: "Famous shrine with thousands of vermilion torii gates.",
    image: "https://images.pexels.com/photos/1440476/pexels-photo-1440476.jpeg",
    type: "cultural",
    rating: 4.9,
    price: null,
    coordinates: [34.9671, 135.7726],
    destinationId: "dest-4"
  }
];