import React from 'react';
import { useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import Card from '../ui/Card';
import { destinations } from '../../data/mockData';
import { MapPin, Star } from 'lucide-react';

const FeaturedDestinations: React.FC = () => {
  const navigate = useNavigate();
  const featuredDestinations = destinations.slice(0, 4);

  const container = {
    hidden: { opacity: 0 },
    show: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2
      }
    }
  };

  const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0, transition: { duration: 0.6 } }
  };

  return (
    <section className="py-16 bg-gray-50">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-bold mb-4">Popular Destinations</h2>
          <p className="text-gray-600 max-w-2xl mx-auto">
            Discover amazing places to visit on your next journey. These destinations are loved by travelers worldwide.
          </p>
        </div>
        
        <motion.div 
          variants={container}
          initial="hidden"
          whileInView="show"
          viewport={{ once: true, amount: 0.2 }}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8"
        >
          {featuredDestinations.map((destination) => (
            <motion.div key={destination.id} variants={item}>
              <Card 
                className="h-full"
                onClick={() => navigate(`/destinations/${destination.id}`)}
              >
                <div className="relative h-48 overflow-hidden">
                  <img 
                    src={destination.image} 
                    alt={destination.name}
                    className="w-full h-full object-cover transition-transform duration-300 hover:scale-110"
                  />
                  <div className="absolute top-4 right-4 bg-white bg-opacity-90 rounded-full py-1 px-2 flex items-center">
                    <Star size={16} className="text-yellow-400 mr-1" />
                    <span className="text-sm font-medium">{destination.rating}</span>
                  </div>
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
                    <div className="bg-teal-100 text-teal-800 text-xs px-2 py-1 rounded">
                      {destination.climate}
                    </div>
                  </div>
                  <p className="text-gray-600 text-sm line-clamp-2 mb-3">{destination.description}</p>
                  <div className="flex justify-between items-center">
                    <div className="flex">
                      {Array(destination.priceRange).fill(0).map((_, i) => (
                        <span key={i} className="text-teal-600">$</span>
                      ))}
                      {Array(3 - destination.priceRange).fill(0).map((_, i) => (
                        <span key={i} className="text-gray-300">$</span>
                      ))}
                    </div>
                    <span className="text-sm text-teal-600 hover:underline cursor-pointer">
                      View Details
                    </span>
                  </div>
                </div>
              </Card>
            </motion.div>
          ))}
        </motion.div>
        
        <div className="text-center mt-12">
          <button 
            onClick={() => navigate('/destinations')}
            className="text-teal-600 font-medium hover:underline"
          >
            View All Destinations
          </button>
        </div>
      </div>
    </section>
  );
};

export default FeaturedDestinations;