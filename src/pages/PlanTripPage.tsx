import React, { useState, useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import MapView from '../components/planner/MapView';
import RouteSidebar from '../components/planner/RouteSidebar';
import AITripAssistant from '../components/planner/AITripAssistant';
import { destinations, accommodations, attractions } from '../data/mockData';
import { RoutePoint, Destination } from '../types';
import { generateUniqueId, calculateTotalCost, calculateTotalDuration } from '../utils/helpers';
import { TripPlanResponse } from '../components/planner/AITripAssistant';

const PlanTripPage: React.FC = () => {
  const location = useLocation();
  const initialDestinationId = location.state?.destinationId;
  
  const [selectedDestinations, setSelectedDestinations] = useState<RoutePoint[]>([]);
  const [totalCost, setTotalCost] = useState(0);
  const [totalDuration, setTotalDuration] = useState(0);
  
  // If a destination ID is provided in location state, add it to the route
  useEffect(() => {
    if (initialDestinationId) {
      const destination = destinations.find(d => d.id === initialDestinationId);
      if (destination && !selectedDestinations.some(d => d.destinationId === initialDestinationId)) {
        handleAddDestination(destination);
      }
    }
  }, [initialDestinationId]);
  
  // Calculate totals when route changes
  useEffect(() => {
    setTotalCost(calculateTotalCost(selectedDestinations, accommodations, attractions));
    setTotalDuration(calculateTotalDuration(selectedDestinations));
  }, [selectedDestinations]);
  
  const handleAddDestination = (destination: Destination) => {
    // Check if destination is already in the route
    if (selectedDestinations.some(d => d.destinationId === destination.id)) {
      // Maybe show a toast or message
      console.log(`${destination.name} is already in your route.`);
      return;
    }
    
    // Add new destination to the route
    setSelectedDestinations([
      ...selectedDestinations,
      {
        id: generateUniqueId(),
        order: selectedDestinations.length,
        destinationId: destination.id,
        selectedAttractions: [],
        stayDuration: 2, // Default stay duration
      }
    ]);
  };
  
  const handleRemoveDestination = (index: number) => {
    const updatedDestinations = [...selectedDestinations];
    updatedDestinations.splice(index, 1);
    
    // Update order for remaining destinations
    const reorderedDestinations = updatedDestinations.map((dest, i) => ({
      ...dest,
      order: i
    }));
    
    setSelectedDestinations(reorderedDestinations);
  };
  
  const handleUpdateDuration = (index: number, duration: number) => {
    const updatedDestinations = [...selectedDestinations];
    updatedDestinations[index] = {
      ...updatedDestinations[index],
      stayDuration: duration
    };
    
    setSelectedDestinations(updatedDestinations);
  };
  
  const handleSelectAccommodation = (routePointIndex: number, accommodationId: string) => {
    const updatedDestinations = [...selectedDestinations];
    
    // Toggle accommodation selection
    if (updatedDestinations[routePointIndex].selectedAccommodationId === accommodationId) {
      updatedDestinations[routePointIndex].selectedAccommodationId = undefined;
    } else {
      updatedDestinations[routePointIndex].selectedAccommodationId = accommodationId;
    }
    
    setSelectedDestinations(updatedDestinations);
  };
  
  const handleToggleAttraction = (routePointIndex: number, attractionId: string) => {
    const updatedDestinations = [...selectedDestinations];
    const routePoint = updatedDestinations[routePointIndex];
    
    // Toggle attraction selection
    if (routePoint.selectedAttractions.includes(attractionId)) {
      routePoint.selectedAttractions = routePoint.selectedAttractions.filter(id => id !== attractionId);
    } else {
      routePoint.selectedAttractions.push(attractionId);
    }
    
    setSelectedDestinations(updatedDestinations);
  };

  const handleApplyPlan = (plan: TripPlanResponse) => {
    const plannedRoute = plan.stops.flatMap(stop => {
      const destination = destinations.find(item =>
        item.name.toLowerCase() === stop.destination.toLowerCase(),
      );
      const accommodation = accommodations.find(item =>
        item.name.toLowerCase() === stop.hotel.toLowerCase() && item.destinationId === destination?.id,
      );

      if (!destination) return [];

      return [{
        id: generateUniqueId(),
        order: 0,
        destinationId: destination.id,
        selectedAccommodationId: accommodation?.id,
        selectedAttractions: [],
        stayDuration: stop.nights,
      }];
    });

    setSelectedDestinations(currentRoute => {
      const existingDestinationIds = new Set(currentRoute.map(routePoint => routePoint.destinationId));
      const newRoutePoints = plannedRoute.filter(routePoint => {
        if (existingDestinationIds.has(routePoint.destinationId)) return false;
        existingDestinationIds.add(routePoint.destinationId);
        return true;
      });

      return [...currentRoute, ...newRoutePoints].map((routePoint, index) => ({
        ...routePoint,
        order: index,
      }));
    });
  };
  
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-3xl md:text-4xl font-bold mb-3">Plan Your Trip</h1>
        <p className="text-gray-600 max-w-2xl">
          Create your custom travel route by selecting destinations on the map. We'll recommend accommodations and attractions for each stop on your journey.
        </p>
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 h-[600px]">
          <MapView 
            destinations={destinations}
            selectedDestinations={selectedDestinations}
            onDestinationSelect={handleAddDestination}
          />
        </div>
        <div className="flex flex-col gap-6">
          <AITripAssistant
            selectedDestinations={selectedDestinations}
            destinations={destinations}
            accommodations={accommodations}
            attractions={attractions}
            onApplyPlan={handleApplyPlan}
          />
          <div className="h-[600px]">
            <RouteSidebar 
              selectedDestinations={selectedDestinations}
              destinations={destinations}
              accommodations={accommodations}
              attractions={attractions}
              onRemoveDestination={handleRemoveDestination}
              onUpdateDuration={handleUpdateDuration}
              onSelectAccommodation={handleSelectAccommodation}
              onToggleAttraction={handleToggleAttraction}
              totalCost={totalCost}
              totalDuration={totalDuration}
            />
          </div>
        </div>
      </div>
    </div>
  );
};

export default PlanTripPage;