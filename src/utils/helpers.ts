import { FilterOptions, Destination, RoutePoint, RadiusUnit, UserLocation } from '../types';

/** Great-circle distance in meters between two [lat, lng] points. */
export const haversineMeters = (
  a: [number, number],
  b: [number, number],
): number => {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b[0] - a[0]);
  const dLon = toRad(b[1] - a[1]);
  const lat1 = toRad(a[0]);
  const lat2 = toRad(b[0]);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
};

export const haversineKm = (a: [number, number], b: [number, number]): number =>
  haversineMeters(a, b) / 1000;

/** True when `point` lies within `radiusMeters` of `origin`. */
export const isWithinRadius = (
  origin: [number, number],
  point: [number, number],
  radiusMeters: number,
): boolean => haversineMeters(origin, point) <= radiusMeters;

export const formatRadiusLabel = (radiusMeters: number, unit: RadiusUnit): string => {
  if (unit === 'km') {
    const km = radiusMeters / 1000;
    return `${Number.isInteger(km) ? km : km.toFixed(1)} km`;
  }
  return `${Math.round(radiusMeters)} m`;
};

export const toRadiusMeters = (value: number, unit: RadiusUnit): number =>
  unit === 'km' ? value * 1000 : value;

export const describeUserLocation = (location: UserLocation | null): string => {
  if (!location) return 'Not set';
  const accuracy = location.accuracyM != null ? ` (±${Math.round(location.accuracyM)}m)` : '';
  return `${location.label}${accuracy}`;
};

export const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(amount);
};

/** Best-effort human location: address after an em dash in the description, else city/country. */
export const getPlaceLocation = (destination: Destination): string => {
  const dashIndex = destination.description.indexOf('—');
  if (dashIndex !== -1) {
    const address = destination.description.slice(dashIndex + 1).trim().replace(/\.$/, '');
    if (address) return address;
  }
  return destination.country === 'Indonesia'
    ? 'Bandung, Indonesia'
    : destination.country;
};

/** Resolve a place name (from the AI planner) to a catalog destination. */
export const findDestinationByName = (
  destinations: Destination[],
  name: string,
): Destination | undefined => {
  const needle = String(name || '').trim().toLowerCase();
  if (!needle) return undefined;
  return (
    destinations.find(item => item.name.toLowerCase() === needle) ||
    destinations.find(item =>
      needle.includes(item.name.toLowerCase()) || item.name.toLowerCase().includes(needle),
    )
  );
};

export const calculateTotalCost = (routePoints: RoutePoint[], accommodations: any[], attractions: any[]): number => {
  let totalCost = 0;
  
  routePoints.forEach(point => {
    // Add accommodation costs
    if (point.selectedAccommodationId) {
      const accommodation = accommodations.find(acc => acc.id === point.selectedAccommodationId);
      if (accommodation) {
        totalCost += accommodation.price * point.stayDuration;
      }
    }
    
    // Add attraction costs
    point.selectedAttractions.forEach(attrId => {
      const attraction = attractions.find(attr => attr.id === attrId);
      if (attraction && attraction.price) {
        totalCost += attraction.price;
      }
    });
  });
  
  return totalCost;
};

export const calculateTotalDuration = (routePoints: RoutePoint[]): number => {
  return routePoints.reduce((total, point) => total + point.stayDuration, 0);
};

export const filterDestinations = (destinations: Destination[], filters: FilterOptions): Destination[] => {
  return destinations.filter(dest => {
    // Filter by region
    if (filters.region && dest.region !== filters.region) {
      return false;
    }
    
    // Filter by climate
    if (filters.climate && dest.climate !== filters.climate) {
      return false;
    }
    
    // Filter by price range
    if (filters.priceRange && filters.priceRange.length > 0) {
      if (!filters.priceRange.includes(dest.priceRange)) {
        return false;
      }
    }
    
    // Filter by search query
    if (filters.searchQuery) {
      const query = filters.searchQuery.toLowerCase();
      return (
        dest.name.toLowerCase().includes(query) ||
        dest.country.toLowerCase().includes(query) ||
        dest.description.toLowerCase().includes(query)
      );
    }
    
    return true;
  });
};

export const generateUniqueId = (): string => {
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
};