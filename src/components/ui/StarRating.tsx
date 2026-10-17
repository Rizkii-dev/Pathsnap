import React from 'react';
import { Star } from 'lucide-react';

interface StarRatingProps {
  rating: number;
  max?: number;
  size?: number;
  showValue?: boolean;
  className?: string;
}

const StarRating: React.FC<StarRatingProps> = ({
  rating,
  max = 5,
  size = 16,
  showValue = true,
  className = '',
}) => {
  const clamped = Math.max(0, Math.min(max, rating));

  return (
    <span className={`inline-flex items-center gap-1 ${className}`}>
      <span className="inline-flex" aria-label={`${clamped} out of ${max} stars`}>
        {Array.from({ length: max }, (_, index) => {
          const fillLevel = clamped - index;
          return (
            <span key={index} className="relative inline-block" style={{ width: size, height: size }}>
              <Star size={size} className="absolute inset-0 text-gray-300" />
              {fillLevel > 0 && (
                <span
                  className="absolute inset-0 overflow-hidden"
                  style={{ width: `${Math.min(1, fillLevel) * 100}%` }}
                >
                  <Star size={size} className="text-yellow-400 fill-yellow-400" />
                </span>
              )}
            </span>
          );
        })}
      </span>
      {showValue && (
        <span className="text-sm font-medium text-gray-800">{clamped.toFixed(1)}</span>
      )}
    </span>
  );
};

export default StarRating;
