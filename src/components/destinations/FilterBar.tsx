import React, { useState } from 'react';
import { FilterOptions } from '../../types';
import { Search, Filter, X } from 'lucide-react';
import Button from '../ui/Button';

interface FilterBarProps {
  onFilterChange: (filters: FilterOptions) => void;
}

const FilterBar: React.FC<FilterBarProps> = ({ onFilterChange }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState<FilterOptions>({});
  
  const regions = ['Asia', 'Europe', 'North America', 'South America', 'Africa', 'Oceania'];
  const climates = ['Tropical', 'Temperate', 'Seasonal', 'Desert', 'Mediterranean', 'Polar'];
  
  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setSearchQuery(value);
    onFilterChange({ ...filters, searchQuery: value });
  };
  
  const handleFilterChange = (key: keyof FilterOptions, value: any) => {
    const updatedFilters = { ...filters, [key]: value };
    setFilters(updatedFilters);
    onFilterChange(updatedFilters);
  };
  
  const handlePriceRangeChange = (level: number) => {
    let priceRange = [...(filters.priceRange || [])];
    
    if (priceRange.includes(level)) {
      priceRange = priceRange.filter(price => price !== level);
    } else {
      priceRange.push(level);
    }
    
    handleFilterChange('priceRange', priceRange);
  };
  
  const clearFilters = () => {
    setFilters({});
    setSearchQuery('');
    onFilterChange({});
  };
  
  // Determine if any filter is active
  const hasActiveFilters = searchQuery || filters.region || filters.climate || (filters.priceRange && filters.priceRange.length > 0);
  
  return (
    <div className="bg-white rounded-lg shadow-md mb-8">
      <div className="p-4 border-b">
        <div className="relative">
          <Search size={18} className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-500" />
          <input
            type="text"
            placeholder="Search destinations..."
            value={searchQuery}
            onChange={handleSearchChange}
            className="w-full pl-10 pr-12 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
          <button
            onClick={() => setShowFilters(!showFilters)}
            className="absolute right-3 top-1/2 transform -translate-y-1/2"
          >
            <Filter size={18} className={`text-gray-500 ${showFilters ? 'text-teal-600' : ''}`} />
          </button>
        </div>
      </div>
      
      {showFilters && (
        <div className="p-4 border-b">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div>
              <h3 className="font-medium mb-2">Region</h3>
              <div className="flex flex-wrap gap-2">
                {regions.map(region => (
                  <button
                    key={region}
                    onClick={() => handleFilterChange('region', filters.region === region ? undefined : region)}
                    className={`text-sm px-3 py-1 rounded-full ${
                      filters.region === region
                        ? 'bg-teal-500 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    }`}
                  >
                    {region}
                  </button>
                ))}
              </div>
            </div>
            
            <div>
              <h3 className="font-medium mb-2">Climate</h3>
              <div className="flex flex-wrap gap-2">
                {climates.map(climate => (
                  <button
                    key={climate}
                    onClick={() => handleFilterChange('climate', filters.climate === climate ? undefined : climate)}
                    className={`text-sm px-3 py-1 rounded-full ${
                      filters.climate === climate
                        ? 'bg-teal-500 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    }`}
                  >
                    {climate}
                  </button>
                ))}
              </div>
            </div>
            
            <div>
              <h3 className="font-medium mb-2">Price Range</h3>
              <div className="flex flex-wrap gap-2">
                {[1, 2, 3].map(level => (
                  <button
                    key={level}
                    onClick={() => handlePriceRangeChange(level)}
                    className={`text-sm px-4 py-1 rounded-full ${
                      filters.priceRange?.includes(level)
                        ? 'bg-teal-500 text-white'
                        : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                    }`}
                  >
                    {Array(level).fill(0).map((_, i) => '$').join('')}
                  </button>
                ))}
              </div>
            </div>
          </div>
          
          <div className="flex justify-end mt-4">
            <Button
              variant="text"
              size="sm"
              onClick={clearFilters}
              className={`mr-2 ${!hasActiveFilters ? 'opacity-50 cursor-not-allowed' : ''}`}
              disabled={!hasActiveFilters}
              icon={<X size={16} />}
            >
              Clear All
            </Button>
          </div>
        </div>
      )}
    </div>
  );
};

export default FilterBar;