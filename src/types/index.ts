export interface Destination {
  id: string;
  name: string;
  country: string;
  description: string;
  image: string;
  rating: number;
  region: string;
  climate: string;
  priceRange: 1 | 2 | 3; // 1 = Budget, 2 = Mid-range, 3 = Luxury
  coordinates: [number, number]; // [latitude, longitude]
}

export interface Accommodation {
  id: string;
  name: string;
  description: string;
  image: string;
  price: number;
  rating: number;
  type: 'hotel' | 'hostel' | 'resort' | 'apartment';
  amenities: string[];
  coordinates: [number, number];
  destinationId: string;
}

export interface Attraction {
  id: string;
  name: string;
  description: string;
  image: string;
  type: 'cultural' | 'natural' | 'entertainment' | 'historical';
  rating: number;
  price: number | null; // null if free
  coordinates: [number, number];
  destinationId: string;
}

export interface RoutePoint {
  id: string;
  order: number;
  destinationId: string;
  selectedAccommodationId?: string;
  selectedAttractions: string[];
  notes?: string;
  stayDuration: number; // in days
}

export interface Itinerary {
  id: string;
  name: string;
  routePoints: RoutePoint[];
  totalCost: number;
  totalDuration: number;
  createdAt: Date;
}

export type FilterOptions = {
  region?: string;
  climate?: string;
  priceRange?: number[];
  searchQuery?: string;
};