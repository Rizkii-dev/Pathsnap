import React from 'react';
import Hero from '../components/home/Hero';
import FeaturedDestinations from '../components/home/FeaturedDestinations';
import FeatureHighlights from '../components/home/FeatureHighlights';
import Testimonials from '../components/home/Testimonials';

const HomePage: React.FC = () => {
  return (
    <div>
      <Hero />
      <FeaturedDestinations />
      <FeatureHighlights />
      <Testimonials />
    </div>
  );
};

export default HomePage;