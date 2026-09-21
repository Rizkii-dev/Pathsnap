import { FilterOptions, Destination, RoutePoint } from '../types';

export const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
  }).format(amount);
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