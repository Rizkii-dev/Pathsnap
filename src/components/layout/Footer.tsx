import React from 'react';
import { Link } from 'react-router-dom';
import { MapPin, Instagram, Twitter, Facebook, Mail, Phone } from 'lucide-react';

const Footer: React.FC = () => {
  return (
    <footer className="bg-gray-900 text-white">
      <div className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
          
          {/* Company Info */}
          <div>
            <div className="flex items-center mb-4">
              <MapPin size={24} className="text-teal-400 mr-2" />
              <span className="text-xl font-bold">Pathsnap</span>
            </div>
            <p className="text-gray-400 mb-4">
              Plan your perfect journey with custom routes and recommendations for destinations around the world.
            </p>
            <div className="flex space-x-4">
              <a href="#" className="text-gray-400 hover:text-teal-400 transition-colors">
                <Instagram size={20} />
              </a>
              <a href="#" className="text-gray-400 hover:text-teal-400 transition-colors">
                <Twitter size={20} />
              </a>
              <a href="#" className="text-gray-400 hover:text-teal-400 transition-colors">
                <Facebook size={20} />
              </a>
            </div>
          </div>
          
          {/* Quick Links */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Quick Links</h3>
            <ul className="space-y-2">
              <li>
                <Link to="/" className="text-gray-400 hover:text-teal-400 transition-colors">Home</Link>
              </li>
              <li>
                <Link to="/destinations" className="text-gray-400 hover:text-teal-400 transition-colors">Destinations</Link>
              </li>
              <li>
                <Link to="/plan" className="text-gray-400 hover:text-teal-400 transition-colors">Plan Your Trip</Link>
              </li>
              <li>
                <Link to="/contact" className="text-gray-400 hover:text-teal-400 transition-colors">Contact Us</Link>
              </li>
            </ul>
          </div>
          
          {/* Support */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Support</h3>
            <ul className="space-y-2">
              <li>
                <Link to="/faq" className="text-gray-400 hover:text-teal-400 transition-colors">FAQs</Link>
              </li>
              <li>
                <Link to="/privacy" className="text-gray-400 hover:text-teal-400 transition-colors">Privacy Policy</Link>
              </li>
              <li>
                <Link to="/terms" className="text-gray-400 hover:text-teal-400 transition-colors">Terms of Service</Link>
              </li>
              <li>
                <Link to="/help" className="text-gray-400 hover:text-teal-400 transition-colors">Help Center</Link>
              </li>
            </ul>
          </div>
          
          {/* Contact */}
          <div>
            <h3 className="text-lg font-semibold mb-4">Contact Us</h3>
            <ul className="space-y-3">
              <li className="flex items-start">
                <Mail size={18} className="text-teal-400 mr-2 mt-1" />
                <span className="text-gray-400">support@pathsnap.com</span>
              </li>
              <li className="flex items-start">
                <Phone size={18} className="text-teal-400 mr-2 mt-1" />
                <span className="text-gray-400">+1 (555) 123-4567</span>
              </li>
            </ul>
          </div>
        </div>
        
        <div className="border-t border-gray-800 mt-12 pt-8 text-center text-gray-400">
          <p>© {new Date().getFullYear()} Pathsnap. All rights reserved.</p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;