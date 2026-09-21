import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import { MapPin, Star } from 'lucide-react';
import { Destination } from '../../types';

interface DestinationCardProps {
  destination: Destination;
}

const DestinationCard: React.FC<DestinationCardProps> = ({ destination }) => {
  const navigate = useNavigate();
  
  const handleClick = () => {
    navigate(`/destinations/${destination.id}`);
  };

  return (
    <motion.div
      whileHover={{ y: -5 }}
      transition={{ duration: 0.2 }}
      className="bg-white rounded-xl shadow-md overflow-hidden cursor-pointer h-full"
      onClick={handleClick}
    >
      <div className="relative h-48">
        <img 
          src={destination.image} 
          alt={destination.name}
          className="w-full h-full object-cover transition-transform duration-300 hover:scale-105"
        />
        <div className="absolute top-4 right-4 bg-white bg-opacity-90 rounded-full py-1 px-2 flex items-center">
          <Star size={16} className="text-yellow-400 mr-1" />
          <span className="text-sm font-medium">{destination.rating}</span>
        </div>
        <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black to-transparent h-16"></div>
      </div>
      
      <div className="p-4">
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-lg font-semibold">{destination.name}</h3>
            <div className="flex items-center text-gray-500 mb-2">
              <MapPin size={16} className="mr-1" />
              <span>{destination.country}</span>
            </div>
          </div>
          <div className="flex items-center">
            <div className="bg-teal-100 text-teal-800 text-xs px-2 py-1 rounded mr-2">
              {destination.climate}
            </div>
            <div className="bg-gray-100 text-gray-800 text-xs px-2 py-1 rounded">
              {destination.region}
            </div>
          </div>
        </div>
        
        <p className="text-gray-600 text-sm mb-3 line-clamp-2">{destination.description}</p>
        
        <div className="flex justify-between items-center">
          <div className="flex">
            {Array(destination.priceRange).fill(0).map((_, i) => (
              <span key={i} className="text-teal-600">$</span>
            ))}
            {Array(3 - destination.priceRange).fill(0).map((_, i) => (
              <span key={i} className="text-gray-300">$</span>
            ))}
          </div>
          <button className="text-sm text-teal-600 hover:underline">
            View Details
          </button>
        </div>
      </div>
    </motion.div>
  );
};

export default DestinationCard;