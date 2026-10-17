import React, { useState } from 'react';
import { Crosshair, MapPin, Loader2, MousePointerClick } from 'lucide-react';
import { RadiusUnit, UserLocation } from '../../types';
import { describeUserLocation, formatRadiusLabel, toRadiusMeters } from '../../utils/helpers';

interface LocationControlsProps {
  userLocation: UserLocation | null;
  radiusMeters: number;
  radiusUnit: RadiusUnit;
  isPickingOnMap: boolean;
  onUserLocationChange: (location: UserLocation | null) => void;
  onRadiusMetersChange: (meters: number) => void;
  onRadiusUnitChange: (unit: RadiusUnit) => void;
  onPickingOnMapChange: (picking: boolean) => void;
}

const LocationControls: React.FC<LocationControlsProps> = ({
  userLocation,
  radiusMeters,
  radiusUnit,
  isPickingOnMap,
  onUserLocationChange,
  onRadiusMetersChange,
  onRadiusUnitChange,
  onPickingOnMapChange,
}) => {
  const [isLocating, setIsLocating] = useState(false);
  const [error, setError] = useState('');
  const [manualLabel, setManualLabel] = useState('');

  const handleUseMyLocation = () => {
    if (!navigator.geolocation) {
      setError('This browser does not support location access.');
      return;
    }

    setIsLocating(true);
    setError('');

    navigator.geolocation.getCurrentPosition(
      (position) => {
        onUserLocationChange({
          coords: [position.coords.latitude, position.coords.longitude],
          label: 'Current location',
          source: 'gps',
          accuracyM: position.coords.accuracy,
        });
        setIsLocating(false);
      },
      (err) => {
        setIsLocating(false);
        if (err.code === err.PERMISSION_DENIED) {
          setError('Location permission denied. Type a place name instead, or allow location in the browser.');
        } else if (err.code === err.POSITION_UNAVAILABLE) {
          setError('Location unavailable right now. Try again or type a place name.');
        } else {
          setError('Timed out getting your location. Try again or type a place name.');
        }
      },
      {
        enableHighAccuracy: true,
        timeout: 12000,
        maximumAge: 30_000,
      },
    );
  };

  const handleManualSubmit = (event: React.FormEvent) => {
    event.preventDefault();
    const label = manualLabel.trim();
    if (!label) {
      setError('Enter a place name, or use “Use my location”.');
      return;
    }
    // Keep existing coords when retyping a label so the radius circle stays anchored.
    onUserLocationChange({
      coords: userLocation?.coords ?? null,
      label,
      source: 'manual',
      accuracyM: undefined,
    });
    setManualLabel('');
    setError('');
  };

  const handleRadiusValueChange = (raw: string) => {
    const value = Number(raw);
    if (!Number.isFinite(value) || value <= 0) return;
    onRadiusMetersChange(toRadiusMeters(value, radiusUnit));
  };

  const radiusDisplayValue =
    radiusUnit === 'km'
      ? Number((radiusMeters / 1000).toFixed(2))
      : Math.round(radiusMeters);

  return (
    <div className="rounded-lg border border-gray-200 bg-white p-3 shadow-sm">
      <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-gray-900">
        <MapPin size={16} className="text-teal-600" />
        Location & prioritization radius
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <button
          type="button"
          onClick={handleUseMyLocation}
          disabled={isLocating}
          className="inline-flex items-center gap-1.5 rounded-lg bg-teal-600 px-3 py-1.5 text-sm font-medium text-white transition-colors hover:bg-teal-700 disabled:opacity-60"
        >
          {isLocating ? (
            <Loader2 size={14} className="animate-spin" />
          ) : (
            <Crosshair size={14} />
          )}
          {isLocating ? 'Locating…' : 'Use my location'}
        </button>

        <button
          type="button"
          onClick={() => onPickingOnMapChange(!isPickingOnMap)}
          className={`inline-flex items-center gap-1.5 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors ${
            isPickingOnMap
              ? 'bg-amber-500 text-white hover:bg-amber-600'
              : 'border border-gray-200 text-gray-700 hover:bg-gray-50'
          }`}
        >
          <MousePointerClick size={14} />
          {isPickingOnMap ? 'Click map to set pin…' : 'Drop pin on map'}
        </button>

        <form onSubmit={handleManualSubmit} className="flex min-w-0 flex-1 gap-1.5">
          <input
            type="text"
            value={manualLabel}
            onChange={(event) => setManualLabel(event.target.value)}
            placeholder="Or type a place (e.g. Dago)"
            aria-label="Manual location name"
            className="min-w-0 flex-1 rounded-lg border border-gray-200 px-2.5 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
          <button
            type="submit"
            className="rounded-lg border border-gray-200 px-2.5 py-1.5 text-sm text-gray-700 hover:bg-gray-50"
          >
            Set
          </button>
        </form>
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-2 text-sm text-gray-700">
        <span className="text-xs font-medium uppercase tracking-wide text-gray-500">
          Priority radius
        </span>
        <input
          type="number"
          min="1"
          step={radiusUnit === 'km' ? 0.1 : 50}
          value={radiusDisplayValue}
          onChange={(event) => handleRadiusValueChange(event.target.value)}
          aria-label="Prioritization radius value"
          className="w-20 rounded border border-gray-200 px-2 py-1 text-sm"
        />
        <select
          value={radiusUnit}
          onChange={(event) => {
            const nextUnit = event.target.value as RadiusUnit;
            // Keep the same physical distance when switching units.
            onRadiusUnitChange(nextUnit);
          }}
          aria-label="Radius unit"
          className="rounded border border-gray-200 px-2 py-1 text-sm"
        >
          <option value="m">meters</option>
          <option value="km">km</option>
        </select>
        <span className="text-xs text-gray-500">
          {formatRadiusLabel(radiusMeters, radiusUnit)} · places inside are prioritized
        </span>
      </div>

      <p className="mt-2 text-xs text-gray-600">
        Anchor: <span className="font-medium text-gray-800">{describeUserLocation(userLocation)}</span>
        {userLocation?.source === 'gps' && (
          <span className="ml-1 text-teal-700">· GPS</span>
        )}
        {userLocation?.source === 'manual' && (
          <span className="ml-1 text-amber-700">· text (approximate)</span>
        )}
      </p>

      {error && <p className="mt-1.5 text-xs text-red-600">{error}</p>}
    </div>
  );
};

export default LocationControls;
