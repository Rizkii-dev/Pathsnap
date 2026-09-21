import React from 'react';
import { motion } from 'framer-motion';
import { MapPin, Hotel, Map, Compass } from 'lucide-react';

const features = [
  {
    icon: <MapPin className="w-8 h-8 text-teal-600" />,
    title: 'Custom Routes',
    description: 'Create personalized travel routes by adding destinations and visualize your journey on an interactive map.'
  },
  {
    icon: <Hotel className="w-8 h-8 text-teal-600" />,
    title: 'Accommodation Suggestions',
    description: 'Get curated accommodation recommendations for each stop on your journey, from luxury hotels to budget hostels.'
  },
  {
    icon: <Map className="w-8 h-8 text-teal-600" />,
    title: 'Local Attractions',
    description: 'Discover must-see attractions, hidden gems, and cultural experiences at each destination in your itinerary.'
  },
  {
    icon: <Compass className="w-8 h-8 text-teal-600" />,
    title: 'Complete Itineraries',
    description: 'View your complete travel plan including costs, duration, and detailed information for each stop.'
  }
];

const FeatureHighlights: React.FC = () => {
  return (
    <section className="py-16 bg-white">
      <div className="container mx-auto px-4">
        <div className="text-center mb-12">
          <h2 className="text-3xl md:text-4xl font-bold mb-4">How Pathsnap Works</h2>
          <p className="text-gray-600 max-w-2xl mx-auto">
            Plan your perfect journey with our powerful travel planning tools.
          </p>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          {features.map((feature, index) => (
            <motion.div 
              key={index}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1, duration: 0.5 }}
              className="bg-gray-50 p-6 rounded-xl"
            >
              <div className="bg-white w-16 h-16 rounded-full flex items-center justify-center mb-4 shadow-sm">
                {feature.icon}
              </div>
              <h3 className="text-xl font-semibold mb-2">{feature.title}</h3>
              <p className="text-gray-600">{feature.description}</p>
            </motion.div>
          ))}
        </div>
        
        <motion.div 
          initial={{ opacity: 0, y: 40 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ duration: 0.7, delay: 0.3 }}
          className="mt-16 bg-gradient-to-r from-teal-600 to-teal-800 rounded-2xl p-8 md:p-12 text-white text-center"
        >
          <h3 className="text-2xl md:text-3xl font-bold mb-4">Ready to Plan Your Dream Journey?</h3>
          <p className="text-lg md:text-xl mb-8 max-w-2xl mx-auto">
            Start creating your personalized travel route today and discover amazing places along the way.
          </p>
          <a 
            href="/plan" 
            className="inline-block bg-white text-teal-700 font-medium px-6 py-3 rounded-lg hover:bg-gray-100 transition-colors"
          >
            Start Planning
          </a>
        </motion.div>
      </div>
    </section>
  );
};

export default FeatureHighlights;