import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, useMap, Polyline, Circle, CircleMarker } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Destination, RoutePoint, UserLocation } from '../../types';
import { haversineMeters } from '../../utils/helpers';

// Fix for Leaflet marker images
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

const DefaultIcon = L.icon({
  iconUrl: icon,
  shadowUrl: iconShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41]
});

L.Marker.prototype.options.icon = DefaultIcon;

const userIcon = L.divIcon({
  className: 'pathsnap-user-marker',
  html: `<div style="
    width:18px;height:18px;border-radius:50%;
    background:#dc2626;border:3px solid #fff;
    box-shadow:0 0 0 2px #dc2626, 0 2px 6px rgba(0,0,0,.35);
  "></div>`,
  iconSize: [18, 18],
  iconAnchor: [9, 9],
});

interface MapViewProps {
  destinations: Destination[];
  selectedDestinations: RoutePoint[];
  onDestinationSelect: (destination: Destination) => void;
  userLocation?: UserLocation | null;
  radiusMeters?: number;
  isPickingOnMap?: boolean;
  onMapPickLocation?: (coords: [number, number]) => void;
}

// This component is needed to update the map view when selected destinations change
const ChangeView: React.FC<{ center: [number, number]; zoom: number }> = ({ center, zoom }) => {
  const map = useMap();
  map.setView(center, zoom);
  return null;
};

const MapClickHandler: React.FC<{
  enabled: boolean;
  onMapPickLocation?: (coords: [number, number]) => void;
}> = ({ enabled, onMapPickLocation }) => {
  const map = useMap();

  useEffect(() => {
    if (!enabled || !onMapPickLocation) return;

    const handleClick = (event: L.LeafletMouseEvent) => {
      onMapPickLocation([event.latlng.lat, event.latlng.lng]);
    };

    map.on('click', handleClick);
    return () => {
      map.off('click', handleClick);
    };
  }, [map, enabled, onMapPickLocation]);

  return null;
};

const MapView: React.FC<MapViewProps> = ({
  destinations,
  selectedDestinations,
  onDestinationSelect,
  userLocation,
  radiusMeters = 2000,
  isPickingOnMap = false,
  onMapPickLocation,
}) => {
  const [center, setCenter] = useState<[number, number]>([0, 0]);
  const [zoom, setZoom] = useState(2);

  const userCoords = userLocation?.coords ?? null;
  const hasRadiusAnchor = Boolean(userCoords);
  const radius = Math.max(radiusMeters, 1);

  // Prefer the traveler's real position; fall back to catalog centroid.
  useEffect(() => {
    if (userCoords) {
      setCenter(userCoords);
      setZoom(radius <= 500 ? 16 : radius <= 2000 ? 14 : 12);
      return;
    }
    if (destinations.length > 0) {
      const lats = destinations.map(d => d.coordinates[0]);
      const lngs = destinations.map(d => d.coordinates[1]);
      const avgLat = lats.reduce((s, v) => s + v, 0) / lats.length;
      const avgLng = lngs.reduce((s, v) => s + v, 0) / lngs.length;
      setCenter([avgLat, avgLng]);
      setZoom(12);
    }
  }, [userCoords, radius, destinations]);

  // Update center when route changes (only if no user anchor)
  useEffect(() => {
    if (userCoords) return;
    if (selectedDestinations.length > 0) {
      const lastDestination = selectedDestinations[selectedDestinations.length - 1];
      const destination = destinations.find(d => d.id === lastDestination.destinationId);

      if (destination) {
        setCenter(destination.coordinates);
        setZoom(5);
      }
    }
  }, [selectedDestinations, destinations, userCoords]);

  const isInRadius = (coords: [number, number]): boolean => {
    if (!userCoords || !hasRadiusAnchor) return false;
    return haversineMeters(userCoords, coords) <= radius;
  };

  // Create route line for visualization
  const routePositions = selectedDestinations
    .map(point => {
      const destination = destinations.find(d => d.id === point.destinationId);
      return destination ? destination.coordinates : null;
    })
    .filter(coordinates => coordinates !== null) as [number, number][];

  return (
    <div className="relative h-full w-full rounded-lg overflow-hidden shadow-md">
      <MapContainer
        center={center}
        zoom={zoom}
        style={{ height: '100%', width: '100%' }}
      >
        <ChangeView center={center} zoom={zoom} />
        <MapClickHandler enabled={isPickingOnMap && Boolean(onMapPickLocation)} onMapPickLocation={onMapPickLocation} />
        <TileLayer
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        />

        {/* Traveler anchor + prioritization radius */}
        {userCoords && (
          <>
            <Circle
              center={userCoords}
              radius={radius}
              pathOptions={{
                color: '#0B9C8A',
                fillColor: '#0B9C8A',
                fillOpacity: 0.12,
                weight: 2,
                dashArray: '6 6',
              }}
            />
            <Marker position={userCoords} icon={userIcon}>
              <Popup>
                <div>
                  <h3 className="font-semibold">{userLocation?.label || 'You are here'}</h3>
                  <p className="text-sm text-gray-600">
                    Priority radius: {radius >= 1000 ? `${(radius / 1000).toFixed(1)} km` : `${Math.round(radius)} m`}
                  </p>
                </div>
              </Popup>
            </Marker>
          </>
        )}

        {/* All available destinations — teal when inside the radius */}
        {destinations.map((destination) => {
          const inside = isInRadius(destination.coordinates);
          return (
            <CircleMarker
              key={destination.id}
              center={destination.coordinates}
              radius={inside ? 9 : 7}
              pathOptions={{
                color: inside ? '#047857' : '#2563eb',
                fillColor: inside ? '#10b981' : '#3b82f6',
                fillOpacity: 0.9,
                weight: 2,
              }}
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
                  {inside && (
                    <p className="mt-1 text-xs font-medium text-emerald-700">
                      Inside your priority radius
                    </p>
                  )}
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
            </CircleMarker>
          );
        })}

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

      {/* Compact legend */}
      <div className="pointer-events-none absolute bottom-3 left-3 z-[1000] rounded-lg bg-white/95 px-3 py-2 text-xs shadow-md">
        <div className="mb-1 font-semibold text-gray-800">Map legend</div>
        <div className="flex items-center gap-1.5 text-gray-700">
          <span className="inline-block h-2.5 w-2.5 rounded-full bg-red-600" /> You
        </div>
        <div className="flex items-center gap-1.5 text-gray-700">
          <span className="inline-block h-2.5 w-2.5 rounded-full bg-emerald-500" /> In radius (AI prioritizes)
        </div>
        <div className="flex items-center gap-1.5 text-gray-700">
          <span className="inline-block h-2.5 w-2.5 rounded-full bg-blue-500" /> Outside radius
        </div>
      </div>
    </div>
  );
};

export default MapView;
