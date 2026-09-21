import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { MapPin, Star, Hotel, Map, Calendar, DollarSign, Globe, Thermometer, PlusCircle } from 'lucide-react';
import Button from '../components/ui/Button';
import { destinations, accommodations, attractions } from '../data/mockData';
import { formatCurrency } from '../utils/helpers';

const DestinationDetailPage: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  
  const destination = destinations.find(dest => dest.id === id);
  
  if (!destination) {
    return (
      <div className="container mx-auto px-4 py-12 text-center">
        <h2 className="text-2xl font-semibold mb-4">Destination not found</h2>
        <p className="mb-8">Sorry, the destination you're looking for doesn't exist.</p>
        <Button variant="primary" onClick={() => navigate('/destinations')}>
          Browse Destinations
        </Button>
      </div>
    );
  }
  
  // Get accommodations and attractions for this destination
  const destinationAccommodations = accommodations.filter(acc => acc.destinationId === destination.id);
  const destinationAttractions = attractions.filter(attr => attr.destinationId === destination.id);
  
  return (
    <div>
      {/* Hero Section */}
      <div 
        className="h-80 bg-cover bg-center relative"
        style={{ backgroundImage: `url(${destination.image})` }}
      >
        <div className="absolute inset-0 bg-black bg-opacity-40"></div>
        <div className="container mx-auto px-4 h-full flex items-end pb-8 relative z-10">
          <div>
            <motion.h1 
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              className="text-3xl md:text-4xl font-bold text-white mb-2"
            >
              {destination.name}
            </motion.h1>
            <div className="flex items-center text-white mb-4">
              <MapPin size={16} className="mr-1" />
              <span>{destination.country}</span>
              <div className="mx-3 h-5 border-l border-white opacity-30"></div>
              <Star size={16} className="text-yellow-400 mr-1" />
              <span>{destination.rating} rating</span>
            </div>
            <div className="flex space-x-3">
              <span className="bg-teal-600 text-white px-3 py-1 rounded-full text-sm font-medium inline-flex items-center">
                <Globe size={14} className="mr-1" />
                {destination.region}
              </span>
              <span className="bg-orange-600 text-white px-3 py-1 rounded-full text-sm font-medium inline-flex items-center">
                <Thermometer size={14} className="mr-1" />
                {destination.climate}
              </span>
              <span className="bg-blue-600 text-white px-3 py-1 rounded-full text-sm font-medium inline-flex items-center">
                <DollarSign size={14} className="mr-1" />
                {Array(destination.priceRange).fill('$').join('')}
              </span>
            </div>
          </div>
        </div>
      </div>
      
      <div className="container mx-auto px-4 py-8">
        <div className="flex flex-col lg:flex-row gap-8">
          <div className="lg:w-2/3">
            {/* Overview */}
            <div className="bg-white rounded-lg shadow-md p-6 mb-8">
              <h2 className="text-2xl font-semibold mb-4">Overview</h2>
              <p className="text-gray-700 mb-6">
                {destination.description}
                {/* Extended description */}
                <span className="block mt-4">
                  {destination.name} offers travelers a unique blend of cultural experiences, natural beauty, and unforgettable adventures. 
                  Whether you're looking to relax, explore, or immerse yourself in a new culture, this destination has something for everyone.
                </span>
              </p>
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="border rounded-lg p-4">
                  <h3 className="font-medium mb-2 flex items-center">
                    <Calendar size={18} className="mr-2 text-teal-600" />
                    Best Time to Visit
                  </h3>
                  <p className="text-sm text-gray-600">
                    {destination.climate === 'Tropical' ? 'October to April' : 
                     destination.climate === 'Temperate' ? 'May to September' : 
                     destination.climate === 'Desert' ? 'November to February' : 
                     'All year round'}
                  </p>
                </div>
                <div className="border rounded-lg p-4">
                  <h3 className="font-medium mb-2 flex items-center">
                    <Globe size={18} className="mr-2 text-teal-600" />
                    Local Language
                  </h3>
                  <p className="text-sm text-gray-600">
                    {destination.country === 'Indonesia' ? 'Indonesian' :
                     destination.country === 'France' ? 'French' :
                     destination.country === 'USA' ? 'English' :
                     destination.country === 'Japan' ? 'Japanese' :
                     destination.country === 'Egypt' ? 'Arabic' :
                     destination.country === 'Australia' ? 'English' : 'Local Language'}
                  </p>
                </div>
                <div className="border rounded-lg p-4">
                  <h3 className="font-medium mb-2 flex items-center">
                    <DollarSign size={18} className="mr-2 text-teal-600" />
                    Currency
                  </h3>
                  <p className="text-sm text-gray-600">
                    {destination.country === 'Indonesia' ? 'Indonesian Rupiah (IDR)' :
                     destination.country === 'France' ? 'Euro (EUR)' :
                     destination.country === 'USA' ? 'US Dollar (USD)' :
                     destination.country === 'Japan' ? 'Japanese Yen (JPY)' :
                     destination.country === 'Egypt' ? 'Egyptian Pound (EGP)' :
                     destination.country === 'Australia' ? 'Australian Dollar (AUD)' : 'Local Currency'}
                  </p>
                </div>
              </div>
            </div>
            
            {/* Accommodations */}
            <div className="bg-white rounded-lg shadow-md p-6 mb-8">
              <h2 className="text-2xl font-semibold mb-4 flex items-center">
                <Hotel size={20} className="mr-2 text-teal-600" />
                Where to Stay
              </h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {destinationAccommodations.map(accommodation => (
                  <motion.div 
                    key={accommodation.id}
                    whileHover={{ y: -5 }}
                    transition={{ duration: 0.2 }}
                    className="border rounded-lg overflow-hidden shadow-sm"
                  >
                    <div className="h-40 overflow-hidden">
                      <img 
                        src={accommodation.image} 
                        alt={accommodation.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                    <div className="p-4">
                      <div className="flex justify-between items-start mb-2">
                        <h3 className="font-semibold">{accommodation.name}</h3>
                        <div className="flex items-center">
                          <Star size={14} className="text-yellow-400 mr-1" />
                          <span className="text-sm">{accommodation.rating}</span>
                        </div>
                      </div>
                      <p className="text-sm text-gray-600 mb-3">{accommodation.description}</p>
                      <div className="flex items-center justify-between">
                        <div className="text-teal-700 font-medium">
                          {formatCurrency(accommodation.price)} / night
                        </div>
                        <button className="text-sm text-teal-600 hover:underline flex items-center">
                          <span>View Details</span>
                        </button>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
            
            {/* Attractions */}
            <div className="bg-white rounded-lg shadow-md p-6">
              <h2 className="text-2xl font-semibold mb-4 flex items-center">
                <Map size={20} className="mr-2 text-teal-600" />
                Things to Do
              </h2>
              
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {destinationAttractions.map(attraction => (
                  <motion.div 
                    key={attraction.id}
                    whileHover={{ y: -5 }}
                    transition={{ duration: 0.2 }}
                    className="border rounded-lg overflow-hidden shadow-sm"
                  >
                    <div className="h-40 overflow-hidden">
                      <img 
                        src={attraction.image} 
                        alt={attraction.name}
                        className="w-full h-full object-cover"
                      />
                    </div>
                    <div className="p-4">
                      <div className="flex justify-between items-start mb-2">
                        <h3 className="font-semibold">{attraction.name}</h3>
                        <div className="flex items-center">
                          <Star size={14} className="text-yellow-400 mr-1" />
                          <span className="text-sm">{attraction.rating}</span>
                        </div>
                      </div>
                      <p className="text-sm text-gray-600 mb-3">{attraction.description}</p>
                      <div className="flex items-center justify-between">
                        <div className="font-medium">
                          {attraction.price ? formatCurrency(attraction.price) : 'Free Entry'}
                        </div>
                        <span className="text-xs px-2 py-1 bg-gray-100 rounded-full">
                          {attraction.type}
                        </span>
                      </div>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </div>
          
          {/* Sidebar */}
          <div className="lg:w-1/3">
            <div className="bg-white rounded-lg shadow-md p-6 sticky top-24">
              <h3 className="text-xl font-semibold mb-4">Add to Your Route</h3>
              <p className="text-gray-600 mb-6">
                Add {destination.name} to your travel itinerary and discover the best places to stay and things to do.
              </p>
              
              <Button 
                variant="primary" 
                fullWidth
                className="mb-4"
                icon={<PlusCircle size={18} />}
                onClick={() => navigate('/plan', { state: { destinationId: destination.id } })}
              >
                Add to My Route
              </Button>
              
              <div className="bg-gray-50 rounded-lg p-4 mt-6">
                <h4 className="font-medium mb-2">Weather</h4>
                <p className="text-sm text-gray-600 mb-4">
                  {destination.climate === 'Tropical' ? 'Warm and humid throughout the year with temperatures between 75-90°F (24-32°C).' : 
                   destination.climate === 'Temperate' ? 'Four distinct seasons with warm summers and cold winters. Temperature varies by season.' : 
                   destination.climate === 'Desert' ? 'Hot days and cool nights with very little rainfall. Daytime temperatures can exceed 100°F (38°C).' : 
                   destination.climate === 'Seasonal' ? 'Distinct seasons with temperature variations throughout the year.' :
                   'Varied climate conditions throughout the year.'}
                </p>
                
                <h4 className="font-medium mb-2">Travel Tips</h4>
                <ul className="text-sm text-gray-600 space-y-2">
                  <li>• Best to visit during off-peak seasons to avoid crowds</li>
                  <li>• Local transportation options include {destination.region === 'Asia' ? 'taxis and tuk-tuks' : 'public transit and ride shares'}</li>
                  <li>• Try the local cuisine for an authentic experience</li>
                  <li>• Always carry some local currency for small purchases</li>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default DestinationDetailPage;