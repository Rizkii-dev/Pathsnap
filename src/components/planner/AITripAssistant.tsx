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

interface AreaOption {
  name: string;
  country: string;
  region: string;
}

interface AreaSelection {
  areas: string[];
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
    hotel: string;
    pricePerNightUsd: number;
    hotelTotalUsd: number;
  }>;
  notes: string[];
}

interface RetrievedAreaData {
  area: string;
  country: string;
  destinations: Array<{
    name: string;
    description: string;
    rating: number;
    priceRange: number;
    hotels: Array<{
      name: string;
      pricePerNight: number;
      rating: number;
      type: string;
      amenities: string[];
    }>;
  }>;
}

const GROQ_API_URL = 'https://api.groq.com/openai/v1/chat/completions';
const GROQ_MODEL = 'qwen/qwen3.8-27b';

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
  retrievedData: RetrievedAreaData[],
): TripPlanResponse => {
  if (!plan || typeof plan !== 'object' || !Array.isArray(plan.stops) || !Array.isArray(plan.notes)) {
    throw new Error('The assistant returned an invalid trip plan shape.');
  }

  const availableDestinations = retrievedData.flatMap(area => area.destinations);
  let calculatedTotal = 0;

  const validatedStops = plan.stops.map(stop => {
    const destination = availableDestinations.find(item =>
      item.name.toLowerCase() === stop.destination?.toLowerCase(),
    );
    const hotel = destination?.hotels.find(item =>
      item.name.toLowerCase() === stop.hotel?.toLowerCase(),
    );

    if (!destination || !hotel) {
      throw new Error(`The assistant selected travel data that was not retrieved: ${stop.destination} / ${stop.hotel}.`);
    }

    if (!Number.isInteger(stop.nights) || stop.nights < 1) {
      throw new Error('The assistant returned an invalid number of nights.');
    }

    const hotelTotal = hotel.pricePerNight * stop.nights;
    calculatedTotal += hotelTotal;

    return {
      destination: destination.name,
      country: retrievedData.find(area => area.destinations.includes(destination))?.country || stop.country,
      nights: stop.nights,
      hotel: hotel.name,
      pricePerNightUsd: hotel.pricePerNight,
      hotelTotalUsd: hotelTotal,
    };
  });

  const budget = typeof plan.budgetUsd === 'number' ? plan.budgetUsd : null;
  return {
    planTitle: String(plan.planTitle || 'Trip plan'),
    budgetUsd: budget,
    durationDays: typeof plan.durationDays === 'number' ? plan.durationDays : null,
    totalEstimatedHotelCostUsd: calculatedTotal,
    withinBudget: budget === null ? null : calculatedTotal <= budget,
    stops: validatedStops,
    notes: plan.notes.map(note => String(note)),
  };
};

const formatUsd = (amount: number): string => `$${amount.toLocaleString('en-US', {
  minimumFractionDigits: 0,
  maximumFractionDigits: 2,
})}`;

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
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      role: 'assistant',
      content: 'Hi! I can chat about destinations or build a route across multiple areas. Ask about places to stay, attractions, timing, or your travel budget.',
    },
  ]);

  const apiKey = import.meta.env.VITE_GROQ_API_KEY;

  const areaOptions: AreaOption[] = destinations.map(destination => ({
    name: destination.name,
    country: destination.country,
    region: destination.region,
  }));

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
      climate: destination?.climate,
      stayDurationDays: routePoint.stayDuration,
      accommodation: selectedAccommodation?.name,
      attractions: selectedAttractions.map(item => item.name),
    };
  });

  // This is the local MCP-style tool: the model chooses areas, but the app controls retrieval.
  const retrieveTravelData = (requestedAreas: string[]): RetrievedAreaData[] => {
    const matchingDestinations = requestedAreas.flatMap(requestedArea => destinations.filter(destination => {
      const normalizedArea = requestedArea.toLowerCase();
      return destination.name.toLowerCase() === normalizedArea ||
        destination.country.toLowerCase() === normalizedArea ||
        destination.region.toLowerCase() === normalizedArea;
    }));
    const uniqueDestinations = matchingDestinations.filter((destination, index, allDestinations) =>
      allDestinations.findIndex(item => item.id === destination.id) === index,
    );

    return uniqueDestinations.map(destination => ({
        area: destination.name,
        country: destination.country,
        destinations: [{
          name: destination.name,
          description: destination.description,
          rating: destination.rating,
          priceRange: destination.priceRange,
          hotels: accommodations
            .filter(item => item.destinationId === destination.id)
            .map(item => ({
              name: item.name,
              pricePerNight: item.price,
              rating: item.rating,
              type: item.type,
              amenities: item.amenities,
            })),
        }],
      }));
  };

  const requestAreaSelection = async (question: string): Promise<string[]> => {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        temperature: 0,
        response_format: { type: 'json_object' },
        messages: [
          {
            role: 'system',
            content: 'You select travel data sources for Pathsnap. Choose only areas from the supplied allowlist. Return JSON only in this exact shape: {"areas":["Area Name"]}. A plan may contain multiple areas, destinations, countries, or regions, so select every matching area that could help answer the user. For example, a request for multiple Asian destinations should select all relevant matching areas. Select at least one when the request is travel-related.',
          },
          {
            role: 'user',
            content: `Available areas:\n${JSON.stringify(areaOptions)}\n\nUser request: ${question}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error((await response.text()) || `Area selection failed with status ${response.status}`);
    }

    const data: { choices?: Array<{ message?: { content?: string } }> } = await response.json();
    const content = data.choices?.[0]?.message?.content;
    if (!content) throw new Error('Groq returned no area selection.');

    const selection = parseJsonResponse<AreaSelection>(content);
    const allowedAreas = new Set(areaOptions.flatMap(area => [
      area.name.toLowerCase(),
      area.country.toLowerCase(),
      area.region.toLowerCase(),
    ]));
    return selection.areas.filter(area => allowedAreas.has(area.toLowerCase()));
  };

  const requestIntent = async (question: string): Promise<ConversationIntent['action']> => {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
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
      }),
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

  const requestTravelChat = async (question: string): Promise<string> => {
    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        temperature: 0.4,
        messages: [
          {
            role: 'system',
            content: 'You are Pathsnap, a friendly travel destination assistant. Answer only travel-related questions. Use the supplied destination context and current route when relevant. Do not invent specific facts, hotels, prices, or attractions that are not provided. If the context is insufficient, say so briefly. Keep the response under 120 words.',
          },
          ...messages.slice(-6).map(({ role, content }) => ({ role, content })),
          {
            role: 'user',
            content: `Destination context:\n${JSON.stringify({ destinations, attractions }, null, 2)}\n\nCurrent route:\n${JSON.stringify(buildTripContext(), null, 2)}\n\nQuestion: ${question}`,
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error((await response.text()) || `Travel chat failed with status ${response.status}`);
    }

    const data: { choices?: Array<{ message?: { content?: string } }> } = await response.json();
    const answer = data.choices?.[0]?.message?.content;
    if (!answer) throw new Error('Groq returned an empty travel response.');
    return answer;
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
      const action = await requestIntent(question);

      if (action === 'reject') {
        setMessages(current => [...current, {
          role: 'assistant',
          content: 'I can help with travel destinations, routes, budgets, hotels, activities, and trip planning. Please ask me a travel-related question.',
        }]);
        return;
      }

      if (action === 'chat') {
        const answer = await requestTravelChat(question);
        setMessages(current => [...current, { role: 'assistant', content: answer }]);
        return;
      }

      const selectedAreas = await requestAreaSelection(question);
      const retrievedData = retrieveTravelData(selectedAreas);

      if (retrievedData.length === 0) {
        throw new Error('No matching travel data was found for the areas selected by the assistant.');
      }

      const response = await fetch(GROQ_API_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: GROQ_MODEL,
          temperature: 0,
          response_format: { type: 'json_object' },
          messages: [
            {
              role: 'system',
              content: 'You are Pathsnap\'s trip planning engine. Return exactly ONE JSON object, never an array, with no markdown or extra text. Use exactly this shape: {"planTitle":"string","budgetUsd":number|null,"durationDays":number|null,"totalEstimatedHotelCostUsd":number,"withinBudget":boolean|null,"stops":[{"destination":"string","country":"string","nights":number,"hotel":"string","pricePerNightUsd":number,"hotelTotalUsd":number}],"notes":["string"]}. The stops array must contain only one object per selected hotel. Use only exact destination and hotel names from the retrieved data. Never invent activities, destinations, hotels, amenities, or prices. Use the exact retrieved hotel price as pricePerNightUsd. Calculate hotelTotalUsd as nights multiplied by pricePerNightUsd and totalEstimatedHotelCostUsd as the sum of hotelTotalUsd. If the requested budget cannot be met, set withinBudget to false; never change a retrieved price to make it fit. If the request does not specify a budget or duration, use null. Keep notes concise.',
            },
            {
              role: 'user',
              content: `User request:\n${question}\n\nCurrent route context:\n${JSON.stringify(buildTripContext(), null, 2)}\n\nAreas selected by the data-source step:\n${JSON.stringify(selectedAreas)}\n\nRetrieved destination and hotel data (the only source of prices):\n${JSON.stringify(retrievedData, null, 2)}`,
            },
          ],
        }),
      });

      if (!response.ok) {
        const details = await response.text();
        throw new Error(details || `Groq request failed with status ${response.status}`);
      }

      const data: { choices?: Array<{ message?: { content?: string } }> } = await response.json();
      const content = data.choices?.[0]?.message?.content;

      if (!content) {
        throw new Error('Groq returned an empty response.');
      }

      const tripPlan = validateTripPlan(
        parseJsonResponse<TripPlanResponse>(content),
        retrievedData,
      );

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
              <span className="text-sm text-gray-600">Chat or build a multi-area route with AI</span>
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
                <p className="text-xs text-teal-100">Powered by Groq</p>
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
                        <div key={`${stop.destination}-${stop.hotel}-${stopIndex}`} className="rounded border border-gray-200 bg-white p-2">
                          <p className="font-medium text-gray-900">
                            {stopIndex + 1}. {stop.destination}, {stop.country}
                          </p>
                          <p className="text-xs text-gray-600">
                            {stop.nights} {stop.nights === 1 ? 'night' : 'nights'} at {stop.hotel}
                          </p>
                          <p className="text-xs text-gray-600">
                            {formatUsd(stop.pricePerNightUsd)} / night, {formatUsd(stop.hotelTotalUsd)} total
                          </p>
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