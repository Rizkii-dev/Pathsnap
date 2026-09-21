import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate } from 'react-router-dom';
import Button from '../ui/Button';
import { MapPin } from 'lucide-react';

const Hero: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div className="relative min-h-screen flex items-center bg-cover bg-center" style={{ 
      backgroundImage: "linear-gradient(rgba(0, 0, 0, 0.5), rgba(0, 0, 0, 0.7)), url('https://images.pexels.com/photos/1271619/pexels-photo-1271619.jpeg')"
    }}>
      <div className="absolute inset-0 bg-gradient-to-b from-transparent to-black opacity-30"></div>
      
      <div className="container mx-auto px-4 z-10 pt-24">
        <div className="max-w-3xl mx-auto text-center text-white">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8 }}
          >
            <h1 className="text-4xl md:text-6xl font-bold mb-6">
              Create Your Perfect Journey
            </h1>
            
            <p className="text-xl md:text-2xl mb-8 text-gray-200">
              Plan custom travel routes, discover accommodations, and explore attractions tailored to your preferences.
            </p>
            
            <div className="flex flex-col sm:flex-row justify-center items-center space-y-4 sm:space-y-0 sm:space-x-4">
              <Button 
                variant="primary"
                size="lg"
                onClick={() => navigate('/plan')}
                icon={<MapPin size={20} />}
              >
                Start Planning
              </Button>
              
              <Button 
                variant="outline"
                size="lg"
                className="border-white text-white hover:bg-white hover:bg-opacity-20"
                onClick={() => navigate('/destinations')}
              >
                Explore Destinations
              </Button>
            </div>
          </motion.div>
          
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.5, duration: 1 }}
            className="mt-16 grid grid-cols-2 md:grid-cols-4 gap-4 md:gap-8"
          >
            {[
              { number: '500+', label: 'Destinations' },
              { number: '10,000+', label: 'Happy Travelers' },
              { number: '5,000+', label: 'Accommodations' },
              { number: '3,000+', label: 'Attractions' }
            ].map((stat, index) => (
              <div key={index} className="bg-black bg-opacity-30 backdrop-blur-sm p-4 rounded-lg">
                <p className="text-2xl md:text-3xl font-bold text-teal-400">{stat.number}</p>
                <p className="text-gray-300">{stat.label}</p>
              </div>
            ))}
          </motion.div>
        </div>
      </div>
    </div>
  );
};

export default Hero;