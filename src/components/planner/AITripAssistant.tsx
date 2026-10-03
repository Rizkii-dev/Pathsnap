import React, { useState } from 'react';
import { Bot, Send, Sparkles, X } from 'lucide-react';
import { Accommodation, Attraction, Destination, RoutePoint } from '../../types';

interface AITripAssistantProps {
  selectedDestinations: RoutePoint[];
  destinations: Destination[];
  accommodations: Accommodation[];
  attractions: Attraction[];
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

  const validatedStops = plan.stops.flatMap(stop => {
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
  let stops = validatedStops;

  // Day-trip models sometimes put the itinerary only in notes. Recover those visits
  // so "Add plan to Your Route" still has stops to apply.
  if (stops.length === 0 && plan.notes.length > 0) {
    const notesText = plan.notes.join(' ').toLowerCase();
    const recovered = shortlist
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

const formatShortlistForPrompt = (places: ShortlistedPlace[]): string => {
  if (places.length === 0) return '(no places returned)';
  return places
    .map((place, index) => {
      const parts = [
        `${index + 1}. ${place.name}`,
        place.avgTotalPrice != null ? `avgTotal=${formatUsd(place.avgTotalPrice)}` : null,
        place.avgAccommodationPrice != null ? `avgStay=${formatUsd(place.avgAccommodationPrice)}` : null,
        place.rating != null ? `rating=${place.rating}` : null,
        place.sameArea ? `nearYou${place.distanceKm != null ? ` (${place.distanceKm}km)` : ''}` : null,
      ].filter(Boolean);
      return parts.join(' | ');
    })
    .join('\n');
};

const AITripAssistant: React.FC<AITripAssistantProps> = ({
  selectedDestinations,
  destinations,
  accommodations,
  attractions,
  onApplyPlan,
}) => {
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
      content: 'Hi! Set your budget, location, travel area, days, and trip type, then ask a question. Short trips keep routes light (3–5 hours); vacations allow fuller days.',
    },
  ]);

  const apiKey = import.meta.env.VITE_GROQ_API_KEY;

  const parseQueryForm = () => {
    const budgetUsd = Number(queryForm.budgetUsd);
    const days = Number(queryForm.days);
    return {
      budgetUsd: Number.isFinite(budgetUsd) && budgetUsd > 0 ? budgetUsd : 0,
      userLocation: queryForm.userLocation.trim(),
      travelArea: queryForm.travelArea.trim() || 'Bandung',
      days: Number.isFinite(days) && days > 0 ? Math.floor(days) : 1,
      tripType: queryForm.tripType,
    };
  };

  const runQueryTravelPlaces = async (params: {
    budgetUsd: number;
    userLocation: string;
    travelArea: string;
    days: number;
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

  /** Local catalog fallback when the MCP place query is down — names + rough prices only. */
  const buildLocalShortlist = (): ShortlistedPlace[] => {
    return destinations.map(destination => {
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
      };
    }).slice(0, 30);
  };

  /** Hotels only for shortlisted destination names — keeps the plan payload small. */
  const retrieveHotelsForShortlist = (shortlist: ShortlistedPlace[]) => {
    const names = new Set(shortlist.map(item => item.name.toLowerCase()));
    return destinations
      .filter(destination => names.has(destination.name.toLowerCase()))
      .map(destination => ({
        destination: destination.name,
        country: destination.country,
        hotels: accommodations
          .filter(item => item.destinationId === destination.id)
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
          content: `Recent conversation:\n${JSON.stringify(messages.slice(-6).map(({ role, content }) => ({ role, content })))}\n\nNew message: ${question}`,
        },
      ],
    };
    logAiRequest('intent', payload);

    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error((await response.text()) || `Intent detection failed with status ${response.status}`);
    }

    const data: { choices?: Array<{ message?: { content?: string } }> } = await response.json();
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
      : destinations.slice(0, 30).map((item, index) => `${index + 1}. ${item.name}`).join('\n');

    const payload = {
      model: GROQ_MODEL,
      temperature: 0.4,
      messages: [
        {
          role: 'system',
          content: 'You are Pathsnap, a friendly travel destination assistant. Answer only travel-related questions. Use the supplied destination names (and compact prices when present). Do not invent specific facts, hotels, prices, or attractions that are not provided. If the context is insufficient, say so briefly. Keep the response under 120 words.',
        },
        ...messages.slice(-6).map(({ role, content }) => ({ role, content })),
        {
          role: 'user',
          content: `Destination names (from budget/location query):\n${namesBlock}\n\nCurrent route:\n${JSON.stringify(buildTripContext(), null, 2)}\n\nQuestion: ${question}`,
        },
      ],
    };
    logAiRequest('travel-chat', payload);

    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      throw new Error((await response.text()) || `Travel chat failed with status ${response.status}`);
    }

    const data: { choices?: Array<{ message?: { content?: string } }> } = await response.json();
    const answer = data.choices?.[0]?.message?.content;
    if (!answer) throw new Error('Groq returned an empty travel response.');
    return answer;
  };

  /**
   * Plan flow: Groq tool-calling → query_travel_places MCP tool → plan on shortlist names only.
   */
  const requestTripPlanWithTools = async (
    question: string,
    formParams: ReturnType<typeof parseQueryForm>,
    shortlist: ShortlistedPlace[],
    hotelData: ReturnType<typeof retrieveHotelsForShortlist>,
  ): Promise<TripPlanResponse> => {
    const maxStops = maxStopsForTrip(formParams.tripType, formParams.days);
    const paceRule = formParams.tripType === 'short'
      ? `Trip type is a normal short trip (about 3–5 hours). Include AT MOST ${maxStops} stops total. Prefer 2–3 nearby places. Do not pack a full-day tour into a short outing.`
      : `Trip type is a vacation (${formParams.days} day${formParams.days === 1 ? '' : 's'}). Include at most ${maxStops} stops total, about 3 places per day, and allow realistic travel time between places.`;

    const systemContent = `You are Pathsnap's trip planning engine. First call query_travel_places with the provided form parameters to retrieve shortlisted place names and prices. Then return exactly ONE JSON object, never an array, with no markdown or extra text. Use exactly this shape: {"planTitle":"string","budgetUsd":number|null,"durationDays":number|null,"totalEstimatedHotelCostUsd":number,"withinBudget":boolean|null,"stops":[{"destination":"string","country":"string","nights":number,"hotel":string|null,"pricePerNightUsd":number,"hotelTotalUsd":number}],"notes":["string"]}. ${paceRule} Every place the traveler will visit MUST appear in stops — including day trips and places with no overnight stay. For a day visit set nights to 0, hotel to null, pricePerNightUsd to 0, and hotelTotalUsd to 0. Only set a hotel name when booking an overnight stay. The userLocation is only the trip starting point — never list it in stops unless it is also in the shortlist. Use only exact destination and hotel names from the tool results and hotel list. Never invent places, hotels, amenities, or prices.`;

    const userContent = `User request:\n${question}\n\nForm parameters for query_travel_places:\n${JSON.stringify(formParams)}\n\nCurrent route:\n${JSON.stringify(buildTripContext())}`;

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

    const toolResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(toolCallPayload),
    });

    if (!toolResponse.ok) {
      throw new Error((await toolResponse.text()) || `Groq tool call failed with status ${toolResponse.status}`);
    }

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

    const toolData: { choices?: Array<{ message?: GroqToolMessage }> } = await toolResponse.json();
    const toolMessage = toolData.choices?.[0]?.message;

    const conversation: GroqToolMessage[] = [...baseMessages];

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
          content: JSON.stringify(toolResult),
        });
      }
    } else {
      // Model skipped the tool — still feed the shortlist we already ran.
      conversation.push({
        role: 'tool',
        tool_call_id: 'forced-query',
        content: JSON.stringify({
          query: formParams,
          count: shortlist.length,
          places: shortlist,
        }),
      });
    }

    // Hotel list is only the shortlisted destinations (not the full catalog).
    const planUserContent = `Retrieved shortlist (names + avg prices):\n${JSON.stringify(shortlist)}\n\nAvailable hotels for those places only:\n${JSON.stringify(hotelData)}\n\nReturn the trip plan JSON now.`;

    // If we already have an assistant tool_calls turn, continue after tool results.
    // Otherwise append a fresh user turn with the shortlist.
    if (toolMessage?.tool_calls?.length) {
      conversation.push({ role: 'user', content: planUserContent });
    } else {
      conversation.push({ role: 'user', content: planUserContent });
    }

    const planPayload = {
      model: GROQ_MODEL,
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: conversation,
    };
    logAiRequest('trip-plan:final', planPayload);

    const planResponse = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(planPayload),
    });

    if (!planResponse.ok) {
      throw new Error((await planResponse.text()) || `Groq plan request failed with status ${planResponse.status}`);
    }

    const planData: { choices?: Array<{ message?: { content?: string } }> } = await planResponse.json();
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
        shortlist = queryResult.places;
      } catch (queryError) {
        console.warn('[query_travel_places] falling back to local names only:', queryError);
        shortlist = buildLocalShortlist();
        usingLocalFallback = true;
      }

      const action = await requestIntent(question);

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
                  value={queryForm.userLocation}
                  onChange={event => updateQueryForm('userLocation', event.target.value)}
                  placeholder="e.g. Coblong, Dago, or Jln Diponegoro No 22"
                  className="mt-1 w-full rounded border border-gray-200 px-2 py-1 text-sm"
                  disabled={isLoading}
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
                      {message.plan.stops.map((stop, stopIndex) => (
                        <div key={`${stop.destination}-${stop.hotel ?? 'day'}-${stopIndex}`} className="rounded border border-gray-200 bg-white p-2">
                          <p className="font-medium text-gray-900">
                            {stopIndex + 1}. {stop.destination}, {stop.country}
                          </p>
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
                        </div>
                      ))}
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
