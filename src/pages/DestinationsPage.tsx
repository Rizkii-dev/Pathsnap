import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import DestinationCard from '../components/destinations/DestinationCard';
import FilterBar from '../components/destinations/FilterBar';
import { destinations } from '../data/mockData';
import { filterDestinations } from '../utils/helpers';
import { FilterOptions } from '../types';

const DestinationsPage: React.FC = () => {
  const [filteredDestinations, setFilteredDestinations] = useState(destinations);
  const [filters, setFilters] = useState<FilterOptions>({});
  
  useEffect(() => {
    setFilteredDestinations(filterDestinations(destinations, filters));
  }, [filters]);
  
  const handleFilterChange = (newFilters: FilterOptions) => {
    setFilters(newFilters);
  };
  
  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8 text-center">
        <h1 className="text-3xl md:text-4xl font-bold mb-3">Explore Destinations</h1>
        <p className="text-gray-600 max-w-2xl mx-auto">
          Discover amazing places around the world to add to your travel route. Filter by region, climate, or budget to find your perfect destinations.
        </p>
      </div>
      
      <FilterBar onFilterChange={handleFilterChange} />
      
      {filteredDestinations.length === 0 ? (
        <div className="text-center py-12">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="text-gray-500"
          >
            <svg 
              className="w-16 h-16 mx-auto mb-4 text-gray-300" 
              fill="none" 
              stroke="currentColor" 
              viewBox="0 0 24 24" 
              xmlns="http://www.w3.org/2000/svg"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
            </svg>
            <h3 className="text-xl font-semibold mb-2">No destinations found</h3>
            <p>Try adjusting your search criteria</p>
          </motion.div>
        </div>
      ) : (
        <motion.div 
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        >
          {filteredDestinations.map((destination) => (
            <DestinationCard key={destination.id} destination={destination} />
          ))}
        </motion.div>
      )}
    </div>
  );
};

export default DestinationsPage;