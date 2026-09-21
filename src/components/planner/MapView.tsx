import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap, Polyline } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Destination, RoutePoint } from '../../types';

// Fix for Leaflet marker images
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
  iconUrl: icon,
  shadowUrl: iconShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41]
});

L.Marker.prototype.options.icon = DefaultIcon;

interface MapViewProps {
  destinations: Destination[];
  selectedDestinations: RoutePoint[];
  onDestinationSelect: (destination: Destination) => void;
}

// This component is needed to update the map view when selected destinations change
const ChangeView: React.FC<{ center: [number, number]; zoom: number }> = ({ center, zoom }) => {
  const map = useMap();
  map.setView(center, zoom);
  return null;
};

const MapView: React.FC<MapViewProps> = ({ 
  destinations, 
  selectedDestinations,
  onDestinationSelect
}) => {
  const [center, setCenter] = useState<[number, number]>([0, 0]);
  const [zoom, setZoom] = useState(2);
  
  // Set initial center based on destinations
  useEffect(() => {
    if (destinations.length > 0) {
      setCenter(destinations[0].coordinates);
    }
  }, [destinations]);
  
  // Update center when route changes
  useEffect(() => {
    if (selectedDestinations.length > 0) {
      const lastDestination = selectedDestinations[selectedDestinations.length - 1];
      const destination = destinations.find(d => d.id === lastDestination.destinationId);
      
      if (destination) {
        setCenter(destination.coordinates);
        setZoom(5);
      }
    }
  }, [selectedDestinations, destinations]);
  
  // Create route line for visualization
  const routePositions = selectedDestinations
    .map(point => {
      const destination = destinations.find(d => d.id === point.destinationId);
      return destination ? destination.coordinates : null;
    })
    .filter(coordinates => coordinates !== null) as [number, number][];
  
  return (
    <div className="h-full w-full rounded-lg overflow-hidden shadow-md">
      <MapContainer 
        center={center} 
        zoom={zoom} 
        style={{ height: '100%', width: '100%' }}
      >
        <ChangeView center={center} zoom={zoom} />
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />
        
        {/* All available destinations */}
        {destinations.map((destination) => (
          <Marker 
            key={destination.id} 
            position={destination.coordinates}
            eventHandlers={{
              click: () => {
                onDestinationSelect(destination);
              }
            }}
          >
            <Popup>
              <div>
                <h3 className="font-semibold">{destination.name}</h3>
                <p className="text-sm">{destination.country}</p>
                <div className="mt-2">
                  <button 
                    className="text-sm bg-teal-600 text-white px-2 py-1 rounded hover:bg-teal-700"
                    onClick={() => onDestinationSelect(destination)}
                  >
                    Add to Route
                  </button>
                </div>
              </div>
            </Popup>
          </Marker>
        ))}
        
        {/* Route line */}
        {routePositions.length > 1 && (
          <Polyline
            positions={routePositions}
            color="#0B9C8A"
            weight={4}
            opacity={0.7}
            smoothFactor={1}
          />
        )}
      </MapContainer>
    </div>
  );
};

export default MapView;