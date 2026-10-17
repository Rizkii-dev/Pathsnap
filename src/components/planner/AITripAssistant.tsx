import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Bot, Send, Sparkles, X, ExternalLink, Star } from 'lucide-react';
import { Accommodation, Attraction, Destination, RoutePoint, UserLocation } from '../../types';
import { findDestinationByName, haversineMeters, isWithinRadius } from '../../utils/helpers';

interface AITripAssistantProps {
  selectedDestinations: RoutePoint[];
  destinations: Destination[];
  accommodations: Accommodation[];
  attractions: Attraction[];
  userLocation: UserLocation | null;
  radiusMeters: number;
  onApplyPlan: (plan: TripPlanResponse) => void;
}

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  plan?: TripPlanResponse;
}

interface ConversationIntent {
  action: 'plan' | 'chat' | 'reject';
}

export interface TripPlanResponse {
  planTitle: string;
  budgetUsd: number | null;
  durationDays: number | null;
  totalEstimatedHotelCostUsd: number;
  withinBudget: boolean | null;
  stops: Array<{
    destination: string;
    country: string;
    nights: number;
    hotel: string | null;
    pricePerNightUsd: number;
    hotelTotalUsd: number;
  }>;
  notes: string[];
}

type PlanStop = TripPlanResponse['stops'][number];

interface ShortlistedPlace {
  name: string;
  avgAccommodationPrice: number | null;
  avgAttractionPrice: number | null;
  totalAttractionPrice: number;
  avgTotalPrice: number | null;
  rating: number | null;
  district: string | null;
  city: string | null;
  sameArea: boolean;
  distanceKm: number | null;
  affordableAttractions: boolean;
  /** Set client-side from user GPS + radius — used to prioritize nearby places. */
  inRadius?: boolean;
  coordinates?: [number, number] | null;
}

interface QueryTravelPlacesResult {
  query: {
    budgetUsd: number;
    userLocation: string;
    travelArea: string;
    days: number;
  };
  count: number;
  places: ShortlistedPlace[];
}

interface TripQueryForm {
  budgetUsd: string;
  userLocation: string;
  travelArea: string;
  days: string;
  tripType: TripType;
}

type TripType = 'short' | 'vacation';

const TRIP_TYPE_OPTIONS: Array<{ value: TripType; label: string; hint: string }> = [
  { value: 'short', label: 'Normal short trip', hint: 'About 3–5 hours · 2–3 places' },
  { value: 'vacation', label: 'Vacation', hint: 'Full days · ~3 places per day' },
];

/** Cap how many places fit the selected pace — short trips cannot absorb a full itinerary. */
const maxStopsForTrip = (tripType: TripType, days: number): number => {
  const safeDays = Number.isFinite(days) && days > 0 ? Math.floor(days) : 1;
  return tripType === 'short' ? 3 : Math.max(3, safeDays * 3);
};

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODEL = 'qwen/qwen3.8-27b';
const QUERY_TOOL_URL = '/api/query-travel-places';

/** Free-tier Groq ITPM is tiny — keep every prompt compact and retry when the bucket is full. */
const MAX_PROMPT_PLACES = 12;
const MAX_GROQ_RETRIES = 4;

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

const parseRetryAfterMs = (errorBody: string): number => {
  const match = errorBody.match(/try again in ([\d.]+)s/i);
  if (match) return Math.ceil(parseFloat(match[1]) * 1000) + 300;
  return 2000;
};

/** Skip the Groq intent call for obvious requests — saves ITPM right before the big plan request. */
const detectLocalIntent = (question: string): ConversationIntent['action'] | null => {
  const q = question.toLowerCase();
  if (/\b(route|itinerary|trip plan|plan my|plan a|plan the|make me a|build (me )?a|create (me )?a|generate (me )?a)\b/.test(q)) {
    return 'plan';
  }
  if (/\b(hi|hello|hey|thanks|thank you|ok|okay)\b/.test(q) && q.length < 40) {
    return 'chat';
  }
  return null;
};

const formatGroqError = (body: string, status: number, step: string): string => {
  try {
    const parsed = JSON.parse(body) as { error?: { message?: string; code?: string } };
    const message = parsed?.error?.message || body;
    if (
      status === 429 ||
      parsed?.error?.code === 'rate_limit_exceeded' ||
      /rate.?limit|tokens per minute|itpm/i.test(message)
    ) {
      return 'The AI service hit its free-tier token rate limit. Wait a few seconds and send the request again.';
    }
    return message || `${step} failed with status ${status}`;
  } catch {
    return body || `${step} failed with status ${status}`;
  }
};

/** POST to Groq with rate-limit retry so ITPM bursts do not surface as raw errors. */
const fetchGroq = async (
  apiKey: string,
  payload: Record<string, unknown>,
  step: string,
): Promise<{ choices?: Array<{ message?: { content?: string | null; tool_calls?: unknown[] } }> }> => {
  let lastError = '';
  let lastStatus = 0;

  for (let attempt = 1; attempt <= MAX_GROQ_RETRIES; attempt++) {
    let response: Response;
    try {
      response = await fetch(GROQ_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(payload),
      });
    } catch {
      throw new Error('Unable to reach the AI service. Check your connection and try again.');
    }

    if (response.ok) {
      return response.json();
    }

    lastError = await response.text();
    lastStatus = response.status;
    const isRateLimit =
      response.status === 429 ||
      /rate.?limit|tokens per minute|itpm|try again in/i.test(lastError);

    if (isRateLimit && attempt < MAX_GROQ_RETRIES) {
      const waitMs = parseRetryAfterMs(lastError);
      console.warn(`[Groq ${step}] rate limited, retrying in ${waitMs}ms (attempt ${attempt}/${MAX_GROQ_RETRIES})`);
      await sleep(waitMs);
      continue;
    }

    throw new Error(formatGroqError(lastError, response.status, step));
  }

  throw new Error(formatGroqError(lastError, lastStatus, step));
};

const QUERY_TRAVEL_PLACES_TOOL = {
  type: 'function' as const,
  function: {
    name: 'query_travel_places',
    description:
      'MCP tool that queries PostgreSQL for travel places matching budget, user location, travel area, and trip length. Returns compact place names with average accommodation and attraction prices, ranked by affordability then proximity (same district/city) then rating.',
    parameters: {
      type: 'object',
      properties: {
        budgetUsd: {
          type: 'number',
          description: 'Total trip budget in USD.',
        },
        userLocation: {
          type: 'string',
          description: "User's current location or district/city (e.g. Coblong, Dago).",
        },
        travelArea: {
          type: 'string',
          description: 'Destination area to search (e.g. Bandung).',
        },
        days: {
          type: 'integer',
          description: 'Number of vacation days.',
        },
        userCoords: {
          type: 'array',
          items: { type: 'number' },
          description: 'Optional [lat, lng] of the traveler. Prefer this over geocoding userLocation.',
        },
        radiusMeters: {
          type: 'number',
          description: 'Prioritization radius in meters around the traveler.',
        },
      },
      required: ['budgetUsd', 'userLocation', 'travelArea', 'days'],
    },
  },
};

const logAiRequest = (step: string, payload: unknown) => {
  const body = JSON.stringify(payload);
  const messageCount = Array.isArray((payload as { messages?: unknown[] })?.messages)
    ? (payload as { messages: unknown[] }).messages.length
    : 0;
  console.group(`[AI Request] ${step}`);
  console.log('Approx. size (chars):', body.length);
  console.log('Approx. size (KB):', Math.round(body.length / 1024 * 10) / 10);
  console.log('Message count:', messageCount);
  console.log('Payload:', payload);
  console.groupEnd();
};

const parseJsonResponse = <T,>(content: string): T => {
  const jsonContent = content.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
  const parsed: unknown = JSON.parse(jsonContent);

  if (Array.isArray(parsed) || parsed === null || typeof parsed !== 'object') {
    throw new Error('The assistant returned an invalid JSON object instead of one trip plan.');
  }

  return parsed as T;
};

const validateTripPlan = (
  plan: TripPlanResponse,
  shortlist: ShortlistedPlace[],
  hotelLookup: Array<{ name: string; destination: string; price: number }>,
  options: { userLocation?: string; catalogNames?: string[]; maxStops?: number; tripType?: TripType } = {},
): TripPlanResponse => {
  if (!plan || typeof plan !== 'object' || !Array.isArray(plan.stops) || !Array.isArray(plan.notes)) {
    throw new Error('The assistant returned an invalid trip plan shape.');
  }

  const shortlistNames = new Set(shortlist.map(item => item.name.toLowerCase()));
  const catalogNames = new Set((options.catalogNames || []).map(name => name.toLowerCase()));
  const startLocation = String(options.userLocation || '').trim().toLowerCase();
  let calculatedTotal = 0;

  const resolvePlaceName = (value: string) => {
    const name = String(value || '').trim().toLowerCase();
    if (!name) return null;
    const shortlistHit = shortlist.find(item => item.name.toLowerCase() === name);
    if (shortlistHit) return shortlistHit.name;
    const catalogHit = (options.catalogNames || []).find(item => item.toLowerCase() === name);
    if (catalogHit) return catalogHit;
    const loose = shortlist.find(item =>
      name.includes(item.name.toLowerCase()) || item.name.toLowerCase().includes(name),
    );
    return loose?.name || null;
  };

  const isStartingLocation = (value: string) => {
    const name = String(value || '').trim().toLowerCase();
    if (!name || !startLocation) return false;
    return (
      name === startLocation ||
      name.includes(startLocation) ||
      startLocation.includes(name)
    );
  };

  const validatedStops = plan.stops.flatMap((stop): PlanStop[] => {
    const rawName = String(stop.destination || '').trim();
    if (!rawName) return [];

    // The traveler's current location is the start point, not a tour stop.
    if (isStartingLocation(rawName)) return [];

    const resolvedName = resolvePlaceName(rawName);
    if (!resolvedName) {
      console.warn('[validateTripPlan] skipping unknown place:', rawName);
      return [];
    }
    if (!shortlistNames.has(resolvedName.toLowerCase()) && !catalogNames.has(resolvedName.toLowerCase())) {
      console.warn('[validateTripPlan] skipping non-catalog place:', rawName);
      return [];
    }

    const hotelName = typeof stop.hotel === 'string' ? stop.hotel.trim() : '';
    const nights = Number.isInteger(stop.nights) && stop.nights > 0 ? stop.nights : 0;

    // Day visit or trip without lodging — still a route stop.
    if (!hotelName) {
      return [{
        destination: resolvedName,
        country: stop.country || 'Indonesia',
        nights,
        hotel: null,
        pricePerNightUsd: 0,
        hotelTotalUsd: 0,
      }];
    }

    const hotel = hotelLookup.find(item =>
      item.name.toLowerCase() === hotelName.toLowerCase() &&
      item.destination.toLowerCase() === resolvedName.toLowerCase(),
    ) || hotelLookup.find(item => item.name.toLowerCase() === hotelName.toLowerCase());

    if (!hotel) {
      // Keep the visit even if the invented hotel is dropped.
      return [{
        destination: resolvedName,
        country: stop.country || 'Indonesia',
        nights,
        hotel: null,
        pricePerNightUsd: 0,
        hotelTotalUsd: 0,
      }];
    }

    const hotelTotal = hotel.price * nights;
    calculatedTotal += hotelTotal;

    return [{
      destination: resolvedName,
      country: stop.country || 'Indonesia',
      nights,
      hotel: hotel.name,
      pricePerNightUsd: hotel.price,
      hotelTotalUsd: hotelTotal,
    }];
  });

  const budget = typeof plan.budgetUsd === 'number' ? plan.budgetUsd : null;
  let stops: PlanStop[] = validatedStops;

  // Day-trip models sometimes put the itinerary only in notes. Recover those visits
  // so "Add plan to Your Route" still has stops to apply.
  if (stops.length === 0 && plan.notes.length > 0) {
    const notesText = plan.notes.join(' ').toLowerCase();
    const recovered: PlanStop[] = shortlist
      .filter(place => notesText.includes(place.name.toLowerCase()))
      .filter(place => !isStartingLocation(place.name))
      .map(place => ({
        destination: place.name,
        country: 'Indonesia',
        nights: 0,
        hotel: null,
        pricePerNightUsd: 0,
        hotelTotalUsd: 0,
      }));
    stops = recovered;
  }

  // Pace limit: a 3–5 hour outing cannot absorb a full multi-stop tour.
  const maxStops = options.maxStops;
  if (typeof maxStops === 'number' && maxStops > 0 && stops.length > maxStops) {
    console.warn(`[validateTripPlan] trimming ${stops.length} stops to ${maxStops} for trip type ${options.tripType || ''}`);
    stops = stops.slice(0, maxStops);
    calculatedTotal = stops.reduce((sum, stop) => sum + stop.hotelTotalUsd, 0);
  }

  return {
    planTitle: String(plan.planTitle || 'Trip plan'),
    budgetUsd: budget,
    durationDays: typeof plan.durationDays === 'number' ? plan.durationDays : null,
    totalEstimatedHotelCostUsd: calculatedTotal,
    withinBudget: budget === null ? null : calculatedTotal <= budget,
    stops,
    notes: plan.notes.map(note => String(note)),
  };
};

const formatUsd = (amount: number): string => `$${amount.toLocaleString('en-US', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
})}`;

/** Places inside the radius first, then by distance — so the model sees priority order. */
const sortPlacesForPrompt = (places: ShortlistedPlace[]): ShortlistedPlace[] => {
  return [...places].sort((a, b) => {
    const aIn = a.inRadius ? 0 : 1;
    const bIn = b.inRadius ? 0 : 1;
    if (aIn !== bIn) return aIn - bIn;
    const da = a.distanceKm ?? Number.POSITIVE_INFINITY;
    const db = b.distanceKm ?? Number.POSITIVE_INFINITY;
    if (da !== db) return da - db;
    return (b.rating ?? -1) - (a.rating ?? -1);
  });
};

const formatShortlistForPrompt = (places: ShortlistedPlace[]): string => {
  if (places.length === 0) return '(no places returned)';
  return sortPlacesForPrompt(places)
    .slice(0, MAX_PROMPT_PLACES)
    .map((place, index) => {
      const parts = [
        `${index + 1}. ${place.name}`,
        place.inRadius ? 'PRIORITY_IN_RADIUS' : null,
        place.avgTotalPrice != null ? `avgTotal=${formatUsd(place.avgTotalPrice)}` : null,
        place.avgAccommodationPrice != null ? `avgStay=${formatUsd(place.avgAccommodationPrice)}` : null,
        place.rating != null ? `rating=${place.rating}` : null,
        place.distanceKm != null ? `dist=${place.distanceKm}km` : null,
      ].filter(Boolean);
      return parts.join(' | ');
    })
    .join('\n');
};

type HotelArea = {
  destination: string;
  country: string;
  hotels: Array<{ name: string; pricePerNight: number; rating: number | null }>;
};

/** One line per place — far smaller than JSON.stringify on nested hotel objects. */
const formatHotelsForPrompt = (hotelData: HotelArea[]): string => {
  if (hotelData.length === 0) return '(no hotels)';
  return hotelData
    .slice(0, MAX_PROMPT_PLACES)
    .map(area => {
      const hotels = area.hotels
        .slice(0, 8)
        .map(hotel => {
          const rating = hotel.rating != null ? `, ${hotel.rating}` : '';
          return `${hotel.name} ($${hotel.pricePerNight}/night${rating})`;
        })
        .join('; ');
      return `${area.destination}: ${hotels || '(none)'}`;
    })
    .join('\n');
};

/** Slim place objects for tool results / validation — drop fields the model does not need. */
const compactPlacesForPrompt = (places: ShortlistedPlace[]) =>
  sortPlacesForPrompt(places).slice(0, MAX_PROMPT_PLACES).map(place => ({
    name: place.name,
    avgTotalPrice: place.avgTotalPrice,
    avgAccommodationPrice: place.avgAccommodationPrice,
    rating: place.rating,
    inRadius: place.inRadius ?? false,
    distanceKm: place.distanceKm,
  }));

const AITripAssistant: React.FC<AITripAssistantProps> = ({
  selectedDestinations,
  destinations,
  accommodations,
  attractions,
  userLocation,
  radiusMeters,
  onApplyPlan,
}) => {
  const navigate = useNavigate();
  const [isOpen, setIsOpen] = useState(false);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState('');
  const [queryForm, setQueryForm] = useState<TripQueryForm>({
    budgetUsd: '200',
    userLocation: '',
    travelArea: 'Bandung',
    days: '3',
    tripType: 'vacation',
  });
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      role: 'assistant',
      content: 'Hi! Set your budget, travel area, days, and trip type, then ask a question. Use the location controls above for GPS + priority radius — nearby places are highlighted and preferred. Short trips keep routes light (3–5 hours); vacations allow fuller days.',
    },
  ]);

  const apiKey = import.meta.env.VITE_GROQ_API_KEY;

  const parseQueryForm = () => {
    const budgetUsd = Number(queryForm.budgetUsd);
    const days = Number(queryForm.days);
    // Prefer GPS/map coords + label when available; fall back to typed text.
    const anchorLabel = userLocation?.label?.trim() || queryForm.userLocation.trim();
    return {
      budgetUsd: Number.isFinite(budgetUsd) && budgetUsd > 0 ? budgetUsd : 0,
      userLocation: anchorLabel,
      travelArea: queryForm.travelArea.trim() || 'Bandung',
      days: Number.isFinite(days) && days > 0 ? Math.floor(days) : 1,
      tripType: queryForm.tripType,
      // Exact coords skip geocoding on the query tool and enable radius ranking.
      userCoords: userLocation?.coords ?? null,
      radiusMeters: Math.round(radiusMeters),
    };
  };

  const runQueryTravelPlaces = async (params: {
    budgetUsd: number;
    userLocation: string;
    travelArea: string;
    days: number;
    userCoords?: [number, number] | null;
    radiusMeters?: number;
  }): Promise<QueryTravelPlacesResult> => {
    logAiRequest('mcp-query_travel_places', params);

    let response: Response;
    try {
      response = await fetch(QUERY_TOOL_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
      });
    } catch {
      throw new Error(
        'Place query service is unreachable. Start it with `npm run query-tool` (port 8787).',
      );
    }

    if (!response.ok) {
      const details = await response.text();
      const emptyOrProxy =
        !details.trim() ||
        details.trim().startsWith('<') ||
        /proxy/i.test(details) ||
        response.status === 502 ||
        response.status === 503 ||
        response.status === 504;
      if (emptyOrProxy) {
        throw new Error(
          'Place query service is not running. Start it with `npm run query-tool` (port 8787).',
        );
      }
      throw new Error(details || `query_travel_places failed with status ${response.status}`);
    }

    return response.json();
  };

  const buildTripContext = () => selectedDestinations.map((routePoint, index) => {
    const destination = destinations.find(item => item.id === routePoint.destinationId);
    const selectedAccommodation = accommodations.find(
      item => item.id === routePoint.selectedAccommodationId,
    );
    const selectedAttractions = attractions.filter(item =>
      routePoint.selectedAttractions.includes(item.id),
    );

    return {
      stop: index + 1,
      destination: destination?.name,
      country: destination?.country,
      stayDurationDays: routePoint.stayDuration,
      accommodation: selectedAccommodation?.name,
      attractions: selectedAttractions.map(item => item.name),
    };
  });

  /** Attach distance / inRadius from the traveler's GPS anchor when available. */
  const annotateWithRadius = (places: ShortlistedPlace[]): ShortlistedPlace[] => {
    const origin = userLocation?.coords;
    if (!origin) {
      return places.map(place => ({ ...place, inRadius: false, coordinates: place.coordinates ?? null }));
    }

    return places.map(place => {
      const coords =
        place.coordinates ??
        destinations.find(d => d.name.toLowerCase() === place.name.toLowerCase())?.coordinates ??
        null;

      if (!coords) {
        return { ...place, inRadius: false, coordinates: null };
      }

      const meters = haversineMeters(origin, coords);
      return {
        ...place,
        coordinates: coords,
        distanceKm: Math.round((meters / 1000) * 100) / 100,
        inRadius: isWithinRadius(origin, coords, radiusMeters),
      };
    });
  };

  /** Local catalog fallback when the MCP place query is down — names + rough prices only. */
  const buildLocalShortlist = (): ShortlistedPlace[] => {
    return annotateWithRadius(destinations.map(destination => {
      const destHotels = accommodations.filter(item => item.destinationId === destination.id);
      const destAttractions = attractions.filter(item => item.destinationId === destination.id);
      const avgAcc = destHotels.length > 0
        ? destHotels.reduce((sum, item) => sum + item.price, 0) / destHotels.length
        : null;
      const totalAttr = destAttractions.reduce((sum, item) => sum + (item.price || 0), 0);
      const avgAttr = destAttractions.length > 0 ? totalAttr / destAttractions.length : 0;

      return {
        name: destination.name,
        avgAccommodationPrice: avgAcc,
        avgAttractionPrice: avgAttr,
        totalAttractionPrice: totalAttr,
        avgTotalPrice: avgAcc != null ? avgAcc + avgAttr : avgAttr,
        rating: destination.rating,
        district: null,
        city: destination.region || null,
        sameArea: false,
        distanceKm: null,
        affordableAttractions: true,
        coordinates: destination.coordinates,
        inRadius: false,
      };
    }).slice(0, 30));
  };

  /** Hotels only for shortlisted destination names — keeps the plan payload small. */
  const retrieveHotelsForShortlist = (shortlist: ShortlistedPlace[]): HotelArea[] => {
    const names = new Set(shortlist.slice(0, MAX_PROMPT_PLACES).map(item => item.name.toLowerCase()));
    return destinations
      .filter(destination => names.has(destination.name.toLowerCase()))
      .slice(0, MAX_PROMPT_PLACES)
      .map(destination => ({
        destination: destination.name,
        country: destination.country,
        hotels: accommodations
          .filter(item => item.destinationId === destination.id)
          .slice(0, 8)
          .map(item => ({
            name: item.name,
            pricePerNight: item.price,
            rating: item.rating,
          })),
      }));
  };

  const requestIntent = async (question: string): Promise<ConversationIntent['action']> => {
    const payload = {
      model: GROQ_MODEL,
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: [
        {
          role: 'system',
          content: 'Classify the user message for a travel planner. Return exactly one JSON object in this shape: {"action":"plan|chat|reject"}. Use plan for itinerary, route, budget, duration, hotel selection, or trip-building requests. Use chat for travel destination questions, recommendations, culture, weather, or general travel conversation. Use reject for anything unrelated to travel. The only allowed action values are plan, chat, and reject.',
        },
        {
          role: 'user',
          // Only the latest turn — history can wait for the chat/plan call.
          content: `New message: ${question}`,
        },
      ],
    };
    logAiRequest('intent', payload);

    const data = await fetchGroq(apiKey, payload, 'intent');
    const content = data.choices?.[0]?.message?.content;
    if (!content) throw new Error('Groq returned no conversation intent.');

    const intent = parseJsonResponse<ConversationIntent>(content);
    if (!['plan', 'chat', 'reject'].includes(intent.action)) {
      throw new Error('Groq returned an unsupported conversation intent.');
    }

    return intent.action;
  };

  const requestTravelChat = async (
    question: string,
    shortlist: ShortlistedPlace[],
  ): Promise<string> => {
    // Names first — never dump full destination/attraction objects into the prompt.
    const namesBlock = shortlist.length > 0
      ? formatShortlistForPrompt(shortlist)
      : destinations.slice(0, MAX_PROMPT_PLACES).map((item, index) => `${index + 1}. ${item.name}`).join('\n');

    const routeLines = buildTripContext()
      .map(stop => `${stop.stop}. ${stop.destination ?? '?'}${stop.stayDurationDays != null ? ` (${stop.stayDurationDays}d)` : ''}`)
      .join('\n') || '(empty)';

    const payload = {
      model: GROQ_MODEL,
      temperature: 0.4,
      messages: [
        {
          role: 'system',
          content: 'You are Pathsnap, a friendly travel destination assistant. Answer only travel-related questions. Use the supplied destination names (and compact prices when present). Do not invent specific facts, hotels, prices, or attractions that are not provided. If the context is insufficient, say so briefly. Keep the response under 120 words.',
        },
        ...messages.slice(-4).map(({ role, content }) => ({ role, content })),
        {
          role: 'user',
          content: `Destination names (from budget/location query):\n${namesBlock}\n\nCurrent route:\n${routeLines}\n\nQuestion: ${question}`,
        },
      ],
    };
    logAiRequest('travel-chat', payload);

    const data = await fetchGroq(apiKey, payload, 'travel-chat');
    const answer = data.choices?.[0]?.message?.content;
    if (!answer) throw new Error('Groq returned an empty travel response.');
    return answer;
  };

  /**
   * Plan flow: Groq tool-calling → query_travel_places MCP tool → plan on shortlist names only.
   * Payloads stay compact (names + prices only) to fit free-tier ITPM.
   */
  const requestTripPlanWithTools = async (
    question: string,
    formParams: ReturnType<typeof parseQueryForm>,
    shortlist: ShortlistedPlace[],
    hotelData: HotelArea[],
  ): Promise<TripPlanResponse> => {
    const maxStops = maxStopsForTrip(formParams.tripType, formParams.days);
    const paceRule = formParams.tripType === 'short'
      ? `Trip type is a normal short trip (about 3–5 hours). Include AT MOST ${maxStops} stops total. Prefer 2–3 nearby places. Do not pack a full-day tour into a short outing.`
      : `Trip type is a vacation (${formParams.days} day${formParams.days === 1 ? '' : 's'}). Include at most ${maxStops} stops total, about 3 places per day, and allow realistic travel time between places.`;

    const radiusKm = (radiusMeters / 1000).toFixed(radiusMeters >= 1000 ? 1 : 2);
    const radiusRule = userLocation?.coords
      ? `The traveler's anchor is ${userLocation.label} at ${userLocation.coords[0]}, ${userLocation.coords[1]}. STRONGLY PRIORITIZE places marked PRIORITY_IN_RADIUS or inRadius=true (within ${radiusKm} km). Prefer those for stops first; only add outside-radius places when the route needs more options.`
      : `If a location label is provided, prefer places near that area when possible.`;

    const systemContent = `You are Pathsnap's trip planning engine. First call query_travel_places with the provided form parameters to retrieve shortlisted place names and prices. Then return exactly ONE JSON object, never an array, with no markdown or extra text. Use exactly this shape: {"planTitle":"string","budgetUsd":number|null,"durationDays":number|null,"totalEstimatedHotelCostUsd":number,"withinBudget":boolean|null,"stops":[{"destination":"string","country":"string","nights":number,"hotel":string|null,"pricePerNightUsd":number,"hotelTotalUsd":number}],"notes":["string"]}. ${paceRule} ${radiusRule} Every place the traveler will visit MUST appear in stops — including day trips and places with no overnight stay. For a day visit set nights to 0, hotel to null, pricePerNightUsd to 0, and hotelTotalUsd to 0. Only set a hotel name when booking an overnight stay. The userLocation is only the trip starting point — never list it in stops unless it is also in the shortlist. Use only exact destination and hotel names from the tool results and hotel list. Never invent places, hotels, amenities, or prices.`;

    const routeLines = buildTripContext()
      .map(stop => `${stop.stop}. ${stop.destination ?? '?'}${stop.stayDurationDays != null ? ` (${stop.stayDurationDays}d)` : ''}`)
      .join('\n') || '(empty)';

    const userContent = `User request:\n${question}\n\nForm parameters for query_travel_places:\n${JSON.stringify(formParams)}\n\nPriority radius: ${radiusMeters} meters${userLocation?.coords ? ` around ${userLocation.label}` : ''}. Prefer PRIORITY_IN_RADIUS places.\n\nCurrent route:\n${routeLines}`;

    const baseMessages = [
      { role: 'system', content: systemContent },
      { role: 'user', content: userContent },
    ];

    const toolCallPayload = {
      model: GROQ_MODEL,
      temperature: 0,
      tools: [QUERY_TRAVEL_PLACES_TOOL],
      tool_choice: 'auto',
      messages: baseMessages,
    };
    logAiRequest('trip-plan:tool-call', toolCallPayload);

    const toolData = await fetchGroq(apiKey, toolCallPayload, 'trip-plan:tool-call');

    type GroqToolMessage = {
      role: string;
      content?: string | null;
      tool_calls?: Array<{
        id: string;
        type: string;
        function: { name: string; arguments: string };
      }>;
      tool_call_id?: string;
    };

    const toolMessage = toolData.choices?.[0]?.message as GroqToolMessage | undefined;

    const conversation: GroqToolMessage[] = [...baseMessages];
    // Compact tool payload — never re-send the full shortlist JSON twice.
    const hotelBlock = formatHotelsForPrompt(hotelData);

    if (toolMessage?.tool_calls?.length) {
      conversation.push({
        role: 'assistant',
        content: toolMessage.content ?? null,
        tool_calls: toolMessage.tool_calls,
      });

      for (const call of toolMessage.tool_calls) {
        if (call.function.name !== 'query_travel_places') {
          conversation.push({
            role: 'tool',
            tool_call_id: call.id,
            content: JSON.stringify({ error: `Unknown tool ${call.function.name}` }),
          });
          continue;
        }

        let args = formParams;
        try {
          args = { ...formParams, ...JSON.parse(call.function.arguments || '{}') };
        } catch {
          // keep form params if the model returned invalid JSON args
        }

        let toolResult: QueryTravelPlacesResult;
        try {
          toolResult = await runQueryTravelPlaces(args);
          toolResult.places = annotateWithRadius(toolResult.places);
        } catch (toolError) {
          console.warn('[query_travel_places] tool call failed, using precomputed shortlist:', toolError);
          toolResult = {
            query: args,
            count: shortlist.length,
            places: shortlist,
          };
        }
        conversation.push({
          role: 'tool',
          tool_call_id: call.id,
          // Compact places only — full JSON objects blow the free-tier token budget.
          content: JSON.stringify({
            count: toolResult.count,
            places: compactPlacesForPrompt(toolResult.places),
          }),
        });
      }
    } else {
      // Model skipped the tool — still feed the shortlist we already ran.
      conversation.push({
        role: 'tool',
        tool_call_id: 'forced-query',
        content: JSON.stringify({
          count: shortlist.length,
          places: compactPlacesForPrompt(shortlist),
        }),
      });
    }

    // Hotels + instruction only. Shortlist is already in the tool turn above.
    const planUserContent = `Available hotels:\n${hotelBlock}\n\nReturn the trip plan JSON now.`;
    conversation.push({ role: 'user', content: planUserContent });

    const planPayload = {
      model: GROQ_MODEL,
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: conversation,
    };
    logAiRequest('trip-plan:final', planPayload);

    const planData = await fetchGroq(apiKey, planPayload, 'trip-plan:final');
    const content = planData.choices?.[0]?.message?.content;
    if (!content) throw new Error('Groq returned an empty trip plan.');

    return validateTripPlan(
      parseJsonResponse<TripPlanResponse>(content),
      shortlist,
      hotelData.flatMap(area =>
        area.hotels.map(hotel => ({
          name: hotel.name,
          destination: area.destination.toLowerCase(),
          price: hotel.pricePerNight,
        })),
      ),
      {
        userLocation: formParams.userLocation,
        catalogNames: destinations.map(item => item.name),
        maxStops,
        tripType: formParams.tripType,
      },
    );
  };

  const sendMessage = async (event: React.FormEvent) => {
    event.preventDefault();
    const question = input.trim();

    if (!question || isLoading) return;

    const userMessage: ChatMessage = { role: 'user', content: question };
    setMessages(current => [...current, userMessage]);
    setInput('');
    setError('');

    if (!apiKey) {
      setError('Add VITE_GROQ_API_KEY to your local .env file to enable the assistant.');
      return;
    }

    setIsLoading(true);

    try {
      const formParams = parseQueryForm();

      // Run the MCP query first — compact names + prices only.
      let shortlist: ShortlistedPlace[] = [];
      let usingLocalFallback = false;
      try {
        const queryResult = await runQueryTravelPlaces(formParams);
        shortlist = annotateWithRadius(queryResult.places);
      } catch (queryError) {
        console.warn('[query_travel_places] falling back to local names only:', queryError);
        shortlist = buildLocalShortlist();
        usingLocalFallback = true;
      }

      const action = detectLocalIntent(question) ?? (await requestIntent(question));

      if (action === 'reject') {
        setMessages(current => [...current, {
          role: 'assistant',
          content: 'I can help with travel destinations, routes, budgets, hotels, activities, and trip planning. Please ask me a travel-related question.',
        }]);
        return;
      }

      const fallbackNote = usingLocalFallback
        ? 'Note: the live place query service was unreachable, so this uses the local catalog (not budget/location-ranked).\n\n'
        : '';

      if (action === 'chat') {
        const answer = await requestTravelChat(question, shortlist);
        setMessages(current => [...current, {
          role: 'assistant',
          content: fallbackNote ? `${fallbackNote}${answer}` : answer,
        }]);
        return;
      }

      const hotelData = retrieveHotelsForShortlist(shortlist);
      const tripPlan = await requestTripPlanWithTools(question, formParams, shortlist, hotelData);

      setMessages(current => [...current, {
        role: 'assistant',
        content: tripPlan.planTitle,
        plan: tripPlan,
      }]);
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to reach the assistant.');
    } finally {
      setIsLoading(false);
    }
  };

  const updateQueryForm = (field: keyof TripQueryForm, value: string) => {
    setQueryForm(current => ({ ...current, [field]: value }));
  };

  return (
    <div className="mt-6">
      {!isOpen ? (
        <button
          type="button"
          onClick={() => setIsOpen(true)}
          className="flex w-full items-center justify-between rounded-lg border border-teal-200 bg-teal-50 p-4 text-left transition-colors hover:bg-teal-100"
        >
          <span className="flex items-center">
            <span className="mr-3 rounded-full bg-teal-600 p-2 text-white">
              <Sparkles size={18} />
            </span>
            <span>
              <span className="block font-semibold text-gray-900">Ask the AI trip assistant</span>
              <span className="text-sm text-gray-600">Budget-aware place query, chat, and route plan</span>
            </span>
          </span>
          <Bot className="text-teal-700" size={20} />
        </button>
      ) : (
        <div className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-md">
          <div className="flex items-center justify-between bg-teal-600 p-4 text-white">
            <div className="flex items-center">
              <Bot size={20} className="mr-2" />
              <div>
                <h2 className="font-semibold">AI Trip Assistant</h2>
                <p className="text-xs text-teal-100">Powered by Groq + local place query</p>
              </div>
            </div>
            <button
              type="button"
              onClick={() => setIsOpen(false)}
              aria-label="Close AI trip assistant"
              className="rounded p-1 hover:bg-teal-700"
            >
              <X size={18} />
            </button>
          </div>

          <div className="border-b border-gray-100 bg-gray-50 p-3">
            <p className="mb-2 text-xs font-medium uppercase tracking-wide text-gray-500">
              Trip query
            </p>
            <div className="grid grid-cols-2 gap-2">
              <label className="block text-xs text-gray-600">
                Budget (USD)
                <input
                  type="number"
                  min="0"
                  value={queryForm.budgetUsd}
                  onChange={event => updateQueryForm('budgetUsd', event.target.value)}
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading}
                />
              </label>
              <label className="block text-xs text-gray-600">
                Days
                <input
                  type="number"
                  min="1"
                  value={queryForm.days}
                  onChange={event => updateQueryForm('days', event.target.value)}
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading}
                />
              </label>
              <label className="block text-xs text-gray-600">
                Your location
                <input
                  type="text"
                  value={userLocation?.label || queryForm.userLocation}
                  onChange={event => updateQueryForm('userLocation', event.target.value)}
                  placeholder="e.g. Coblong, Dago, or GPS"
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading || Boolean(userLocation)}
                  title={userLocation ? 'Location set via map/GPS controls above' : undefined}
                />
              </label>
              <label className="block text-xs text-gray-600">
                Travel area
                <input
                  type="text"
                  value={queryForm.travelArea}
                  onChange={event => updateQueryForm('travelArea', event.target.value)}
                  placeholder="e.g. Bandung"
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading}
                />
              </label>
              <label className="col-span-2 block text-xs text-gray-600">
                Trip type
                <select
                  value={queryForm.tripType}
                  onChange={event => updateQueryForm('tripType', event.target.value as TripType)}
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading}
                >
                  {TRIP_TYPE_OPTIONS.map(option => (
                    <option key={option.value} value={option.value}>
                      {option.label} — {option.hint}
                    </option>
                  ))}
                </select>
              </label>
            </div>
          </div>

          <div className="max-h-72 space-y-3 overflow-y-auto p-4">
            {messages.map((message, index) => (
              <div
                key={`${message.role}-${index}`}
                className={`flex ${message.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                {message.plan ? (
                  <div className="max-w-[95%] rounded-lg bg-gray-100 p-3 text-sm text-gray-700">
                    <h3 className="mb-2 font-semibold text-gray-900">{message.plan.planTitle}</h3>
                    <div className="mb-3 flex flex-wrap gap-x-4 gap-y-1 text-xs text-gray-600">
                      {message.plan.durationDays !== null && <span>{message.plan.durationDays} days</span>}
                      {message.plan.budgetUsd !== null && <span>Budget: {formatUsd(message.plan.budgetUsd)}</span>}
                      <span>Hotels: {formatUsd(message.plan.totalEstimatedHotelCostUsd)}</span>
                      {message.plan.withinBudget !== null && (
                        <span className={message.plan.withinBudget ? 'font-medium text-green-700' : 'font-medium text-red-700'}>
                          {message.plan.withinBudget ? 'Within budget' : 'Over budget'}
                        </span>
                      )}
                    </div>
                    <div className="space-y-2">
                      {message.plan.stops.map((stop, stopIndex) => {
                        const matchedDestination = findDestinationByName(destinations, stop.destination);
                        return (
                          <div key={`${stop.destination}-${stop.hotel ?? 'day'}-${stopIndex}`} className="rounded border border-gray-200 bg-white p-2">
                            <div className="flex items-start justify-between gap-2">
                              <p className="font-medium text-gray-900">
                                {stopIndex + 1}. {stop.destination}, {stop.country}
                              </p>
                              {matchedDestination && (
                                <span className="inline-flex items-center whitespace-nowrap rounded-full bg-yellow-50 px-2 py-0.5 text-xs font-medium text-yellow-800">
                                  <Star size={12} className="mr-0.5 text-yellow-400 fill-yellow-400" />
                                  {matchedDestination.rating.toFixed(1)}
                                </span>
                              )}
                            </div>
                            {stop.hotel && stop.nights > 0 ? (
                              <>
                                <p className="text-xs text-gray-600">
                                  {stop.nights} {stop.nights === 1 ? 'night' : 'nights'} at {stop.hotel}
                                </p>
                                <p className="text-xs text-gray-600">
                                  {formatUsd(stop.pricePerNightUsd)} / night, {formatUsd(stop.hotelTotalUsd)} total
                                </p>
                              </>
                            ) : (
                              <p className="text-xs text-gray-600">Day visit — no overnight stay</p>
                            )}
                            {matchedDestination && (
                              <button
                                type="button"
                                onClick={() => navigate(`/destinations/${matchedDestination.id}`)}
                                className="mt-2 inline-flex items-center gap-1 text-xs font-medium text-teal-600 hover:text-teal-700 hover:underline"
                              >
                                <ExternalLink size={12} />
                                View details
                              </button>
                            )}
                          </div>
                        );
                      })}
                    </div>
                    {message.plan.notes.length > 0 && (
                      <ul className="mt-3 list-disc space-y-1 pl-4 text-xs text-gray-600">
                        {message.plan.notes.map((note, noteIndex) => <li key={`${note}-${noteIndex}`}>{note}</li>)}
                      </ul>
                    )}
                    <button
                      type="button"
                      onClick={() => onApplyPlan(message.plan as TripPlanResponse)}
                      className="mt-3 w-full rounded-lg bg-teal-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-teal-700"
                    >
                      Add plan to Your Route
                    </button>
                  </div>
                ) : (
                  <p className={`max-w-[85%] rounded-lg px-3 py-2 text-sm whitespace-pre-wrap ${
                    message.role === 'user'
                      ? 'bg-teal-600 text-white'
                      : 'bg-gray-100 text-gray-700'
                  }`}>
                    {message.content}
                  </p>
                )}
              </div>
            ))}
            {isLoading && <p className="text-sm text-gray-500">Thinking...</p>}
            {error && <p className="text-sm text-red-600">{error}</p>}
          </div>

          <form onSubmit={sendMessage} className="flex gap-2 border-t p-3">
            <input
              value={input}
              onChange={event => setInput(event.target.value)}
              placeholder="Ask about your route..."
              aria-label="Ask the AI trip assistant"
              className="min-w-0 flex-1 rounded-lg border px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-teal-500"
              disabled={isLoading}
            />
            <button
              type="submit"
              aria-label="Send question"
              disabled={isLoading || !input.trim()}
              className="rounded-lg bg-teal-600 px-3 text-white transition-colors hover:bg-teal-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <Send size={18} />
            </button>
          </form>
        </div>
      )}
    </div>
  );
};

export default AITripAssistant;
