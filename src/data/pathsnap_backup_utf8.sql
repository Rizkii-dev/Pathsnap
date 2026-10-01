--
-- PostgreSQL database dump
--

-- Dumped from database version 16.4 (Debian 16.4-1.pgdg110+2)
-- Dumped by pg_dump version 16.4 (Debian 16.4-1.pgdg110+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: tiger; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger;


ALTER SCHEMA tiger OWNER TO postgres;

--
-- Name: tiger_data; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA tiger_data;


ALTER SCHEMA tiger_data OWNER TO postgres;

--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA topology;


ALTER SCHEMA topology OWNER TO postgres;

--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: fuzzystrmatch; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS fuzzystrmatch WITH SCHEMA public;


--
-- Name: EXTENSION fuzzystrmatch; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION fuzzystrmatch IS 'determine similarities and distance between strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_tiger_geocoder; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder WITH SCHEMA tiger;


--
-- Name: EXTENSION postgis_tiger_geocoder; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_tiger_geocoder IS 'PostGIS tiger geocoder and reverse geocoder';


--
-- Name: postgis_topology; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_topology WITH SCHEMA topology;


--
-- Name: EXTENSION postgis_topology; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis_topology IS 'PostGIS topology spatial types and functions';


--
-- Name: accommodation_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.accommodation_type AS ENUM (
    'hotel',
    'villa',
    'resort',
    'hostel',
    'guesthouse',
    'homestay',
    'apartment',
    'glamping',
    'campground',
    'other'
);


ALTER TYPE public.accommodation_type OWNER TO postgres;

--
-- Name: entity_kind; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.entity_kind AS ENUM (
    'place',
    'accommodation'
);


ALTER TYPE public.entity_kind OWNER TO postgres;

--
-- Name: price_level; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.price_level AS ENUM (
    'free',
    'budget',
    'moderate',
    'expensive',
    'luxury'
);


ALTER TYPE public.price_level OWNER TO postgres;

--
-- Name: scrape_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.scrape_status AS ENUM (
    'pending',
    'extracted',
    'needs_review',
    'approved',
    'rejected',
    'duplicate'
);


ALTER TYPE public.scrape_status OWNER TO postgres;

--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


ALTER FUNCTION public.set_updated_at() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accommodation_amenities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accommodation_amenities (
    accommodation_id bigint NOT NULL,
    amenity_id integer NOT NULL
);


ALTER TABLE public.accommodation_amenities OWNER TO postgres;

--
-- Name: accommodation_images; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accommodation_images (
    id bigint NOT NULL,
    accommodation_id bigint NOT NULL,
    url text NOT NULL,
    caption character varying(200),
    is_cover boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.accommodation_images OWNER TO postgres;

--
-- Name: accommodation_images_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accommodation_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accommodation_images_id_seq OWNER TO postgres;

--
-- Name: accommodation_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accommodation_images_id_seq OWNED BY public.accommodation_images.id;


--
-- Name: accommodations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.accommodations (
    id bigint NOT NULL,
    slug character varying(160) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    type public.accommodation_type NOT NULL,
    star_class smallint,
    city_id integer NOT NULL,
    address text,
    location public.geography(Point,4326) NOT NULL,
    latitude double precision GENERATED ALWAYS AS (public.st_y((location)::public.geometry)) STORED,
    longitude double precision GENERATED ALWAYS AS (public.st_x((location)::public.geometry)) STORED,
    rating_avg numeric(2,1),
    rating_count integer DEFAULT 0 NOT NULL,
    price_per_night_min numeric(12,0),
    price_per_night_max numeric(12,0),
    price_level public.price_level,
    check_in_time time without time zone,
    check_out_time time without time zone,
    total_rooms integer,
    max_guests integer,
    phone character varying(30),
    website text,
    booking_url text,
    google_place_id character varying(100),
    is_hidden_gem boolean DEFAULT false NOT NULL,
    hidden_gem_score numeric(4,3),
    hidden_gem_reason text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    district_id integer,
    osm_ref character varying(30),
    enriched_at timestamp with time zone,
    CONSTRAINT accommodations_check CHECK ((price_per_night_max >= price_per_night_min)),
    CONSTRAINT accommodations_hidden_gem_score_check CHECK (((hidden_gem_score >= (0)::numeric) AND (hidden_gem_score <= (1)::numeric))),
    CONSTRAINT accommodations_price_per_night_min_check CHECK ((price_per_night_min >= (0)::numeric)),
    CONSTRAINT accommodations_rating_avg_check CHECK (((rating_avg >= (0)::numeric) AND (rating_avg <= (5)::numeric))),
    CONSTRAINT accommodations_star_class_check CHECK (((star_class >= 1) AND (star_class <= 5)))
);


ALTER TABLE public.accommodations OWNER TO postgres;

--
-- Name: accommodations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.accommodations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.accommodations_id_seq OWNER TO postgres;

--
-- Name: accommodations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.accommodations_id_seq OWNED BY public.accommodations.id;


--
-- Name: ai_extractions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ai_extractions (
    id bigint NOT NULL,
    raw_item_id bigint NOT NULL,
    model_name character varying(100) NOT NULL,
    prompt_version character varying(30),
    extracted_kind public.entity_kind,
    extracted_data jsonb NOT NULL,
    hidden_gem_score numeric(4,3),
    hidden_gem_reason text,
    confidence numeric(4,3),
    needs_review boolean DEFAULT true NOT NULL,
    promoted_place_id bigint,
    promoted_accommodation_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ai_extractions_check CHECK (((promoted_place_id IS NULL) OR (promoted_accommodation_id IS NULL)))
);


ALTER TABLE public.ai_extractions OWNER TO postgres;

--
-- Name: ai_extractions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ai_extractions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ai_extractions_id_seq OWNER TO postgres;

--
-- Name: ai_extractions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ai_extractions_id_seq OWNED BY public.ai_extractions.id;


--
-- Name: amenities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.amenities (
    id integer NOT NULL,
    name character varying(80) NOT NULL
);


ALTER TABLE public.amenities OWNER TO postgres;

--
-- Name: amenities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.amenities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.amenities_id_seq OWNER TO postgres;

--
-- Name: amenities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.amenities_id_seq OWNED BY public.amenities.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id integer NOT NULL,
    name character varying(80) NOT NULL,
    slug character varying(80) NOT NULL
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: cities; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.cities (
    id integer NOT NULL,
    province_id integer NOT NULL,
    name character varying(100) NOT NULL,
    type character varying(20) DEFAULT 'kota'::character varying,
    boundary public.geography(MultiPolygon,4326)
);


ALTER TABLE public.cities OWNER TO postgres;

--
-- Name: cities_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.cities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cities_id_seq OWNER TO postgres;

--
-- Name: cities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.cities_id_seq OWNED BY public.cities.id;


--
-- Name: data_sources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.data_sources (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    base_url text,
    notes text
);


ALTER TABLE public.data_sources OWNER TO postgres;

--
-- Name: data_sources_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.data_sources_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.data_sources_id_seq OWNER TO postgres;

--
-- Name: data_sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.data_sources_id_seq OWNED BY public.data_sources.id;


--
-- Name: districts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.districts (
    id integer NOT NULL,
    city_id integer NOT NULL,
    name character varying(100) NOT NULL,
    boundary public.geography(MultiPolygon,4326)
);


ALTER TABLE public.districts OWNER TO postgres;

--
-- Name: districts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.districts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.districts_id_seq OWNER TO postgres;

--
-- Name: districts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.districts_id_seq OWNED BY public.districts.id;


--
-- Name: place_images; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.place_images (
    id bigint NOT NULL,
    place_id bigint NOT NULL,
    url text NOT NULL,
    caption character varying(200),
    is_cover boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.place_images OWNER TO postgres;

--
-- Name: place_images_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.place_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.place_images_id_seq OWNER TO postgres;

--
-- Name: place_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.place_images_id_seq OWNED BY public.place_images.id;


--
-- Name: place_sources; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.place_sources (
    place_id bigint NOT NULL,
    source_id integer NOT NULL,
    source_url text,
    last_synced timestamp with time zone
);


ALTER TABLE public.place_sources OWNER TO postgres;

--
-- Name: place_tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.place_tags (
    place_id bigint NOT NULL,
    tag_id integer NOT NULL
);


ALTER TABLE public.place_tags OWNER TO postgres;

--
-- Name: places; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.places (
    id bigint NOT NULL,
    slug character varying(160) NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    category_id integer,
    city_id integer NOT NULL,
    address text,
    location public.geography(Point,4326) NOT NULL,
    latitude double precision GENERATED ALWAYS AS (public.st_y((location)::public.geometry)) STORED,
    longitude double precision GENERATED ALWAYS AS (public.st_x((location)::public.geometry)) STORED,
    rating_avg numeric(2,1),
    rating_count integer DEFAULT 0 NOT NULL,
    price_min numeric(12,0),
    price_max numeric(12,0),
    price_level public.price_level,
    opening_hours jsonb,
    phone character varying(30),
    website text,
    google_place_id character varying(100),
    is_hidden_gem boolean DEFAULT false NOT NULL,
    hidden_gem_score numeric(4,3),
    hidden_gem_reason text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    district_id integer,
    osm_ref character varying(30),
    enriched_at timestamp with time zone,
    CONSTRAINT places_check CHECK ((price_max >= price_min)),
    CONSTRAINT places_hidden_gem_score_check CHECK (((hidden_gem_score >= (0)::numeric) AND (hidden_gem_score <= (1)::numeric))),
    CONSTRAINT places_price_min_check CHECK ((price_min >= (0)::numeric)),
    CONSTRAINT places_rating_avg_check CHECK (((rating_avg >= (0)::numeric) AND (rating_avg <= (5)::numeric)))
);


ALTER TABLE public.places OWNER TO postgres;

--
-- Name: places_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.places_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.places_id_seq OWNER TO postgres;

--
-- Name: places_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.places_id_seq OWNED BY public.places.id;


--
-- Name: provinces; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.provinces (
    id integer NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.provinces OWNER TO postgres;

--
-- Name: provinces_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.provinces_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.provinces_id_seq OWNER TO postgres;

--
-- Name: provinces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.provinces_id_seq OWNED BY public.provinces.id;


--
-- Name: raw_scraped_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.raw_scraped_items (
    id bigint NOT NULL,
    run_id bigint NOT NULL,
    source_url text,
    raw_payload jsonb NOT NULL,
    content_hash character(64),
    status public.scrape_status DEFAULT 'pending'::public.scrape_status NOT NULL,
    scraped_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.raw_scraped_items OWNER TO postgres;

--
-- Name: raw_scraped_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.raw_scraped_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.raw_scraped_items_id_seq OWNER TO postgres;

--
-- Name: raw_scraped_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.raw_scraped_items_id_seq OWNED BY public.raw_scraped_items.id;


--
-- Name: scrape_runs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.scrape_runs (
    id bigint NOT NULL,
    source_id integer NOT NULL,
    query text,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    items_found integer DEFAULT 0
);


ALTER TABLE public.scrape_runs OWNER TO postgres;

--
-- Name: scrape_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.scrape_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.scrape_runs_id_seq OWNER TO postgres;

--
-- Name: scrape_runs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.scrape_runs_id_seq OWNED BY public.scrape_runs.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tags (
    id integer NOT NULL,
    name character varying(60) NOT NULL
);


ALTER TABLE public.tags OWNER TO postgres;

--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tags_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tags_id_seq OWNER TO postgres;

--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: accommodation_images id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_images ALTER COLUMN id SET DEFAULT nextval('public.accommodation_images_id_seq'::regclass);


--
-- Name: accommodations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations ALTER COLUMN id SET DEFAULT nextval('public.accommodations_id_seq'::regclass);


--
-- Name: ai_extractions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_extractions ALTER COLUMN id SET DEFAULT nextval('public.ai_extractions_id_seq'::regclass);


--
-- Name: amenities id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amenities ALTER COLUMN id SET DEFAULT nextval('public.amenities_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: cities id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities ALTER COLUMN id SET DEFAULT nextval('public.cities_id_seq'::regclass);


--
-- Name: data_sources id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_sources ALTER COLUMN id SET DEFAULT nextval('public.data_sources_id_seq'::regclass);


--
-- Name: districts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.districts ALTER COLUMN id SET DEFAULT nextval('public.districts_id_seq'::regclass);


--
-- Name: place_images id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_images ALTER COLUMN id SET DEFAULT nextval('public.place_images_id_seq'::regclass);


--
-- Name: places id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places ALTER COLUMN id SET DEFAULT nextval('public.places_id_seq'::regclass);


--
-- Name: provinces id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.provinces ALTER COLUMN id SET DEFAULT nextval('public.provinces_id_seq'::regclass);


--
-- Name: raw_scraped_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raw_scraped_items ALTER COLUMN id SET DEFAULT nextval('public.raw_scraped_items_id_seq'::regclass);


--
-- Name: scrape_runs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scrape_runs ALTER COLUMN id SET DEFAULT nextval('public.scrape_runs_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Data for Name: accommodation_amenities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accommodation_amenities (accommodation_id, amenity_id) FROM stdin;
\.


--
-- Data for Name: accommodation_images; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accommodation_images (id, accommodation_id, url, caption, is_cover, sort_order) FROM stdin;
\.


--
-- Data for Name: accommodations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.accommodations (id, slug, name, description, type, star_class, city_id, address, location, rating_avg, rating_count, price_per_night_min, price_per_night_max, price_level, check_in_time, check_out_time, total_rooms, max_guests, phone, website, booking_url, google_place_id, is_hidden_gem, hidden_gem_score, hidden_gem_reason, is_active, created_at, updated_at, district_id, osm_ref, enriched_at) FROM stdin;
1	hotel-sukajadi-n29391348	Hotel Sukajadi	\N	hotel	\N	1	\N	0101000020E61000003DD2E0B636E65A40DF9A85877A8B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/29391348	\N
2	imperium-n29392374	Imperium	\N	hotel	\N	1	\N	0101000020E6100000ED9F02BB75E65A40C461C499BA9E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/29392374	\N
3	topaz-n32042016	Topaz	\N	hotel	\N	1	\N	0101000020E6100000A462ADEB61E55A407D810F142E921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/32042016	\N
4	grand-hotel-preanger-n32520353	Grand Hotel Preanger	\N	hotel	\N	1	Jalan Asia Afrika, 81	0101000020E6100000ED9DD15625E75A40BE94CB9074AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	https://aerowisatahotels.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/32520353	\N
5	padma-hotel-bandung-n479731735	Padma Hotel Bandung	\N	hotel	\N	1	Jalan Rancabentang, #56-58, Bandung	0101000020E610000056B77A4EFAE65A403303F0AA62751BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/479731735	\N
6	grha-ciumbuleuit-guest-house-n479731737	Grha Ciumbuleuit Guest House	\N	hotel	\N	1	Jalan Ciumbeuluit	0101000020E6100000F73471BCCCE65A40E22E0CA2FF771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	https://grhaciumbuleuitgh.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/479731737	\N
7	arion-swiss-bell-n1013447614	Arion Swiss Bell	\N	hotel	\N	1	\N	0101000020E61000003132B731ACE65A40276D05A804A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1013447614	\N
8	jayakarta-n1099327692	Jayakarta	\N	hotel	\N	1	Ir. H Juanda	0101000020E610000049D6E1E8AAE75A4026F5AFF6C17B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1099327692	\N
9	camerlang-n1158819836	Camerlang	\N	hotel	\N	1	\N	0101000020E6100000BB8CAC4640E65A40202922C32AA61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1158819836	\N
10	mutiara-n1158819872	Mutiara	\N	hotel	\N	1	\N	0101000020E6100000D9A898944CE65A409DD66D50FBA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1158819872	\N
11	edelweiss-n1212690953	Edelweiss	\N	hotel	\N	1	\N	0101000020E610000058E4D70F31E65A404A8CAF8740871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1212690953	\N
12	hotel-patra-jasa-n1342928043	Hotel Patra Jasa	\N	hotel	\N	1	\N	0101000020E61000004B28339449E75A404EF80038518E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342928043	\N
13	hotel-utari-n1342944385	Hotel Utari	\N	hotel	\N	1	\N	0101000020E61000009D0E643D35E75A40D1CB28965B9A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342944385	\N
14	hotel-karmila-n1342944393	Hotel Karmila	\N	hotel	\N	1	\N	0101000020E6100000CFCCDDF824E75A4016985F178F9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342944393	\N
15	utc-dago-hotel-n1342944408	UTC Dago Hotel	\N	hotel	\N	1	Jl. Ir. H. Juanda, 4, Bandung	0101000020E6100000175CBDD419E75A409D4B7155D99F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342944408	\N
16	hotel-halmahera-n1342948124	Hotel Halmahera	\N	hotel	\N	1	\N	0101000020E6100000804754A86EE75A40D6355A0EF4A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342948124	\N
17	hotel-gandasari-n1342948128	Hotel Gandasari	\N	hotel	\N	1	\N	0101000020E6100000D69B07663BE75A406F4B3F3CA6A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342948128	\N
18	hotel-royal-palace-n1342970049	Hotel Royal Palace	\N	hotel	\N	1	\N	0101000020E6100000BD1C76DF31E75A401CB3EC4960AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342970049	\N
19	hotel-royal-merdeka-n1342970053	Hotel Royal Merdeka	\N	hotel	\N	1	\N	0101000020E610000077CC8AF216E75A4050AFEF1EFBA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1342970053	\N
20	sheraton-bandung-hotel-towers-n1381753562	Sheraton Bandung Hotel & Towers	\N	hotel	\N	1	Jalan Ir. H. Juanda, 390, Bandung	0101000020E61000008D1C339AA6E75A4086A52666627F1BC0	\N	0	\N	\N	\N	\N	\N	156	\N	+62 22 2500303	https://www.marriott.com/hotels/travel/bdosi-sheraton-bandung-hotel-and-towers/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1381753562	\N
21	wisma-putri-pocut-baren-n1385463113	Wisma Putri Pocut Baren	\N	other	\N	1	\N	0101000020E61000006F0388CCA6E75A409CCD99A37D8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1385463113	\N
22	sari-ater-kamboti-bandung-n1586233214	Sari Ater Kamboti Bandung	\N	hotel	\N	1	\N	0101000020E61000001419671D1FE55A407E62AE5637881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 222-011000	https://sariater-hotel.com/kamboti	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1586233214	\N
23	the-majesty-hotel-n1587039078	The Majesty Hotel	\N	hotel	\N	1	Jl. Surya Sumantri, Bandung	0101000020E6100000E25AED612FE55A409010E50B5A881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1587039078	\N
24	provence-n1655564498	Provence	\N	hotel	\N	1	\N	0101000020E610000092CCEA1D6EE55A4025A7C013C4721BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1655564498	\N
25	perdana-wisata-n1700853213	Perdana Wisata	\N	hotel	\N	1	\N	0101000020E6100000A719F78B7EE65A402ABD80A845AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	https://www.hotelperdanawisata.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1700853213	\N
26	hotel-agusta-n1706574395	Hotel Agusta	\N	hotel	\N	1	\N	0101000020E61000005842D2028FE85A408E812B8F24971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1706574395	\N
27	hotel-yehezkiel-n1706574396	Hotel Yehezkiel	\N	hotel	\N	1	\N	0101000020E6100000C10B11267BE85A40174273428D971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1706574396	\N
28	hotel-california-n1785955514	Hotel California	\N	other	\N	1	\N	0101000020E610000040BC53A6BDE65A404A51781A7A9D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1785955514	\N
29	otten-inn-n1788564509	Otten Inn	\N	other	\N	1	\N	0101000020E610000027AE19CF56E65A402828452BF79A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1788564509	\N
30	otten-ville-boutique-hotel-n1788564513	Otten Ville Boutique Hotel	\N	hotel	\N	1	\N	0101000020E6100000AE60C03772E65A40871FF708909C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1788564513	\N
31	bumi-bhandawa-n1801234292	Bumi Bhandawa	\N	hotel	\N	1	\N	0101000020E6100000F471C8610BE85A40F174F8B53F891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1801234292	\N
32	sensa-n1924435640	Sensa	\N	hotel	\N	1	\N	0101000020E610000060014C19B8E65A40FA55CA7C51941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1924435640	\N
33	aston-tropicana-n1924439599	Aston Tropicana	\N	hotel	4	1	\N	0101000020E610000048AD8B36A2E65A400DCE9662FD951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1924439599	\N
34	fave-n1924439614	Fave	\N	hotel	\N	1	\N	0101000020E6100000E2299ABDA2E65A405725917D90951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1924439614	\N
35	cherry-homes-n2016397751	Cherry Homes	\N	hotel	\N	1	\N	0101000020E6100000582A5E1B60E55A4041237DFF8B8C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2016397751	\N
36	hotel-gegerkalong-asri-n2039449490	Hotel Gegerkalong Asri	\N	hotel	\N	1	\N	0101000020E61000005956F54D75E55A404A91216C1D791BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2039449490	\N
37	papandayan-n2490687089	Papandayan	\N	hotel	\N	1	\N	0101000020E6100000ACBE04B8EAE75A40DEAAEB504DB11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2490687089	\N
38	parakan-wangi-n2494627703	Parakan Wangi	\N	hotel	\N	1	\N	0101000020E6100000B7312C3531E85A40466D2C7299CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2494627703	\N
39	the-summit-siliwangi-n2494655270	The Summit Siliwangi	\N	hotel	\N	1	\N	0101000020E6100000A790D03B3AE75A40052A2D6D82A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2494655270	\N
40	meize-hotel-jl-sumbawa-n3105373529	Meize Hotel - Jl. Sumbawa	\N	hotel	\N	1	Sumbawa, 7, Bandung	0101000020E610000096CBEB2D8AE75A40DC0B7151D2A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 22 426 3888	https://www.meizehotel.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3105373529	\N
41	park-hotel-n3269202627	Park Hotel	\N	hotel	\N	1	\N	0101000020E6100000814BB6700FE95A4090DB2F9FAC981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3269202627	\N
42	mercure-bandung-setiabudi-n3353575236	Mercure Bandung Setiabudi	\N	hotel	\N	1	Jl Dr Setiabudi, 269-275	0101000020E61000003123618415E65A407F95325F146B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3353575236	\N
43	verona-palace-hotel-n3365192832	Verona Palace Hotel	\N	hotel	\N	1	Surya Sumantri, Bandung	0101000020E6100000F0E1ED9C41E55A405A06E6327F8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3365192832	\N
44	sofyan-inn-specia-n3376282081	Sofyan Inn Specia	\N	hotel	\N	1	Jalan Buah Batu, 31, Bandung	0101000020E6100000C51B3E8E8BE75A40605969520ABA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3376282081	\N
45	amaris-hotel-setiabudhi-n3376673101	Amaris Hotel Setiabudhi	\N	hotel	\N	1	Jalan Dr. Setiabudi, 156A, Bandung	0101000020E6100000AE6763801FE65A401D9BD31BA47E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3376673101	\N
46	wisma-tubagus-n3376756789	Wisma Tubagus	\N	guesthouse	\N	1	\N	0101000020E610000043684EA871E75A40722C94F1948A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3376756789	\N
47	sm-residence-pasteur-n3405488095	SM Residence Pasteur	\N	hotel	\N	1	Babakan Jeruk Indah, 1 / 11, Bandung	0101000020E6100000632BC31355E55A402DD560753F8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3405488095	\N
48	vio-hotel-n3424716226	Vio Hotel	\N	hotel	\N	1	\N	0101000020E610000077CA598E46E65A403156E58C729A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3424716226	\N
49	pullman-n3436699526	Pullman	\N	hotel	5	1	\N	0101000020E610000056A64EF685E75A4065BCF781F5991BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3436699526	\N
50	grand-pasundan-convention-hotel-n3506203980	Grand Pasundan Convention Hotel	\N	hotel	\N	1	PETA, Bandung	0101000020E61000006D97EC8EFBE55A40D734EF3845BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3506203980	\N
51	patradissa-n3733193725	Patradissa	\N	hotel	\N	1	\N	0101000020E61000006F7EC34483E65A406E6B0BCF4BA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3733193725	\N
52	the-silk-at-dago-n3807724904	The Silk At Dago	\N	hotel	\N	1	Jalan Ir. H. Juanda, 392-394, Bandung	0101000020E6100000FE75B867A7E75A40338CBB41B47E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3807724904	\N
53	puri-tomat-n3807746630	Puri Tomat	\N	hotel	\N	1	\N	0101000020E61000006815472FB4E75A40B6099C114A7C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3807746630	\N
54	kementerian-pertanian-mess-guest-house-n3809369314	Kementerian Pertanian MESS/GUEST House	\N	guesthouse	\N	1	\N	0101000020E61000000316AF68A9E75A409E12C605567C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3809369314	\N
55	wirton-dago-hotel-n3809369329	Wirton Dago Hotel	\N	hotel	\N	1	\N	0101000020E61000002E4E21FCB0E75A40044C2A64F8791BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3809369329	\N
56	benua-hotel-n3809666546	Benua Hotel	\N	hotel	\N	1	\N	0101000020E610000069519FE40EE85A407B736EC960BB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3809666546	\N
57	bantal-guling-alun-alun-n3809732416	Bantal Guling Alun Alun	\N	guesthouse	\N	1	\N	0101000020E610000089E53B9DD0E65A407C48539852BA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62224211425	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3809732416	\N
58	panoramic-n4143034493	Panoramic	\N	apartment	\N	1	Jalan Soekarno Hatta	0101000020E610000094E23ECDA4EB5A40838B70EE0AC01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4143034493	\N
59	hotel-metro-n4143034494	HOTEL METRO	\N	hotel	\N	1	Jalan Soekarno-Hatta	0101000020E61000003C2C79E1F3E95A40C0C293275AC31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4143034494	\N
60	hotel-lengkong-n4150284489	Hotel Lengkong	\N	hotel	\N	1	Jalan Lengkong Besar	0101000020E61000003419E9A026E75A402F7480BB47B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4150284489	\N
61	regata-hotel-n4263828828	Regata Hotel	\N	hotel	\N	1	Jalan Dr. Setiabudi, 35	0101000020E610000068A6C52A6FE65A40C00F62C2C3871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4263828828	\N
62	gh-universal-hotel-n4267738966	GH Universal Hotel	\N	hotel	\N	1	Jalan Dr. Setiabudi, #376, Bandung	0101000020E61000004F7A3AB24DE65A40F9DB9E20B1651BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4267738966	\N
63	fabu-hotel-bandung-n4288729690	Fabu Hotel Bandung	\N	hotel	\N	1	Jalan Kebon Jati, 32	0101000020E6100000152AEE2E86E65A40B15FC1470EAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4288729690	\N
64	bandung-hostel-n4320694456	Bandung Hostel	\N	hostel	\N	1	Jalan Laksamana Laut RE Martadinata, 217, bandung, Jawa Barat	0101000020E61000003E26529A4DE85A40BF524C9473A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4320694456	\N
65	zodiak-n4326502122	Zodiak	\N	hotel	\N	1	Jl. Kebon Kawung, Pasir Kaliki, Cicendo, #54, Bandung	0101000020E61000004D405DEE5DE65A40518E5DFD33A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4326502122	\N
66	serena-hotel-n4326512398	Serena Hotel	\N	hotel	\N	1	Jl. Marjuk , Kebon Kawung, 4-6, Bandung	0101000020E61000006391CB248FE65A4073DAAE2BC1A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4326512398	\N
67	grand-sovia-hotel-n4326513914	Grand Sovia Hotel	\N	hotel	\N	1	Jalan Kebon Kawung , Pasirkaliki, Cicendo, 16, Bandung	0101000020E610000060E97C7896E65A408E7406465EA61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4326513914	\N
68	parahyangan-residences-n4327194341	Parahyangan Residences	\N	guesthouse	\N	1	Jl. Ciumbuleuit, Hegarmanah, Bandung	0101000020E6100000874556C8A6E65A40F1DCD67157821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4327194341	\N
69	u-village-hotel-and-villa-n4327220812	U Village Hotel and Villa	\N	villa	\N	1	Jalan Bukit Tunggul, Ciumbuleuit, Cidadap, 8, Bandung	0101000020E610000029E55A59C7E65A40A80AFC975A7D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4327220812	\N
70	summerbird-bed-and-brasserie-n4328071039	Summerbird - Bed and Brasserie	\N	hotel	\N	1	Jl. Ksatriaan, 11, Bandung	0101000020E6100000D04B20802FE65A40A9C36570EFA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4328071039	\N
71	d-batoe-boutique-hotel-n4328088067	D'batoe Boutique Hotel	\N	hotel	\N	1	Jalan HOS. Tjokroaminoto, 78, Bandung	0101000020E61000001EB63EF644E65A40F33AE2900DA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4328088067	\N
72	grand-pacific-hotel-n4328094416	Grand Pacific Hotel	\N	hotel	\N	1	Jalan Pasirkaliki , Pasirkaliki, Cicendo, 100, Bandung, Jawa Barat	0101000020E610000078A8B75043E65A40ED478AC8B0A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4328094416	\N
73	hotel-citradream-bandung-n4328099655	Hotel Citradream Bandung	\N	hotel	\N	1	Jl. Pasirkaliki, 36-42, Bandung	0101000020E61000004DEF874446E65A40F2385673CAA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4328099655	\N
74	apartment-gardujati-guest-house-n4328119383	Apartment Gardujati / Guest House	\N	guesthouse	\N	1	Jl. Gardujati, Kb. Jeruk, Andir,, 85, Bandung, Jawa Barat	0101000020E61000003A64B95B48E65A40B04C09D2D6AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4328119383	\N
75	hotel-imperium-bandung-n4329680561	Hotel Imperium Bandung	\N	hotel	\N	1	Jalan Dr. Rum, 30-32, Bandung	0101000020E6100000EA6A3C2270E65A402C27463B139F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4329680561	\N
76	vio-veteran-n4354994539	Vio Veteran	\N	hotel	\N	1	Jl. Veteran, 32, Bandung	0101000020E61000003C65DAA35CE75A404C1AA37554AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4354994539	\N
77	malaka-hotel-n4364208638	Malaka Hotel	\N	hotel	\N	1	Jalan Halimun, 36	0101000020E61000009D578682E3E75A4023EC25D75EB51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364208638	\N
78	hotel-cihampelas-3-n4368904700	Hotel Cihampelas 3	\N	hotel	\N	1	\N	0101000020E6100000642A583EA6E65A40849ECDAACF8D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368904700	\N
79	bukit-dago-business-hotel-n4364221707	Bukit Dago Business Hotel	\N	hotel	\N	1	Jalan Ir. H. Juanda, 311, Badung	0101000020E61000009F1C058882E75A403CCC4D8A45821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364221707	\N
80	hotel-new-naripan-n4364264976	Hotel New Naripan	\N	hotel	\N	1	Jalan Naripan, 31-25, Bandung	0101000020E61000003888314429E75A40BC58BD6834AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364264976	\N
81	vio-surapaati-n4364268209	Vio Surapaati	\N	hotel	\N	1	Jalan Surapati, 51, Bandung	0101000020E610000098AA0F7FA8E75A40E250099975981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364268209	\N
82	four-points-by-sheraton-bandung-n4364351816	Four Points by Sheraton Bandung	\N	hotel	\N	1	Jalan Ir. H. Juanda, 46, Bandung	0101000020E6100000CABCFA1D2FE75A406EB42D14FA9A1BC0	\N	0	\N	\N	\N	\N	\N	162	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364351816	\N
83	favehotel-n4364431589	favehotel	\N	hotel	\N	1	Jalan Braga, 99-101, Bandung	0101000020E610000024F83A04E9E65A400CB501333AAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4364431589	\N
84	grand-malabar-hotel-n4365642382	Grand Malabar Hotel	\N	hotel	\N	1	Jalan Malabar, 2, Bandung	0101000020E6100000BEC2DDB4F4E75A40D2657B3E14AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365642382	\N
85	ardan-hotel-n4365686176	Ardan Hotel	\N	hotel	\N	1	Jalan Sederhana, 8-10, Bandung	0101000020E6100000C124F0E258E65A406336B7F8CA921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365686176	\N
86	zodiak-hotel-n4365828036	Zodiak Hotel	\N	hotel	\N	1	Jalan Prof. Dr. Sutami, 133, Bandung	0101000020E61000003BBE62B25DE55A4052C6AEA360841BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365828036	\N
87	grand-tebu-hotel-n4365845390	Grand Tebu Hotel	\N	hotel	\N	1	Jalan R.E. Martadinata, 207, Bandung	0101000020E6100000D6EC37C945E85A4042340411F3A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365845390	\N
88	d-best-hotel-n4365862470	D'Best Hotel	\N	hotel	\N	1	Jalan Oto Iskandardinata, 460, Bandung	0101000020E610000050093EBC9DE65A405CA6CB07A9B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365862470	\N
89	harapan-indah-hotel-n4365868418	Harapan Indah Hotel	\N	hotel	\N	1	Jalan Gatot Subroto, 45B, Bandung	0101000020E6100000FF06EDD5C7E75A405A620A7B7FB01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365868418	\N
90	de-rain-n4365969235	De'Rain	\N	hotel	3	1	Jalan Lengkong Kecil, 76-80, Bandung	0101000020E6100000F3D203D575E75A4006DF8F36E9B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365969235	\N
91	zodiak-hotel-n4365975820	Zodiak Hotel	\N	hotel	\N	1	Jalan Pasir Kaliki, 50, Bandung	0101000020E6100000CA55873746E65A40761E70B8EAA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365975820	\N
92	de-hoff-cihampelas-cottage-n4366003613	De Hoff Cihampelas Cottage	\N	hotel	\N	1	Jalan Westhoff, 18 A-B, Bandung, Jawa Barat	0101000020E6100000F64B7ACE4CE65A40BB4B3D66FB9B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366003613	\N
93	ivory-by-ayola-hotel-n4366036884	Ivory by Ayola Hotel	\N	hotel	\N	1	Jalan Bahureksa, 3, Bandung	0101000020E6100000E6CFB7054BE75A4027C0B0FCF99E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366036884	\N
94	raffleshom-hotel-n4366160271	Raffleshom Hotel	\N	hotel	\N	1	Jalan Pangarang, 24, Bandung	0101000020E6100000F2C17CC30EE75A402280E552A6B21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366160271	\N
95	hotel-dafam-rio-n4366211031	Hotel Dafam Rio	\N	hotel	\N	1	Jalan R.E. Martadinata, 160, bandung	0101000020E6100000B4EE7AC443E85A40E8EF4A372EA81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366211031	\N
96	arimbi-dewi-sartika-n4366500173	Arimbi Dewi Sartika	\N	hotel	\N	1	Jalan Dewi Sartika, 108A, Bandung	0101000020E6100000DEBB17A9C1E65A403CFC901216B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366500173	\N
97	cihampelas-hotel-2-n4366529015	Cihampelas hotel 2	\N	hotel	\N	1	Jalan Cihampelas, 222, Bandung	0101000020E61000008A4C0A3DACE65A4073BE3335648F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366529015	\N
98	hyper-inn-n4366542977	Hyper Inn	\N	hotel	\N	1	Paskal Hyper Square Blok D, Jl. Pasar Kaliki, 29-32, Bandung	0101000020E6100000B566D07506E65A40D7D5897038A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4366542977	\N
99	zest-hotel-n4367108753	Zest Hotel	\N	hotel	\N	1	Jalan Sukajadi, 16, Bandung	0101000020E6100000C9D3A8763CE65A40B2E8E797D2941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367108753	\N
100	cihampelas-hotel-1-n4367119795	Cihampelas Hotel 1	\N	hotel	\N	1	Jalan Cihampelas, 240, Bandung	0101000020E61000000801F912AAE65A408E8DE5023C8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367119795	\N
101	dpalma-hotel-n4367137267	dPalma Hotel	\N	hotel	\N	1	Jalan Gatot Subroto, 41, Bandung	0101000020E610000066D828EBB7E75A409392793FC9B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367137267	\N
102	namin-hotel-n4367194151	Namin Hotel	\N	hotel	\N	1	Jalan Hasanudin, 10, Bandung	0101000020E6100000ED1406C053E75A4035327ED069941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367194151	\N
103	idea-s-hotel-n4367285388	Idea's Hotel	\N	hotel	\N	1	Jalan Ibrahim Adji, 414, Bandung	0101000020E61000000E87003B12E95A401730DC14EAC41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367285388	\N
104	m-premiere-hotel-n4367306824	M Premiere Hotel	\N	hotel	\N	1	Jalan Tirtayasa, 5, Bandung	0101000020E6100000DFA1CD1635E75A40EF1417EC2B9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367306824	\N
105	unique-guesthouse-1-n4367331942	Unique Guesthouse 1	\N	hotel	\N	1	Jalan Ence Ajis, 34, Bandung	0101000020E6100000A3456C6663E65A40AA3EA1E8CBAC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367331942	\N
106	de-qur-hotel-n4367333994	De'qur Hotel	\N	hotel	\N	1	Jalan Dipatiukur, 27, Bandung	0101000020E61000002F641AF274E75A4022718FA50F951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367333994	\N
107	grand-cordela-hotel-n4367336310	Grand Cordela Hotel	\N	hotel	\N	1	Jalan Soekarno Hatta, 791, Bandung	0101000020E6100000F04DD36707EC5A40BB511A2087BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367336310	\N
108	travello-hotel-n4367339333	Travello Hotel	\N	hotel	\N	1	Jalan Dr. Setiabudi, 268, Bandung	0101000020E610000045926AE91BE65A40AA65C63604721BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367339333	\N
109	veleza-n4367346832	VELeZA	\N	hotel	3	1	Jalan Lengkong Kecil, 84, Bandung	0101000020E61000007FA6B9707BE75A400142356FE6B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367346832	\N
110	the-victoria-luxurious-guesthouse-n4367377390	The Victoria Luxurious Guesthouse	\N	hotel	\N	1	Jalan Sukaresmi, 4-6, Bandung	0101000020E6100000135A208BFEE55A40EF4ADC7415841BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367377390	\N
111	the-suites-metro-n4367388682	The Suites@Metro	\N	apartment	\N	1	Jalan Soekarno-Hatta, 689, Bandung	0101000020E61000003606F8C92CEA5A40B73DE6A848C21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367388682	\N
112	house-sangkuriang-n4367403002	House Sangkuriang	\N	hotel	\N	1	Jalan Sangkuriang, 1, Bandung, Jawa Barat	0101000020E610000052BF661426E75A4054BE0C6BCF891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367403002	\N
113	garden-permata-hote-n4367415073	Garden Permata Hote	\N	hotel	\N	1	Jalan Lemah Neundeut, 7, Bandung	0101000020E61000005A66118A2DE55A40FA04F5D2B9871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367415073	\N
114	sofia-house-dago-hotel-n4367486386	Sofia House Dago Hotel	\N	hotel	\N	1	\N	0101000020E610000003E4F0EE6DE75A40A6924B2DA5901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367486386	\N
157	attic-n4395991497	Attic	\N	guesthouse	\N	1	Jalan Ir. H. Juanda, 130	0101000020E6100000E4C3471F4EE75A40424DE3CDD08E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4395991497	\N
115	noor-hotel-n4367492914	Noor Hotel	\N	hotel	\N	1	Jalan Madura, 6, Bandung	0101000020E6100000A759A0DDA1E75A405C1A6437D8A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367492914	\N
116	d-river-guest-house-n4367499145	D' River Guest House	\N	hotel	\N	1	\N	0101000020E61000007EE0CF95ADE65A40E167B7F1828B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367499145	\N
117	orange-home-s-syariah-n4367529941	Orange Home's Syariah	\N	hotel	\N	1	Jalan Babakan Jeruk 1, 76, Bandung	0101000020E6100000F8B9EBB655E55A4030D461855B8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367529941	\N
118	d-sovia-hotel-n4367950798	D'sovia Hotel	\N	hotel	\N	1	Jalan Gardujati, 81-83, Bandung	0101000020E61000003B0ECD8646E65A405241EA1B3DAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367950798	\N
119	dago-s-hill-hotel-n4367985579	Dago's Hill Hotel	\N	hotel	\N	1	Jl. Tubagus Ismail VIII, 39A, Bandung	0101000020E610000007BC276AC4E75A4072E1404816881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4367985579	\N
120	hotel-endah-parahyangan-n4368072361	Hotel Endah Parahyangan	\N	hotel	\N	1	Jl. Raya Cimindi, 14, Cimahi	0101000020E61000001E4C2FD65CE45A403A5AD5928EA21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368072361	\N
121	grand-setiabudi-hotel-apartment-n4368082307	Grand Setiabudi Hotel & Apartment	\N	hotel	\N	1	Jalan Dr. Setiabudi, 130-134, Bandung	0101000020E6100000DC86ACC92EE65A409CF5CE0DF27F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368082307	\N
122	novotel-bandung-n4368154959	Novotel Bandung	\N	hotel	4	1	Jalan Cihampelas, 23, Bandung	0101000020E6100000F70E6DB6A8E65A40EC18B2158F9E1BC0	\N	0	\N	\N	\N	\N	\N	156	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368154959	\N
123	lotus-hotel-n4368184538	Lotus Hotel	\N	hotel	\N	1	\N	0101000020E61000003F749C36BEE75A40A9A67FA4E3851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368184538	\N
124	fullmar-house-n4368836119	Fullmar House	\N	hotel	\N	1	\N	0101000020E61000006FD97CB754E55A40C1B975EDC18A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368836119	\N
125	asoka-hotel-n4368869499	Asoka Hotel	\N	hotel	\N	1	\N	0101000020E610000012FF0B5F3AE75A4055489E9042B61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368869499	\N
126	hotel-ilos-n4368870949	Hotel Ilos	\N	hotel	\N	1	\N	0101000020E6100000C599154067E55A4093509F8955901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368870949	\N
127	amalio-hotel-n4368872127	Amalio Hotel	\N	hotel	\N	1	\N	0101000020E610000018D2E1218CE85A40773BB13D69971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368872127	\N
128	hotel-danoufa-n4368900414	Hotel Danoufa	\N	hotel	\N	1	\N	0101000020E6100000D8D88063AAE75A40306D93E57F951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368900414	\N
129	arwiga-hotel-and-convention-n4368902095	Arwiga Hotel and Convention	\N	hotel	\N	1	\N	0101000020E61000002075E04158E65A407FB5B4649F911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368902095	\N
130	hotel-corsica-n4368992655	Hotel Corsica	\N	hotel	\N	1	\N	0101000020E610000055E69C8E36E85A4090CD9F80379E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4368992655	\N
131	sweet-karina-hotel-n4369159158	Sweet Karina Hotel	\N	hotel	\N	1	\N	0101000020E61000002488A9E367E55A403E5F0E16A98B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4369159158	\N
132	nandya-hotel-n4369754653	Nandya Hotel	\N	hotel	\N	1	\N	0101000020E61000000DA661F808E75A40564D6B2E92B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4369754653	\N
133	asmila-boutique-hotel-n4369854694	Asmila Boutique Hotel	\N	hotel	\N	1	\N	0101000020E61000005F6C109C69E65A408F15A17D51871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4369854694	\N
134	el-cavana-hotel-n4369877696	El Cavana Hotel	\N	hotel	\N	1	\N	0101000020E6100000002A0B1552E65A4060B7BEFEDAA81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4369877696	\N
135	arinda-guest-house-n4370117219	Arinda Guest House	\N	hotel	\N	1	\N	0101000020E61000001B66683C91E95A405C6ED51AEFA31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370117219	\N
136	hotel-88-bandung-kopo-n4370125443	Hotel 88 Bandung Kopo	\N	hotel	\N	1	\N	0101000020E6100000CBF275197EE55A40FD851E317ACE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370125443	\N
137	hotel-wisma-dago-n4370151162	HOTEL WISMA DAGO	\N	hotel	\N	1	\N	0101000020E610000015C9570229E75A40E2AC889AE8931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370151162	\N
138	vio-cihampelas-n4370162206	Vio Cihampelas	\N	hotel	\N	1	\N	0101000020E610000032DCCA5CAAE65A407CAE5BA90C981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370162206	\N
139	excellent-seven-boutique-hotel-n4370175009	Excellent Seven Boutique Hotel	\N	hotel	\N	1	\N	0101000020E6100000C9891B5C5FE65A4015037F53B39A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370175009	\N
140	hotel-grand-kopo-n4370179384	Hotel Grand Kopo	\N	hotel	\N	1	\N	0101000020E610000063528DA81AE65A40E2AA573618BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370179384	\N
141	zodiak-kebon-jati-n4370470049	Zodiak@Kebon Jati	\N	hotel	\N	1	\N	0101000020E610000070F4E79175E65A400AD39C610FAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370470049	\N
142	bali-indah-hotel-n4370481546	Bali Indah Hotel	\N	hotel	\N	1	\N	0101000020E610000029A95D5D5FE75A402C4487C091C01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370481546	\N
143	hotel-istana-n4370531568	Hotel Istana	\N	hotel	\N	1	\N	0101000020E6100000063708292EE75A4023426D65D3AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370531568	\N
144	vio-hotel-pasteur-n4370599589	Vio Hotel Pasteur	\N	hotel	\N	1	\N	0101000020E610000014FDEB2642E55A402CFF10D19E911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4370599589	\N
145	amira-hotel-n4373080471	Amira Hotel	\N	hotel	\N	1	\N	0101000020E610000088974CBA52E55A405C960A8563891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373080471	\N
146	sakura-guest-house-n4373107740	Sakura Guest House	\N	hotel	\N	1	\N	0101000020E6100000B65FE39FBEE65A40B5F6E39B129D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373107740	\N
147	elenor-s-home-n4373130278	Elenor's Home	\N	hotel	\N	1	\N	0101000020E61000007AD278D87AE65A4077A5C05D518D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373130278	\N
148	pondok-kurnia-n4373140133	Pondok Kurnia	\N	hotel	\N	1	\N	0101000020E61000005656E4211DE85A40C2C3B46FEEC71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373140133	\N
149	arlya-hotel-n4373174485	Arlya Hotel	\N	hotel	\N	1	\N	0101000020E6100000EACBD24ECDE95A40C1B5C99706AC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373174485	\N
150	kenangan-hotel-n4373270426	Kenangan Hotel	\N	hotel	\N	1	\N	0101000020E61000003F7100FDBEE65A404162BB7B80A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373270426	\N
151	hotel-salon-fora-n4373321350	Hotel Salon Fora	\N	hotel	\N	1	\N	0101000020E6100000369AB745F4E55A40458AB784327B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373321350	\N
152	oasis-hotel-n4373373687	Oasis Hotel	\N	hotel	\N	1	\N	0101000020E6100000235BA7DBA3E75A40D7A60C7789A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373373687	\N
153	hotel-boulevard-n4373419773	Hotel Boulevard	\N	hotel	\N	1	\N	0101000020E61000008BB9B59613E85A4019C00067CEB71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373419773	\N
154	hotel-anda-n4373592307	Hotel Anda	\N	hotel	\N	1	\N	0101000020E6100000AB048BC319E85A40BBB7223141AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4373592307	\N
155	palm-hotel-n4374570796	Palm Hotel	\N	hotel	\N	1	Jalan Belakang Pasar	0101000020E610000083DDB06D51E65A401202A89839AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4374570796	\N
156	rizh-garden-n4381766291	Rizh Garden	\N	hotel	\N	1	\N	0101000020E6100000F95404EEAFE75A402984C42C6AB61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4381766291	\N
158	bantal-guling-n4402017325	Bantal Guling	\N	hotel	\N	1	Jenderal Gatot Subroto, 194, Bandung	0101000020E6100000AF100CD6EEE85A404DAFDEF2A2B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4402017325	\N
159	gh-universal-n4403942376	GH Universal	\N	hotel	\N	1	\N	0101000020E61000006FB65E784AE65A4001593E8166661BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4403942376	\N
160	basecamp-n4489016289	Basecamp	\N	guesthouse	\N	1	Jalan Randusari, E36	0101000020E6100000B092EA9678EA5A40C5D853BCDBB61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4489016289	\N
161	suryalaya-inn-n4543278790	Suryalaya Inn	\N	hotel	\N	1	\N	0101000020E61000000D1E0137E6E75A400B58175C18C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4543278790	\N
162	venice-guest-house-n4555510932	Venice Guest House	\N	guesthouse	\N	1	\N	0101000020E6100000B59EC662C0E65A4011A6CDDD53A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4555510932	\N
163	fave-hotel-n4655134787	Fave Hotel	\N	hotel	\N	1	\N	0101000020E61000004FC939B107E65A4053697A3F24AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4655134787	\N
164	gado-gadu-hostel-real-adress-n5022145228	Gado Gadu Hostel (real adress!)	\N	hotel	\N	1	\N	0101000020E610000051476C1C56E65A408F931D763AAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5022145228	\N
165	rompis-residence-n5031456123	Rompis Residence	\N	hostel	\N	1	Jalan Suka Mulya, 3-1	0101000020E6100000B3F0506FA1E55A40702711E15F8C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62212013422	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5031456123	\N
166	the-newton-hotel-n5172665198	The Newton Hotel	\N	hotel	\N	1	Jl. RE Martadinata, 223-227, Bandung	0101000020E61000002AF7A7F94FE85A40687AE46ABFA81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5172665198	\N
167	caryota-n5182888921	Caryota	\N	hotel	\N	1	\N	0101000020E6100000CCE5AB892AE65A400684D6C397891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5182888921	\N
168	chez-bon-hostel-n5291705249	Chez Bon Hostel	\N	hostel	\N	1	Jalan Braga, 45	0101000020E6100000FEABD8A903E75A40B1E1E995B2AC1BC0	\N	0	\N	\N	\N	\N	\N	8	\N	+62-22-4260-600	http://chez-bon.com	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5291705249	\N
169	hotel-lini-n5451497375	Hotel Lini	\N	hotel	4	1	4, Bandung	0101000020E610000048FB1F60ADE65A406D23F9A5D9A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5451497375	\N
170	pondok-e7-n5698297022	Pondok E7	\N	hostel	\N	1	Jalan Emung, 7	0101000020E6100000EF78EE9895E75A40872FB88BD5B31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 821 2197 9826	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5698297022	\N
171	aston-pasteur-n5750040967	Aston Pasteur	\N	hotel	\N	1	\N	0101000020E6100000E9143F2196E55A40804177EEE2921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5750040967	\N
172	the-house-tour-hotel-n5833680550	The House Tour Hotel	\N	hotel	\N	1	Jalan Panumbang Jaya, 5, Bandung	0101000020E6100000BA2C26369FE65A40F0AA6285B6771BC0	\N	0	\N	\N	\N	\N	\N	20	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5833680550	\N
173	bobopod-paskal-n5849852581	Bobopod Paskal	Bobobox is the first high technology capsule hotel in Indonesia.	hotel	\N	1	Jalan HOS. Tjokroaminoto, 76A, Bandung	0101000020E610000071E2AB1D45E65A40F67EA31D37A41BC0	\N	0	\N	\N	\N	\N	\N	62	\N	+62224266430	https://bobobox.co.id/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5849852581	\N
174	hotel-harris-n6151203590	Hotel Harris	\N	hotel	\N	1	\N	0101000020E6100000C257CFA4A8E65A4060D3DE3BC5851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6151203590	\N
175	rusun-tongkeng-n6155111485	Rusun Tongkeng	\N	apartment	\N	1	\N	0101000020E610000075498BE9F8E75A404EB51666A1A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6155111485	\N
176	pinisi-backpacker-n6278571391	Pinisi Backpacker	\N	hostel	\N	1	Jalan Musen, 92 / 6A	0101000020E61000009587E01346E65A40F062AB15B7A31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+622286868610	http://www.pinisibackpacker.com	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6278571391	\N
177	hotel-pangarang-sari-n9805277511	Hotel Pangarang Sari	\N	hotel	\N	1	\N	0101000020E61000005B8B602D08E75A40AF6994E46FB11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805277511	\N
178	kos-pak-h-e-sukendar-n6777587530	Kos Pak H.E Sukendar	\N	guesthouse	\N	1	Jl. Siliwangi Dalam Gang 3 No.19 RT08/RW01, Cipaganti, Coblong, Bandung, 19	0101000020E610000019B4EB39C4E65A4032D989DC1D8B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6777587530	\N
179	home-mr-syarif-bastaman-n6854504885	Home Mr Syarif Bastaman	\N	guesthouse	\N	1	Jalan Dakota, A20	0101000020E61000000454388254E45A40D11B936A44951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6854504885	\N
180	ostel-by-ostic-n7076351776	Ostel by Ostic	\N	guesthouse	\N	1	Jalan Tanjung Anom, 12	0101000020E61000008F2EDBF321E65A40D905836BEEA01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7076351776	\N
181	serelah-n7081714941	Serelah	\N	hotel	\N	1	\N	0101000020E610000097FF907EFBE65A409603E21A44A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7081714941	\N
182	yokotel-n7081727464	Yokotel	\N	hotel	\N	1	\N	0101000020E6100000F25597F848E65A408A90BA9D7D9D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7081727464	\N
183	sukaraja-n7087017045	Sukaraja	\N	guesthouse	\N	1	\N	0101000020E6100000E9FF0BBA73E45A4042B51C435B911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7087017045	\N
184	courtyard-bandung-dago-n7661595392	Courtyard Bandung Dago	\N	hotel	\N	1	Jalan Ir H Juanda, 33, Bandung	0101000020E6100000337A241411E75A401C8BB7DFEB9D1BC0	\N	0	\N	\N	\N	\N	\N	192	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7661595392	\N
185	moxy-bandung-n7661597002	Moxy Bandung	\N	hotel	3	1	Jalan Ir H Djuanda, 69, Bandung	0101000020E610000007B309302CE75A40F2672E26EC991BC0	\N	0	\N	\N	\N	\N	\N	109	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7661597002	\N
186	ottenway-hostel-n7890431757	ottenway hostel	\N	other	\N	1	\N	0101000020E61000007A330F0558E65A403D4FF2D9F09A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7890431757	\N
187	kost-putra-nyalindung-itb-n8050910212	Kost Putra Nyalindung ITB	A dorm / flat for students of Institut Teknologi Bandung, and or other universities.	guesthouse	\N	1	PPR ITB Blok L, Jalan Nyalindung , 40142, 4	0101000020E6100000DD0BCC0AC5E75A40664007A74F6C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/8050910212	\N
188	hotel-santika-pasir-koja-n9800515672	Hotel Santika Pasir Koja	\N	hotel	\N	1	\N	0101000020E610000009A69A59CBE55A405AEB30CB43BB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9800515672	\N
189	zodiak-taurus-hotel-bandung-n9803556199	Zodiak Taurus Hotel Bandung	\N	hotel	\N	1	\N	0101000020E61000001EFB592C45E65A40F3F972B048A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9803556199	\N
190	cassadua-hotel-n9805299566	Cassadua Hotel	\N	hotel	\N	1	\N	0101000020E6100000A6553E1501E55A402FF76E980D8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805299566	\N
191	hotel-bandung-permai-n9805312659	Hotel Bandung Permai	\N	hotel	\N	1	\N	0101000020E61000001B97169A90E85A40C4C9A255D2A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805312659	\N
192	hemangini-hotel-bandung-n9805316457	Hemangini Hotel Bandung	\N	hotel	\N	1	\N	0101000020E610000020D1048A58E65A408CB8A57AD7851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805316457	\N
193	art-deco-luxury-hotel-n9805337893	Art Deco Luxury Hotel	\N	hotel	\N	1	\N	0101000020E61000003E35A847E4E65A4098721992EE7A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805337893	\N
194	hotel-image-n9805348926	Hotel Image	\N	hotel	\N	1	\N	0101000020E6100000CD1C37A135E75A4024AB6C697FB91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805348926	\N
195	hotel-ammeerra-n9805414865	Hotel Ammeerra	\N	hotel	\N	1	\N	0101000020E6100000A03715A9B0E55A407CD69013817D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805414865	\N
196	geary-hotel-bandung-n9805536597	Geary Hotel Bandung	\N	hotel	\N	1	\N	0101000020E61000004BAE62F19BE65A409C2E30D05AA61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805536597	\N
197	kembang-hotel-cihampelas-bandung-n9805540456	Kembang Hotel Cihampelas Bandung	\N	hotel	\N	1	\N	0101000020E610000049EA4EC1ABE65A40A75F7D97AD981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805540456	\N
198	hotel-negla-sari-bandung-n9805578775	Hotel Negla Sari Bandung	\N	hotel	\N	1	\N	0101000020E6100000633F30ECD5E65A40A2F19FC959AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805578775	\N
199	hotel-unik-bandung-n9805664420	Hotel Unik Bandung	\N	hotel	\N	1	\N	0101000020E61000006AE67FA86AE65A40A53AD33A60A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805664420	\N
200	hotel-10-buah-batu-n9805727870	Hotel 10 Buah Batu	\N	hotel	\N	1	\N	0101000020E610000086CF317BB4E75A40D09CF529C7BC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805727870	\N
201	setrasari-hotel-n9805777954	Setrasari Hotel	\N	hotel	\N	1	\N	0101000020E6100000338F577B33E55A40766968A8F6861BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805777954	\N
202	ruby-hotel-bandung-n9805811387	Ruby Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000CE2335A355E65A403EB896242A9F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9805811387	\N
203	sentra-inn-bandung-n9807670497	Sentra Inn Bandung	\N	hotel	\N	1	\N	0101000020E61000002BB4BD27A0E75A4013AFFC4344B31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9807670497	\N
204	hostel-intech-kopo-538-n9807694443	Hostel Intech Kopo 538	\N	hotel	\N	1	\N	0101000020E61000005C93C90457E55A404F57772CB6D11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9807694443	\N
205	pratidina-business-residence-n9807795332	Pratidina Business Residence	\N	hotel	\N	1	\N	0101000020E6100000EB596B836EE85A401DEF44FFBA911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9807795332	\N
206	de-braga-by-artotel-bandung-n9807817528	De Braga By Artotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000597FF0460BE75A40542CC8E072AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9807817528	\N
207	pass-hill-house-n9808104016	Pass Hill House	\N	hotel	\N	1	\N	0101000020E61000001B67D311C0E75A40D80DDB1665C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9808104016	\N
208	greko-creative-hub-hotel-bandung-n9809020563	Greko Creative Hub Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000D492D8FFCAE75A40F6903A4BDAAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9809020563	\N
209	oyo-2183-cibeureum-residence-n9813954095	OYO 2183 Cibeureum Residence	\N	hotel	\N	1	\N	0101000020E6100000B9196EC067E45A4030229BF573A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9813954095	\N
210	the-regia-by-ultimo-n9816386508	The Regia by Ultimo	\N	hotel	\N	1	\N	0101000020E61000005BE21291ABE65A40D602D605178E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9816386508	\N
211	fox-harris-hotel-bandung-n9816492337	Fox Harris Hotel Bandung	\N	hotel	\N	1	\N	0101000020E61000000021EDDA39E75A40285481A499A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9816492337	\N
212	u-janevalla-bandung-n9843372844	U Janevalla Bandung	\N	hotel	\N	1	\N	0101000020E61000006C10413022E75A40894A7E1F69A31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9843372844	\N
213	grandia-n9943969629	Grandia	\N	hotel	\N	1	\N	0101000020E6100000FF5657AAB0E65A4025F5543D4F9A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9943969629	\N
214	hotel-sanira-n10740506117	Hotel Sanira	\N	hotel	\N	1	Jalan W. R. Supratman, 37	0101000020E6100000DB83B5D63CE85A40935742D2029F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 227208480	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10740506117	\N
215	lucia-premium-kost-n11047765437	Lucia Premium Kost	\N	hostel	\N	1	\N	0101000020E6100000AAF3A8F83FE75A40AF71474959A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11047765437	\N
216	ibis-styles-n11064477660	ibis Styles	\N	hotel	3	1	\N	0101000020E610000003C2983E85E75A40BF918A10689A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11064477660	\N
217	mercure-bandung-city-centre-n11070277751	Mercure Bandung City Centre	\N	hotel	4	1	\N	0101000020E6100000EA82B0091FE75A4073D0CA6207B21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11070277751	\N
218	kostan-syifa-n11491738070	Kostan Syifa	\N	apartment	\N	1	\N	0101000020E6100000988D29B39CE75A409DBCC804FC8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11491738070	\N
219	kost-bu-nia-n11546593921	Kost Bu Nia	\N	hostel	\N	1	Jalan Rancabentang II, No.1, Bandung	0101000020E610000005F3FC0EEAE65A40D371906B9E7E1BC0	\N	0	\N	\N	\N	\N	\N	11	\N	+6282116959928	https://mamikos.com/room/kost-kota-bandung-kost-campur-murah-kost-bu-nia-cidadap-bandung-2	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11546593921	\N
220	gino-feruci-kebonjati-hotel-n11608070660	Gino Feruci Kebonjati Hotel	\N	hotel	\N	1	\N	0101000020E610000005E4A66153E65A402BB693D27DAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11608070660	\N
221	skyland-guest-house-bandung-n11915115699	Skyland Guest House Bandung	\N	hotel	\N	1	\N	0101000020E6100000D71C7B5116E55A40415F1F4201881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11915115699	\N
222	little-mykonos-n11984843791	Little Mykonos	\N	hotel	\N	1	\N	0101000020E61000002FD3403DC7E65A40A1B54714FFA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11984843791	\N
223	hilton-bandung-n12006584835	Hilton Bandung	\N	hotel	5	1	Jalan HOS. Tjokroaminoto, 41-43, Bandung	0101000020E6100000647EC9213DE65A4003F0AA6285A61BC0	\N	0	\N	\N	\N	\N	\N	186	\N	+62 22 86051300	https://www.hilton.com/en/hotels/bdohihi-hilton-bandung/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12006584835	\N
224	lagrande-n12029263569	LaGrande	\N	apartment	\N	1	\N	0101000020E610000044DC9C4A06E75A402AE09EE74FA31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12029263569	\N
225	puma-hotel-n12064373925	Puma Hotel	\N	hotel	\N	1	\N	0101000020E61000002882380FA7E65A40F75B960A85931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12064373925	\N
226	arion-suites-hotel-n12637947272	Arion Suites Hotel	\N	hotel	\N	1	Jl. Otto Iskander Dirata, 16	0101000020E6100000E2A5400BAEE65A4026FB8CB04DA71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+6281212120248	https://arionsuiteshotel.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12637947272	\N
227	panen-hotel-bandung-by-tebu-group-n13456067401	Panen Hotel Bandung (By Tebu Group)	\N	hotel	\N	1	Jalan L.L. RE. Martadinata, 100	0101000020E6100000FCDEA63FFBE75A402AD890C9F3A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 22 20507474	https://panenhotels.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13456067401	\N
228	pop-hotels-n13460475168	pop hotels	\N	hotel	\N	1	\N	0101000020E6100000193499967DE55A40A47A21D390B71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13460475168	\N
229	rumah-oren-n13514149101	Rumah Oren	\N	guesthouse	\N	1	Jalan Segar, F10	0101000020E6100000CFDC43C277EC5A4034EC415255A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13514149101	\N
230	rumah-aca-com-n13622908680	Rumah Aca.com	\N	hostel	\N	1	\N	0101000020E6100000C972124A5FE75A403B26416E758F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13622908680	\N
231	arwiga-hotel-n13713723687	Arwiga Hotel	\N	hotel	\N	1	\N	0101000020E6100000286F360C55E65A406D872B0C36921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13713723687	\N
232	suryakencana-boutique-guest-house-n13730213277	Suryakencana Boutique Guest House	\N	guesthouse	\N	1	\N	0101000020E6100000FC6772D64CE75A406F168ACFF8911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13730213277	\N
233	serela-hotel-n13737191450	Serela Hotel	\N	hotel	\N	1	\N	0101000020E61000002E5F4D54A5E65A407D13F9E417941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13737191450	\N
234	truntum-n13770681054	Truntum	\N	hotel	\N	1	Jalan Cihampelas, 91	0101000020E61000000A552069A6E65A402C6684B707991BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+622263170000	https://truntumhotels.com/hotels/truntum-cihampelas-bandung	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13770681054	\N
235	hotel-madju-n13801732632	Hotel Madju	\N	hotel	\N	1	\N	0101000020E6100000068CE4E1F3E75A4000A2050DA2A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13801732632	\N
236	the-kamalaya-hotel-wedding-guest-house-n13834358543	The Kamalaya Hotel Wedding & Guest House	\N	hotel	\N	1	Jl. The Kamalaya Hotel Wedding & Guest House, 319, Bandung, Jawa Barat	0101000020E6100000BB1D2B427BE75A4061F998B44E811BC0	\N	0	\N	\N	\N	\N	\N	31	\N	+62 852-5000-0538	https://thekamalayahotel.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13834358543	\N
237	kost-elhaz-bandung-n13990557159	KOST ELHAZ BANDUNG	\N	hostel	\N	1	Jalan Pare Pandan II 4, Bandung Kota, 40283, ID, 4, Kel. Babakan Sari	0101000020E6100000A1E8CB1C5CE95A40C009850838AC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13990557159	\N
238	buton-backpacker-lodge-n14023644201	Buton Backpacker Lodge	\N	hostel	\N	1	Jalan Haji Akbar, 19	0101000020E6100000B32E241667E65A40485B4BB7DBA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/14023644201	\N
239	kos-kos-kos-dago-n14085922101	Kos kos kos dago	\N	guesthouse	\N	1	capitol dago valley, 36	0101000020E6100000D9BC602640E75A40FBAE08FEB77A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/14085922101	\N
240	kosan-rangga-gempol-rg10a-n14179825202	Kosan Rangga Gempol RG10A	\N	guesthouse	\N	1	Jalan Ranggagempol, 10A	0101000020E6100000DBD726BA53E75A40F222B836F99A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/14179825202	\N
241	hotel-scarlet-dago-w119439014	Hotel Scarlet Dago	\N	hotel	5	1	\N	0101000020E610000031EAFFC12CE75A40234910AE808A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119439014	\N
242	the-palais-dago-w119445946	The Palais Dago	\N	hotel	2	1	Jalan Ir. H. Juanda, Bandung	0101000020E610000009E23C9C40E75A40EC7B1EEDC9951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119445946	\N
243	hotel-aryaduta-w119549570	Hotel Aryaduta	\N	hotel	\N	1	Jalan Merdeka, Bandung	0101000020E6100000DAF85D2228E75A401B1F775B33A31BC0	\N	0	\N	\N	\N	\N	\N	254	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119549570	\N
244	hotel-the-101-w119549571	Hotel The 101	\N	hotel	\N	1	\N	0101000020E610000046DA7C120EE75A4043F68B2320A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119549571	\N
245	santika-hotel-w119756601	Santika Hotel	\N	hotel	3	1	\N	0101000020E610000061B9EF622BE75A40F8382E3E60A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119756601	\N
246	posters-hotel-w119763516	Posters Hotel	\N	hotel	\N	1	\N	0101000020E61000009B0E5311DDE85A406CC94F4FC4971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119763516	\N
247	wisma-pradana-bank-btn-w120331569	Wisma Pradana Bank BTN	\N	guesthouse	\N	1	Jalan Ir. H. Djuanda, 142	0101000020E61000003F0114234BE75A408529255F648D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/120331569	\N
248	amaris-hotel-w120339378	Amaris Hotel	\N	hotel	\N	1	\N	0101000020E6100000F30181CEA4E65A404974E0E69E8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/120339378	\N
249	isola-resort-upi-w152648494	Isola Resort UPI	\N	hotel	\N	1	\N	0101000020E6100000222DDF44BEE55A406B8E626F18731BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152648494	\N
250	rossan-villa-w152934589	Rossan Villa	\N	villa	\N	1	\N	0101000020E610000054A70359CFE55A40A8DD544909661BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152934589	\N
251	gh-universal-hotel-w152934590	GH Universal Hotel	\N	hotel	\N	1	\N	0101000020E6100000DCF126BF45E65A40CE9F8037EE661BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152934590	\N
252	banana-inn-w152936381	Banana Inn	\N	hotel	\N	1	Jalan Dr. Setiabudi, 191, Bandung	0101000020E610000047A6E8EDF4E55A400DECE703B8771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152936381	\N
253	hotel-karangsetra-w152991392	Hotel Karangsetra	\N	hotel	\N	1	\N	0101000020E6100000BB4967BB1DE65A40642717BE19881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152991392	\N
254	pondok-sany-rosa-w153285183	Pondok Sany Rosa	\N	hotel	\N	1	\N	0101000020E6100000E5AECA2A91E65A404E4B0746B9871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/153285183	\N
255	fabu-hotel-w153883975	Fabu Hotel	\N	hotel	\N	1	\N	0101000020E6100000294586B075E65A408F9AC0BEE7A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/153883975	\N
256	hotel-nyland-w154066275	Hotel Nyland	\N	hotel	\N	1	Jalan Doktor Djunjunan, 125, Bandung	0101000020E61000002444F98296E55A40C4AAE6DE68941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/154066275	\N
257	bali-world-hotel-w154217968	Bali World Hotel	\N	hotel	\N	1	Bandung	0101000020E61000003744CB7072EA5A4038C604EBEEC01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/154217968	\N
258	ahadiat-hotel-bungalow-w154435842	Ahadiat Hotel & Bungalow	\N	hotel	\N	1	\N	0101000020E6100000642A583EA6E55A402733DE567A851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/154435842	\N
259	casa-d-ladera-w155189909	Casa D'Ladera	\N	hotel	\N	1	\N	0101000020E6100000FC2191112BE65A40234910AE80721BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/155189909	\N
260	ponty-w155190112	Ponty	\N	hotel	\N	1	\N	0101000020E61000008E95F32018E65A4010B8640BF7701BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/155190112	\N
261	setiabudhi-indah-hotel-w155190113	Setiabudhi Indah Hotel	\N	hotel	\N	1	Jalan Dr. Setiabudi, 266, Bandung, Jawa Barat	0101000020E6100000FA545FA722E65A409BFB500E0B721BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/155190113	\N
262	wisma-angkasa-w155228864	Wisma Angkasa	\N	other	\N	1	\N	0101000020E610000030DBA91416E65A408F087C348B7E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/155228864	\N
263	nalendra-w155777651	Nalendra	\N	hotel	\N	1	\N	0101000020E610000009AB0C3EA8E65A407519A31A9B8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/155777651	\N
264	citarum-hotel-w182847335	Citarum Hotel	\N	hotel	\N	1	Jalan Citarum, 16, Bandung	0101000020E610000081EB8A19E1E75A40A0AA9DBC239E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/182847335	\N
265	the-jayakarta-suites-bandung-w183513822	The Jayakarta Suites Bandung	\N	hotel	\N	1	Jl. Ir. H. Juanda No.381A, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135, Bandung	0101000020E6100000BEC3488AA3E75A4001D41E40D07B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/183513822	\N
266	sheraton-bandung-hotel-towers-w185428752	Sheraton Bandung Hotel & Towers	\N	hotel	\N	1	Jl. Ir. H. Juanda No.390, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135, Bandung	0101000020E61000003B191C25AFE75A40AA1A738D857F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185428752	\N
267	ghotic-w185937173	Ghotic	\N	hotel	\N	1	\N	0101000020E61000007D9CC47B69E95A405D35CF11F9C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185937173	\N
268	wisma-pln-w187367314	Wisma PLN	\N	guesthouse	\N	1	\N	0101000020E61000001FF873652BE85A400E91894AD9C01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/187367314	\N
269	bumi-kitri-w194709221	Bumi Kitri	\N	hotel	3	1	\N	0101000020E6100000490966F107E95A40F1BBE9961D921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 22 7216913	https://www.hotelbumikitri.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/194709221	\N
270	asoka-inn-w222621719	ASOKA Inn	\N	hotel	\N	1	\N	0101000020E61000001FAD20BC2CE55A40844B2256DA851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/222621719	\N
271	hotel-golden-flower-w372063342	Hotel Golden Flower	\N	hotel	\N	1	Jalan Asia Afrika, 15-17, Bandung	0101000020E6100000A3E5400FB5E65A40676A6D7594AE1BC0	\N	0	\N	\N	\N	\N	\N	193	\N	\N	https://golden-flower.co.id/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/372063342	\N
272	kalya-hotel-w376352094	Kalya Hotel	\N	hotel	\N	1	Jalan Sumur Bandung, 7	0101000020E6100000F304C24E31E75A40A15923CCFE8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/376352094	\N
273	wisma-kartini-w376352123	Wisma Kartini	\N	hotel	\N	1	\N	0101000020E61000001D9A684675E75A40CD9EBAA8CCAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/376352123	\N
274	bumi-sawunggaling-w381032769	Bumi Sawunggaling	\N	hotel	\N	1	\N	0101000020E610000001EF2E61FEE65A40ACC77DAB759A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/381032769	\N
275	sapadia-w381033009	Sapadia	\N	hostel	\N	1	\N	0101000020E610000042E7DABC16E75A40AED4B32094971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/381033009	\N
276	hotel-pelangi-indah-w381616655	Hotel Pelangi Indah	\N	hotel	\N	1	\N	0101000020E610000066C1C41F45E65A4092A52089A8A31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/381616655	\N
277	pia-hotel-bandung-w381642374	Pia Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000D44E8358ECE75A408AA07B20C3CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/381642374	\N
278	triple-c-guest-house-w413568982	Triple C Guest House	\N	guesthouse	\N	1	Jalan Setra Indah Utara 2, 1, Bandung	0101000020E6100000113BAEA1AFE55A4062BCE6559D851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/413568982	\N
279	hotel-pasar-baru-heritage-bandung-w418955041	Hotel Pasar Baru Heritage Bandung	\N	hotel	\N	1	\N	0101000020E610000076114B6FA4E65A40BDA8DDAF02AC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/418955041	\N
280	kimaya-w421572125	Kimaya	\N	hotel	\N	1	Jalan Braga, Bandung	0101000020E610000086787F1711E75A40762F9C10DFAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421572125	\N
281	hotel-gino-feruci-w421572129	Hotel Gino Feruci	\N	hotel	\N	1	Jalan Braga, Bandung	0101000020E6100000B6076BADF9E65A40022EC896E5AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421572129	\N
282	vue-palace-artotel-curated-w421576674	Vue Palace Artotel Curated	\N	hotel	\N	1	Jalan Kebon Jukut, Bandung	0101000020E6100000E8AD7081BAE65A409BA7DF2AF4A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421576674	\N
283	hotel-bidakara-savoy-homann-w421576677	Hotel Bidakara Savoy Homann	\N	hotel	\N	1	Jalan Asia Afrika, Bandung	0101000020E6100000C81121640FE75A40FEAA6DD454B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	http://www.savoyhomann-hotel.com	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421576677	\N
284	hotel-kumala-w421576684	Hotel Kumala	\N	hotel	\N	1	Jalan Asia Afrika, Bandung	0101000020E6100000C2C826544BE75A407B40EAC083B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421576684	\N
285	the-suddha-asia-afrika-bandung-w421576685	The Suddha Asia Afrika Bandung	\N	hotel	2	1	Jalan Asia Afrika, 128, Bandung	0101000020E6100000337B8FE93FE75A407F66B56565B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421576685	\N
286	grha-ciumbuleuit-guest-house-w522949390	Grha Ciumbuleuit Guest House	\N	hotel	\N	1	\N	0101000020E61000009D45949BCDE65A403DB9A64066771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/522949390	\N
287	ibis-trans-studio-bandung-w422236651	Ibis Trans Studio Bandung	\N	hotel	\N	1	Jenderal Gatot Subroto, Bandung	0101000020E610000028F04E3EBDE85A4066E2B1FA7EB51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/422236651	\N
288	the-trans-luxury-hotel-w422236652	The Trans Luxury Hotel	\N	hotel	\N	1	Jalan Gatot Subroto, Bandung	0101000020E61000000186E5CFB7E85A40252CE0545AB51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/422236652	\N
289	atlantic-city-hotel-bandung-w425693199	Atlantic City Hotel Bandung	\N	hotel	\N	1	Jalan Pasir Kaliki, 126, Bandung	0101000020E61000005428C1D144E65A40FE220D13B2A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62224208222	http://www.atlanticcityhotelbandung.com	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/425693199	\N
290	hotel-chrysanta-w512057463	Hotel Chrysanta	\N	hotel	\N	1	\N	0101000020E6100000958D188744E65A401AD18778359A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512057463	\N
291	tama-boutique-hotel-w512168582	Tama Boutique Hotel	\N	hotel	\N	1	\N	0101000020E6100000849ECDAA4FE65A4087A3AB74779D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512168582	\N
292	kampioen-bed-and-breakfast-w512276736	Kampioen Bed And Breakfast	\N	hotel	\N	1	\N	0101000020E61000005E3013A081E65A40B21A01CB009E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512276736	\N
293	the-luxton-bandung-hotel-w512353719	The Luxton Bandung Hotel	\N	hotel	\N	1	Jl. Ir. H. Juanda No.18, Bandung	0101000020E61000004F006A0F20E75A40CEA21C716D9D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512353719	\N
294	hay-hotel-bandung-w512353748	Hay Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000ED4ACB483DE75A403CA81F2FFF9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512353748	\N
295	de-paviljoen-w512704804	De Paviljoen	\N	hotel	\N	1	\N	0101000020E6100000F0EF7DBBB6E75A405EA0A4C002A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512704804	\N
296	hotel-serela-riau-bandung-w512704810	Hotel Serela Riau Bandung	\N	hotel	\N	1	\N	0101000020E6100000729472ADACE75A40F245D67503A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512704810	\N
297	kytos-hotel-bandung-w512932720	Kytos Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000CE8E54DFF9E55A406EE1D4624B7A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/512932720	\N
298	hotel-latief-inn-bandung-w513014413	Hotel Latief Inn Bandung	\N	hotel	\N	1	\N	0101000020E6100000B72D252683E75A40EE8D6B8D52AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513014413	\N
299	crowne-plaza-hotel-bandung-w513238429	Crowne Plaza Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000F045C5492BE75A40A75027EA16AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513238429	\N
300	latief-inn-hotel-w513259571	Latief Inn Hotel	\N	hotel	\N	1	\N	0101000020E6100000433A3C8471E75A403D89BE7108AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513259571	\N
301	rumah-tawa-hotel-w513259587	Rumah Tawa Hotel	\N	hotel	\N	1	Jalan Cibuntut, Bandung	0101000020E61000003D3D00F35AE75A40F222B836F9AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 22 4264244	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513259587	\N
302	hotel-kedaton-w513325733	Hotel Kedaton	\N	hotel	\N	1	Jalan Suniaraja, 14, Bandung	0101000020E6100000C5515ED0E7E65A40C7478B3386A91BC0	\N	0	\N	\N	\N	\N	\N	116	\N	+62 22 4219898	https://kedatonhotel.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513325733	\N
303	mogens-guest-house-bandung-w513325815	Mogens Guest House Bandung	\N	hotel	\N	1	\N	0101000020E61000004F070D58CDE65A40072A3E99DAA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513325815	\N
304	hotel-kurnia-w513432777	Hotel Kurnia	\N	hotel	\N	1	\N	0101000020E610000087E52A7178E75A4011AEDBFBAFB61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513432777	\N
305	hotel-montameri-bandung-w513439349	Hotel Montameri Bandung	\N	hotel	\N	1	\N	0101000020E6100000CEEEDAEF1AE85A402FF7C95180B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513439349	\N
306	yokotel-hotel-bandung-w513524062	Yokotel Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000E72A27EB81E65A40C124F0E258AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513524062	\N
307	oyo-944-doorman-guest-house-w513569070	OYO 944 Doorman Guest House	\N	hotel	\N	1	\N	0101000020E6100000B6A2282B61E65A40ADDFA7058AAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513569070	\N
308	chara-hotel-bandung-w513810440	Chara Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000FDCBA43CA9E75A4000B26BD674B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/513810440	\N
309	hotel-zodiak-asia-afrika-bandung-w514105041	Hotel Zodiak Asia Afrika Bandung	\N	hotel	\N	1	\N	0101000020E6100000385AC466B6E65A40D297947142AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/514105041	\N
310	andelir-hotel-w514640354	Andelir Hotel	\N	hotel	\N	1	\N	0101000020E6100000AB5FE97C78E65A40BB698E07B6951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/514640354	\N
311	hotel-anugerah-w516636636	Hotel Anugerah	\N	guesthouse	\N	1	\N	0101000020E6100000527644CFF7E55A401200773469661BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/516636636	\N
312	gumilang-regency-hotel-w516640017	Gumilang Regency Hotel	\N	hotel	\N	1	\N	0101000020E6100000FFCD8B135FE65A40C630CCAE20621BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/516640017	\N
313	cinnamon-hotel-boutique-syariah-w519057340	Cinnamon Hotel Boutique Syariah	\N	hotel	\N	1	\N	0101000020E61000000BB43BA418E65A40AA6C0EC63E6F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/519057340	\N
314	salis-hotel-bandung-w520137248	Salis Hotel Bandung	\N	hotel	\N	1	\N	0101000020E61000002FD571A117E65A4009580630C0711BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/520137248	\N
315	hotel-augusta-valley-w520137332	Hotel Augusta Valley	\N	hotel	\N	1	Jalan Cipaku I, 19, Bandung	0101000020E610000027D9EA724AE65A405174136BA7741BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	+62 22 2005036	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/520137332	\N
316	sheo-resort-hotel-w522949382	SHEO Resort Hotel	\N	hotel	\N	1	\N	0101000020E61000009BDDFF6CD0E65A403F027FF8F9771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/522949382	\N
317	concordia-hotel-w522949417	Concordia Hotel	\N	hotel	\N	1	\N	0101000020E6100000B6604E75EDE65A40AE9AE7887C771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/522949417	\N
318	sky-city-home-w530304162	Sky City Home	\N	hotel	\N	1	Jalan Dago Asri, C37	0101000020E6100000B1D183CC5FE75A40D0BB0C5AA3811BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/530304162	\N
319	kristalia-hotel-w530331484	Kristalia Hotel	\N	hotel	\N	1	\N	0101000020E6100000CEC06D12A8E65A4020D099B4A9A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/530331484	\N
320	antapani-home-stay-w530965788	Antapani Home Stay	\N	hotel	\N	1	\N	0101000020E6100000AC04E67C8CEA5A407BD7A02FBDAD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/530965788	\N
321	kos-pak-suherwan-w536556040	Kos Pak Suherwan	\N	guesthouse	\N	1	Gang Cisitu Lama VII, 31	0101000020E610000072DF6A9D38E75A40585936CE01851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/536556040	\N
322	alqueby-hotel-w536660878	Alqueby Hotel	\N	hotel	\N	1	\N	0101000020E610000008D04AB5AAE95A405CE3D81FCDA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/536660878	\N
323	v-hotel-w546473715	V Hotel	\N	hotel	\N	1	\N	0101000020E6100000ED7F80B56AE55A400A2C802903871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546473715	\N
324	hotel-neo-dipatiukur-w546634832	Hotel NEO Dipatiukur	\N	hotel	\N	1	\N	0101000020E6100000E256410C74E75A40F16B7FC2348F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546634832	\N
325	homy-kost-ekslusif-bandung-w546721635	Homy Kost Ekslusif Bandung	\N	hotel	\N	1	\N	0101000020E6100000972E0E782AE75A40EB7E04B463891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546721635	\N
326	vio-hotel-w548319227	Vio Hotel	\N	hotel	\N	1	\N	0101000020E6100000FCD1263DC2E75A40BC259419CA9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548319227	\N
327	pondok-bunda-w548474142	Pondok Bunda	\N	guesthouse	\N	1	\N	0101000020E6100000124DA088C5E75A40813A8A181B8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548474142	\N
328	swan-house-w629346935	Swan House	\N	hotel	\N	1	\N	0101000020E61000008DE9AE91C9E65A40B8BA5285F57D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/629346935	\N
329	dbest-express-hotel-w632229280	Dbest Express Hotel	\N	hotel	\N	1	\N	0101000020E61000000D665DEDF2E65A4090EFF73020C81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632229280	\N
330	the-batik-bed-and-coffee-bandung-w632231657	The Batik Bed And Coffee Bandung	\N	hotel	\N	1	\N	0101000020E61000008BF95EE836E75A40332ABA3F28C91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632231657	\N
331	p-hostel-bandung-w632254939	P Hostel Bandung	\N	hostel	\N	1	\N	0101000020E6100000A83C15CB88E65A40BF1072DEFFBF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632254939	\N
332	d-best-hotel-w632544348	D Best Hotel	\N	hotel	\N	1	\N	0101000020E6100000C23AE9D89CE65A40897E6DFDF4B71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632544348	\N
333	hotel-grand-tulip-bandung-w632553819	Hotel Grand Tulip Bandung	\N	hotel	\N	1	\N	0101000020E6100000BCDA9B293EE65A40F060D56A59B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632553819	\N
334	hotel-nyland-3-cijagra-w632681439	Hotel Nyland 3 Cijagra	\N	hotel	\N	1	\N	0101000020E6100000EE0D19EA0BE85A40C1DE69D729CB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632681439	\N
335	asri-residence-w632681480	Asri Residence	\N	hotel	\N	1	\N	0101000020E61000004BBC4DC903E85A404CF84AC56BCB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/632681480	\N
336	hotel-arimbi-kopo-w633172661	Hotel Arimbi Kopo	\N	hotel	\N	1	\N	0101000020E610000019C8B3CBB7E55A407676E8AA2FC91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/633172661	\N
337	hotel-eve-bandung-w633176935	Hotel Eve Bandung	\N	hotel	\N	1	\N	0101000020E61000008527F4FA13E65A40BA75EDC15ACB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/633176935	\N
338	fora-guest-house-suka-asih-w633769488	Fora Guest House Suka Asih	\N	hotel	\N	1	\N	0101000020E61000008FC8D2E2E7E55A40799C58969EBF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/633769488	\N
339	geowisata-inn-w634629051	Geowisata Inn	\N	hotel	\N	1	\N	0101000020E610000061342BDB07E55A40F73AA92F4BAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/634629051	\N
340	serela-waringin-hotel-w635812821	Serela Waringin Hotel	\N	hotel	\N	1	\N	0101000020E6100000B9A981E6F3E55A403CC8A1348AAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/635812821	\N
341	losmen-leuwi-panjang-w635900850	Losmen Leuwi Panjang	\N	hotel	\N	1	\N	0101000020E610000085E574FE12E65A40D8124DFB41C81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/635900850	\N
342	grand-guci-hotel-w636145859	Grand Guci Hotel	\N	hotel	\N	1	Jalan HOS. Tjokroaminoto, 53-55, Bandung	0101000020E61000001CB5C2F43DE65A40987B9285F9A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/636145859	\N
343	oyo-1308-darmo-residence-w636169669	OYO 1308 Darmo Residence	\N	hotel	\N	1	\N	0101000020E6100000CB187A1FA2E55A40F0B215EA9F961BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/636169669	\N
344	oyo-617-sukaraja-residence-w636227969	OYO 617 Sukaraja Residence	\N	hotel	\N	1	\N	0101000020E61000007A4F8AFBB4E45A40A1246E5F51931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/636227969	\N
345	new-moonlight-hotel-bandung-w636241818	New Moonlight Hotel Bandung	\N	hotel	\N	1	\N	0101000020E610000007E11B542CE65A402EC901BB9AB41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/636241818	\N
346	hotel-reddoorz-malabar-39-samoja-w636448775	Hotel Reddoorz Malabar 39 Samoja	\N	hotel	\N	1	\N	0101000020E61000003DF60E12FDE75A4041E4E3C924B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/636448775	\N
347	hunian-kost-sangkuriang-w637420053	Hunian Kost Sangkuriang	\N	hostel	\N	1	\N	0101000020E61000003BFF76D92FE75A40812AC995D5871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/637420053	\N
348	javaretro-hotel-suite-w638389091	Javaretro Hotel & Suite	\N	hotel	\N	1	\N	0101000020E610000089E0C9B8F3E45A4049A93A9AD98D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638389091	\N
349	ariandri-boutique-guesthouse-w638454858	Ariandri Boutique Guesthouse	\N	hotel	\N	1	\N	0101000020E61000001189E71148E55A40AC34CE4B6A8D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638454858	\N
350	park-view-hotel-w638461705	Park View Hotel	\N	hotel	\N	1	Jalan Sukajadi, 153, Bandung	0101000020E61000002D9B94DD27E65A402CCAB61D648B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638461705	\N
351	mess-memed-sastrawirya-w638461740	Mess Memed Sastrawirya	\N	other	\N	1	\N	0101000020E61000003037CE5C16E65A40D0FA4AD6978B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638461740	\N
352	grand-aquila-hotel-bandung-w638470841	Grand Aquila Hotel Bandung	\N	hotel	\N	1	\N	0101000020E61000002D76A0F3BFE55A4086C54DB27A941BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638470841	\N
353	sukajadi-hotel-bandung-w638488952	Sukajadi Hotel Bandung	\N	hotel	\N	1	\N	0101000020E610000043194FA937E65A40C963BC9CC88A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638488952	\N
354	belviu-hotel-bandung-w638489886	Belviu Hotel Bandung	\N	hotel	\N	1	\N	0101000020E6100000E749E3616BE65A40F245D67503881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638489886	\N
355	cleo-guest-house-w638490225	Cleo Guest House	\N	hotel	\N	1	\N	0101000020E61000000D2950D54EE65A4083C2A04CA3891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638490225	\N
356	naval-hotel-w638490354	Naval Hotel	\N	hotel	\N	1	\N	0101000020E61000000983D7D333E65A4065DDE45C2F8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638490354	\N
357	ibis-bandung-pasteur-w638684927	ibis Bandung Pasteur	\N	hotel	3	1	Dokter Djundjunan, 22	0101000020E61000001C92FF6E26E65A40621D7D827A991BC0	\N	0	\N	\N	\N	\N	\N	147	\N	\N	https://all.accor.com/hotel/9397/index.en.shtml	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/638684927	\N
358	capital-o-1044-diemdi-hotel-w639144367	Capital O 1044 Diemdi Hotel	\N	hotel	\N	1	\N	0101000020E610000033F4F4B63EE95A40FFC9840431AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/639144367	\N
359	mercure-bandung-nexa-supratman-w640405516	Mercure Bandung Nexa Supratman	\N	hotel	4	1	\N	0101000020E610000090430E5B44E85A403C8CA438A29E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/640405516	\N
360	hotel-mitra-w640405932	Hotel Mitra	\N	hotel	\N	1	\N	0101000020E6100000B7FD3C5725E85A4085775ECF7C9B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/640405932	\N
361	hotel-promenade-w673518847	Hotel Promenade	\N	hotel	\N	1	\N	0101000020E61000006851E971A9E65A40A8FE412443961BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/673518847	\N
362	best-western-w678398281	Best Western	\N	hotel	\N	1	\N	0101000020E610000076BA3D520EE75A40B9FA56900BA31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/678398281	\N
363	amaris-cimanuk-w721493913	Amaris Cimanuk	\N	hotel	\N	1	\N	0101000020E6100000ADC66D8FB9E75A40B477A114089E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/721493913	\N
364	hotel-sofiyah-neglasari-w857928866	Hotel Sofiyah Neglasari	\N	hotel	\N	1	\N	0101000020E6100000953A1279DCE85A401F9CF46338931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/857928866	\N
365	mandiri-kost-w858677597	Mandiri Kost	\N	hostel	\N	1	Manisi, Bandung	0101000020E610000025B1A4DCFDED5A4087AF65E88EBC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/858677597	\N
366	zaffirt-house-w858677599	Zaffirt House	\N	hostel	\N	1	\N	0101000020E6100000B5BC1704FBED5A40497B2876D9BC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/858677599	\N
367	kostan-cipadung-permai-w858680637	Kostan Cipadung Permai	\N	hostel	\N	1	Jalan Permai II, Cipadung Wetan	0101000020E6100000D0BFB8AFDEED5A40F0EBD1657BB61BC0	\N	0	\N	\N	\N	\N	\N	30	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/858680637	\N
368	dago-suites-apartement-w867209820	Dago Suites Apartement	\N	hotel	\N	1	Jl. Sangkuriang No.13, Dago Suites Apartment 1st Floor GF-A, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135, 13, Bandung	0101000020E610000074ED0BE805E75A40496D3D9EF1881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/867209820	\N
369	kostan-koe-w871875478	Kostan Koe	\N	hotel	\N	1	Jalan Dago Asri IV, H6	0101000020E6100000615859364EE75A40A5E2B5018E831BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/871875478	\N
370	hotel-wisma-dago-22-w872804190	Hotel Wisma Dago 22	\N	hotel	\N	1	\N	0101000020E610000011CA56F28CE75A40FC7E202F5A7E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/872804190	\N
371	the-regia-dago-w876390540	The Regia Dago	\N	hotel	\N	1	\N	0101000020E6100000F9403C5CBCE75A4072C8618B38781BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/876390540	\N
372	hotel-horison-w951465918	Hotel Horison	\N	hotel	\N	1	Jalan Pelajar Pejuang 45, 121, Bandung	0101000020E61000004C60298103E85A406FB5F3A21BBE1BC0	\N	0	\N	\N	\N	\N	\N	208	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/951465918	\N
373	kost-putri-no-15d-w1052970770	Kost Putri No.15D	\N	hotel	\N	1	\N	0101000020E61000005CFF5316AAE75A40F77475C7628B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1052970770	\N
374	new-b-w1082250050	New B	\N	hotel	\N	1	\N	0101000020E6100000ED25321848E85A40E46FD63B37A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1082250050	\N
375	kos-h-ade-w1158955877	Kos H. Ade	\N	hostel	\N	1	Jalan Insinyur Haji Juanda, 197, Bandung	0101000020E6100000915B38B558E75A40E15DD328C9871BC0	\N	0	\N	\N	\N	\N	\N	6	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1158955877	\N
376	shakti-hotel-w1200663212	Shakti Hotel	\N	hotel	\N	1	Jalan Soekarno-Hatta, 735, Bandung	0101000020E6100000D8D2A3A99EEC5A4010A331A4D4BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1200663212	\N
377	grand-asrilia-hotel-w1206655963	Grand Asrilia Hotel	\N	hotel	\N	1	\N	0101000020E6100000398DFEE1F8E75A4066529ED4F2BE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1206655963	\N
378	hotel-tebu-w1234640088	Hotel Tebu	\N	hotel	\N	1	\N	0101000020E6100000995D9C9DB1E75A405FC0817F00A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1234640088	\N
379	holiday-inn-bandung-pasteur-w1286450090	Holiday Inn Bandung Pasteur	\N	hotel	4	1	Jl. Dr. Djunjunan, 96	0101000020E61000009FA5D01ED4E55A40A249BD022C951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	https://www.ihg.com/holidayinn/hotels/us/en/bandung/bdopa/hoteldetail	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1286450090	\N
380	pia-hotel-w1370426942	Pia Hotel	\N	hotel	\N	1	\N	0101000020E610000093A4106DECE75A405BCEA5B8AACC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1370426942	\N
381	hotel-lingga-w1370729232	Hotel Lingga	\N	hotel	\N	1	\N	0101000020E6100000AF9BAD171EE85A40B35F77BAF3CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1370729232	\N
382	hotel-astria-graha-w1395143854	Hotel Astria Graha	\N	hotel	\N	1	\N	0101000020E6100000E580B80611E75A40E758390F82B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1395143854	\N
383	l-hotel-bandung-w1409981523	├⌐L Hotel Bandung	\N	hotel	4	1	Jalan Merdeka, 2, Bandung, Jawa Barat	0101000020E6100000673C5B5114E75A40FAD8B85917AA1BC0	\N	0	\N	\N	\N	\N	\N	514	\N	\N	https://bandung.el-hotels.com/	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1409981523	\N
384	the-luxton-w1417983396	The Luxton	\N	hotel	\N	1	Jl. Ir. H.Djuanda, 18, Bandung	0101000020E610000019A5F04520E75A402EA0617B779D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1417983396	\N
385	saninten-inn-w1434803982	Saninten Inn	\N	hotel	\N	1	Jalan Saninten, 65, Bandung	0101000020E61000007C8967BF24E85A408BEFD5D86F9F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1434803982	\N
386	sukajadi-guest-house-w1484267798	Sukajadi Guest House	\N	guesthouse	\N	1	\N	0101000020E61000005519219713E65A4008B364E99E801BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1484267798	\N
\.


--
-- Data for Name: ai_extractions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ai_extractions (id, raw_item_id, model_name, prompt_version, extracted_kind, extracted_data, hidden_gem_score, hidden_gem_reason, confidence, needs_review, promoted_place_id, promoted_accommodation_id, created_at) FROM stdin;
\.


--
-- Data for Name: amenities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.amenities (id, name) FROM stdin;
1	WiFi
2	Pool
3	Breakfast
4	Parking
5	AC
6	Hot Water
7	Restaurant
8	Kitchen
9	Family Room
10	Pet Friendly
\.


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (id, name, slug) FROM stdin;
1	Waterfall	waterfall
2	Viewpoint	viewpoint
3	Cave	cave
4	Hot Spring	hot_spring
5	Camp Site	camp_site
6	Nature Reserve	nature_reserve
7	Crater	crater
8	Tea Plantation	tea_plantation
9	Other	other
10	Culinary	culinary
11	Culture & Museum	culture
12	Shopping	shopping
\.


--
-- Data for Name: cities; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.cities (id, province_id, name, type, boundary) FROM stdin;
1	1	Bandung	kota	\N
\.


--
-- Data for Name: data_sources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.data_sources (id, name, base_url, notes) FROM stdin;
1	overpass_osm	https://overpass-api.de	\N
2	google_places	https://places.googleapis.com	\N
3	gemini_scoring	https://ai.google.dev	\N
\.


--
-- Data for Name: districts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.districts (id, city_id, name, boundary) FROM stdin;
1	1	Andir	\N
2	1	Antapani	\N
3	1	Arcamanik	\N
4	1	Astanaanyar	\N
5	1	Babakan Ciparay	\N
6	1	Bandung Kidul	\N
7	1	Bandung Kulon	\N
8	1	Bandung Wetan	\N
9	1	Batununggal	\N
10	1	Bojongloa Kaler	\N
11	1	Bojongloa Kidul	\N
12	1	Buahbatu	\N
13	1	Cibeunying Kaler	\N
14	1	Cibeunying Kidul	\N
15	1	Cibiru	\N
16	1	Cicendo	\N
17	1	Cidadap	\N
18	1	Cinambo	\N
19	1	Coblong	\N
20	1	Gedebage	\N
21	1	Kiaracondong	\N
22	1	Lengkong	\N
23	1	Mandalajati	\N
24	1	Panyileukan	\N
25	1	Rancasari	\N
26	1	Regol	\N
27	1	Sukajadi	\N
28	1	Sukasari	\N
29	1	Sumur Bandung	\N
30	1	Ujungberung	\N
\.


--
-- Data for Name: place_images; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.place_images (id, place_id, url, caption, is_cover, sort_order) FROM stdin;
\.


--
-- Data for Name: place_sources; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.place_sources (place_id, source_id, source_url, last_synced) FROM stdin;
\.


--
-- Data for Name: place_tags; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.place_tags (place_id, tag_id) FROM stdin;
\.


--
-- Data for Name: places; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.places (id, slug, name, description, category_id, city_id, address, location, rating_avg, rating_count, price_min, price_max, price_level, opening_hours, phone, website, google_place_id, is_hidden_gem, hidden_gem_score, hidden_gem_reason, is_active, created_at, updated_at, district_id, osm_ref, enriched_at) FROM stdin;
1	monumen-purwa-aswa-purba-n1013403364	Monumen Purwa Aswa Purba	\N	11	1	\N	0101000020E61000007616629A8EE65A40C3D7D7BAD4A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1013403364	\N
2	bandung-lautan-api-n1014721911	Bandung Lautan Api	\N	11	1	\N	0101000020E6100000FC6C8901B7E65A4025C4019942BC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1014721911	\N
3	bdg-0-n1700852205	BDG 0	\N	11	1	\N	0101000020E610000010C75FFF1AE75A4011BF0754A4AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1700852205	\N
4	knil-monument-n1708180763	KNIL monument	\N	11	1	\N	0101000020E6100000F612190CE4E55A40524832AB77981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1708180763	\N
5	monumen-perpamsi-n1823875695	Monumen Perpamsi	\N	11	1	\N	0101000020E610000060483DFA15E75A404D60DFF3689F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/1823875695	\N
6	graf-van-de-onbekende-soldaat-en-onbekende-burger-n2500454839	Graf van de onbekende soldaat en onbekende burger	\N	11	1	\N	0101000020E6100000EAA6DE64E5E55A4025F14D2E219A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/2500454839	\N
7	husein-sastranegana-n3128774234	Husein Sastranegana	\N	11	1	\N	0101000020E6100000DC35D71F97E55A4073B389DD88A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3128774234	\N
8	rumah-bersejarah-inggit-garnasih-n3348067546	Rumah Bersejarah Inggit Garnasih	Museum about Sukarno's ex-wife	11	1	Jalan Inggit Ganarsih, 8	0101000020E6100000D5EDEC2B8FE65A40D0BF1369D1B91BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 07:00-16:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348067546	\N
9	monumen-konferensi-asia-afrika-n3348122792	Monumen Konferensi Asia Afrika	\N	11	1	\N	0101000020E6100000D25F9E8488E75A40666CE8667FB01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348122792	\N
10	monumen-tank-baja-n3348123493	Monumen Tank Baja	\N	11	1	\N	0101000020E6100000550ED2F8AAE75A40254FA3DAF1B01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348123493	\N
11	monumen-penjara-bung-karno-n3348135338	Monumen Penjara Bung Karno	\N	11	1	\N	0101000020E610000020BD3CF8E4E65A4067C4BB1237AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348135338	\N
12	monumen-laskar-wanita-n3348140433	Monumen Laskar Wanita	\N	11	1	\N	0101000020E61000006281AFE8D6E65A40BABE0F0709A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348140433	\N
13	monumen-tentara-pelajar-n3348140434	Monumen Tentara Pelajar	\N	11	1	\N	0101000020E6100000C6E12769D9E65A403018B72CBAA81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3348140434	\N
14	makam-pendiri-kota-bandung-n3431378604	Makam Pendiri Kota Bandung	\N	11	1	\N	0101000020E610000067B62BF4C1E65A40D386C3D2C0AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3431378604	\N
15	machine-gun-n3434620514	Machine gun	\N	11	1	\N	0101000020E6100000EC72A5F93EE75A406415809076B51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3434620514	\N
16	kopi-aroma-n3754824465	Kopi Aroma	\N	9	1	\N	0101000020E610000026434420CDE65A404F0240BA7DAB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3754824465	\N
17	balai-pengelolaan-taman-budaya-n3809369307	Balai Pengelolaan Taman Budaya	\N	11	1	\N	0101000020E6100000F756C96CB5E75A40DF3653211E791BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3809369307	\N
18	panhard-ebr-fl-11-n3817206785	Panhard EBR FL-11	Panhard EBR FL-11	11	1	\N	0101000020E61000004D9940B651E85A404D52F41B81B31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/3817206785	\N
19	galeri-cinde-n4329454377	Galeri Cinde	\N	11	1	Jl. Pahlawan , Neglasari, Cibeunying Kaler, 58, Bandung	0101000020E6100000A34918BC9EE85A409FDD6B521B961BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4329454377	\N
20	iris-garden-n4338249203	Iris Garden	\N	9	1	\N	0101000020E61000006120634914E85A40589E510482DA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4338249203	\N
21	pintu-utara-stasiun-bandung-n4365723062	Pintu Utara Stasiun Bandung	\N	11	1	Jalan Kebon Kawung, 22A, Bandung	0101000020E61000002DEBFEB190E65A4042BC64D295A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4365723062	\N
22	egioto-com-n4451042091	Egioto.com	\N	2	1	\N	0101000020E6100000A5A54D30F7E45A40EE55D0590B781BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4451042091	\N
23	amazing-art-world-n4625757227	Amazing Art World	\N	11	1	Jalan Setiabudhi, 293	0101000020E6100000EA888DC32AE65A40929F43CF1C681BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 09:00-21:00"}	+62 222018280	https://m.facebook.com/AmazingArtWorld.Bandung/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/4625757227	\N
24	pastoor-h-c-verbraak-n5178031251	Pastoor H.C. Verbraak	\N	11	1	\N	0101000020E610000090F062064FE75A408D316601C9A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5178031251	\N
25	seni-abadi-n5188407891	Seni Abadi	\N	11	1	\N	0101000020E610000066F50EB7C3E65A405A8A3FE5F39D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5188407891	\N
26	pintu-masuk-forest-walk-babakan-siliwangi-n5312537881	Pintu Masuk Forest Walk Babakan Siliwangi	\N	9	1	\N	0101000020E6100000EB3713D305E75A401212691B7F8A1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5312537881	\N
27	sumur-bandung-n5503920859	Sumur Bandung	\N	9	1	\N	0101000020E6100000374767AAF1E65A4047979240DEAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5503920859	\N
28	bandung-science-center-n5506699714	Bandung Science Center	\N	11	1	Jalan Sirnagalih, 15	0101000020E6100000A50A90B20FE65A4084D2BC885B821BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 09:00-17:00"}	+62222060412	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5506699714	\N
29	museum-gedung-sate-n5554688585	Museum Gedung Sate	\N	11	1	Jalan Diponegoro, 22	0101000020E6100000A9C1340C9FE75A40ABE2D7593E9C1BC0	\N	0	\N	\N	\N	{"osm": "Tu-Su 09:30-16:00"}	+62224267753	http://museumgedungsate.jabarprov.go.id	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5554688585	\N
30	patung-maung-bandung-n5564292643	Patung Maung Bandung	\N	11	1	\N	0101000020E6100000FAD005F5ADE65A40096B0833129E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5564292643	\N
31	museum-pos-indonesia-n5586548849	Museum Pos Indonesia	\N	11	1	Jalan Cilaki, 73, Bandung	0101000020E61000002C6112D3AAE75A4016DEE522BE9B1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Fr 08:00-16:00; Sa 09:00-13:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5586548849	\N
32	karang-setra-n5591673207	Karang Setra	\N	9	1	\N	0101000020E61000000068DEBB17E65A408D3A843B61831BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5591673207	\N
33	jalan-sukamaju-n5638762921	Jalan Sukamaju	\N	2	1	\N	0101000020E610000034F1B33632ED5A40E5CAEA67FBB11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5638762921	\N
34	flyover-pelangi-antapani-n5654460921	Flyover Pelangi Antapani	\N	2	1	\N	0101000020E610000016D8086932E95A40CF3F0B53A5A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5654460921	\N
35	shoes-and-bags-shopping-street-n5686426821	Shoes and bags shopping street	\N	9	1	\N	0101000020E6100000D43DFC4605E65A40E7131ED901CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5686426821	\N
36	gedung-denzibang-n5778956253	Gedung Denzibang	\N	2	1	\N	0101000020E61000001C06F35748E95A400D1F6C0C95C21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5778956253	\N
37	perumahan-sukaasih-n5824553653	Perumahan Sukaasih	\N	2	1	\N	0101000020E610000030A990E1E7EB5A400A67B796C9A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5824553653	\N
38	patung-inovasi-n6725832656	Patung Inovasi	Triangle of managing Bandung: Innovation, decentralization, and collaboration.	11	1	\N	0101000020E6100000F54883DB5AE75A40C4115AC5D1A31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6725832656	\N
39	hall-of-fame-jawa-barat-n5885293835	Hall of Fame Jawa Barat	\N	11	1	\N	0101000020E61000004FFC620072EA5A40D4EBBBC73EBD1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Sa 08:00-17:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/5885293835	\N
40	lapang-karet-n6009237968	Lapang Karet	\N	9	1	\N	0101000020E610000052D32EA699E65A409E1C4F159D8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6009237968	\N
41	jalan-cipaera-n6123051585	Jalan Cipaera	\N	2	1	\N	0101000020E61000001EE5BBEFF3E75A406B56C73BD1AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6123051585	\N
42	dago-car-free-day-n6149684552	Dago Car Free Day	Road closed for cars and street full of food, music, dance and other activities.	9	1	\N	0101000020E61000008A0A308738E75A4058C27F5FC8971BC0	\N	0	\N	\N	\N	{"osm": "Su 06:00-10:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6149684552	\N
43	jalan-majalengka-dalam-n6265263186	Jalan Majalengka Dalam	\N	2	1	\N	0101000020E6100000A983616559E85A4026C45C52B5AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6265263186	\N
44	jalan-sukasari-ii-n6342441385	Jalan Sukasari II	\N	2	1	\N	0101000020E6100000BF8D8301BAE75A40BFDB172BC5911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6342441385	\N
45	tugu-selamat-datang-di-kota-bandung-n6466097818	Tugu Selamat Datang di Kota Bandung	\N	11	1	\N	0101000020E6100000EC7310CF6DE45A40966C86657DA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6466097818	\N
46	kebun-dinas-sindanglaya-n6657073006	Kebun Dinas Sindanglaya	Kebun Dinas Sindanglaya. Kebun Dinas Sindanglaya berlokasi di Kelurahan Sindangjaya, Kecamatan Mandalajati, Kota Bandung, mempunyai fungsi kebun sebagai kebun produksi dan kebun koleksi seluas 1,84 ha, dengan komoditas yang dikembangkan 12 Komoditas	9	1	\N	0101000020E6100000DCC07861C6EB5A406E6EA708CB931BC0	\N	0	\N	\N	\N	\N	+62 22 7831 287	https://bpbtpbdg.wordpress.com/?s=sindanglaya	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6657073006	\N
47	museum-perbendaharaan-n6714107763	Museum Perbendaharaan	\N	11	1	Jalan Diponegoro, 45B	0101000020E610000018755204DDE75A403DEC2A49439A1BC0	\N	0	\N	\N	\N	{"osm": "Mo, Sa, Su 09:00-16:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6714107763	\N
48	kereta-api-td-1002-n6725618307	Kereta Api TD 1002	Steam locomotive Werkspoor TD1002 was used on 600 mm railroad rail built by the Dutch East Indies Staatsspoorwegen (SS), around Cikampek and Krawang in 1912-1920. SS brought 3 units of TD10 steam locomotive from Werkspoor factory in 1926.	11	1	\N	0101000020E61000002B48D85CDAE65A40CED1996A1CA81BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6725618307	\N
49	zerotoys-museum-mainan-n6725758915	Zerotoys Museum Mainan	\N	11	1	Jalan Sunda, 39a	0101000020E61000002B07C43588E75A40409072E60DAE1BC0	\N	0	\N	\N	\N	{"osm": "Mo-We, Fr-Su 11:00-20:00"}	\N	https://m.facebook.com/zerotoys	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/6725758915	\N
50	bandung-planning-gallery-n7083339722	Bandung Planning Gallery	\N	11	1	\N	0101000020E6100000208D542907E75A4009D91E6228A41BC0	\N	0	\N	\N	\N	{"osm": "Mo-Sa 09:00-16:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7083339722	\N
51	mesjid-al-hidayah-n7246694685	Mesjid Al-Hidayah	\N	2	1	\N	0101000020E610000090FBB1A4B7E75A40A0432AD6BA8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7246694685	\N
52	lapangan-volly-sadang-serang-n7466927526	Lapangan Volly Sadang Serang	\N	9	1	\N	0101000020E6100000D64FA4A000E85A407AA5D189A9911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7466927526	\N
53	lapangan-bulutangkis-n7466927551	Lapangan Bulutangkis	\N	9	1	\N	0101000020E61000000F924FD9FAE75A4064BD079E31921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/7466927551	\N
54	taman-permata-permai-n8434131078	Taman Permata Permai	\N	9	1	\N	0101000020E610000055D0FE5165EB5A400124E4CD2BB01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/8434131078	\N
55	bandung-lautan-api-n9269437521	Bandung Lautan Api	\N	9	1	\N	0101000020E6100000443B021393E65A4094F7713447BE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9269437521	\N
56	open-space-n9726770690	Open Space	\N	9	1	\N	0101000020E6100000EA17361408EE5A40A06CCA15DEBD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9726770690	\N
57	bunderan-cibiru-n9808094311	Bunderan Cibiru	\N	11	1	\N	0101000020E61000001B82E332EEED5A406AB5D14A6BBD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9808094311	\N
58	tugu-sepatu-cibaduyut-n9816621944	Tugu Sepatu Cibaduyut	\N	11	1	\N	0101000020E6100000BDA02A4B19E65A40BE50C07630CA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9816621944	\N
59	kampung-korea-bandung-n9938445753	Kampung Korea Bandung	\N	9	1	\N	0101000020E61000001EBAEA4B00E95A40ADF314DE8AA91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9938445753	\N
60	taman-asia-africa-n9938653539	Taman Asia Africa	\N	9	1	\N	0101000020E6100000CE8C7E341CE95A40E426B4F688AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9938653539	\N
61	taman-metrologi-n9942070649	Taman Metrologi	\N	9	1	\N	0101000020E6100000AC472B082FE65A400AE4C8B9038B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9942070649	\N
62	taman-gaya-n9942077640	Taman Gaya	\N	9	1	\N	0101000020E6100000878BDCD355E65A40EBD3E06C29861BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/9942077640	\N
63	tembok-ratapan-n10277073758	Tembok Ratapan	\N	11	1	\N	0101000020E61000005DF3F45B05E75A4060B3B7EFAC901BC0	\N	0	\N	\N	\N	\N	\N	https://rinaldimunir.wordpress.com/2017/07/11/tembok-ratapan-di-kampus-itb/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10277073758	\N
64	museum-nike-ardilla-n10280227881	Museum Nike Ardilla	\N	11	1	Jalan Aria Utama, 5, Bandung	0101000020E61000004845AD7A0AEB5A40AD9DCD4F16C31BC0	\N	0	\N	\N	\N	\N	+6281572115999	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10280227881	\N
65	museum-kebudayaan-tionghoa-n10280251596	Museum Kebudayaan Tionghoa	\N	11	1	Jalan Nana Rohana, 37, Bandung	0101000020E6100000DDF52DCEF3E45A4081BA3775D4AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10280251596	\N
66	sanggar-olah-seni-babakan-siliwangi-n10284195908	Sanggar Olah Seni Babakan Siliwangi	\N	11	1	\N	0101000020E61000002CF9331713E75A406C9D13D6218A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10284195908	\N
67	galeri-soermardja-n10284202116	Galeri Soermardja	\N	11	1	\N	0101000020E6100000A1DB4B1A23E75A40B7A8609EDF911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10284202116	\N
68	galeri-kebun-seni-tamansari-bandung-n10653924700	Galeri Kebun Seni Tamansari Bandung	\N	11	1	Jl. Tamansari, Lb. Siliwangi, Kec. Coblong, Bandung	0101000020E61000009CEC551AE7E65A40BA6EA532208E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10653924700	\N
69	gloya-by-krida-nusantara-n10656979386	Gloya by Krida Nusantara	\N	11	1	Jalan Insinyur Haji Juanda, 386, Bandung	0101000020E610000015E63DCE34E75A400C1C7519A39A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10656979386	\N
70	kutipan-pidi-baiq-n10793588346	Kutipan Pidi Baiq	\N	9	1	\N	0101000020E61000007DE47BEBE8E65A40AB19637149AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10793588346	\N
71	kutipan-m-a-w-brouwer-n10793588347	Kutipan M.A.W. Brouwer	\N	9	1	\N	0101000020E610000006F93482E8E65A402025766D6FAF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10793588347	\N
72	taman-tingkat-rw-n10796527130	Taman tingkat RW	\N	9	1	\N	0101000020E6100000AED85F764FEE5A40C0D831642BB61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10796527130	\N
261	taman-rw-01-w734351252	Taman RW 01	\N	9	1	\N	0101000020E6100000FD02305434E75A40B317C04AF4C81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/734351252	\N
73	rth-posyandu-tanjung-n10796580135	RTH Posyandu Tanjung	\N	9	1	\N	0101000020E6100000591EFF603BEE5A407DF266C350B51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10796580135	\N
74	rth-bukit-mbah-garut-n10796647093	RTH Bukit Mbah Garut	\N	9	1	\N	0101000020E61000000E84640193EE5A4046D1031F839D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10796647093	\N
75	taman-sempadan-sungai-babakan-surabaya-n10798900144	Taman Sempadan Sungai Babakan Surabaya	\N	9	1	\N	0101000020E61000001477BCC96FE95A4050FEEE1D35A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798900144	\N
76	taman-lingkungan-n10798911771	Taman Lingkungan	\N	9	1	\N	0101000020E61000006AE4A9FD8CE95A409443D5F901A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798911771	\N
77	taman-bermain-anak-wisata-sungai-n10798931990	Taman Bermain Anak Wisata Sungai	\N	9	1	\N	0101000020E6100000F31142516AE95A405D1ABFF04AA21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798931990	\N
78	taman-lingkungan-n10798961359	Taman Lingkungan	\N	9	1	\N	0101000020E6100000B8FBC165BAE65A40A19BA2C8FFC11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798961359	\N
79	taman-lingkungan-kurdi-cempaka-n10798971702	Taman Lingkungan Kurdi Cempaka	\N	9	1	\N	0101000020E6100000DBDC989EB0E65A40EA8722EEFBC11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798971702	\N
80	taman-lingkungan-n10798980720	Taman Lingkungan	\N	9	1	\N	0101000020E610000013F648DE94E65A406121CE1EC3C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798980720	\N
81	taman-lingkungan-n10798991642	Taman Lingkungan	\N	9	1	\N	0101000020E61000008737C6A9B1E65A40A340FA8106C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798991642	\N
82	taman-lingkungan-rw-03-n10798991953	Taman Lingkungan RW 03	\N	9	1	\N	0101000020E61000004717409D97E65A4095174FF344BE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10798991953	\N
83	taman-lingkungan-n10799012026	Taman Lingkungan	\N	9	1	\N	0101000020E6100000B8AE98115EE65A4014701981C2C21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10799012026	\N
84	taman-ulekan-bri-n10799022176	Taman Ulekan BRI	\N	9	1	\N	0101000020E61000006982F2881BE65A4037AA2E3B1FB11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10799022176	\N
85	taman-kali-citepus-n10799032132	Taman Kali Citepus	\N	9	1	\N	0101000020E6100000957F2DAF5CE65A4040016FDCBDBF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10799032132	\N
86	taman-lingkungan-n10799041423	Taman Lingkungan	\N	9	1	\N	0101000020E61000001B79C5F855E65A403F41182E61B31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10799041423	\N
87	taman-lingkungan-rw-n10799055980	Taman Lingkungan RW	\N	9	1	\N	0101000020E61000007062A30719E65A40A5DD431DB1B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10799055980	\N
88	rth-sempadan-rel-kereta-n10800366668	RTH Sempadan Rel Kereta	\N	9	1	\N	0101000020E6100000A8305B5771E75A40398C930C4AAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10800366668	\N
89	taman-bermain-anak-n10800368855	Taman Bermain Anak	\N	9	1	\N	0101000020E61000009AA03CE246E55A406AB1CA3B3D8D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10800368855	\N
90	taman-bola-n10801192061	Taman Bola	\N	9	1	\N	0101000020E610000070534D5A82E85A402B1AC638DA9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10801192061	\N
91	seasons-playground-n10996585701	Seasons Playground	\N	9	1	Bandung Indah Plaza - Lantai 3, Jl. Merdeka No.56, Citarum, Kec. Bandung Wetan, Lantai 3, Kota Bandung	0101000020E6100000690C29F51BE75A40DEF1DC312BA21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/10996585701	\N
92	gedung-sate-n11048805968	Gedung Sate	\N	2	1	\N	0101000020E61000000B52DFE899E75A4012E5C1CC2D9B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11048805968	\N
93	bandung-sister-cities-braunschweig-n11052507720	Bandung sister cities - Braunschweig	\N	11	1	\N	0101000020E6100000DEE11BAFE5E65A40FDA36FD234A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11052507720	\N
94	tugu-pkk-n11052532594	Tugu PKK	\N	11	1	\N	0101000020E61000007C77D09101E85A40C9101148D39A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11052532594	\N
95	train-n11061286364	Train	\N	11	1	\N	0101000020E61000006B4B789D68E85A4008115FDCFCAD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11061286364	\N
96	lengkong-night-street-food-n11064992945	Lengkong Night Street Food	\N	9	1	\N	0101000020E61000008AA07B2043E75A409F52CA106CB11BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 18:00-00:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11064992945	\N
97	patung-ikan-n11337699136	Patung Ikan	\N	11	1	\N	0101000020E6100000E2708B9E00E75A40A0CCF56C0CC01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11337699136	\N
98	saritem-redlight-disrtict-n11415319631	Saritem Redlight Disrtict	\N	9	1	\N	0101000020E610000056B032BF3FE65A400575801601AC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11415319631	\N
99	kelompok-seni-tani-n11459991301	Kelompok Seni Tani	\N	9	1	\N	0101000020E610000064247B841AEB5A40F57DDD8E15B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11459991301	\N
100	atrium-cibadag-n11539070161	Atrium Cibadag	\N	2	1	\N	0101000020E6100000BB809719B6EC5A401107640A31D21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11539070161	\N
101	atrium-cileutik-n11539070162	Atrium Cileutik	\N	2	1	\N	0101000020E61000008266214BB0EC5A40A97290C657D11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11539070162	\N
102	atrium-ciunik-n11539070163	Atrium Ciunik	\N	2	1	\N	0101000020E6100000FB5A971AA1EC5A40FC5B5DA9C2D21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11539070163	\N
103	tugu-perjuangan-bandung-timur-n11990031883	Tugu Perjuangan Bandung Timur	\N	11	1	\N	0101000020E6100000952BBCCBC5EA5A408F9E6C14A3A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/11990031883	\N
104	monumen-al-jabbar-n12051490449	Monumen Al Jabbar	\N	11	1	\N	0101000020E61000003B8908FF22ED5A40DC3EF559AFCB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12051490449	\N
105	ptdi-factory-tour-bandros-start-n12064456186	PTDI Factory tour Bandros start	\N	9	1	\N	0101000020E6100000452FA3586EE55A4049D576137C9B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12064456186	\N
106	sister-city-park-n12073059377	Sister City Park	\N	9	1	\N	0101000020E610000017748C753BE75A404A703491E3A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12073059377	\N
107	gong-n12090548597	Gong	\N	11	1	\N	0101000020E610000032FA76B7D7E65A40EA7F14D09FB11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12090548597	\N
108	dunia-antariksa-n12090565556	Dunia Antariksa	\N	9	1	\N	0101000020E6100000D767734122E65A402F9B4A500D8D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12090565556	\N
109	kontrakan-bp-dodo-n12488357574	Kontrakan bp dodo	\N	9	1	\N	0101000020E61000000AB54BC0D4E95A40AE2F6D93E5C71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12488357574	\N
110	taman-sd-dan-sma-14-n12624763934	Taman SD dan SMA 14	\N	9	1	Jalan Pramukha XIII, Bandung	0101000020E61000000FE7864BB3E85A40B6C82C31859D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/12624763934	\N
111	tank-n13036991649	Tank	\N	11	1	\N	0101000020E61000006245B2ECEEE75A4092CF8657ED9D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13036991649	\N
112	museum-kavaleri-n13042314420	Museum Kavaleri	\N	11	1	\N	0101000020E61000004557337C55E85A40201B92A4B5B31BC0	\N	0	\N	\N	\N	{"osm": "Tu-Su 10:00-15:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13042314420	\N
113	taman-ulin-n13306436431	Taman Ulin	\N	9	1	\N	0101000020E61000004D65F61ED3E65A40F4E56091BA981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13306436431	\N
114	caskade-park-n13306436432	Caskade Park	\N	9	1	\N	0101000020E6100000F82C1911D6E65A409CC827BFA0981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13306436432	\N
115	lost-in-clay-n13535911147	Lost in Clay	\N	9	1	\N	0101000020E6100000B9066CBD15E75A40A452EC681C8A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13535911147	\N
116	taman-plano-n13621753513	Taman Plano	\N	9	1	\N	0101000020E61000005506C4DACEE85A4066F3DD5273961BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 07:00-22:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13621753513	\N
117	galeri-rasulullah-n13650694532	Galeri Rasulullah	\N	11	1	\N	0101000020E6100000DE550F9807ED5A40AC095861E9CA1BC0	\N	0	\N	\N	\N	{"osm": "We-Su 09:00-15:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13650694532	\N
118	margacinta-park-n13833618295	Margacinta Park	\N	9	1	\N	0101000020E610000075351E1178E95A40413F9D3C76D11BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 08:00-18:00"}	\N	https://msha.ke/margacintapark	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/13833618295	\N
119	museum-itb-n14041350074	Museum ITB	\N	11	1	\N	0101000020E610000030B209D5F2E65A40BDD98B0D828B1BC0	\N	0	\N	\N	\N	{"osm": "Tu-Su 10:00-15:00"}	\N	https://museum.itb.ac.id/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/14041350074	\N
120	sekali-teman-tetap-teman-n14085713330	Sekali Teman Tetap Teman	\N	11	1	\N	0101000020E610000004E21A4410E75A402A148EC5DB8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	node/14085713330	\N
121	taman-prabuwangi-w27807705	Taman Prabuwangi	\N	9	1	\N	0101000020E6100000DF6FB4E306EB5A40989DEA35E2A61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/27807705	\N
122	alun-alun-kota-bandung-w87148716	Alun-Alun Kota Bandung	Lush and shaded by trees urban city park, build using synthetic grass.	9	1	\N	0101000020E61000006D6814DCD9E65A407627E9ABF5AF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/87148716	\N
123	lapangan-supratman-w95526288	Lapangan Supratman	\N	9	1	Bandung	0101000020E6100000A75DA7EC4FE85A40BAE303F170A11BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/95526288	\N
124	taman-radio-w95604245	Taman Radio	\N	9	1	Bandung	0101000020E6100000C01A0C1A1FE75A409611CDF22B9C1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/95604245	\N
125	kebun-binatang-bandung-w95610582	Kebun Binatang Bandung	\N	9	1	Jalan Taman Sari, 6	0101000020E6100000B0912408D7E65A403B376DC669901BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 08:00-16:00"}	\N	https://www.bandung-zoo.com/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/95610582	\N
126	taman-cikapayang-dago-w119441848	Taman Cikapayang Dago	\N	9	1	Bandung	0101000020E610000052B1D6F530E75A4037CFC76B14981BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119441848	\N
127	bandung-sister-cities-fort-worth-texas-w119880466	Bandung Sister Cities -  Fort Worth, Texas	\N	11	1	\N	0101000020E61000008B34F10EF0E65A40A1C9B4ECFFA21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119880466	\N
128	gedung-indonesia-menggugat-w119880736	Gedung Indonesia Menggugat	\N	11	1	\N	0101000020E61000009BB80B83E8E65A406E7484C256A71BC0	\N	0	\N	\N	\N	{"osm": "Mo-Fr 08:00-17:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/119880736	\N
129	museum-geologi-w125174070	Museum Geologi	\N	11	1	Jalan Diponegoro, 57, Bandung	0101000020E61000001233FB3CC6E75A402157EA59109A1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Th 08:00-16:00; Sa, Su 08:00-14:00"}	+62 22-7213822	http://museum.geology.esdm.go.id	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/125174070	\N
130	taman-kandaga-puspa-w125806416	Taman Kandaga Puspa	The park is recently revamped and revitalized by the government (in progress) with new plants and amenities. River flows in the middle of the park. Good for morning walk and popular among community members. meadow, park, recreational, grass, trees, river	9	1	Jalan Cisangkuy	0101000020E610000003D8367BD6E75A40C2C9ECE2EC9C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/125806416	\N
131	taman-lansia-w125806418	Taman Lansia	meadow, park, recreational, grass, trees, river	9	1	Bandung	0101000020E61000008E4B6606BBE75A40C5313784CF9B1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/125806418	\N
132	pet-park-w125806419	Pet Park	\N	9	1	Bandung	0101000020E6100000E1B20A9B01E85A40988CBEDDED9D1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/125806419	\N
133	museum-barli-w152982392	Museum Barli	\N	11	1	Jalan Profesor Dokter Sutami, 91, Bandung	0101000020E61000001C19F55A9AE55A40BB7CEBC37A831BC0	\N	0	\N	\N	\N	{"osm": "Mo-Sa 10:00-17:00"}	+62 22 2011898	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/152982392	\N
134	taman-lalu-lintas-ade-irma-suryani-w154007026	Taman Lalu Lintas Ade Irma Suryani	\N	9	1	\N	0101000020E6100000AE62F19B42E75A408F28FE3916A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/154007026	\N
135	trans-studio-bandung-w154204630	Trans Studio Bandung	\N	9	1	Bandung	0101000020E6100000C36FF9FEBCE85A409191FD3DC2B21BC0	\N	0	\N	\N	\N	\N	\N	https://www.transentertainment.com/transstudio/bandung	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/154204630	\N
136	gedung-merdeka-w166968558	Gedung Merdeka	\N	11	1	Jalan Asia Afrika, Bandung	0101000020E610000060257A74FEE65A40F3C418FD0DAF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/166968558	\N
137	museum-konferensi-asia-afrika-w166968559	Museum Konferensi Asia-Afrika	\N	11	1	Jalan Asia Afrika, 65, Bandung	0101000020E61000000AE764F302E75A40481229722DAF1BC0	\N	0	\N	\N	\N	{"osm": "We, Th, Sa 09:00-12:00; We, Th, Sa 13:00-15:00; Fr 13:30-15:30, 09:00-11:30"}	+62 22 4233564	https://mkaa.kemlu.go.id/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/166968559	\N
138	saung-angklung-udjo-w167064114	Saung Angklung Udjo	\N	9	1	\N	0101000020E6100000D373C1CFEEE95A406FB65E78CA971BC0	\N	0	\N	\N	\N	\N	+62 821-8282-1200	https://www.angklung-udjo.co.id/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/167064114	\N
139	lap-stks-bandung-w185437317	lap STKS BANDUNG	\N	9	1	\N	0101000020E61000003FD296299CE75A40FC2E1114E47C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185437317	\N
140	taman-panatayuda-w168566326	Taman Panatayuda	\N	9	1	Bandung	0101000020E6100000C5234CAC67E75A403AB3B85A82971BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/168566326	\N
141	taman-patung-laskar-wanita-w168567649	Taman Patung Laskar Wanita	\N	9	1	\N	0101000020E610000015713AC9D6E65A40D482177D05A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/168567649	\N
142	taman-patung-pelajar-pejuang-w168567650	Taman Patung Pelajar Pejuang	\N	9	1	\N	0101000020E61000005C76887FD8E65A40D1ADD7F4A0A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/168567650	\N
143	taman-komplek-ddk-369-w183473029	Taman Komplek DDK 369	\N	9	1	Bandung	0101000020E61000006D33BA289FE75A401AA144F0647C1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/183473029	\N
144	taman-pdam-w183513819	Taman PDAM	\N	9	1	Bandung	0101000020E6100000F5ABEFB295E75A4025E1E7644E7C1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/183513819	\N
262	taman-piset-w734357298	Taman Piset	\N	9	1	\N	0101000020E61000007A0668B606E85A40AA3EA1E8CBBC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/734357298	\N
145	taman-budaya-jawa-barat-w184714612	Taman Budaya Jawa Barat	\N	9	1	Jalan Bukit Dago Selatan No. 53A, Bandung	0101000020E61000008CB73AA5A8E75A402D382806ED7A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/184714612	\N
146	taman-tunas-kelapa-w185123551	Taman Tunas Kelapa	Fountain park located between LLRE Martadinata & Gandapura street. It has picnic benches,fountain and trees on both end of the park. Situated right across the lush green Taman Pramuka.	9	1	Jalan R.E. Martadinata	0101000020E6100000F3716DA818E85A400274A95B87A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185123551	\N
147	taman-balai-kota-bandung-w185126823	Taman Balai Kota Bandung	Lush green City park located within the compound of Balai Kota Bandung (Bandung City Hall). Integrated with Bandros shelter, Bandung City Tour on Bus.	9	1	Jalan Wastukencana, 2, Bandung	0101000020E6100000B0A998EF05E75A40A9482AF812A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185126823	\N
148	taman-foto-w185126847	Taman Foto	Local recreational park with meadow, and trees.	9	1	\N	0101000020E61000001ECF1DB322E85A40BE77E5C468A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185126847	\N
149	tugu-persib-w185127241	Tugu PERSIB	\N	9	1	\N	0101000020E6100000865FA05A33E75A408DD31055F8AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185127241	\N
150	taman-budaya-w185407983	Taman Budaya	\N	9	1	Bandung	0101000020E6100000F078495288E75A40579F6120BE7A1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185407983	\N
151	hutan-kota-babakan-siliwangi-w185442864	Hutan Kota Babakan Siliwangi	\N	9	1	Bandung	0101000020E61000000B66A77A0DE75A4047AE9B525E8B1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185442864	\N
152	taman-rw-13-w185930431	Taman RW 13	\N	9	1	\N	0101000020E61000005B441493B7E95A40C75BF80B87D71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185930431	\N
153	pemakaman-keluarga-w185934075	Pemakaman Keluarga	\N	11	1	\N	0101000020E6100000111EC8D523EA5A404892D6CEE6D71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/185934075	\N
154	taman-superhero-w243451182	Taman Superhero	\N	9	1	Bandung	0101000020E6100000A236BBFF59E85A4002E8418BB6A41BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/243451182	\N
155	gasmin-w244694107	Gasmin	\N	9	1	\N	0101000020E610000088ABB99253EA5A403A98A839D4AA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/244694107	\N
156	lapangan-cinta-w297868568	Lapangan Cinta	\N	9	1	\N	0101000020E610000019856E4015E75A40DA7C128E0F911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/297868568	\N
157	taman-ganesha-w297869547	Taman Ganesha	\N	9	1	Bandung	0101000020E6100000D900118711E75A408EB1135E82931BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/297869547	\N
158	lapangan-panggung-w303890876	Lapangan panggung	\N	9	1	\N	0101000020E6100000922AE510CCE65A4072B4F4B237921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/303890876	\N
159	rusa-tutul-w318932227	Rusa Tutul	\N	9	1	\N	0101000020E6100000E966DA59CFE65A40AFE364879D8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318932227	\N
160	betet-w318932228	Betet	\N	9	1	\N	0101000020E610000005EA831BDFE65A40AF71474959901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318932228	\N
161	kakaktua-raja-hitam-w318932229	Kakaktua Raja Hitam	\N	9	1	\N	0101000020E610000042565CC1DBE65A40B1BE26101B911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318932229	\N
162	kura-kura-w318932975	Kura - Kura	\N	9	1	\N	0101000020E610000047B1378CDDE65A4081542F641A921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318932975	\N
163	orang-utan-w318937147	Orang Utan	\N	9	1	\N	0101000020E6100000FF154383DEE65A40C6CF903BB68F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318937147	\N
164	kasuari-w318937148	Kasuari	\N	9	1	\N	0101000020E61000001019FB37D4E65A4017FB8161AF8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318937148	\N
165	koak-biru-w318937155	Koak Biru	\N	9	1	\N	0101000020E610000013D55B03DBE65A40275591C0D5901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/318937155	\N
166	taman-vanda-w321028422	Taman Vanda	\N	9	1	\N	0101000020E61000001EDA6C510BE75A40E6AB89AA04A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/321028422	\N
167	taman-pasopati-w327980246	Taman Pasopati	\N	9	1	Bandung	0101000020E61000000DE59F74FDE65A40385A1F20A9971BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/327980246	\N
168	taman-musik-centrum-w327985080	Taman Musik Centrum	\N	9	1	\N	0101000020E6100000EC037FAE6CE75A40827BF9F8DFA51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/327985080	\N
169	taman-film-w327986858	Taman Film	\N	9	1	\N	0101000020E610000014121F8EE4E65A4052D0926C1A981BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/327986858	\N
170	taman-skate-w340592887	Taman Skate	\N	9	1	\N	0101000020E6100000C4F5DECEF4E65A40E8908AB5AE971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/340592887	\N
171	taman-cibeunying-w342532165	Taman Cibeunying	\N	9	1	Bandung	0101000020E610000078921914F2E75A4042D13C80459E1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/342532165	\N
172	taman-kota-di-jalan-gempol-w376352112	Taman kota di jalan gempol	\N	9	1	Bandung	0101000020E61000000CB32B885CE75A4031708AD8719D1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/376352112	\N
173	tugu-soekarno-w376626831	Tugu Soekarno	\N	11	1	\N	0101000020E61000005DFC6D4F10E75A40F163CC5D4B901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/376626831	\N
174	parking-area-outdoor-w377400031	Parking Area Outdoor	\N	9	1	\N	0101000020E61000000927B38BB3E75A40F14520031E7D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/377400031	\N
175	taman-rumah-anggrek-w377559023	Taman Rumah Anggrek	\N	9	1	Bandung	0101000020E6100000A33B889DA9E75A40B70BCD751A791BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/377559023	\N
176	taman-fitness-w380223188	Taman Fitness	\N	9	1	Bandung	0101000020E610000077B17AD168E75A40138DA4935B911BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/380223188	\N
177	dago-north-pedestrian-1-w545984956	Dago North Pedestrian 1	\N	9	1	\N	0101000020E6100000675A07AC41E75A40A3B7D331428B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984956	\N
178	taman-cikapundung-riverside-w390192526	Taman Cikapundung Riverside	\N	9	1	\N	0101000020E610000059E02BBAF5E65A408EAACBCE47AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/390192526	\N
179	taman-teras-cikapundung-w409819040	Taman Teras Cikapundung	\N	9	1	\N	0101000020E6100000BB9866BAD7E65A407ADE8D0585891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/409819040	\N
180	taman-rajiman-w410281036	Taman Rajiman	\N	9	1	\N	0101000020E61000003E5EA3407AE65A40B85B9203769D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/410281036	\N
181	alun-alun-pinus-w413681134	Alun Alun Pinus	\N	9	1	\N	0101000020E6100000F4DCE79DAFEC5A401F46ADD5C3DC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/413681134	\N
182	gedung-denis-w421572126	Gedung DENIS	\N	11	1	Jalan Braga, Bandung	0101000020E6100000C83F33880FE75A40234FED670CAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421572126	\N
183	gereja-katedral-santo-petrus-bandung-w421614232	Gereja Katedral Santo Petrus Bandung	\N	11	1	\N	0101000020E6100000FB54BA6015E75A40295888B3C7A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/421614232	\N
184	trans-studio-bandung-w422236650	Trans Studio Bandung	\N	9	1	\N	0101000020E6100000FB1E9A1EB9E85A40372C5789C3B31BC0	\N	0	\N	\N	\N	\N	\N	https://www.transstudiobandung.com/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/422236650	\N
185	galeri-pusat-kebudayaan-w519673073	Galeri Pusat Kebudayaan	\N	11	1	Jalan Naripan, 7-9, Bandung	0101000020E61000009F7B6A500FE75A404EEFE2FDB8AD1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 10:00-18:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/519673073	\N
186	rabbit-town-w522949322	Rabbit Town	\N	9	1	Jalan Ranca Bentang, 30 - 32	0101000020E6100000FF72D2A00DE75A40CBAABEA9FE771BC0	\N	0	\N	\N	\N	{"osm": "Su 09:00-20:00; Mo-Sa 10:00-20:00"}	+622264404848	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/522949322	\N
187	amanda-brownies-parking-spot-w529801202	Amanda Brownies Parking spot	\N	9	1	\N	0101000020E6100000973AC8EB41E75A407533EDAC278C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/529801202	\N
188	museum-kota-bandung-w530035434	Museum Kota Bandung	\N	11	1	Jalan Aceh, 47, Kota Bandung	0101000020E6100000E6F6DC5303E75A40FA8678DAD0A31BC0	\N	0	\N	\N	\N	{"osm": "Tu-Su 10:00-17:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/530035434	\N
189	taman-saparua-w538094726	Taman Saparua	\N	9	1	Bandung	0101000020E61000007259E08673E75A40185B087250A21BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/538094726	\N
190	taman-maluku-w538094727	Taman Maluku	\N	9	1	Bandung	0101000020E61000006646E4605BE75A40F9765C9E18A31BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/538094727	\N
191	chinatown-bandung-w538800605	Chinatown Bandung	\N	9	1	Jalan Kelenteng, 41, Bandung	0101000020E6100000A97BAE00F0E55A4031105F8143AB1BC0	\N	0	\N	\N	\N	\N	+62 22 6038114	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/538800605	\N
192	taman-toka-tanaman-obat-kosmetik-dan-aromaterapi-w541314204	Taman TOKA (Tanaman Obat, Kosmetik dan Aromaterapi)	\N	9	1	\N	0101000020E6100000FB96395D16E75A40E380A7DAB88F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/541314204	\N
193	taman-parkir-umum-w545973406	Taman Parkir Umum	\N	9	1	\N	0101000020E61000006323B5F5F8E75A40418E9C3BB08A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545973406	\N
194	bumi-samami-w545973409	Bumi Samami	\N	9	1	Bandung	0101000020E6100000F33CB83BEBE75A40C6E9DACD42891BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 08:00-16:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545973409	\N
195	taman-binaan-lpm-w545984955	Taman Binaan LPM	\N	9	1	Bandung	0101000020E6100000D1A3F32B67E75A40FBE0C677738A1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984955	\N
196	dago-north-pedestrian-park-2-w545984960	Dago North Pedestrian Park 2	\N	9	1	\N	0101000020E6100000BCF4E5BB4AE75A4041727CFEC58D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984960	\N
197	dago-pedestrian-park-2-w545984961	Dago Pedestrian Park 2	\N	9	1	\N	0101000020E6100000596C938A46E75A407EA603FE95921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984961	\N
198	taman-kota-rth-tirtawening-w545984972	Taman Kota RTH Tirtawening	\N	9	1	Bandung	0101000020E61000007360DE8813E75A409BD4867945961BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984972	\N
199	taman-tugu-kb-w545984973	Taman Tugu KB	\N	9	1	Bandung	0101000020E6100000EE92DD71AFE65A405875560BEC891BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984973	\N
200	taman-hegarmanah-w545984974	Taman Hegarmanah	\N	9	1	\N	0101000020E6100000835F347568E65A408DE3D1D73D831BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/545984974	\N
201	taman-segitiga-dago-w546210764	Taman Segitiga Dago	\N	9	1	Bandung	0101000020E6100000BEE36FD63BE75A400D5531957E8A1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546210764	\N
202	taman-gasibu-w546640085	Taman Gasibu	\N	9	1	Bandung	0101000020E61000007753252598E75A40C86C7F1DEE991BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546640085	\N
203	taman-cibeunying-w546640087	Taman Cibeunying	\N	9	1	\N	0101000020E61000008D2F359DF8E75A40E3E71AC1219F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546640087	\N
204	taman-sejarah-w546640090	Taman Sejarah	\N	9	1	\N	0101000020E6100000B82231410DE75A401F5A756737A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/546640090	\N
205	ruang-terbuka-publik-rtp-itenas-w547802076	Ruang Terbuka Publik (RTP) Itenas	\N	9	1	\N	0101000020E610000036BE405AADE85A405E41E43E83971BC0	\N	0	\N	\N	\N	\N	\N	https://www.medcom.id/pendidikan/news-pendidikan/yKXqm64N-walkot-bandung-dorong-perguruan-tinggi-ikut-jejak-itenas-bikin-ruang-terbuka-publik	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/547802076	\N
206	taman-dinas-perpus-dan-arsip-bandung-w547914280	Taman Dinas Perpus dan Arsip Bandung	\N	9	1	\N	0101000020E610000065EFD64345E75A404A2AAE85B4A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/547914280	\N
207	taman-pusdai-w547922945	Taman PUSDAI	\N	9	1	\N	0101000020E610000063EDEF6C0FE85A4053646314BA991BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/547922945	\N
208	taman-sosiologi-w548307336	Taman Sosiologi	\N	9	1	\N	0101000020E61000001F5E7C76E5E75A40814FBD7F3D881BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548307336	\N
209	taman-teknik-sipil-w548325514	Taman Teknik Sipil	\N	9	1	\N	0101000020E6100000835D5ECA0AE75A402C7299E491911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325514	\N
210	lapangan-radar-w548325515	Lapangan Radar	\N	9	1	\N	0101000020E6100000CD237F30F0E65A4033A9FCC632901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325515	\N
211	taman-parkir-sipil-w548325516	Taman Parkir Sipil	\N	9	1	\N	0101000020E61000007FB1AD55F1E65A401935046CAC911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325516	\N
212	taman-masjid-salman-w548325519	Taman Masjid Salman	\N	9	1	\N	0101000020E61000006742380B20E75A4021A2E2491C931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325519	\N
213	kebun-botani-gku-barat-w548325521	Kebun Botani GKU Barat	\N	9	1	\N	0101000020E610000079C3C771F1E65A40C99FB998B08F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325521	\N
214	dpr-w548325522	DPR	Di Bawah Pohon RIndang	9	1	\N	0101000020E6100000523DE30C0FE75A40DE67A6C52A8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325522	\N
215	lapangan-barrac-w548325527	Lapangan Barrac	\N	9	1	\N	0101000020E6100000B94EC87322E75A40C315AB611A911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325527	\N
216	taman-planologi-w548325529	Taman Planologi	\N	9	1	\N	0101000020E6100000B75384E519E75A40DFFC868906911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325529	\N
217	taman-perminyakan-w548325545	Taman Perminyakan	\N	9	1	\N	0101000020E610000082D371EB24E75A4067D1E05BFD8D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325545	\N
218	lapangan-bioskop-kampus-w548325557	Lapangan Bioskop Kampus	\N	9	1	\N	0101000020E610000027D2472A1DE75A4077442A3174911BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548325557	\N
219	taman-lembah-tubagus-w548338829	Taman Lembah Tubagus	\N	9	1	\N	0101000020E6100000B9533A58FFE75A407BB0D69AF7891BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548338829	\N
220	fasum-sg-park-w548475475	Fasum SG Park	\N	9	1	Sutra Graha, Bandung	0101000020E610000093C08B63C9E75A40E6C9DA4BBFD11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548475475	\N
221	sg-park-w548475582	SG Park	\N	9	1	\N	0101000020E6100000FD95DFB3BFE75A407A2986F590D21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/548475582	\N
222	taman-rw-14-sadang-sari-w549277439	Taman RW 14 Sadang Sari	\N	9	1	\N	0101000020E6100000A9A10DC006E85A405204DD03198E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/549277439	\N
223	taman-lotus-w549279376	Taman Lotus	\N	9	1	\N	0101000020E6100000B33E8ADFB9E75A40C4AB51B417861BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/549279376	\N
224	taman-gamma-w550477281	Taman Gamma	\N	9	1	\N	0101000020E6100000443E9E4C12E85A40A583F57F0E831BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/550477281	\N
225	taman-ciwalk-w550629663	Taman Ciwalk	\N	9	1	\N	0101000020E6100000A9CDEE7FB6E65A400A43893B83931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/550629663	\N
226	taman-rumah-mode-w550633636	taman Rumah Mode	\N	9	1	\N	0101000020E610000081D1E5CD61E65A4058FC4BF7DF871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/550633636	\N
227	taman-eatboss-w550634187	Taman Eatboss	\N	9	1	\N	0101000020E61000003308628FBFE65A4045847F11347E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/550634187	\N
228	taman-salam-w551635068	Taman salam	\N	9	1	Bandung	0101000020E610000051E2CEE04AE85A402828452BF7A21BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/551635068	\N
229	taman-puskesmas-salam-w551635361	Taman Puskesmas Salam	\N	9	1	\N	0101000020E610000019D46D3F4FE85A405E013BEDDFA31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/551635361	\N
230	karang-setra-water-park-w553910796	Karang Setra Water Park	\N	9	1	\N	0101000020E6100000FCBC4E8F12E65A40A3F9ADE7B5831BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 08:00-20:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/553910796	\N
231	taman-veteran-w556263229	Taman Veteran	\N	9	1	\N	0101000020E6100000DFC0898D9EE75A400FF2D5E99BAF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/556263229	\N
232	taman-depan-porwitabes-w556308928	Taman Depan Porwitabes	\N	9	1	\N	0101000020E6100000BC46263B11E75A40C0A3D7B0F0A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/556308928	\N
233	taman-masjid-istiqomah-w556308937	Taman Masjid Istiqomah	\N	9	1	\N	0101000020E6100000692AD54FC9E75A406DB30CCC659E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/556308937	\N
234	alun-alun-cicendo-w557564409	Alun-Alun Cicendo	\N	9	1	\N	0101000020E6100000107A9164B1E55A40D1D5B1A5A2A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557564409	\N
235	taman-monumen-ktt-non-blok-w557564414	Taman Monumen KTT Non Blok	Taman yang didalamnya Terdapat monumen untuk memperingati diadakannya KTT Non Blok di Indonesia	9	1	Jalan Pajajaran, Bandung	0101000020E6100000B1A6B228ECE55A40B82BAA3418A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557564414	\N
236	taman-simpang-jalan-dr-cipto-jalan-pajajaran-w557564416	Taman simpang Jalan Dr. Cipto / Jalan Pajajaran	\N	9	1	\N	0101000020E61000009CE9149A5AE65A406FDF597160A01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557564416	\N
237	taman-cihapit-w557564431	Taman Cihapit	\N	9	1	Bandung	0101000020E61000004F649C75FCE75A40702DEE9AEB9F1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557564431	\N
238	taman-pandawa-w557567425	Taman Pandawa	\N	9	1	\N	0101000020E6100000925CFE43FAE55A40A379008BFCA21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557567425	\N
239	alun-alun-ujungberung-w557567426	Alun-alun Ujungberung	\N	9	1	\N	0101000020E61000000D7A257FE6EC5A40F11DEB98A9A71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557567426	\N
240	lapangan-rw-11-w557965293	Lapangan RW 11	\N	9	1	\N	0101000020E6100000F6D8F1BAD9E45A4082EBE5D253871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557965293	\N
241	taman-bermain-rw-11-w557965294	Taman Bermain RW 11	\N	9	1	\N	0101000020E610000051D43EC2D5E45A40D139E40BFF861BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/557965294	\N
242	emerald-towers-park-a-w558554788	Emerald Towers Park A	\N	9	1	\N	0101000020E61000005736BDD584EA5A4054CB31B495BA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558554788	\N
243	jne-parking-lot-w558554796	JNE Parking Lot	\N	9	1	\N	0101000020E6100000C04D90227CEA5A401D098F9147BB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558554796	\N
244	emerald-towers-parking-lot-a-w558554805	Emerald Towers Parking Lot A	\N	9	1	\N	0101000020E6100000F91F4F8182EA5A405BD2510E66BB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558554805	\N
245	emerald-towers-parking-lot-b-w558554808	Emerald Towers Parking Lot B	\N	9	1	\N	0101000020E6100000C7D1C19F86EA5A4022B193B025BA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558554808	\N
246	green-pedestrian-w558554827	Green Pedestrian	\N	9	1	\N	0101000020E6100000612E4E217CEA5A4069311DDF83BC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558554827	\N
247	sanggar-hurip-playground-w558556622	Sanggar Hurip Playground	\N	9	1	\N	0101000020E61000001E4E603AADEA5A40E46A64575ABE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/558556622	\N
248	taman-sidoluhur-w564995555	Taman Sidoluhur	\N	9	1	\N	0101000020E610000034F3E49A82E85A408C7049C44A931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/564995555	\N
249	taman-anak-tongkeng-w579485239	Taman Anak Tongkeng	\N	9	1	\N	0101000020E6100000491FA974E6E75A409E9B919CA7A51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/579485239	\N
250	peta-park-w622111127	Peta Park	\N	9	1	Bandung	0101000020E6100000E7B287ACA4E55A40E2C4FC8117BA1BC0	\N	0	\N	\N	\N	{"osm": "Tu-Su 07:00-15:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/622111127	\N
251	taman-bermain-w633755573	Taman Bermain	\N	9	1	Bandung	0101000020E61000006A6803B081E55A400FD0228040BC1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/633755573	\N
252	parahyangan-residence-pool-and-sky-garden-on-26th-floor-w635390760	Parahyangan Residence Pool and Sky Garden (on 26th floor)	\N	9	1	Jalan Ciumbuleuit, 125, Bandung	0101000020E610000094522BA798E65A40EA526D814E821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/635390760	\N
253	papandayan-tower-front-park-w642148336	Papandayan Tower Front Park	\N	9	1	\N	0101000020E61000007625B847A5E65A40A36CDB4136821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/642148336	\N
254	taman-w648346616	Taman	\N	9	1	\N	0101000020E61000001468661CD9E65A405633219C05901BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/648346616	\N
255	volleyball-field-rt-06-w648346712	Volleyball Field RT 06	\N	9	1	\N	0101000020E6100000AF1A95E5B5EC5A40F07F91E1C2A31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/648346712	\N
256	taman-w671794992	Taman	\N	9	1	Kel. Pasir Wangi	0101000020E610000028F04E3E3DED5A40B969D894D09A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/671794992	\N
257	museum-pendidikan-nasional-upi-w700628085	Museum Pendidikan Nasional UPI	\N	11	1	Jalan Dr. Setiabudi, 229, Bandung	0101000020E6100000F17E81C506E65A40E880C93269701BC0	\N	0	\N	\N	\N	{"osm": "Mo-Th 09:00-11:15, 12:30-15:00; Fr 09:00-11:00, 13:00-15:30"}	+6281321512052	https://museumpendidikannasional.upi.edu/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/700628085	\N
258	upi-park-w700639066	UPI Park	\N	9	1	\N	0101000020E61000006A5DB41119E65A405EBA490C02731BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/700639066	\N
259	taman-karang-taruna-w725194613	Taman Karang Taruna	\N	9	1	\N	0101000020E61000001B84B9DD4BE85A40A715F07C50A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/725194613	\N
260	gate-w725194614	Gate	\N	11	1	\N	0101000020E61000007FB9BB734DE85A409FDA2AD20EA91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/725194614	\N
263	taman-alifa-w734357299	Taman Alifa	\N	9	1	\N	0101000020E6100000EE04FBAF73E75A405F76F464A3C01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/734357299	\N
264	sekar-manis-park-w735089657	Sekar Manis Park	\N	9	1	\N	0101000020E6100000782C110338E85A40DF60B9EF62C31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/735089657	\N
265	menara-air-metro-w735114087	Menara Air Metro	\N	9	1	\N	0101000020E61000001620C0D8B1EA5A40F403B23275C21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/735114087	\N
266	taman-cikawao-w735115691	Taman Cikawao	\N	9	1	\N	0101000020E610000063BDACE43EE75A40F79AD48679B51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/735115691	\N
267	burangrang-triangle-park-w735116437	Burangrang Triangle Park	\N	9	1	\N	0101000020E6100000B86576CCAFE75A402C836A8313B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/735116437	\N
268	taman-setiabudhi-supermarket-w737501869	Taman Setiabudhi Supermarket	\N	9	1	\N	0101000020E610000089CC012780E65A40FE68931EE1871BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/737501869	\N
269	taman-saturnus-w737678927	Taman Saturnus	\N	9	1	\N	0101000020E6100000DAA1ABBE84EA5A404E68ED11C5CF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/737678927	\N
270	taman-depan-balai-sartika-w737682742	Taman Depan Balai Sartika	\N	9	1	\N	0101000020E6100000138BCEE8FDE75A409F27F96C78C51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/737682742	\N
271	taman-rw-10-kelurahan-turangga-w737683533	Taman RW 10 Kelurahan Turangga	\N	9	1	\N	0101000020E61000004AED45B41DE85A401997056E38BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/737683533	\N
272	taman-durma-w737684344	Taman Durma	\N	9	1	\N	0101000020E61000003A10487831E85A40A1AD39F6A2BC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/737684344	\N
273	taman-maung-bandung-w739778585	Taman Maung Bandung	\N	9	1	\N	0101000020E61000008175C185E1E65A405E2D776682A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/739778585	\N
274	taman-tank-w739781047	Taman Tank	\N	9	1	\N	0101000020E6100000775D09EE51E85A407D0ADBAA7FB31BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/739781047	\N
275	taman-pembauran-w741776050	Taman Pembauran	\N	9	1	\N	0101000020E61000005516855D14E75A40DBABEA4031C51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/741776050	\N
276	taman-kiarasari-vi-24-w749732420	Taman Kiarasari VI 24	\N	9	1	Jalan Kiarasari VI, 24, Kel. Margasari	0101000020E6100000069FE6E445E95A4058699C97D4CA1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/749732420	\N
277	taman-kiarasari-iv-w749732425	Taman Kiarasari IV	\N	9	1	Jalan Kiarasai IV, 12, Kel. Margasari	0101000020E610000080CDDEBE33E95A406E0FE7864BCB1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/749732425	\N
278	taman-kiarasari-utama-w749732427	Taman Kiarasari Utama	\N	9	1	\N	0101000020E6100000D269824D42E95A400048B76FFFCB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/749732427	\N
279	taman-kiarasari-permai-w749732428	Taman Kiarasari Permai	\N	9	1	Jalan Kiarasari Permai V, Kel. Margasari	0101000020E61000006DCDB11765E95A4059FD118601CB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/749732428	\N
280	taman-mini-endah-cicukang-w750181961	Taman Mini Endah Cicukang	\N	9	1	Jalan Cicukang, Kota Bandung	0101000020E610000091216C1DC1EB5A4008FB1B599EA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750181961	\N
281	taman-cicukang-w750184151	Taman Cicukang	\N	9	1	Jalan Cicukang, Kota Bandung	0101000020E6100000F97A08F4D3EB5A4001EB820BC3A11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750184151	\N
282	kiara-artha-park-w750190780	Kiara Artha Park	\N	9	1	Jalan Jakarta, Bandung	0101000020E61000009494AAA319E95A40DD5D6743FEA91BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 10:00-21:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750190780	\N
283	karangsetra-park-w750198490	Karangsetra park	\N	9	1	Bandung	0101000020E6100000173C968801E65A401491065CFC821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750198490	\N
284	museum-pendidikan-park-w750198977	Museum Pendidikan Park	\N	9	1	Bandung	0101000020E61000009D972FD406E65A4012EC095C68701BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750198977	\N
285	roeslan-abdul-gani-park-w750199502	Roeslan Abdul Gani Park	\N	9	1	Bandung	0101000020E6100000D6E1E82ADDE55A40DAD3C4F132711BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750199502	\N
286	masjid-attaqwa-park-w750200249	Masjid Attaqwa Park	\N	9	1	Bandung	0101000020E61000005708ABB184E55A40195932C7F2761BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750200249	\N
287	al-murabbi-park-w750206390	Al Murabbi Park	\N	9	1	Bandung	0101000020E61000004A8160E957E55A401610FF55EC841BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750206390	\N
288	jalur-hijau-cipaganti-w750207884	Jalur Hijau Cipaganti	\N	9	1	\N	0101000020E6100000A0F18E9D81E65A4004CEAD6B0F8E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750207884	\N
289	jalur-hijau-taman-sari-w750208197	Jalur hijau taman sari	\N	9	1	\N	0101000020E6100000A973FB9B06E75A4039A8B34934971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750208197	\N
290	taman-pkk-w750209307	Taman PKK	\N	9	1	Bandung	0101000020E6100000582B24AA01E85A4062C32EE5D79A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750209307	\N
291	simpay-asih-park-w750210743	Simpay asih Park	\N	9	1	Bandung	0101000020E610000056B549EA29EC5A4080BD1D3C6E9B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750210743	\N
292	taruna-parahyangan-park-w750210837	Taruna Parahyangan Park	\N	9	1	Bandung	0101000020E61000002547F07508EC5A40977B37CC869B1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750210837	\N
293	fcl-front-lobby-park-w750215078	FCL front lobby park	\N	9	1	Bandung	0101000020E6100000D0285DFA97E55A40E774B405DFB71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750215078	\N
294	batununggal-molek-park-w750218153	Batununggal Molek Park	\N	9	1	Bandung	0101000020E61000006987646D78E85A400C3ECDC98BD41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750218153	\N
295	arcamanik-tower-park-w750218798	Arcamanik Tower Park	\N	9	1	Bandung	0101000020E61000006971C63027EB5A408750A5660FAC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750218798	\N
296	taman-abah-toto-w750221930	Taman Abah Toto	\N	9	1	Bandung	0101000020E6100000C396C39302EC5A40B05582C5E1B41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750221930	\N
297	taman-bina-harapan-w750222268	Taman Bina Harapan	\N	9	1	Bandung	0101000020E6100000D4B25A05D6EB5A4006FF113C74A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750222268	\N
298	bina-harapan-park-w750222269	Bina Harapan Park	\N	9	1	Bandung	0101000020E6100000CECA51DBE1EB5A401247C3CEB9A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/750222269	\N
299	taman-indonesia-tenggelam-w752098472	Taman Indonesia Tenggelam	\N	9	1	\N	0101000020E6100000B68C8AEE0FE75A40942EA292DF8F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/752098472	\N
300	dago-atas-sideway-w753202019	Dago Atas Sideway	\N	9	1	\N	0101000020E6100000D3776D25AAE75A40302FC03E3A7D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753202019	\N
301	ddk-park-w753202021	DDK Park	\N	9	1	\N	0101000020E61000004D9539A7A3E75A40BAAB0D04B77C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753202021	\N
302	kemper-park-1-w753202022	Kemper Park 1	\N	9	1	\N	0101000020E61000003D563A69ABE75A4067ED5B525A7C1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753202022	\N
303	taman-pramuka-w753206626	Taman Pramuka	Park located on LLRE Martadinata street. Currently revamped and revitalized with two gates for entrance and exit. The lush green Taman Pramuka is popular among boy & girl scout.	9	1	Bandung	0101000020E61000002C161AE31EE85A409DD1FB6B1EA41BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753206626	\N
304	itb-green-pedestrian-w753210206	ITB Green Pedestrian	\N	9	1	\N	0101000020E61000000D8343B9FEE65A4072AD516A8A931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753210206	\N
305	salman-green-sideway-w753210207	Salman Green Sideway	\N	9	1	\N	0101000020E61000007F3FEBD01FE75A4091813CBB7C931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/753210207	\N
306	angkasa-garden-w834576868	Angkasa Garden	\N	9	1	\N	0101000020E6100000693FADFD78E95A4059B85109F4CE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/834576868	\N
307	amerta-garden-w834581158	Amerta Garden	\N	9	1	\N	0101000020E6100000A987687487E95A404E42E90B21C71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/834581158	\N
308	taman-caladi-w1052972734	Taman Caladi	\N	9	1	Bandung	0101000020E6100000B2A60DE2DEE75A40A703594FAD961BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1052972734	\N
309	thee-huis-gallery-w899798636	Thee Huis Gallery	\N	11	1	Jalan Bukit Dago Selatan No.53A, Bandung	0101000020E610000099F5BDE199E75A40F74F81DDFA7A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/899798636	\N
310	galeri-kamones-w899798638	Galeri Kamones	\N	11	1	Jl. Cigadung Raya Barat No.28A, Cigadung, Kec. Cibeunying Kaler, Kota Bandung, Jawa Barat 40191, Bandung	0101000020E610000035571701DFE75A4085573783647E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/899798638	\N
311	monumen-perjuangan-rakyat-jawa-barat-w934223108	Monumen Perjuangan Rakyat Jawa Barat	\N	11	1	Bandung	0101000020E6100000D7EE682D96E75A4016078662E1921BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/934223108	\N
312	taman-bea-cukai-w961785360	taman bea cukai	\N	9	1	Jalan Pasanggrahan lll, 33, Kel. Mekar Mulya	0101000020E6100000BCC73E6DF9EC5A40338AE59656B31BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961785360	\N
313	taman-pojok-tilu-tilu-w961785361	Taman Pojok Tilu Tilu	\N	9	1	Jalan Panghegar, no 33, Kel. Mekar Mulya	0101000020E6100000113D844C0DED5A4010525CFA3CB31BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961785361	\N
314	taman-rt02-w961785362	taman rt02	\N	9	1	Jalan Panghegar, 15, Kel. Mekar Mulya	0101000020E6100000EFC517EDF1EC5A4082B3EFE599B21BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961785362	\N
315	taman-rw-08-w961785363	Taman RW 08	\N	9	1	Jalan Panghegar, 10, Kel. Mekar Mulya	0101000020E6100000E4E02DEBD9EC5A40994B05700EB21BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961785363	\N
316	taman-rw-02-w961785364	Taman RW 02	\N	9	1	Jalan Pamekar, 10, Kel. Mekar Mulya	0101000020E6100000E09CB6EBCAEC5A403E3CF0D69EB61BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961785364	\N
317	taman-gunung-kareumbi-w961800092	Taman Gunung Kareumbi	\N	9	1	\N	0101000020E610000065C22FF5F3E65A4010C99063EB791BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961800092	\N
318	nara-park-w961800093	Nara Park	\N	9	1	\N	0101000020E61000004F81824108E75A40F61D0DF159781BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/961800093	\N
319	taman-tegalega-w990640380	Taman Tegalega	\N	9	1	\N	0101000020E61000002C843012B5E65A4095CC560339BD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/990640380	\N
320	laswi-heritage-w990640382	Laswi Heritage	\N	11	1	\N	0101000020E6100000D3382FA9B5E85A40B50710F406AE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/990640382	\N
321	taman-dr-slamet-w1052985430	Taman DR Slamet	\N	9	1	Bandung	0101000020E6100000465387269AE65A40CD672F91C1981BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1052985430	\N
322	taman-toga-saninten-w1061094553	Taman Toga Saninten	\N	9	1	Bandung	0101000020E6100000E02B5F3C28E85A40157FCAE7CBA11BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061094553	\N
323	rth-sempadan-jalan-citarum-w1061094555	RTH Sempadan Jalan Citarum	\N	9	1	Bandung	0101000020E6100000831F8B23C5E75A401BBEE02E569F1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061094555	\N
324	taman-magot-w1061406086	Taman Magot	\N	9	1	Bandung	0101000020E6100000BD642D4FB1E55A40091FA56D57BB1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061406086	\N
325	taman-bermain-anak-w1061406087	Taman Bermain Anak	\N	9	1	Bandung	0101000020E6100000937D46D8A6E55A40A224C918C4BC1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061406087	\N
326	taman-gasibu-w1061784121	Taman Gasibu	\N	9	1	Bandung	0101000020E6100000D644550298E75A4000080E1E5C981BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061784121	\N
327	taman-segitiga-w1061784122	Taman Segitiga	\N	9	1	Bandung	0101000020E6100000F41EC25323E75A40138E6A227D8C1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061784122	\N
328	taman-bagus-rangin-w1061784123	Taman Bagus Rangin	\N	9	1	Bandung	0101000020E6100000E36256397EE75A406C97361C96961BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061784123	\N
329	taman-monumen-perjuangan-w1061784124	Taman Monumen Perjuangan	\N	9	1	Bandung	0101000020E61000004EF454E295E75A40F3B116FABB921BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061784124	\N
330	taman-gesit-w1061784128	Taman Gesit	\N	9	1	Bandung	0101000020E6100000B122597677E75A406FC1AD1633951BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061784128	\N
331	taman-bermain-anak-w1061865620	Taman Bermain Anak	\N	9	1	Bandung	0101000020E6100000D7DEA7AAD0E65A401C9CE337E0961BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061865620	\N
332	taman-djuanda-w1061865621	Taman Djuanda	\N	9	1	Bandung	0101000020E61000004D011F72E9E65A405DE223BD039F1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061865621	\N
333	taman-w1061865622	Taman	\N	9	1	Bandung	0101000020E61000001F48DE3914E75A40FE48111956991BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061865622	\N
334	rth-kota-tirtawening-w1061948058	RTH Kota Tirtawening	\N	9	1	Bandung	0101000020E6100000569BFF571DE75A40855B3E9292961BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1061948058	\N
335	taman-kota-tegal-lega-w1144632064	Taman Kota Tegal Lega	\N	9	1	\N	0101000020E6100000A9A514CFB4E65A40EDF6B41E19BE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1144632064	\N
336	taman-rw-04-gelatik-dalam-w1062229853	Taman RW 04 Gelatik Dalam	\N	9	1	Bandung	0101000020E61000002D40DB6AD6E75A40EEF4392D2E941BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062229853	\N
337	rth-polman-w1062272275	RTH Polman	\N	9	1	Bandung	0101000020E61000007854466DACE75A4096FC998B09831BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272275	\N
338	rth-kanayakan-w1062272276	RTH KANAYAKAN	\N	9	1	Bandung	0101000020E6100000DF292ED8D7E75A40354EF9C6C6821BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272276	\N
339	rth-kanayakan-w1062272277	RTH KANAYAKAN	\N	9	1	Bandung	0101000020E610000016DEE522BEE75A40D8CA958B42841BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272277	\N
340	rth-dago-w1062272278	RTH DAGO	\N	9	1	Bandung	0101000020E6100000399A232BBFE75A40D20149D8B77B1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272278	\N
341	rth-itb-w1062272279	RTH ITB	\N	9	1	Bandung	0101000020E61000001C8645FB8EE75A40F23DC857A7771BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272279	\N
342	rth-komplek-w1062272280	RTH Komplek	\N	9	1	Bandung	0101000020E61000006157EE609FE55A400A7547B53EBB1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062272280	\N
343	taman-bukit-dago-w1062571886	Taman Bukit Dago	\N	9	1	Bandung	0101000020E6100000C79E3D97A9E75A40BA00EABC7C791BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062571886	\N
344	taman-masjid-yayasan-nurul-jamil-w1062571887	TAMAN MASJID YAYASAN NURUL JAMIL	\N	9	1	Bandung	0101000020E61000008906CEBE97E75A40028063CF9E7B1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062571887	\N
345	taman-rw-07-w1062571888	Taman RW 07	\N	9	1	Bandung	0101000020E6100000B83764A8AFE55A404F65074B2BC41BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062571888	\N
346	taman-rt-05-rw-09-w1062571889	Taman RT 05 RW 09	\N	9	1	Bandung	0101000020E6100000A96510C49EE55A40A0104B146BC21BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1062571889	\N
347	museum-wolff-schoemaker-preanger-w1124747887	Museum Wolff Schoemaker (Preanger)	\N	11	1	Jalan Asia Afrika, 81, Bandung	0101000020E6100000DA71C3EF26E75A4010960C5B0EAF1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 11:00-17:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1124747887	\N
348	museum-mandala-wangsit-siliwangi-w1124757470	Museum Mandala Wangsit Siliwangi	Army museum	11	1	Jalan Lembong, 38, Bandung	0101000020E6100000E0E0664C1CE75A40E063B0E254AB1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Th, Sa, Su 08:00-14:30; Fr 11:00-14:30"}	+62 22 4203393	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1124757470	\N
349	alun-alun-cempaka-w1145009388	Alun Alun Cempaka	\N	9	1	\N	0101000020E61000009A0645F380EC5A4066D185A28ADC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1145009388	\N
350	taman-shafira-pasir-biru-residence-w1160816333	Taman Shafira Pasir Biru Residence	\N	9	1	\N	0101000020E61000006583F1787FEE5A4022FE614B8FAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160816333	\N
351	taman-graha-cipadung-w1160817007	Taman Graha Cipadung	\N	9	1	\N	0101000020E6100000C2A4F8F804EE5A40A6A1A1DA3BAE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160817007	\N
352	taman-pelangi-graha-cipadung-w1160817223	Taman Pelangi Graha Cipadung	\N	9	1	\N	0101000020E61000005F2283810CEE5A4009C1AA7AF9AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160817223	\N
353	ruang-terbuka-masjid-manunggal-w1160817337	Ruang Terbuka Masjid Manunggal	\N	9	1	\N	0101000020E61000005424BAC216EE5A40AC30C73C3CAD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160817337	\N
354	area-rekreasi-komplek-manglayang-sari-w1160819004	Area Rekreasi Komplek Manglayang Sari	\N	9	1	\N	0101000020E6100000B8150CF846EE5A40A913D044D8A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160819004	\N
355	taman-refleksi-rw-13-w1160819041	Taman Refleksi RW 13	\N	9	1	\N	0101000020E6100000C37872F247EE5A400F1CE1FE6DA81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160819041	\N
356	alun-alun-kiara-asri-w1160950999	Alun Alun Kiara Asri	\N	9	1	\N	0101000020E61000006379FC83EDE95A40D77ED70C15B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160950999	\N
357	taman-lingkungan-gang-arum-w1160955037	Taman Lingkungan Gang Arum	\N	9	1	\N	0101000020E6100000397B0CFBE2E95A40DF89592F86B21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160955037	\N
358	taman-kantor-kecamatan-kiaracondong-w1160955290	Taman Kantor Kecamatan Kiaracondong	\N	9	1	\N	0101000020E6100000B6717ACDE1E95A40994B05700EB21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1160955290	\N
359	taman-rw-15-babakan-surabaya-w1161032426	Taman RW 15 Babakan Surabaya	\N	9	1	\N	0101000020E61000004BC0F91EBFE95A4015843CCCA8AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161032426	\N
360	taman-sempadan-sungai-babakan-surabaya-w1161032956	Taman Sempadan Sungai Babakan Surabaya	\N	9	1	\N	0101000020E6100000D0E2D6EE68E95A40A2027168DBAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161032956	\N
361	taman-komplek-perum-itt-w1161033656	Taman Komplek Perum ITT	\N	9	1	\N	0101000020E610000089CB965151E95A406B2E92D15CAA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161033656	\N
362	ruang-terbuka-w1161034215	Ruang Terbuka	\N	9	1	\N	0101000020E61000005DF2898656E95A40A49C798379A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161034215	\N
363	rth-sempadan-sungai-babakan-surabaya-w1161034727	RTH Sempadan Sungai Babakan Surabaya	\N	9	1	\N	0101000020E6100000B7E79E1A54E95A409649C3DFE5A81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161034727	\N
364	taman-dan-rekreasi-kiara-artha-park-w1161035243	Taman dan Rekreasi Kiara Artha Park	\N	9	1	\N	0101000020E610000053944BE317E95A4027A089B0E1A91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161035243	\N
365	taman-baksur-w1161036306	Taman Baksur	\N	9	1	\N	0101000020E6100000E92C0EC237E95A402B6D718DCFA41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161036306	\N
366	area-rekreasi-anak-puri-tirta-kencana-w1161042005	Area Rekreasi Anak Puri Tirta Kencana	\N	9	1	\N	0101000020E6100000F151DA76B5E95A40BD80A8458E9E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161042005	\N
367	taman-kurdi-w1161047265	Taman Kurdi	\N	9	1	\N	0101000020E61000009DFA9BABC1E65A40DCA62ECF39C61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161047265	\N
368	taman-lpm-womunity-w1161048762	Taman LPM WOMunity	\N	9	1	\N	0101000020E6100000E36E10AD95E65A4023E1D638F6BF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161048762	\N
369	taman-komplek-jati-permai-w1161050177	Taman Komplek Jati Permai	\N	9	1	\N	0101000020E610000021DB430C85E65A40918D51E806C41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161050177	\N
370	taman-terminal-tegalega-w1161051337	Taman Terminal Tegalega	\N	9	1	\N	0101000020E61000006C2409C295E65A4090C82D9C5ABC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161051337	\N
371	rth-pertigaan-jalan-astana-anyar-w1161053823	RTH Pertigaan Jalan Astana Anyar	\N	9	1	\N	0101000020E6100000EF0797E972E65A40B9B2FAD97EB81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161053823	\N
372	rth-jalan-pajagalan-w1161055224	RTH Jalan Pajagalan	\N	9	1	\N	0101000020E610000086A867E66EE65A405AD020AA95B61BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161055224	\N
373	taman-rw-w1161210836	Taman RW	\N	9	1	\N	0101000020E6100000A9F92AF958E75A40781FECB9F1AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161210836	\N
374	rth-sempadan-jalan-taman-citarum-w1161288754	RTH Sempadan Jalan Taman Citarum	\N	9	1	\N	0101000020E61000007BEB0D08BEE75A402B65BE28E69D1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161288754	\N
375	rth-sempadan-jalan-progo-w1161288777	RTH Sempadan Jalan Progo	\N	9	1	\N	0101000020E610000045A1C096B2E75A402980BD1D3C9E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161288777	\N
376	taman-lansia-w1161291496	Taman Lansia	\N	9	1	\N	0101000020E6100000BA50549165E85A403171F5AD20971BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161291496	\N
377	rth-w1161292638	RTH	\N	9	1	\N	0101000020E6100000E23FDD4081E85A400A4D124BCA951BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161292638	\N
378	taman-lingkungan-w1161294195	Taman Lingkungan	\N	9	1	\N	0101000020E61000006E7DA2FC6EE65A4049FA0F4471821BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161294195	\N
379	taman-cidadap-w1161294653	Taman Cidadap	\N	9	1	\N	0101000020E6100000F910548D5EE65A409F5D19AFD47E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161294653	\N
380	rth-bunderan-ciumbuleuit-w1161297086	RTH Bunderan Ciumbuleuit	\N	9	1	\N	0101000020E610000010520141CAE65A40F44F70B1A2761BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1161297086	\N
381	tugu-sister-city-bandung-petaling-jaya-w1193303182	Tugu Sister City Bandung - Petaling Jaya	\N	11	1	\N	0101000020E610000088EEFE1DF6E65A40F477A51B17A41BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1193303182	\N
382	bundaran-cibeureum-w1197847831	Bundaran Cibeureum	\N	9	1	\N	0101000020E610000055489E90C2E45A401442621635AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1197847831	\N
383	taman-sumringah-w1200653171	Taman Sumringah	\N	9	1	\N	0101000020E61000009EA51AAC6EEC5A40B361A81EC4D11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1200653171	\N
384	taman-hukum-w1303199215	Taman Hukum	\N	9	1	\N	0101000020E6100000FEAF84FFBEE65A40C778DED7927F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1303199215	\N
385	taman-tepi-kota-w1222527778	Taman Tepi Kota	\N	9	1	\N	0101000020E610000000BDBA74DDEA5A408CBB41B456A41BC0	\N	0	\N	\N	\N	{"osm": "Mo-Fr 11:00-20:00, Sa-Su 08:00-20:00"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1222527778	\N
386	taman-gantole-w1230842025	Taman Gantole	\N	9	1	\N	0101000020E6100000F5577ECFFEEA5A4050F003464DB21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1230842025	\N
387	local-field-w1230970262	Local Field	\N	9	1	\N	0101000020E6100000536463143AE75A401F251BB4FC851BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1230970262	\N
388	lapangan-segitiga-w1231033708	Lapangan Segitiga	\N	9	1	\N	0101000020E6100000F1506FA106E75A403F16478A6D771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1231033708	\N
389	taman-al-qolam-w1231034299	Taman Al Qolam	\N	9	1	\N	0101000020E6100000CD785BE9B5E65A40DD0143FBFD771BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1231034299	\N
390	kebun-seni-tani-w1231329820	Kebun Seni Tani	\N	9	1	\N	0101000020E610000015DD1F941CEB5A40692F473426B11BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1231329820	\N
391	taman-danau-tilu-w1243176756	Taman Danau Tilu	\N	9	1	\N	0101000020E6100000479E35898BEC5A402A977CA2A1D51BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1243176756	\N
392	lapangan-perumahan-al-islam-w1282745289	Lapangan Perumahan Al-Islam	\N	9	1	\N	0101000020E61000001B77949405EA5A4046D9B6836CCC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1282745289	\N
393	taman-kalkun-w1282745294	Taman Kalkun	\N	9	1	\N	0101000020E61000007D3F355E3AEA5A40413F9D3C76C91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1282745294	\N
394	taman-galaxy-w1282745295	Taman Galaxy	\N	9	1	\N	0101000020E6100000051901150EEA5A40CE95F727A7CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1282745295	\N
395	taman-inklusi-w1284642671	Taman Inklusi	\N	9	1	\N	0101000020E610000049DD297865E75A407B832F4CA6A21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1284642671	\N
396	taman-cisatu-w1299816104	Taman Cisatu	\N	9	1	\N	0101000020E61000000B2769FE98E65A40569E40D8297E1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1299816104	\N
397	plaza-pandang-w1301132302	Plaza Pandang	\N	9	1	\N	0101000020E610000011871167EAEC5A4077DDB64A0BCA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1301132302	\N
398	ruang-terbuka-publik-rtp-itenas-w1303184245	Ruang Terbuka Publik (RTP) Itenas	\N	9	1	\N	0101000020E61000003815A930B6E85A4047510C35AF971BC0	\N	0	\N	\N	\N	\N	\N	https://www.medcom.id/pendidikan/news-pendidikan/yKXqm64N-walkot-bandung-dorong-perguruan-tinggi-ikut-jejak-itenas-bikin-ruang-terbuka-publik	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1303184245	\N
399	taman-pohon-fisip-w1303199211	Taman Pohon FISIP	\N	9	1	\N	0101000020E6100000D734EF38C5E65A40331587D805801BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1303199211	\N
400	taman-rektorat-w1303199227	Taman Rektorat	\N	9	1	\N	0101000020E61000007522C154B3E65A4053F06F2B18801BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1303199227	\N
401	water-tower-oranye-w1303199228	Water Tower Oranye	\N	9	1	\N	0101000020E6100000E94317D4B7E65A40115C9B7C69801BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1303199228	\N
402	tulip-park-1-w1317357915	Tulip Park 1	\N	9	1	\N	0101000020E61000009E8C3BEF10ED5A40A2FF2FE8CEDD1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1317357915	\N
403	tulip-park-2-w1317358129	Tulip Park 2	\N	9	1	\N	0101000020E61000002033068CE4EC5A405A379490FEDD1BC0	\N	0	\N	\N	\N	{"osm": "24/7"}	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1317358129	\N
404	pohon-hukum-w1349368391	Pohon Hukum	\N	9	1	\N	0101000020E6100000F988F3CBBBE65A402F185C73477F1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1349368391	\N
405	lapangan-sd-sukaasih-atas-w1351095918	Lapangan SD Sukaasih Atas	\N	9	1	\N	0101000020E610000039C65FA4E1EB5A400A641B5D4A9A1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1351095918	\N
406	panghegar-waterboom-w1370426961	Panghegar Waterboom	\N	9	1	\N	0101000020E6100000D52E5C0CD4E75A408CD24AC6D6D81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1370426961	\N
407	museum-sri-baduga-w1370429558	Museum Sri Baduga	The museum features various items related with the province of┬áWest Java, such as┬áSundanese┬ácrafts, furnishings, geologic history, and natural diversity.	11	1	Jalan Peta, 185, Kota Bandung	0101000020E61000005402BDCBA0E65A4056C49F9740C01BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 08:00-15:00"}	+62 22 5210976	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1370429558	\N
408	kawasan-jalan-braga-w1381663440	Kawasan Jalan Braga	\N	9	1	\N	0101000020E6100000DD88DD2DFFE65A403FDAA447F8AB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1381663440	\N
409	banceuy-prison-museum-w1411443701	Banceuy Prison Museum	\N	11	1	\N	0101000020E6100000E5FD6E70D8E65A401FCA6141ABAD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1411443701	\N
410	museum-srihadi-soedarsono-w1431411339	Museum Srihadi Soedarsono	\N	11	1	\N	0101000020E6100000D1B6F52EB9E65A4088090F3FA47C1BC0	\N	0	\N	\N	\N	{"osm": "Mo-Su 10:00-17:00"}	\N	https://www.museumsrihadisoedarsono.com/	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1431411339	\N
411	taman-emily-barat-w1434554474	Taman Emily Barat	\N	9	1	\N	0101000020E6100000F349383EA4EC5A40DEB7109A13DA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1434554474	\N
412	taman-emily-tengah-w1434554482	Taman Emily Tengah	\N	9	1	\N	0101000020E61000002FFB75A7BBEC5A404561BC8B9CDA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1434554482	\N
413	taman-emily-timur-w1434554492	Taman Emily Timur	\N	9	1	\N	0101000020E61000005D209CAAD6EC5A40778368AD68DB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1434554492	\N
414	alun-alun-palem-w1434820033	Alun Alun Palem	\N	9	1	\N	0101000020E6100000E09CB6EBCAEC5A40A642E158BCDD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1434820033	\N
415	taman-derwati-w1436136153	Taman Derwati	\N	9	1	\N	0101000020E6100000DF1B430070EB5A40BD83E9C59ADB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1436136153	\N
416	taman-sub-07-sektor-22-sch-w1442741324	Taman Sub 07 Sektor 22 SCH	\N	9	1	\N	0101000020E6100000286B8AB699E55A40E9B6442E38931BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1442741324	\N
417	playground-cynthia-w1443175089	Playground Cynthia	\N	9	1	\N	0101000020E6100000AA0606B584EC5A404FB2D5E594D81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1443175089	\N
418	sawarga-courtyard-w1443187677	Sawarga Courtyard	\N	9	1	\N	0101000020E6100000A9B3A4EDA9EC5A4083047B0217D21BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1443187677	\N
419	taman-tulip-w1454960790	Taman Tulip	\N	9	1	\N	0101000020E6100000F5238FF1F2EC5A4067A329F16FDE1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1454960790	\N
420	taman-sehati-rw-09-w1462081924	Taman Sehati RW.09	\N	9	1	\N	0101000020E6100000C57D9A498AED5A4015D0FA4AD6C71BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1462081924	\N
421	taman-dirgantara-w1467055121	Taman Dirgantara	\N	9	1	\N	0101000020E6100000F3E505D847E35A40485D216239B81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1467055121	\N
422	taman-braga-w1475160334	Taman Braga	\N	9	1	\N	0101000020E61000007DC800F50BE75A40C8D11C59F9AD1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1475160334	\N
423	plaza-timur-w1489896474	Plaza Timur	\N	9	1	\N	0101000020E6100000E52DB2F828ED5A4078CD508138CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489896474	\N
424	taman-tematik-nabi-adam-w1489929123	Taman Tematik Nabi Adam	\N	9	1	\N	0101000020E6100000D042024617ED5A40B50AAC2D86CC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929123	\N
425	taman-tematik-nabi-yunus-w1489929124	Taman Tematik Nabi Yunus	\N	9	1	\N	0101000020E6100000F77D9301FBEC5A401C55979D8FCC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929124	\N
426	taman-tematik-nabi-ibrahim-w1489929125	Taman Tematik Nabi Ibrahim	\N	9	1	\N	0101000020E6100000BAA706F508ED5A4013020352ACCC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929125	\N
427	taman-tematik-nabi-nuh-w1489929126	Taman Tematik Nabi Nuh	\N	9	1	\N	0101000020E6100000590BFD5DE9EC5A40F0879FFF1ECC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929126	\N
428	taman-islam-w1489929127	Taman Islam	\N	9	1	\N	0101000020E6100000B6E10BEEE2EC5A400BCFF00B54CB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929127	\N
429	taman-tematik-nabi-isa-w1489929130	Taman Tematik Nabi Isa	\N	9	1	\N	0101000020E61000009B8AF95EE8EC5A4088AD8F3D31C91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1489929130	\N
430	lapangan-tenis-kawaluyaan-indah-w1491374784	Lapangan Tenis Kawaluyaan Indah	\N	9	1	\N	0101000020E6100000C768780E40EA5A40BC7C467DEDBC1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1491374784	\N
431	lapangan-sekolah-w1502723323	Lapangan Sekolah	\N	9	1	\N	0101000020E610000079211D1EC2ED5A40A8AC01A5FCAF1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1502723323	\N
432	jpl-jalan-braga-w1511658239	JPL Jalan Braga	\N	11	1	\N	0101000020E6100000F6BF12FEFBE65A408FC360FE0AA91BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1511658239	\N
433	taman-pandawa-w1513067561	Taman Pandawa	\N	9	1	\N	0101000020E610000071B092EA16EA5A403F40529F3FB01BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1513067561	\N
434	alun-alun-griya-caraka-w1515964637	Alun Alun Griya Caraka	\N	9	1	\N	0101000020E6100000CF4D9B711AEB5A407DF9AE528BBA1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1515964637	\N
435	taman-al-uhkuwah-w1558985258	Taman Al Uhkuwah	\N	9	1	\N	0101000020E61000003A1D6DC177ED5A40DED7929F9EC81BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1558985258	\N
436	taman-sumber-sari-w1559886641	Taman Sumber Sari	\N	9	1	\N	0101000020E6100000B37BF2B0D0E45A40D1DC54EE4FBB1BC0	\N	0	\N	\N	\N	\N	\N	\N	\N	f	\N	\N	t	2026-09-30 09:15:07.215981+00	2026-09-30 09:15:07.215981+00	\N	way/1559886641	\N
\.


--
-- Data for Name: provinces; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.provinces (id, name) FROM stdin;
1	Jawa Barat
\.


--
-- Data for Name: raw_scraped_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.raw_scraped_items (id, run_id, source_url, raw_payload, content_hash, status, scraped_at) FROM stdin;
73	1	https://www.openstreetmap.org/node/3809666546	{"id": 3809666546, "lat": -6.9329864, "lon": 107.625909, "tags": {"name": "Benua Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6b047c327910cfcb0d673cc96b67d03c1247c47b859aa7ea6ca41f8341a9d866	approved	2026-09-30 09:14:51.059384+00
1	1	https://www.openstreetmap.org/node/29391348	{"id": 29391348, "lat": -6.8862096, "lon": 107.5970895, "tags": {"name": "Hotel Sukajadi", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	867ffab3c78f11bf94b2aa7f577e13dd01480afe15f7f44a4edcf15b9ada6f28	approved	2026-09-30 09:14:51.059384+00
2	1	https://www.openstreetmap.org/node/29392374	{"id": 29392374, "lat": -6.9050087, "lon": 107.6009357, "tags": {"name": "Imperium", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	ca8891ecb9f41ece5ea03fb970c41857aee0cfda3fc9730b0bb84c5d99e375ef	approved	2026-09-30 09:14:51.059384+00
3	1	https://www.openstreetmap.org/node/32042016	{"id": 32042016, "lat": -6.8927539, "lon": 107.5841016, "tags": {"name": "Topaz", "tourism": "hotel", "created_by": "JOSM"}, "type": "node", "_source": "overpass_osm"}	bb2539eca0ae4d13559139b8c222dec3fb1e96579c1d00a4d17d80979beddec4	approved	2026-09-30 09:14:51.059384+00
4	1	https://www.openstreetmap.org/node/32520353	{"id": 32520353, "lat": -6.9213431, "lon": 107.611654, "tags": {"name": "Grand Hotel Preanger", "tourism": "hotel", "website": "https://aerowisatahotels.com/", "wikipedia": "nl:Grand Hotel Preanger", "addr:street": "Jalan Asia Afrika", "addr:housenumber": "81"}, "type": "node", "_source": "overpass_osm"}	9070c44229db8792aea9b83c770430cee7049e4d49068eb82181b68b1e4c25e8	approved	2026-09-30 09:14:51.059384+00
5	1	https://www.openstreetmap.org/node/479731735	{"id": 479731735, "lat": -6.8646342, "lon": 107.6090275, "tags": {"name": "Padma Hotel Bandung", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Rancabentang", "addr:postcode": "40142", "addr:housenumber": "#56-58"}, "type": "node", "_source": "overpass_osm"}	19741a68a30edb09e0628bdcf3ebc42b422c9da7b6e736b597b8d9da6673c5d9	approved	2026-09-30 09:14:51.059384+00
6	1	https://www.openstreetmap.org/node/479731737	{"id": 479731737, "lat": -6.8671861, "lon": 107.6062461, "tags": {"name": "Grha Ciumbuleuit Guest House", "tourism": "hotel", "website": "https://grhaciumbuleuitgh.com/", "addr:street": "Jalan Ciumbeuluit", "opening_hours": "24/7", "internet_access": "wlan"}, "type": "node", "_source": "overpass_osm"}	a3c24baeafecb19f8324d17dcf52f1a7654b1fb80c0dd0efd153e9427694b661	approved	2026-09-30 09:14:51.059384+00
7	1	https://www.openstreetmap.org/node/1013403364	{"id": 1013403364, "lat": -6.914874, "lon": 107.6024538, "tags": {"name": "Monumen Purwa Aswa Purba", "access": "yes", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	b1ad5ce0d7aff54083f0a5eaa2f4a8e06a3a26bcc0945621663f05128b561f0a	approved	2026-09-30 09:14:51.059384+00
8	1	https://www.openstreetmap.org/node/1013447614	{"id": 1013447614, "lat": -6.9131037, "lon": 107.6042599, "tags": {"name": "Arion Swiss Bell", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	7906853a8402c240bcd6d5ceab55d6ee78841c9f6579f9aa065cff47e694e3e7	approved	2026-09-30 09:14:51.059384+00
9	1	https://www.openstreetmap.org/node/1014721911	{"id": 1014721911, "lat": -6.9338478, "lon": 107.6049198, "tags": {"name": "Bandung Lautan Api", "name:en": "Bandung Sea of Fire", "tourism": "artwork", "historic": "monument", "wikidata": "Q2754428", "wikipedia": "en:Bandung Sea of Fire"}, "type": "node", "_source": "overpass_osm"}	ca656528c6e05fc67b38717d60f0666599520871e3753554d8afed3ae7514856	approved	2026-09-30 09:14:51.059384+00
10	1	https://www.openstreetmap.org/node/1099327692	{"id": 1099327692, "lat": -6.8708571, "lon": 107.6198065, "tags": {"name": "Jayakarta", "tourism": "hotel", "addr:street": "Ir. H Juanda"}, "type": "node", "_source": "overpass_osm"}	9f18bd17ee00055222cbeecc619eca3240b9f42637de42b19ac6ab90683f0a4a	approved	2026-09-30 09:14:51.059384+00
11	1	https://www.openstreetmap.org/node/1158819836	{"id": 1158819836, "lat": -6.9122725, "lon": 107.5976731, "tags": {"name": "Camerlang", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9706729c911cc7d24bd046361a281ae982c615cb31138824e04ca73ce47d67c8	approved	2026-09-30 09:14:51.059384+00
12	1	https://www.openstreetmap.org/node/1158819872	{"id": 1158819872, "lat": -6.9120915, "lon": 107.5984241, "tags": {"name": "Mutiara", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9d73c71acb89b32387974eda8ae72e796521896e2c3d1b50fdd749e6f1fd4f07	approved	2026-09-30 09:14:51.059384+00
13	1	https://www.openstreetmap.org/node/1212690953	{"id": 1212690953, "lat": -6.8820821, "lon": 107.5967445, "tags": {"name": "Edelweiss", "tourism": "hotel", "internet_access": "no"}, "type": "node", "_source": "overpass_osm"}	53f5f88bcf77a7b4f65d6ef677da0693d22c87274731deca8c2a8a61ccbce809	approved	2026-09-30 09:14:51.059384+00
14	1	https://www.openstreetmap.org/node/1342928043	{"id": 1342928043, "lat": -6.8889817, "lon": 107.6138659, "tags": {"name": "Hotel Patra Jasa", "tourism": "hotel", "check_date": "2026-03-07"}, "type": "node", "_source": "overpass_osm"}	89890d0e756256afd420ab161e92a378bc8accd13776ad32090e7344447ac1cc	approved	2026-09-30 09:14:51.059384+00
15	1	https://www.openstreetmap.org/node/1342944385	{"id": 1342944385, "lat": -6.90074, "lon": 107.6126245, "tags": {"name": "Hotel Utari", "tourism": "hotel", "check_date": "2025-12-13"}, "type": "node", "_source": "overpass_osm"}	bd43d9c1402e074045227eb9f31ef6f963d17763d1b47b28a4b5999cfec8e011	approved	2026-09-30 09:14:51.059384+00
16	1	https://www.openstreetmap.org/node/1342944393	{"id": 1342944393, "lat": -6.9028896, "lon": 107.6116316, "tags": {"name": "Hotel Karmila", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	63a42216bf3b3150005afb049f988cc789979417fe438fce10565e6f8e69f7ca	approved	2026-09-30 09:14:51.059384+00
17	1	https://www.openstreetmap.org/node/1342944408	{"id": 1342944408, "lat": -6.9061025, "lon": 107.6109516, "tags": {"name": "UTC Dago Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda", "addr:housenumber": "4"}, "type": "node", "_source": "overpass_osm"}	e4821c4ede886edd1edea3f4d7415f49a867b301aa8745e9153daf108f8b5339	approved	2026-09-30 09:14:51.059384+00
18	1	https://www.openstreetmap.org/node/1342948124	{"id": 1342948124, "lat": -6.907181, "lon": 107.616129, "tags": {"name": "Hotel Halmahera", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	a74dc3541821df68383e008c5eae1e80d85adf79d135b5080d0d885c2e13e2f0	approved	2026-09-30 09:14:51.059384+00
19	1	https://www.openstreetmap.org/node/1342948128	{"id": 1342948128, "lat": -6.9078607, "lon": 107.6130004, "tags": {"name": "Hotel Gandasari", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	631a681fdfbc75aa9ef879dfefb11017db6ae1ddbcd29ec919fc01a4fcde824f	approved	2026-09-30 09:14:51.059384+00
20	1	https://www.openstreetmap.org/node/1342970049	{"id": 1342970049, "lat": -6.9173595, "lon": 107.612419, "tags": {"name": "Hotel Royal Palace", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6b76640346db1c1069e7acfe271cb4c38b7c3c74ede038e02df331eff6d04c5b	approved	2026-09-30 09:14:51.059384+00
21	1	https://www.openstreetmap.org/node/1342970053	{"id": 1342970053, "lat": -6.9111142, "lon": 107.6107756, "tags": {"name": "Hotel Royal Merdeka", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	a621a08c84d5c04fb4049fb483b7afbd59b63ca996c266988a80a321a572e6bc	approved	2026-09-30 09:14:51.059384+00
22	1	https://www.openstreetmap.org/node/1381753562	{"id": 1381753562, "lat": -6.8743988, "lon": 107.6195436, "tags": {"fax": "+62 22 2500301", "name": "Sheraton Bandung Hotel & Towers", "email": "Reservationsbandung@sheraton.com", "phone": "+62 22 2500303", "rooms": "156", "tourism": "hotel", "website": "https://www.marriott.com/hotels/travel/bdosi-sheraton-bandung-hotel-and-towers/", "addr:city": "Bandung", "addr:street": "Jalan Ir. H. Juanda", "addr:postcode": "40135", "addr:housenumber": "390"}, "type": "node", "_source": "overpass_osm"}	adc19d2d3efe31be8cf31107a071cf23fd9e116dde15bf414aa8312483133868	approved	2026-09-30 09:14:51.059384+00
23	1	https://www.openstreetmap.org/node/1385463113	{"id": 1385463113, "lat": -6.8852449, "lon": 107.6195556, "tags": {"name": "Wisma Putri Pocut Baren", "tourism": "motel"}, "type": "node", "_source": "overpass_osm"}	942a8363ddba66b0f647b5e5fcc8b2078fed02f8ec5c9d36a7a15b5b180f4a18	approved	2026-09-30 09:14:51.059384+00
24	1	https://www.openstreetmap.org/node/1586233214	{"id": 1586233214, "lat": -6.8830236, "lon": 107.5800241, "tags": {"name": "Sari Ater Kamboti Bandung", "phone": "+62 222-011000", "tourism": "hotel", "website": "https://sariater-hotel.com/kamboti"}, "type": "node", "_source": "overpass_osm"}	32a1934d322541350504374f6704e190dc8a8a9f42e242ce512f5c4c956e7a1e	approved	2026-09-30 09:14:51.059384+00
25	1	https://www.openstreetmap.org/node/1587039078	{"id": 1587039078, "lat": -6.883156, "lon": 107.581017, "tags": {"name": "The Majesty Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Surya Sumantri"}, "type": "node", "_source": "overpass_osm"}	2a914f0a0c60d9b8b6f6bf65493993a420d8cb6c548e6d9a612d153c485db23c	approved	2026-09-30 09:14:51.059384+00
26	1	https://www.openstreetmap.org/node/1655564498	{"id": 1655564498, "lat": -6.8620761, "lon": 107.584846, "tags": {"name": "Provence", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	246f654da089db755a24fecaf520cbe6bb1f0eeb818809d5a9976947ac43b6fe	approved	2026-09-30 09:14:51.059384+00
27	1	https://www.openstreetmap.org/node/1700852205	{"id": 1700852205, "lat": -6.9215253, "lon": 107.6110228, "tags": {"name": "BDG 0", "historic": "memorial", "material": "concrete", "memorial": "stele", "inscription": "Monumen KM BDG 0+00"}, "type": "node", "_source": "overpass_osm"}	edbc4fdcf963ebbcf8f6299c7d8fd61e7909a76610678b40525ea8e6e2632f4a	approved	2026-09-30 09:14:51.059384+00
28	1	https://www.openstreetmap.org/node/1700853213	{"id": 1700853213, "lat": -6.9201876, "lon": 107.6014738, "tags": {"name": "Perdana Wisata", "tourism": "hotel", "website": "https://www.hotelperdanawisata.com/"}, "type": "node", "_source": "overpass_osm"}	b0eb0cd23d2fa95b6c3becef430b2919773d51f70b9d83226884a20faca89559	approved	2026-09-30 09:14:51.059384+00
29	1	https://www.openstreetmap.org/node/1706574395	{"id": 1706574395, "lat": -6.8976004, "lon": 107.6337287, "tags": {"name": "Hotel Agusta", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	3f118ca902315f4b7f744d9e792c1a1ad4bb894e2f6f1d5f1519ab9e145bb298	approved	2026-09-30 09:14:51.059384+00
30	1	https://www.openstreetmap.org/node/1706574396	{"id": 1706574396, "lat": -6.8979998, "lon": 107.6325164, "tags": {"name": "Hotel Yehezkiel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	429263efe976a3d3e28b29eba5ccf0025548e53b65e39324e210d0b3792316cf	approved	2026-09-30 09:14:51.059384+00
31	1	https://www.openstreetmap.org/node/1708180763	{"id": 1708180763, "lat": -6.898894, "lon": 107.5920439, "tags": {"name": "KNIL monument", "name:id": "Monumen KNIL", "historic": "memorial"}, "type": "node", "_source": "overpass_osm"}	24a05a8cac8ef200a7c8bc06cf3edd65b8148da4485ca7bb90f0817b0e4f959f	approved	2026-09-30 09:14:51.059384+00
32	1	https://www.openstreetmap.org/node/1785955514	{"id": 1785955514, "lat": -6.9037861, "lon": 107.6053253, "tags": {"name": "Hotel California", "tourism": "motel"}, "type": "node", "_source": "overpass_osm"}	9ca1145bb4037ba36832d8f7266519f2beee81456ccfda46b6d5bcd285271146	approved	2026-09-30 09:14:51.059384+00
33	1	https://www.openstreetmap.org/node/1788564509	{"id": 1788564509, "lat": -6.9013335, "lon": 107.5990484, "tags": {"name": "Otten Inn", "tourism": "motel"}, "type": "node", "_source": "overpass_osm"}	563db4fb31b57fe942d9edbe35020f6dfa1ccd79837a446f0031aa8ba0d0b6fe	approved	2026-09-30 09:14:51.059384+00
34	1	https://www.openstreetmap.org/node/1788564513	{"id": 1788564513, "lat": -6.9028932, "lon": 107.6007213, "tags": {"name": "Otten Ville Boutique Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	5f03bbd08281aab34f08beac7ae8dc53e1d319686966ee3fbe349253dee8d899	approved	2026-09-30 09:14:51.059384+00
35	1	https://www.openstreetmap.org/node/1801234292	{"id": 1801234292, "lat": -6.8840321, "lon": 107.6256947, "tags": {"name": "Bumi Bhandawa", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	aa72a102404e3c2687e3e0274b53141c8148423325e1ae39a9540dc0d78a8535	approved	2026-09-30 09:14:51.059384+00
36	1	https://www.openstreetmap.org/node/1823875695	{"id": 1823875695, "lat": -6.9056738, "lon": 107.6107164, "tags": {"name": "Monumen Perpamsi", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	fd3a2016eb49d6d30f40841650d53594a72cfa73931b77c2f8a01f742f886f50	approved	2026-09-30 09:14:51.059384+00
37	1	https://www.openstreetmap.org/node/1924435640	{"id": 1924435640, "lat": -6.8948421, "lon": 107.6049865, "tags": {"name": "Sensa", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8788a70ab276f8db6509af41dd2b5778739dd4382532a6046d4e7dc12dbd57c7	approved	2026-09-30 09:14:51.059384+00
38	1	https://www.openstreetmap.org/node/1924439599	{"id": 1924439599, "lat": -6.8964744, "lon": 107.6036507, "tags": {"name": "Aston Tropicana", "stars": "4", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d8c470e0cff503090b223699c1785804dbd441e4b06c0cf8bdaceda29507735c	approved	2026-09-30 09:14:51.059384+00
39	1	https://www.openstreetmap.org/node/1924439614	{"id": 1924439614, "lat": -6.896059, "lon": 107.6036829, "tags": {"name": "Fave", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	41c6d7416d1420313e5290efcfadde5d53d537ed8a1168ba004bf268ec84d869	approved	2026-09-30 09:14:51.059384+00
40	1	https://www.openstreetmap.org/node/2016397751	{"id": 2016397751, "lat": -6.8872528, "lon": 107.5839909, "tags": {"name": "Cherry Homes", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8b6d27a71f4d28335f45fb351dfa3fb8d25e2719dd8daca0451b8390c68bab96	approved	2026-09-30 09:14:51.059384+00
41	1	https://www.openstreetmap.org/node/2039449490	{"id": 2039449490, "lat": -6.8682763, "lon": 107.5852847, "tags": {"name": "Hotel Gegerkalong Asri", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	a37d38ec81e953ae593f40912e9c31ac71a0a7b1223c2613388cda3c1302e990	approved	2026-09-30 09:14:51.059384+00
42	1	https://www.openstreetmap.org/node/2490687089	{"id": 2490687089, "lat": -6.9231465, "lon": 107.6237011, "tags": {"name": "Papandayan", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	5692a9a47781353002a2d1c22ca4e149e3edcf2c7a070aa15367983b4295d27f	approved	2026-09-30 09:14:51.059384+00
43	1	https://www.openstreetmap.org/node/2494627703	{"id": 2494627703, "lat": -6.9498041, "lon": 107.6280034, "tags": {"name": "Parakan Wangi", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	34b3cb09f1b4fbfe557f347df0bd6fd49095e7d7e3c06d84b128f7fec9a82acb	approved	2026-09-30 09:14:51.059384+00
44	1	https://www.openstreetmap.org/node/2494655270	{"id": 2494655270, "lat": -6.9077241, "lon": 107.6129293, "tags": {"name": "The Summit Siliwangi", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	16d7610d8a1e8744364884d681f9ef2694c4f631b442ef5827c8149f982be5a4	approved	2026-09-30 09:14:51.059384+00
45	1	https://www.openstreetmap.org/node/2500454839	{"id": 2500454839, "lat": -6.9005172, "lon": 107.5921261, "tags": {"name": "Graf van de onbekende soldaat en onbekende burger", "historic": "memorial", "architect": "A.W.  Gmelig Meyling", "inscription": "Opgericht ter gedachtenis aan hen die vielen als offer in de strijd om vrede en recht"}, "type": "node", "_source": "overpass_osm"}	0a01d796ffcc4df4fe8881f89bec3dab35b2c8468d8f2fe8c84d7c019b5865fe	approved	2026-09-30 09:14:51.059384+00
46	1	https://www.openstreetmap.org/node/3105373529	{"id": 3105373529, "lat": -6.9148648, "lon": 107.6178088, "tags": {"name": "Meize Hotel - Jl. Sumbawa", "phone": "+62 22 426 3888", "tourism": "hotel", "website": "https://www.meizehotel.com/", "addr:city": "Bandung", "addr:street": "Sumbawa", "addr:postcode": "40113", "addr:housenumber": "7"}, "type": "node", "_source": "overpass_osm"}	b3316923fa1d989457621e85f524fb806d48e66198d57e2911adec93c5827363	approved	2026-09-30 09:14:51.059384+00
47	1	https://www.openstreetmap.org/node/3128774234	{"id": 3128774234, "lat": -6.9067721, "lon": 107.5873489, "tags": {"name": "Husein Sastranegana", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	b0755945232564ce8f816f2f1a494594b9bc4a975a79c31a156415c79a83df72	approved	2026-09-30 09:14:51.059384+00
48	1	https://www.openstreetmap.org/node/3269202627	{"id": 3269202627, "lat": -6.899096, "lon": 107.6415674, "tags": {"name": "Park Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8c29e33bf652845786ca43811a1aef1ad75c0cf4764a96979f1558d7be9f6f39	approved	2026-09-30 09:14:51.059384+00
49	1	https://www.openstreetmap.org/node/3348067546	{"id": 3348067546, "lat": -6.9314629, "lon": 107.6024885, "tags": {"name": "Rumah Bersejarah Inggit Garnasih", "tourism": "museum", "addr:street": "Jalan Inggit Ganarsih", "description": "Museum about Sukarno's ex-wife", "opening_hours": "Mo-Su 07:00-16:00", "addr:housenumber": "8"}, "type": "node", "_source": "overpass_osm"}	d01833396039df8ea2ff2bc3ca21003916ff90800b8ef62c241ba366bc1b8c48	approved	2026-09-30 09:14:51.059384+00
50	1	https://www.openstreetmap.org/node/3348122792	{"id": 3348122792, "lat": -6.922361, "lon": 107.6177074, "tags": {"name": "Monumen Konferensi Asia Afrika", "name:en": "Asian-African Conference Monument", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	832d4d681d4e3e086491e1a7854de04d060b35c8da63a558e8eec31d1d59b042	approved	2026-09-30 09:14:51.059384+00
51	1	https://www.openstreetmap.org/node/3348123493	{"id": 3348123493, "lat": -6.9227976, "lon": 107.6198103, "tags": {"name": "Monumen Tank Baja", "name:en": "Tank Monument", "historic": "tank"}, "type": "node", "_source": "overpass_osm"}	dc82aa8d1d61b36fae9af54e57b6c454b3498616c7c7baaf9fde19014e5962af	approved	2026-09-30 09:14:51.059384+00
52	1	https://www.openstreetmap.org/node/3348135338	{"id": 3348135338, "lat": -6.9191554, "lon": 107.6077252, "tags": {"name": "Monumen Penjara Bung Karno", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	27d0718a94b4f89af2a5df1f8087b4193d55ba60b98f91bfcfb4b9437684b784	approved	2026-09-30 09:14:51.059384+00
53	1	https://www.openstreetmap.org/node/3348140433	{"id": 3348140433, "lat": -6.9150735, "lon": 107.606867, "tags": {"name": "Monumen Laskar Wanita", "historic": "memorial", "memorial": "war_memorial"}, "type": "node", "_source": "overpass_osm"}	0723566b2d22ed6160b54801b83994952b642fba21ab6f2c6b2c9f6e2e36c749	approved	2026-09-30 09:14:51.059384+00
54	1	https://www.openstreetmap.org/node/3348140434	{"id": 3348140434, "lat": -6.9147727, "lon": 107.6070197, "tags": {"name": "Monumen Tentara Pelajar", "historic": "memorial", "memorial": "war_memorial"}, "type": "node", "_source": "overpass_osm"}	b945f51d3c8757eda9d079d54690bbb6b33a0b5a13c96a8ff80be4a8b1e61106	approved	2026-09-30 09:14:51.059384+00
55	1	https://www.openstreetmap.org/node/3353575236	{"id": 3353575236, "lat": -6.8545699, "lon": 107.5950633, "tags": {"name": "Mercure Bandung Setiabudi", "brand": "Mercure", "tourism": "hotel", "addr:street": "Jl Dr Setiabudi", "addr:postcode": "40154", "brand:wikidata": "Q1709809", "brand:wikipedia": "en:Mercure (hotel)", "addr:housenumber": "269-275"}, "type": "node", "_source": "overpass_osm"}	e802d33dd9051582a6462b2b062b804132ef7d4caf45866da7ec713eb1b4674b	approved	2026-09-30 09:14:51.059384+00
56	1	https://www.openstreetmap.org/node/3365192832	{"id": 3365192832, "lat": -6.8891571, "lon": 107.5821297, "tags": {"name": "Verona Palace Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Surya Sumantri"}, "type": "node", "_source": "overpass_osm"}	c118147fee1c9a6444d87ccab67210f3f170cb6ac5c718498c0d90fa5003975f	approved	2026-09-30 09:14:51.059384+00
57	1	https://www.openstreetmap.org/node/3376282081	{"id": 3376282081, "lat": -6.93168, "lon": 107.6178928, "tags": {"name": "Sofyan Inn Specia", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Buah Batu", "addr:postcode": "40262", "addr:housenumber": "31"}, "type": "node", "_source": "overpass_osm"}	81d7b1089f0e0e42e2392ddaa1926d1ad796b6db3b1fe077eaa481c712547515	approved	2026-09-30 09:14:51.059384+00
58	1	https://www.openstreetmap.org/node/3376673101	{"id": 3376673101, "lat": -6.8736729, "lon": 107.5956727, "tags": {"ref": "Setiabudhi", "name": "Amaris Hotel Setiabudhi", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40153", "addr:housenumber": "156A"}, "type": "node", "_source": "overpass_osm"}	4b488eaf55007fc80f6749353cadaded292122a4cc5642fd4aa037c34143f123	approved	2026-09-30 09:14:51.059384+00
59	1	https://www.openstreetmap.org/node/3376756789	{"id": 3376756789, "lat": -6.8853338, "lon": 107.6163121, "tags": {"name": "Wisma Tubagus", "tourism": "guest_house"}, "type": "node", "_source": "overpass_osm"}	1799fef236a031be006b0f286574e849454daa428d8e5cdcf5ed5536de20dc22	approved	2026-09-30 09:14:51.059384+00
60	1	https://www.openstreetmap.org/node/3405488095	{"id": 3405488095, "lat": -6.8850077, "lon": 107.5833177, "tags": {"name": "SM Residence Pasteur", "smoking": "outside", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Babakan Jeruk Indah", "addr:postcode": "40163", "addr:housenumber": "1 / 11"}, "type": "node", "_source": "overpass_osm"}	17da634cafeb2e11e38b533181dacb87403efb29269144464750a3dfa9f5824c	approved	2026-09-30 09:14:51.059384+00
61	1	https://www.openstreetmap.org/node/3424716226	{"id": 3424716226, "lat": -6.9008276, "lon": 107.5980564, "tags": {"name": "Vio Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	260792c522217ad1ba95597f06426ee43ee449d48ce4ac6f56e18ad776ee1436	approved	2026-09-30 09:14:51.059384+00
62	1	https://www.openstreetmap.org/node/3431378604	{"id": 3431378604, "lat": -6.921634, "lon": 107.605588, "tags": {"name": "Makam Pendiri Kota Bandung", "historic": "tomb"}, "type": "node", "_source": "overpass_osm"}	736d2065673a5a77297b245653d6bcf33477fd73755a5d41146709418aa2dd9e	approved	2026-09-30 09:14:51.059384+00
63	1	https://www.openstreetmap.org/node/3434620514	{"id": 3434620514, "lat": -6.9272101, "lon": 107.6132187, "tags": {"name": "Machine gun", "historic": "memorial", "memorial": "war_memorial"}, "type": "node", "_source": "overpass_osm"}	6b37a302a5c486b8957eb1eec13c18463de77152253bbaf4ee0ce4faf451101e	approved	2026-09-30 09:14:51.059384+00
64	1	https://www.openstreetmap.org/node/3436699526	{"id": 3436699526, "lat": -6.9003506, "lon": 107.6175514, "tags": {"name": "Pullman", "brand": "Pullman", "stars": "5", "tourism": "hotel", "brand:wikidata": "Q3410757"}, "type": "node", "_source": "overpass_osm"}	37185b822bc67d32d62af7434710afde087f6243ccc3e79197d567e2c023e2e0	approved	2026-09-30 09:14:51.059384+00
65	1	https://www.openstreetmap.org/node/3506203980	{"id": 3506203980, "lat": -6.9367875, "lon": 107.5934789, "tags": {"name": "Grand Pasundan Convention Hotel", "smoking": "outside", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "PETA"}, "type": "node", "_source": "overpass_osm"}	ea2d981988559ca9341660d86efa0bc1348373ce4794ef1ee71f79fa41523c6c	approved	2026-09-30 09:14:51.059384+00
66	1	https://www.openstreetmap.org/node/3733193725	{"id": 3733193725, "lat": -6.911422, "lon": 107.601762, "tags": {"atm": "no", "name": "Patradissa", "source": "survey", "name:en": "Patradissa Hotel", "tourism": "hotel", "official_name": "Hotel Patradissa", "internet_access": "wlan"}, "type": "node", "_source": "overpass_osm"}	8f72c871dce622f1d7a2d044dbbf16e2a70405f18359104f699fc37488a71999	approved	2026-09-30 09:14:51.059384+00
67	1	https://www.openstreetmap.org/node/3754824465	{"id": 3754824465, "lat": -6.9174718, "lon": 107.6062699, "tags": {"name": "Kopi Aroma", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	17ffca59539c7793e9b533c41a68a9aad7d5199990b6e6abd1f288e509e1ac3c	approved	2026-09-30 09:14:51.059384+00
68	1	https://www.openstreetmap.org/node/3807724904	{"id": 3807724904, "lat": -6.8737345, "lon": 107.6195926, "tags": {"name": "The Silk At Dago", "name:en": "The Silk", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Ir. H. Juanda", "addr:postcode": "40135", "addr:housenumber": "392-394"}, "type": "node", "_source": "overpass_osm"}	3cfaa267e3d3dc05636b66ddf0d9e04cf4abacdc6e58c6256e37940cea44e681	approved	2026-09-30 09:14:51.059384+00
69	1	https://www.openstreetmap.org/node/3807746630	{"id": 3807746630, "lat": -6.8713763, "lon": 107.6203726, "tags": {"name": "Puri Tomat", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	405e021dd3acfbd40a9ee7d04489529162f621262d3db91a088d8068e4c3c204	approved	2026-09-30 09:14:51.059384+00
70	1	https://www.openstreetmap.org/node/3809369307	{"id": 3809369307, "lat": -6.868279, "lon": 107.6204483, "tags": {"name": "Balai Pengelolaan Taman Budaya", "historic": "memorial"}, "type": "node", "_source": "overpass_osm"}	9724461f12cbaeccf651f88c8fa3a245e4e12345ea44698757aa3ed58006fb25	approved	2026-09-30 09:14:51.059384+00
71	1	https://www.openstreetmap.org/node/3809369314	{"id": 3809369314, "lat": -6.8714219, "lon": 107.6197149, "tags": {"name": "Kementerian Pertanian MESS/GUEST House", "tourism": "guest_house"}, "type": "node", "_source": "overpass_osm"}	d2215ec1d30e116fe5077a85cfef4c8cf5ccafd390ab839f170cb6a59ae92579	approved	2026-09-30 09:14:51.059384+00
72	1	https://www.openstreetmap.org/node/3809369329	{"id": 3809369329, "lat": -6.8691116, "lon": 107.6201773, "tags": {"name": "Wirton Dago Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	7bebda0dbaff152e623d9c737499471b1827efe063e453e0fbf7569ded286ea1	approved	2026-09-30 09:14:51.059384+00
74	1	https://www.openstreetmap.org/node/3809732416	{"id": 3809732416, "lat": -6.9319557, "lon": 107.6064828, "tags": {"name": "Bantal Guling Alun Alun", "phone": "+62224211425", "tourism": "guest_house", "check_date": "2025-12-25"}, "type": "node", "_source": "overpass_osm"}	56e061d8d56ca848c064ededcc38e31d615a43f27ccf58e51f4b0edd080719df	approved	2026-09-30 09:14:51.059384+00
75	1	https://www.openstreetmap.org/node/3817206785	{"id": 3817206785, "lat": -6.9252972, "lon": 107.6299873, "tags": {"name": "Panhard EBR FL-11", "historic": "tank", "start_date": "1950", "description": "Panhard EBR FL-11"}, "type": "node", "_source": "overpass_osm"}	dec2b31ff5e6fa230d4e0eaffa70be4cca5cfb5c2f41fe6f20dfb5eb8b212af4	approved	2026-09-30 09:14:51.059384+00
76	1	https://www.openstreetmap.org/node/4143034493	{"id": 4143034493, "lat": -6.9375417, "lon": 107.6819337, "tags": {"name": "Panoramic", "name:en": "Panoramic Apartment", "tourism": "apartment", "building": "apartments", "addr:street": "Jalan Soekarno Hatta"}, "type": "node", "_source": "overpass_osm"}	33925388c4aedae8e48ea2c38c7affe7e56b835d26b4f7c539379f4fd0c74a49	approved	2026-09-30 09:14:51.059384+00
77	1	https://www.openstreetmap.org/node/4143034494	{"id": 4143034494, "lat": -6.9407736, "lon": 107.6555103, "tags": {"name": "HOTEL METRO", "tourism": "hotel", "addr:street": "Jalan Soekarno-Hatta"}, "type": "node", "_source": "overpass_osm"}	a15efa2f1cf86212ffba19706bf7f162170239e7a093253fd67904a1240fdf2e	approved	2026-09-30 09:14:51.059384+00
78	1	https://www.openstreetmap.org/node/4150284489	{"id": 4150284489, "lat": -6.9231252, "lon": 107.6117327, "tags": {"name": "Hotel Lengkong", "tourism": "hotel", "addr:street": "Jalan Lengkong Besar"}, "type": "node", "_source": "overpass_osm"}	ac4a62478bde4905653b9748cfdea9cc3bd27743c1f7e814abeca9e30b9020c9	approved	2026-09-30 09:14:51.059384+00
79	1	https://www.openstreetmap.org/node/4263828828	{"id": 4263828828, "lat": -6.8825827, "lon": 107.6005351, "tags": {"name": "Regata Hotel", "tourism": "hotel", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40154", "addr:housenumber": "35"}, "type": "node", "_source": "overpass_osm"}	97380373e6c25be7cc829fc34682e40a905a6f4bc1e28979bafc53f7102f50b4	approved	2026-09-30 09:14:51.059384+00
80	1	https://www.openstreetmap.org/node/4267738966	{"id": 4267738966, "lat": -6.8493085, "lon": 107.5984922, "tags": {"name": "GH Universal Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40143", "addr:housenumber": "#376"}, "type": "node", "_source": "overpass_osm"}	24b4fa3a6c0658c9275251ed1aecf70bc37254c4d9f48ded351a88f6158f13ae	approved	2026-09-30 09:14:51.059384+00
81	1	https://www.openstreetmap.org/node/4288729690	{"id": 4288729690, "lat": -6.9160701, "lon": 107.6019399, "tags": {"name": "Fabu Hotel Bandung", "tourism": "hotel", "addr:street": "Jalan Kebon Jati", "addr:postcode": "40181", "internet_access": "wlan", "addr:housenumber": "32"}, "type": "node", "_source": "overpass_osm"}	10e520999fa08b4247f69ec4556ca475c3ebe0616ae4ce308056a1734f8d264d	approved	2026-09-30 09:14:51.059384+00
82	1	https://www.openstreetmap.org/node/4320694456	{"id": 4320694456, "lat": -6.9145034, "lon": 107.6297365, "tags": {"name": "Bandung Hostel", "cuisine": "Seafood_Restaurant", "tourism": "hostel", "addr:city": "bandung, Jawa Barat", "addr:street": "Jalan Laksamana Laut RE Martadinata", "addr:housenumber": "217"}, "type": "node", "_source": "overpass_osm"}	c0b6f6dc2cb69be9b6c935cde3d61aafcfe6cc04452eee5767c651b1136ca6eb	approved	2026-09-30 09:14:51.059384+00
83	1	https://www.openstreetmap.org/node/4326502122	{"id": 4326502122, "lat": -6.9123077, "lon": 107.5994831, "tags": {"name": "Zodiak", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Kebon Kawung, Pasir Kaliki, Cicendo", "addr:housenumber": "#54"}, "type": "node", "_source": "overpass_osm"}	95fdd5b6560d4704c44bf41688545a3e09134fa4e78729cfff8f1a63a1f183a8	approved	2026-09-30 09:14:51.059384+00
84	1	https://www.openstreetmap.org/node/4326512398	{"id": 4326512398, "lat": -6.9118697, "lon": 107.6024868, "tags": {"name": "Serena Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Marjuk , Kebon Kawung", "addr:housenumber": "4-6"}, "type": "node", "_source": "overpass_osm"}	a26140824480c95189e7116f4ff8a12aaa51012decf9a43373b09c17fee4cfa2	approved	2026-09-30 09:14:51.059384+00
85	1	https://www.openstreetmap.org/node/4326513914	{"id": 4326513914, "lat": -6.912469, "lon": 107.602934, "tags": {"name": "Grand Sovia Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Kebon Kawung , Pasirkaliki, Cicendo", "addr:housenumber": "16"}, "type": "node", "_source": "overpass_osm"}	f47f155b5fdd097e3e7fdf1fe83ba974f7b9e88e3945062926d943324353aab3	approved	2026-09-30 09:14:51.059384+00
86	1	https://www.openstreetmap.org/node/4327194341	{"id": 4327194341, "lat": -6.8772867, "lon": 107.6039296, "tags": {"name": "Parahyangan Residences", "tourism": "guest_house", "addr:city": "Bandung", "addr:street": "Jl. Ciumbuleuit, Hegarmanah"}, "type": "node", "_source": "overpass_osm"}	7108bc9e40367d40290600af5ea646cb8270af8da0e8aefb2dc860fef7264c10	approved	2026-09-30 09:14:51.059384+00
87	1	https://www.openstreetmap.org/node/4327220812	{"id": 4327220812, "lat": -6.8724159, "lon": 107.6059173, "tags": {"name": "U Village Hotel and Villa", "tourism": "motel", "addr:city": "Bandung", "addr:street": "Jalan Bukit Tunggul, Ciumbuleuit, Cidadap", "addr:housenumber": "8"}, "type": "node", "_source": "overpass_osm"}	086ebe24149e69726bf130ee02d53df92dd26d8baf7e9fa767f1d1d31b256d41	approved	2026-09-30 09:14:51.059384+00
88	1	https://www.openstreetmap.org/node/4328071039	{"id": 4328071039, "lat": -6.9120462, "lon": 107.5966492, "tags": {"name": "Summerbird - Bed and Brasserie", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Ksatriaan", "addr:housenumber": "11"}, "type": "node", "_source": "overpass_osm"}	e9e3d935115334f46ea1fd72e62ab7da4b03b7290e790fdb8a83aaed10357348	approved	2026-09-30 09:14:51.059384+00
89	1	https://www.openstreetmap.org/node/4328088067	{"id": 4328088067, "lat": -6.910208, "lon": 107.5979591, "tags": {"name": "D'batoe Boutique Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan HOS. Tjokroaminoto", "addr:housenumber": "78"}, "type": "node", "_source": "overpass_osm"}	2736e01461b5b82faad2fb083d2d8d73bc296e5f48cff865a6345dff7f8ccc07	approved	2026-09-30 09:14:51.059384+00
90	1	https://www.openstreetmap.org/node/4328094416	{"id": 4328094416, "lat": -6.9088775, "lon": 107.5978586, "tags": {"name": "Grand Pacific Hotel", "tourism": "hotel", "addr:city": "Bandung, Jawa Barat", "addr:street": "Jalan Pasirkaliki , Pasirkaliki, Cicendo", "addr:housenumber": "100"}, "type": "node", "_source": "overpass_osm"}	14029a0852eeb05b3a1de3ac140b215bf042b3cc1dda49a34d47deebd3d44f3e	approved	2026-09-30 09:14:51.059384+00
91	1	https://www.openstreetmap.org/node/4328099655	{"id": 4328099655, "lat": -6.9119051, "lon": 107.5980388, "tags": {"name": "Hotel Citradream Bandung", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Pasirkaliki", "addr:housenumber": "36-42"}, "type": "node", "_source": "overpass_osm"}	c4fb64382df88b737f18d333883465fa2a8fe931ec3ef3865a2f016183ad5d7e	approved	2026-09-30 09:14:51.059384+00
92	1	https://www.openstreetmap.org/node/4328119383	{"id": 4328119383, "lat": -6.9168351, "lon": 107.5981664, "tags": {"name": "Apartment Gardujati / Guest House", "tourism": "guest_house", "addr:city": "Bandung, Jawa Barat", "addr:street": "Jl. Gardujati, Kb. Jeruk, Andir,", "addr:housenumber": "85"}, "type": "node", "_source": "overpass_osm"}	446b2ea17e38dbc4562fec1f2f7332d9f46ef4d215d7eb780f6d2aae7917565b	approved	2026-09-30 09:14:51.059384+00
93	1	https://www.openstreetmap.org/node/4329454377	{"id": 4329454377, "lat": -6.8965886, "lon": 107.6346884, "tags": {"name": "Galeri Cinde", "tourism": "gallery", "addr:city": "Bandung", "addr:street": "Jl. Pahlawan , Neglasari, Cibeunying Kaler", "addr:housenumber": "58"}, "type": "node", "_source": "overpass_osm"}	12d34ca61c018f4e4d7de9ebb5f8fc1a85025fc1a4738c633a1bc862b60b9df7	approved	2026-09-30 09:14:51.059384+00
94	1	https://www.openstreetmap.org/node/4329680561	{"id": 4329680561, "lat": -6.9053468, "lon": 107.6005941, "tags": {"name": "Hotel Imperium Bandung", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dr. Rum", "addr:housenumber": "30-32"}, "type": "node", "_source": "overpass_osm"}	186d21c68008cd090534521e1c0dc8d6b0a93dead71ed3281d7ae4e2b1a09679	approved	2026-09-30 09:14:51.059384+00
95	1	https://www.openstreetmap.org/node/4338249203	{"id": 4338249203, "lat": -6.9633866, "lon": 107.6262382, "tags": {"name": "Iris Garden", "tourism": "attraction", "building": "yes"}, "type": "node", "_source": "overpass_osm"}	52e27256ed55f613409150adf587e81dbf6802918e529fd596b65e4ea6a3e34a	approved	2026-09-30 09:14:51.059384+00
96	1	https://www.openstreetmap.org/node/4354994539	{"id": 4354994539, "lat": -6.9192675, "lon": 107.6150293, "tags": {"name": "Vio Veteran", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Veteran", "addr:postcode": "40112", "addr:housenumber": "32"}, "type": "node", "_source": "overpass_osm"}	371ee1b13378bbd285fd7ff07192c1f35c5638d44e00744d87c12c8465460c68	approved	2026-09-30 09:14:51.059384+00
97	1	https://www.openstreetmap.org/node/4364208638	{"id": 4364208638, "lat": -6.9271196, "lon": 107.6232611, "tags": {"name": "Malaka Hotel", "tourism": "hotel", "addr:street": "Jalan Halimun", "addr:postcode": "40263", "addr:housenumber": "36"}, "type": "node", "_source": "overpass_osm"}	bfe54eca45fe119dcb6d96eba0f22190c466f373739aac841d6947ef445ecc99	approved	2026-09-30 09:14:51.059384+00
150	1	https://www.openstreetmap.org/node/4368904700	{"id": 4368904700, "lat": -6.8884875, "lon": 107.6038967, "tags": {"name": "Hotel Cihampelas 3", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	c750d66c86b5cf18c24844b05cf6e1514452ef3d4bf25adc36534366645b04a0	approved	2026-09-30 09:14:51.059384+00
98	1	https://www.openstreetmap.org/node/4364221707	{"id": 4364221707, "lat": -6.8772184, "lon": 107.617342, "tags": {"name": "Bukit Dago Business Hotel", "tourism": "hotel", "addr:city": "Badung", "addr:street": "Jalan Ir. H. Juanda", "addr:postcode": "40132", "addr:housenumber": "311"}, "type": "node", "_source": "overpass_osm"}	2efc4dd5a014471d121f53d1e7412358511d57c35cb7acacb9a37b33c007ce3d	approved	2026-09-30 09:14:51.059384+00
99	1	https://www.openstreetmap.org/node/4364264976	{"id": 4364264976, "lat": -6.9201218, "lon": 107.6118937, "tags": {"name": "Hotel New Naripan", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Naripan", "addr:postcode": "40111", "addr:housenumber": "31-25"}, "type": "node", "_source": "overpass_osm"}	116b4e16cad7390a08214cce9f37a982e8fb01b2568ec9ff0583997aeae9120f	approved	2026-09-30 09:14:51.059384+00
100	1	https://www.openstreetmap.org/node/4364268209	{"id": 4364268209, "lat": -6.8988861, "lon": 107.6196592, "tags": {"name": "Vio Surapaati", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Surapati", "addr:postcode": "40133", "addr:housenumber": "51"}, "type": "node", "_source": "overpass_osm"}	2133c7504c2f3f5e03bbee0e1b150323191dbfee4ae5c640f202c635adae8b77	approved	2026-09-30 09:14:51.059384+00
101	1	https://www.openstreetmap.org/node/4364351816	{"id": 4364351816, "lat": -6.9013446, "lon": 107.6122508, "tags": {"name": "Four Points by Sheraton Bandung", "brand": "Four Points by Sheraton", "rooms": "162", "tourism": "hotel", "addr:city": "Bandung", "check_date": "2026-03-14", "short_name": "Four Points", "addr:street": "Jalan Ir. H. Juanda", "addr:postcode": "40115", "brand:wikidata": "Q1439966", "addr:housenumber": "46"}, "type": "node", "_source": "overpass_osm"}	4b74f3c2b60afc0d02d4a76735cb54d461aa767938e120c02c5c756baa70a997	approved	2026-09-30 09:14:51.059384+00
102	1	https://www.openstreetmap.org/node/4364431589	{"id": 4364431589, "lat": -6.9172142, "lon": 107.6079722, "tags": {"name": "favehotel", "branch": "Braga", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Braga", "addr:postcode": "40111", "addr:housenumber": "99-101"}, "type": "node", "_source": "overpass_osm"}	9680745064a1ff3b45ec7cb7d9c4b604ae83deed699724ffeda444922a97cf40	approved	2026-09-30 09:14:51.059384+00
103	1	https://www.openstreetmap.org/node/4365642382	{"id": 4365642382, "lat": -6.9199991, "lon": 107.6243107, "tags": {"name": "Grand Malabar Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Malabar", "addr:postcode": "40262", "addr:housenumber": "2"}, "type": "node", "_source": "overpass_osm"}	aa2f88e06e13be1bdbbaf016803ca39cd574dec1e96f58ecb5d78a66abe0b276	approved	2026-09-30 09:14:51.059384+00
104	1	https://www.openstreetmap.org/node/4365686176	{"id": 4365686176, "lat": -6.8933524, "lon": 107.5991752, "tags": {"name": "Ardan Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Sederhana", "addr:postcode": "40161", "addr:housenumber": "8-10"}, "type": "node", "_source": "overpass_osm"}	7d180c6197763ef7e18045d61932375efc5da087ae5359bbaecbac4bc7e18653	approved	2026-09-30 09:14:51.059384+00
105	1	https://www.openstreetmap.org/node/4365723062	{"id": 4365723062, "lat": -6.9126809, "lon": 107.6025815, "tags": {"name": "Pintu Utara Stasiun Bandung", "historic": "monument", "addr:city": "Bandung", "addr:street": "Jalan Kebon Kawung", "addr:postcode": "40171", "addr:housenumber": "22A"}, "type": "node", "_source": "overpass_osm"}	4fea4be12fbb0c5aeb06fe7bda7a93c5abd2956ecc9a0eafea3b5b6aae14cadd	approved	2026-09-30 09:14:51.059384+00
106	1	https://www.openstreetmap.org/node/4365828036	{"id": 4365828036, "lat": -6.8792749, "lon": 107.5838438, "tags": {"name": "Zodiak Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Prof. Dr. Sutami", "addr:postcode": "40141", "addr:housenumber": "133"}, "type": "node", "_source": "overpass_osm"}	9781edeb80f265e9ec66dc77438b6780ba2169c676a2726f94c329058a9c2f3b	approved	2026-09-30 09:14:51.059384+00
107	1	https://www.openstreetmap.org/node/4365845390	{"id": 4365845390, "lat": -6.9130366, "lon": 107.6292594, "tags": {"name": "Grand Tebu Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan R.E. Martadinata", "addr:postcode": "40115", "addr:housenumber": "207"}, "type": "node", "_source": "overpass_osm"}	77cef49c97265ed51181e2a44691e376c904bc975148114c329466070844a720	approved	2026-09-30 09:14:51.059384+00
108	1	https://www.openstreetmap.org/node/4365862470	{"id": 4365862470, "lat": -6.9303323, "lon": 107.6033774, "tags": {"name": "D'Best Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Oto Iskandardinata", "addr:postcode": "40242", "addr:housenumber": "460"}, "type": "node", "_source": "overpass_osm"}	9acfbcef784a62811290a17ed8fce7cb921dd9530e8891e5d4fc1462819b120a	approved	2026-09-30 09:14:51.059384+00
109	1	https://www.openstreetmap.org/node/4365868418	{"id": 4365868418, "lat": -6.9223613, "lon": 107.621572, "tags": {"name": "Harapan Indah Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Gatot Subroto", "addr:postcode": "40262", "addr:housenumber": "45B"}, "type": "node", "_source": "overpass_osm"}	09f2b0a5e811b6188b81d78193a571c68477f103c7f89d566401c5f436c21d0b	approved	2026-09-30 09:14:51.059384+00
110	1	https://www.openstreetmap.org/node/4365969235	{"id": 4365969235, "lat": -6.9237412, "lon": 107.6165669, "tags": {"name": "De'Rain", "stars": "3", "tourism": "hotel", "operator": "Dafam", "addr:city": "Bandung", "wheelchair": "no", "addr:street": "Jalan Lengkong Kecil", "addr:postcode": "40261", "internet_access": "wlan", "addr:housenumber": "76-80", "internet_access:fee": "no"}, "type": "node", "_source": "overpass_osm"}	151bc69b77832b9d689dbdaf09a749dac2241de3fd6ec9063023e6c5fd0511a6	approved	2026-09-30 09:14:51.059384+00
111	1	https://www.openstreetmap.org/node/4365975820	{"id": 4365975820, "lat": -6.9120282, "lon": 107.5980357, "tags": {"name": "Zodiak Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Pasir Kaliki", "addr:postcode": "40171", "addr:housenumber": "50"}, "type": "node", "_source": "overpass_osm"}	95f7531da22aa8b53afc6b955d5d987f1d3dc18fe82f5205e62b8d7574ccf29a	approved	2026-09-30 09:14:51.059384+00
112	1	https://www.openstreetmap.org/node/4366003613	{"id": 4366003613, "lat": -6.9023262, "lon": 107.5984379, "tags": {"name": "De Hoff Cihampelas Cottage", "tourism": "hotel", "addr:city": "Bandung, Jawa Barat", "addr:street": "Jalan Westhoff", "addr:postcode": "40171", "addr:housenumber": "18 A-B"}, "type": "node", "_source": "overpass_osm"}	9cfc5d602485d3b42a0cfe6355f47d7f3066e35c1fc9f8965deaf8fe36e77f70	approved	2026-09-30 09:14:51.059384+00
113	1	https://www.openstreetmap.org/node/4366036884	{"id": 4366036884, "lat": -6.9052505, "lon": 107.613954, "tags": {"name": "Ivory by Ayola Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Bahureksa", "addr:postcode": "40115", "addr:housenumber": "3"}, "type": "node", "_source": "overpass_osm"}	9ebba1dd8251cd77c5215017fd28b6a366d6f46c3610d6b4bb2cc0ec6b5f0b83	approved	2026-09-30 09:14:51.059384+00
114	1	https://www.openstreetmap.org/node/4366160271	{"id": 4366160271, "lat": -6.9244626, "lon": 107.6102761, "tags": {"name": "Raffleshom Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Pangarang", "addr:postcode": "40621", "addr:housenumber": "24"}, "type": "node", "_source": "overpass_osm"}	0fff6dcfe0a80e53de1dee9fc0c69783680c395b0071b4f5113f029fe9416598	approved	2026-09-30 09:14:51.059384+00
115	1	https://www.openstreetmap.org/node/4366211031	{"id": 4366211031, "lat": -6.9142388, "lon": 107.6291362, "tags": {"name": "Hotel Dafam Rio", "tourism": "hotel", "addr:city": "bandung", "addr:street": "Jalan R.E. Martadinata", "addr:postcode": "40113", "addr:housenumber": "160"}, "type": "node", "_source": "overpass_osm"}	535a01650485b462471878210a8bc185747c4671943ebb62868c5b8363c71709	approved	2026-09-30 09:14:51.059384+00
116	1	https://www.openstreetmap.org/node/4366500173	{"id": 4366500173, "lat": -6.9297717, "lon": 107.6055701, "tags": {"name": "Arimbi Dewi Sartika", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dewi Sartika", "addr:postcode": "40252", "addr:housenumber": "108A"}, "type": "node", "_source": "overpass_osm"}	169a698a3707832dca2796fa6058b2a0ad120dedd04f7ce4d1c21b316d01567a	approved	2026-09-30 09:14:51.059384+00
117	1	https://www.openstreetmap.org/node/4366529015	{"id": 4366529015, "lat": -6.8900307, "lon": 107.6042626, "tags": {"name": "Cihampelas hotel 2", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Cihampelas", "addr:postcode": "40131", "addr:housenumber": "222"}, "type": "node", "_source": "overpass_osm"}	d2c0bf3d861cd14d5f49d0d94b1960d17e9c5694e0838474c3e18c0535542c87	approved	2026-09-30 09:14:51.059384+00
118	1	https://www.openstreetmap.org/node/4366542977	{"id": 4366542977, "lat": -6.9142778, "lon": 107.5941443, "tags": {"name": "Hyper Inn", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Paskal Hyper Square Blok D, Jl. Pasar Kaliki", "addr:postcode": "40161", "addr:housenumber": "29-32"}, "type": "node", "_source": "overpass_osm"}	ddccac09c14a398ee08f28b0e9075228ea0d13fce21653672ea8fb3385651a1e	approved	2026-09-30 09:14:51.059384+00
119	1	https://www.openstreetmap.org/node/4367108753	{"id": 4367108753, "lat": -6.8953346, "lon": 107.5974404, "tags": {"name": "Zest Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Sukajadi", "addr:postcode": "40161", "addr:housenumber": "16"}, "type": "node", "_source": "overpass_osm"}	3fc53a94783427f17b4cf90b0b0039edcb229053a61eccd739f286b413a1f837	approved	2026-09-30 09:14:51.059384+00
120	1	https://www.openstreetmap.org/node/4367119795	{"id": 4367119795, "lat": -6.8889008, "lon": 107.6041305, "tags": {"name": "Cihampelas Hotel 1", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Cihampelas", "addr:postcode": "40131", "addr:housenumber": "240"}, "type": "node", "_source": "overpass_osm"}	81700f42152b3d3b19c406d29426a609c334834473347d66bf02987ccef8755b	approved	2026-09-30 09:14:51.059384+00
121	1	https://www.openstreetmap.org/node/4367137267	{"id": 4367137267, "lat": -6.9226427, "lon": 107.6206005, "tags": {"name": "dPalma Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Gatot Subroto", "addr:postcode": "40262", "addr:housenumber": "41"}, "type": "node", "_source": "overpass_osm"}	99fa0d13b3020e68ba5b05650f765c558b64df6e9eb75b07506da9b02005ce18	approved	2026-09-30 09:14:51.059384+00
122	1	https://www.openstreetmap.org/node/4367194151	{"id": 4367194151, "lat": -6.8949349, "lon": 107.6144867, "tags": {"name": "Namin Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Hasanudin", "addr:housenumber": "10"}, "type": "node", "_source": "overpass_osm"}	d3831cee6bc5bd8bd88274730479a35fa7dd0d3e3f4ae257cb3f0453df464944	approved	2026-09-30 09:14:51.059384+00
123	1	https://www.openstreetmap.org/node/4367285388	{"id": 4367285388, "lat": -6.9422992, "lon": 107.6417377, "tags": {"name": "Idea's Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Ibrahim Adji", "addr:postcode": "40281", "addr:housenumber": "414"}, "type": "node", "_source": "overpass_osm"}	af239dae22ec86ba7585b3e59f162cad18927159ddd5808342878eb6c5417619	approved	2026-09-30 09:14:51.059384+00
124	1	https://www.openstreetmap.org/node/4367306824	{"id": 4367306824, "lat": -6.9025113, "lon": 107.6126153, "tags": {"name": "M Premiere Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Tirtayasa", "addr:postcode": "40115", "addr:housenumber": "5"}, "type": "node", "_source": "overpass_osm"}	e459a297b7b7023d5e8cbed01cdb61d455a339bd2bc0c23b5e50780954b25949	approved	2026-09-30 09:14:51.059384+00
125	1	https://www.openstreetmap.org/node/4367331942	{"id": 4367331942, "lat": -6.9187466, "lon": 107.5998169, "tags": {"name": "Unique Guesthouse 1", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Ence Ajis", "addr:postcode": "40181", "addr:housenumber": "34"}, "type": "node", "_source": "overpass_osm"}	526ba773bdaae5bf4533de0f8371c5c19a0a43556f423a42792d2b8a6870de65	approved	2026-09-30 09:14:51.059384+00
126	1	https://www.openstreetmap.org/node/4367333994	{"id": 4367333994, "lat": -6.8955675, "lon": 107.6165128, "tags": {"name": "De'qur Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dipatiukur", "addr:postcode": "40132", "addr:housenumber": "27"}, "type": "node", "_source": "overpass_osm"}	48ca83ece6dd5ffe986d01f03fae8822f516e343b770961cfef465c0a230ae87	approved	2026-09-30 09:14:51.059384+00
127	1	https://www.openstreetmap.org/node/4367336310	{"id": 4367336310, "lat": -6.9370389, "lon": 107.687952, "tags": {"name": "Grand Cordela Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Soekarno Hatta", "addr:postcode": "40294", "addr:housenumber": "791"}, "type": "node", "_source": "overpass_osm"}	7d3830e46155c5949f73da23e6c9de39d114d9fc0759abb4992431e526a9e9c7	approved	2026-09-30 09:14:51.059384+00
128	1	https://www.openstreetmap.org/node/4367339333	{"id": 4367339333, "lat": -6.8613442, "lon": 107.5954536, "tags": {"name": "Travello Hotel", "tourism": "hotel", "addr:city": "Bandung", "check_date": "2025-08-17", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40154", "addr:housenumber": "268"}, "type": "node", "_source": "overpass_osm"}	ddb3865933d9416e41d028d96ef8c808419f577aa7ee1dd52aa3e8e21e3767d9	approved	2026-09-30 09:14:51.059384+00
129	1	https://www.openstreetmap.org/node/4367346832	{"id": 4367346832, "lat": -6.9237306, "lon": 107.6169092, "tags": {"name": "VELeZA", "stars": "3", "tourism": "hotel", "operator": "Veleza Hotel", "addr:city": "Bandung", "wheelchair": "no", "addr:street": "Jalan Lengkong Kecil", "addr:postcode": "40261", "internet_access": "wlan", "addr:housenumber": "84", "internet_access:fee": "no"}, "type": "node", "_source": "overpass_osm"}	7099523d358dce69cf5472df4c03b16b6075c890192be148fdf15e06ff685b53	approved	2026-09-30 09:14:51.059384+00
130	1	https://www.openstreetmap.org/node/4367377390	{"id": 4367377390, "lat": -6.8789881, "lon": 107.5936611, "tags": {"name": "The Victoria Luxurious Guesthouse", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Sukaresmi", "addr:postcode": "40162", "addr:housenumber": "4-6"}, "type": "node", "_source": "overpass_osm"}	d4a50aafb073edf064f73d81a18f2f1f72c41e384b1a23b67e9eb705424fe22f	approved	2026-09-30 09:14:51.059384+00
131	1	https://www.openstreetmap.org/node/4367388682	{"id": 4367388682, "lat": -6.9397303, "lon": 107.6589837, "tags": {"name": "The Suites@Metro", "tourism": "apartment", "addr:city": "Bandung", "addr:street": "Jalan Soekarno-Hatta", "addr:postcode": "40286", "addr:housenumber": "689"}, "type": "node", "_source": "overpass_osm"}	b94a60aad4ccf5b662e5566a120ad0a4fea5ab38390f1def981aaccd664b8bf3	approved	2026-09-30 09:14:51.059384+00
132	1	https://www.openstreetmap.org/node/4367403002	{"id": 4367403002, "lat": -6.8845803, "lon": 107.6116992, "tags": {"name": "House Sangkuriang", "tourism": "hotel", "addr:city": "Bandung, Jawa Barat", "check_date": "2026-03-15", "addr:street": "Jalan Sangkuriang", "addr:postcode": "40135", "addr:housenumber": "1"}, "type": "node", "_source": "overpass_osm"}	ffab5c5592ae428b2c83c985b967755857443699dc564629e7a98b3744022a0a	approved	2026-09-30 09:14:51.059384+00
133	1	https://www.openstreetmap.org/node/4367415073	{"id": 4367415073, "lat": -6.8825448, "lon": 107.5809045, "tags": {"name": "Garden Permata Hote", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Lemah Neundeut", "addr:postcode": "40164", "addr:housenumber": "7"}, "type": "node", "_source": "overpass_osm"}	6f78e8d566d442b4985497ccfce76afcecf1192f3a111383d0bd866ec642f830	approved	2026-09-30 09:14:51.059384+00
134	1	https://www.openstreetmap.org/node/4367486386	{"id": 4367486386, "lat": -6.8912551, "lon": 107.6160848, "tags": {"name": "Sofia House Dago Hotel", "tourism": "hotel", "check_date": "2026-03-06"}, "type": "node", "_source": "overpass_osm"}	55149040f04cfa3bab61cbaf8de366671d6af24d094b59aef8aa17c97181bc11	approved	2026-09-30 09:14:51.059384+00
135	1	https://www.openstreetmap.org/node/4367492914	{"id": 4367492914, "lat": -6.9070748, "lon": 107.6192545, "tags": {"name": "Noor Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Madura", "addr:postcode": "40115", "addr:housenumber": "6"}, "type": "node", "_source": "overpass_osm"}	f20086521c47f7275b5126bebcecd26f1989aa8e1f884244bf83d2ab8c16b1c6	approved	2026-09-30 09:14:51.059384+00
136	1	https://www.openstreetmap.org/node/4367499145	{"id": 4367499145, "lat": -6.8862417, "lon": 107.6043448, "tags": {"name": "D' River Guest House", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	64e23461c35a5eb3f1882b3f21a577f6c8dd974a4868991425b7f859d011af05	approved	2026-09-30 09:14:51.059384+00
137	1	https://www.openstreetmap.org/node/4367529941	{"id": 4367529941, "lat": -6.889021, "lon": 107.5833566, "tags": {"name": "Orange Home's Syariah", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Babakan Jeruk 1", "addr:postcode": "40267", "addr:housenumber": "76"}, "type": "node", "_source": "overpass_osm"}	c0f49f93c24f8ce7f92bc9290bc2ed73423a1e606c9427fbda3cf683824e2386	approved	2026-09-30 09:14:51.059384+00
138	1	https://www.openstreetmap.org/node/4367950798	{"id": 4367950798, "lat": -6.9172253, "lon": 107.5980546, "tags": {"name": "D'sovia Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Gardujati", "addr:postcode": "40181.", "addr:housenumber": "81-83"}, "type": "node", "_source": "overpass_osm"}	ede5bcecaf4446e18893249dfa5081c3406b78f4b9adcbbfc27a988577e35fa4	approved	2026-09-30 09:14:51.059384+00
139	1	https://www.openstreetmap.org/node/4367985579	{"id": 4367985579, "lat": -6.8828975, "lon": 107.6213632, "tags": {"name": "Dago's Hill Hotel", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Tubagus Ismail VIII", "addr:postcode": "40135", "addr:housenumber": "39A"}, "type": "node", "_source": "overpass_osm"}	196cc42fb8262f3436d0e4d545ef804fe987a29564b0e8023d1b6a55718a8a97	approved	2026-09-30 09:14:51.059384+00
140	1	https://www.openstreetmap.org/node/4368072361	{"id": 4368072361, "lat": -6.908747, "lon": 107.5681663, "tags": {"name": "Hotel Endah Parahyangan", "tourism": "hotel", "addr:city": "Cimahi", "addr:street": "Jl. Raya Cimindi", "addr:postcode": "40535", "addr:housenumber": "14"}, "type": "node", "_source": "overpass_osm"}	3c399845274c9eff934b45b14eb8afeabc8377f69c69ffca097a2f7c7206f7e0	approved	2026-09-30 09:14:51.059384+00
141	1	https://www.openstreetmap.org/node/4368082307	{"id": 4368082307, "lat": -6.8749468, "lon": 107.5966057, "tags": {"name": "Grand Setiabudi Hotel & Apartment", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40153", "addr:housenumber": "130-134"}, "type": "node", "_source": "overpass_osm"}	1b8acbaa37c2061473952775bac19a3441c1dbe2ef5cf71d38c8b9b3b4c91b7f	approved	2026-09-30 09:14:51.059384+00
142	1	https://www.openstreetmap.org/node/4368154959	{"id": 4368154959, "lat": -6.9048427, "lon": 107.6040474, "tags": {"name": "Novotel Bandung", "brand": "Novotel", "rooms": "156", "stars": "4", "tourism": "hotel", "operator": "Accor", "addr:city": "Bandung", "addr:street": "Jalan Cihampelas", "addr:postcode": "40171", "brand:wikidata": "Q420545", "addr:housenumber": "23"}, "type": "node", "_source": "overpass_osm"}	3a45adc35e615aaa9eb214c8539bd4c93954f053d79412956b7f5d29f40b13e4	approved	2026-09-30 09:14:51.059384+00
143	1	https://www.openstreetmap.org/node/4368184538	{"id": 4368184538, "lat": -6.8807512, "lon": 107.6209847, "tags": {"name": "Lotus Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	591ae7d21a0222247bc5783b9c74b3b7bc21c5bd386f740a4505f1315c67fbc0	approved	2026-09-30 09:14:51.059384+00
144	1	https://www.openstreetmap.org/node/4368836119	{"id": 4368836119, "lat": -6.8855054, "lon": 107.5832957, "tags": {"name": "Fullmar House", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	5e8921e503576e3edd76bfb0b3d9b64104e422737a52f042a52052914ca26701	approved	2026-09-30 09:14:51.059384+00
145	1	https://www.openstreetmap.org/node/4368869499	{"id": 4368869499, "lat": -6.9279883, "lon": 107.6129377, "tags": {"name": "Asoka Hotel", "tourism": "hotel", "check_date": "2025-05-10"}, "type": "node", "_source": "overpass_osm"}	0324f8a30af30eec6680be833259ab0094fc05dfc666592c853f857b54ae18ca	approved	2026-09-30 09:14:51.059384+00
146	1	https://www.openstreetmap.org/node/4368870949	{"id": 4368870949, "lat": -6.8909513, "lon": 107.5844269, "tags": {"name": "Hotel Ilos", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9265618c638b664ee304b3098758c9c749980f58cae3ad3896bcf188e3fb080d	approved	2026-09-30 09:14:51.059384+00
147	1	https://www.openstreetmap.org/node/4368872127	{"id": 4368872127, "lat": -6.8978624, "lon": 107.633553, "tags": {"name": "Amalio Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	7b40443469565bcba10b7563b4531bcabb3fe65970395d1337c1594e1e668b8e	approved	2026-09-30 09:14:51.059384+00
148	1	https://www.openstreetmap.org/node/4368900414	{"id": 4368900414, "lat": -6.8959957, "lon": 107.6197747, "tags": {"name": "Hotel Danoufa", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	70047e348a821ace4cc19229de65488a3f3d61268f646f93c816b99a212b4583	approved	2026-09-30 09:14:51.059384+00
149	1	https://www.openstreetmap.org/node/4368902095	{"id": 4368902095, "lat": -6.8922096, "lon": 107.5991368, "tags": {"name": "Arwiga Hotel and Convention", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	52ffe0b731d9ac6f13a3b70e00e88d1a9934cf418de524a13f8812a6c4bd05b5	approved	2026-09-30 09:14:51.059384+00
151	1	https://www.openstreetmap.org/node/4368992655	{"id": 4368992655, "lat": -6.9045086, "lon": 107.6283299, "tags": {"name": "Hotel Corsica", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6183b011f38e82c26b2e2d5a10e8f54278a264a5d19f777164b78128d7a944ac	approved	2026-09-30 09:14:51.059384+00
152	1	https://www.openstreetmap.org/node/4369159158	{"id": 4369159158, "lat": -6.8863872, "lon": 107.5844659, "tags": {"name": "Sweet Karina Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	c3fba861200475b03d681a4f7f6a41e2ee8c9b0bf3b7c7991bc25c2dd11d86fd	approved	2026-09-30 09:14:51.059384+00
153	1	https://www.openstreetmap.org/node/4369754653	{"id": 4369754653, "lat": -6.9234092, "lon": 107.6099225, "tags": {"name": "Nandya Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	36d6c33c9bc126314a23aa16eb13039646bff612f3571df326303c3c708b0952	approved	2026-09-30 09:14:51.059384+00
154	1	https://www.openstreetmap.org/node/4369854694	{"id": 4369854694, "lat": -6.8821468, "lon": 107.6001959, "tags": {"name": "Asmila Boutique Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	990fc27b962202609be61a954206bd73966a4ea2ddf6e0a8abb50007691759e9	approved	2026-09-30 09:14:51.059384+00
155	1	https://www.openstreetmap.org/node/4369877696	{"id": 4369877696, "lat": -6.9148979, "lon": 107.5987599, "tags": {"name": "El Cavana Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6533ffacf4380f1da29aff275dcc30ff7d4a99084122dda3cff3467214eb3f4c	approved	2026-09-30 09:14:51.059384+00
156	1	https://www.openstreetmap.org/node/4370117219	{"id": 4370117219, "lat": -6.9100918, "lon": 107.6494895, "tags": {"name": "Arinda Guest House", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d68a892de542ca62b60aa3cd4c8d31938599b0d5ada18a1d0ae2ac07f5351a30	approved	2026-09-30 09:14:51.059384+00
157	1	https://www.openstreetmap.org/node/4370125443	{"id": 4370125443, "lat": -6.951638, "lon": 107.5858215, "tags": {"name": "Hotel 88 Bandung Kopo", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	81d9edadfd66ffb747c76522a44b09588570e4ec4a6573ac48ce70c1ddc92dcb	approved	2026-09-30 09:14:51.059384+00
158	1	https://www.openstreetmap.org/node/4370151162	{"id": 4370151162, "lat": -6.894442, "lon": 107.611878, "tags": {"name": "HOTEL WISMA DAGO", "name:en": "Wisma", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	bb1728edef24a497cc377e7ec3855a6f98b00a73b60f561b594b67734f80fc70	approved	2026-09-30 09:14:51.059384+00
159	1	https://www.openstreetmap.org/node/4370162206	{"id": 4370162206, "lat": -6.8984858, "lon": 107.6041481, "tags": {"name": "Vio Cihampelas", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	819df76b0f89d5ed26f2660fc87a2c47f8ea3fb98cfa1f6cd8bb4cb5cfaa625a	approved	2026-09-30 09:14:51.059384+00
160	1	https://www.openstreetmap.org/node/4370175009	{"id": 4370175009, "lat": -6.9010747, "lon": 107.5995703, "tags": {"name": "Excellent Seven Boutique Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	19217c1c0b826977d970746cc71d8a0c3d6e20a84233ceb5ac55c237023a8467	approved	2026-09-30 09:14:51.059384+00
161	1	https://www.openstreetmap.org/node/4370179384	{"id": 4370179384, "lat": -6.9366158, "lon": 107.5953771, "tags": {"name": "Hotel Grand Kopo", "tourism": "hotel", "check_date": "2024-03-22"}, "type": "node", "_source": "overpass_osm"}	e6c94116527b22efed3024873d35c97cd185145137cad5e4f4bcc731e1782057	approved	2026-09-30 09:14:51.059384+00
162	1	https://www.openstreetmap.org/node/4370470049	{"id": 4370470049, "lat": -6.9160743, "lon": 107.6009259, "tags": {"name": "Zodiak@Kebon Jati", "tourism": "hotel", "check_date": "2025-08-09"}, "type": "node", "_source": "overpass_osm"}	d98de4b247ec60ef1ee569af5407583d4ff0ab561916b1f2a00f5da208bf5eef	approved	2026-09-30 09:14:51.059384+00
163	1	https://www.openstreetmap.org/node/4370481546	{"id": 4370481546, "lat": -6.938056, "lon": 107.6151956, "tags": {"name": "Bali Indah Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	f0a18e1a15b3ab71bc15c81bf24f14accf16d1820d89648684af1ec079a73d69	approved	2026-09-30 09:14:51.059384+00
164	1	https://www.openstreetmap.org/node/4370531568	{"id": 4370531568, "lat": -6.9177986, "lon": 107.6121924, "tags": {"name": "Hotel Istana", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	a503d47b630a62e6eb145c426b73788a20bfead0eb9d9688a216dca4cb391d68	approved	2026-09-30 09:14:51.059384+00
165	1	https://www.openstreetmap.org/node/4370599589	{"id": 4370599589, "lat": -6.8922074, "lon": 107.5821626, "tags": {"name": "Vio Hotel Pasteur", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	750c9766a1e0b96e0a638963b0658fbce8423d14d47eb456fde54efbcbe781ff	approved	2026-09-30 09:14:51.059384+00
166	1	https://www.openstreetmap.org/node/4373080471	{"id": 4373080471, "lat": -6.8841687, "lon": 107.5831743, "tags": {"name": "Amira Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	cdc45eb27fed82cb08416c1f6a09c50e655a63ecf7c6c42ff89ddfa5607dbb3d	approved	2026-09-30 09:14:51.059384+00
167	1	https://www.openstreetmap.org/node/4373107740	{"id": 4373107740, "lat": -6.9033913, "lon": 107.6053848, "tags": {"name": "Sakura Guest House", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	b9aee03e58ad39b4701d438629271fe97df818cf2ddeb8dac8fd83741b7323d9	approved	2026-09-30 09:14:51.059384+00
168	1	https://www.openstreetmap.org/node/4373130278	{"id": 4373130278, "lat": -6.8880057, "lon": 107.6012479, "tags": {"name": "Elenor's Home", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	1052e831c00f30fe11ac1f1ee1b885996b934e5f3830c0d7447b893ad41cecc1	approved	2026-09-30 09:14:51.059384+00
169	1	https://www.openstreetmap.org/node/4373140133	{"id": 4373140133, "lat": -6.9452455, "lon": 107.6267781, "tags": {"name": "Pondok Kurnia", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	f793fb3ddc7d08084b749f5833650d81303a7799766114b655e74949f6eae861	approved	2026-09-30 09:14:51.059384+00
170	1	https://www.openstreetmap.org/node/4373174485	{"id": 4373174485, "lat": -6.9179939, "lon": 107.653156, "tags": {"name": "Arlya Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	57d152332a43284f14a287ada6a587a8928e5b27b92bbfec61d11a2232a109dd	approved	2026-09-30 09:14:51.059384+00
171	1	https://www.openstreetmap.org/node/4373270426	{"id": 4373270426, "lat": -6.9125995, "lon": 107.605407, "tags": {"name": "Kenangan Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	fb65b0aeb8a802d801453da885a2120bbd23051558aa90ffacb0a4e52e2f0201	approved	2026-09-30 09:14:51.059384+00
172	1	https://www.openstreetmap.org/node/4373321350	{"id": 4373321350, "lat": -6.8703099, "lon": 107.5930342, "tags": {"name": "Hotel Salon Fora", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	2f477409582de80e5272cae1951f702d64af0ea0b29d89e59d8c0356e1c6bde6	approved	2026-09-30 09:14:51.059384+00
173	1	https://www.openstreetmap.org/node/4373373687	{"id": 4373373687, "lat": -6.9116572, "lon": 107.6193761, "tags": {"name": "Oasis Hotel", "tourism": "hotel", "check_date": "2025-10-19"}, "type": "node", "_source": "overpass_osm"}	35b021ae19eb17a50fbaf616769ada2fbe35627b6c001d484387b02ee601cca6	approved	2026-09-30 09:14:51.059384+00
174	1	https://www.openstreetmap.org/node/4373419773	{"id": 4373419773, "lat": -6.9294983, "lon": 107.6261956, "tags": {"name": "Hotel Boulevard", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8222734c01f89d2623a6343a4b660c703451b5a92f1dd36e2a5a1b880b6f0970	approved	2026-09-30 09:14:51.059384+00
175	1	https://www.openstreetmap.org/node/4373592307	{"id": 4373592307, "lat": -6.919194, "lon": 107.6265725, "tags": {"name": "Hotel Anda", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8bd3a5522493693d314e89e1212ad3527e34b95dc56e0443ce065c2d46f1021e	approved	2026-09-30 09:14:51.059384+00
176	1	https://www.openstreetmap.org/node/4374570796	{"id": 4374570796, "lat": -6.9172119, "lon": 107.59872, "tags": {"name": "Palm Hotel", "name:it": "Palm", "tourism": "hotel", "addr:street": "Jalan Belakang Pasar", "internet_access": "wlan"}, "type": "node", "_source": "overpass_osm"}	2dc6127b8507f3a5049501303f7adab194bf027f243b48628c7f371c8f860760	approved	2026-09-30 09:14:51.059384+00
177	1	https://www.openstreetmap.org/node/4381766291	{"id": 4381766291, "lat": -6.9281394, "lon": 107.6201129, "tags": {"name": "Rizh Garden", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6af63e954f463a8c1ab4dd8c117baabf627a51cfd7fa7e7dd293c2899b00974d	approved	2026-09-30 09:14:51.059384+00
178	1	https://www.openstreetmap.org/node/4395991497	{"id": 4395991497, "lat": -6.8894684, "lon": 107.6141432, "tags": {"name": "Attic", "tourism": "guest_house", "addr:street": "Jalan Ir. H. Juanda", "addr:housenumber": "130"}, "type": "node", "_source": "overpass_osm"}	b0dfa2e67aaaca346cf33a35d4ce871101b6d3344c041c6497f11923a4d45701	approved	2026-09-30 09:14:51.059384+00
179	1	https://www.openstreetmap.org/node/4402017325	{"id": 4402017325, "lat": -6.9303091, "lon": 107.6395774, "tags": {"name": "Bantal Guling", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jenderal Gatot Subroto", "addr:housenumber": "194"}, "type": "node", "_source": "overpass_osm"}	1b1b86fc94617e64791bde0457407d756125c2ee32b9817fb40feb68229acac5	approved	2026-09-30 09:14:51.059384+00
180	1	https://www.openstreetmap.org/node/4403942376	{"id": 4403942376, "lat": -6.8500004, "lon": 107.5982953, "tags": {"name": "GH Universal", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	371fc43ae4ce4e7170c2379902e70f6c5b2b17ff4c0f34da58e7b5ffb874c7ed	approved	2026-09-30 09:14:51.059384+00
181	1	https://www.openstreetmap.org/node/4451042091	{"id": 4451042091, "lat": -6.8672308, "lon": 107.5775872, "tags": {"name": "Egioto.com", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	6cd62663f2feda74774357e6748e735b476d1a49690a81639773bff4292413e5	approved	2026-09-30 09:14:51.059384+00
182	1	https://www.openstreetmap.org/node/4489016289	{"id": 4489016289, "lat": -6.9285726, "lon": 107.6636102, "tags": {"name": "Basecamp", "tourism": "guest_house", "addr:street": "Jalan Randusari", "addr:postcode": "40291", "internet_access": "wlan", "addr:housenumber": "E36"}, "type": "node", "_source": "overpass_osm"}	a53bfe93a79a137250b2135d741d2c830ff9a579112283d990277b0fb4ec9207	approved	2026-09-30 09:14:51.059384+00
183	1	https://www.openstreetmap.org/node/4543278790	{"id": 4543278790, "lat": -6.9434523, "lon": 107.6234262, "tags": {"name": "Suryalaya Inn", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6f96f613f91f33585e71a23f0819e55937d17ea2dd51cb048fbbd6a8a8c1d8c8	approved	2026-09-30 09:14:51.059384+00
184	1	https://www.openstreetmap.org/node/4555510932	{"id": 4555510932, "lat": -6.9124293, "lon": 107.6054923, "tags": {"name": "Venice Guest House", "tourism": "guest_house", "internet_access": "wlan"}, "type": "node", "_source": "overpass_osm"}	85ec0349c3594b4c37f3e1796ac69aa7080c8c7fcbf42a5b050daf88f75716ae	approved	2026-09-30 09:14:51.059384+00
185	1	https://www.openstreetmap.org/node/4625757227	{"id": 4625757227, "lat": -6.8516724, "lon": 107.5963601, "tags": {"name": "Amazing Art World", "phone": "+62 222018280", "tourism": "museum", "website": "https://m.facebook.com/AmazingArtWorld.Bandung/", "addr:street": "Jalan Setiabudhi", "opening_hours": "Mo-Su 09:00-21:00", "addr:housenumber": "293"}, "type": "node", "_source": "overpass_osm"}	0fc91b8dde13799cebda5ffa7547faaf4a0b44179df3965e85c621c0a99e0418	approved	2026-09-30 09:14:51.059384+00
186	1	https://www.openstreetmap.org/node/4655134787	{"id": 4655134787, "lat": -6.9161539, "lon": 107.5942195, "tags": {"name": "Fave Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	097643f6c6c544764f33178a297b06887f3fc94625d29b180da7dc69fc7ea858	approved	2026-09-30 09:14:51.059384+00
187	1	https://www.openstreetmap.org/node/5022145228	{"id": 5022145228, "lat": -6.9172152, "lon": 107.5990058, "tags": {"name": "Gado Gadu Hostel (real adress!)", "name:de": "Gado Gadu Hostel (richtige Adresse!)", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	2ed6f3f2cb4b992e2d7731ee39e493c802ec2c26db0c36d214e788be9367cc59	approved	2026-09-30 09:14:51.059384+00
188	1	https://www.openstreetmap.org/node/5031456123	{"id": 5031456123, "lat": -6.8870845, "lon": 107.5879782, "tags": {"name": "Rompis Residence", "phone": "+62212013422", "tourism": "hostel", "addr:street": "Jalan Suka Mulya", "addr:postcode": "40163", "addr:housenumber": "3-1"}, "type": "node", "_source": "overpass_osm"}	4ec910eeb19db92834d9d940c054070edaf200ed4f106cc1a9c751dffa774ae3	approved	2026-09-30 09:14:51.059384+00
189	1	https://www.openstreetmap.org/node/5172665198	{"id": 5172665198, "lat": -6.9147927, "lon": 107.6298813, "tags": {"name": "The Newton Hotel", "tourism": "hotel", "addr:city": "Bandung", "check_date": "2026-05-06", "addr:street": "Jl. RE Martadinata", "addr:housenumber": "223-227"}, "type": "node", "_source": "overpass_osm"}	0933e2945365736c4ae90df57d91a7643a6cb89a59a4b5aa05d62339a4ff1706	approved	2026-09-30 09:14:51.059384+00
190	1	https://www.openstreetmap.org/node/5178031251	{"id": 5178031251, "lat": -6.9089699, "lon": 107.6141983, "tags": {"name": "Pastoor H.C. Verbraak", "tourism": "artwork", "historic": "memorial", "memorial": "statue", "start_date": "1922", "inscription": "PASTOOR\\nH.C.VERBRAAK.\\n1835 ΓÇô 1918.\\nAALMOEZENIER\\n1874 ΓÇô 1881\\nATJEH\\n1874 ΓÇô 1907"}, "type": "node", "_source": "overpass_osm"}	4fc4436b0d566ab24ff4a01ebf3b63f21d4502b2aeb18ec3a39faaaaa075d1f7	approved	2026-09-30 09:14:51.059384+00
191	1	https://www.openstreetmap.org/node/5182888921	{"id": 5182888921, "lat": -6.884368, "lon": 107.5963463, "tags": {"name": "Caryota", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	3833f2f4ffcee8796084085a8c316388a10f80f00b467d0eb8c0e87b2fa12e82	approved	2026-09-30 09:14:51.059384+00
192	1	https://www.openstreetmap.org/node/5188407891	{"id": 5188407891, "lat": -6.9042507, "lon": 107.6056955, "tags": {"name": "Seni Abadi", "tourism": "gallery"}, "type": "node", "_source": "overpass_osm"}	86c72a167e7c75e88394c87e2f924bd6fcaa9dec5e7397aa65073a904f9fe8a3	approved	2026-09-30 09:14:51.059384+00
193	1	https://www.openstreetmap.org/node/5291705249	{"id": 5291705249, "lat": -6.91865, "lon": 107.6095986, "tags": {"name": "Chez Bon Hostel", "phone": "+62-22-4260-600", "rooms": "8", "tourism": "hostel", "website": "http://chez-bon.com", "breakfast": "Mo-Su 7:00-11:00", "wheelchair": "no", "addr:street": "Jalan Braga", "addr:postcode": "40111", "internet_access": "wlan", "addr:housenumber": "45"}, "type": "node", "_source": "overpass_osm"}	5b6b8c8e98167f17a9d074e37190811536a2fa75be620d8e73363fa47347fe81	approved	2026-09-30 09:14:51.059384+00
194	1	https://www.openstreetmap.org/node/5312537881	{"id": 5312537881, "lat": -6.8852505, "lon": 107.6097305, "tags": {"fee": "no", "name": "Pintu Masuk Forest Walk Babakan Siliwangi", "tourism": "attraction", "opening_hours": "24/7"}, "type": "node", "_source": "overpass_osm"}	1a0483bd0dc44bf2d1004118155f6612477d3ca29e9dcac76574f52de5f24d8e	approved	2026-09-30 09:14:51.059384+00
195	1	https://www.openstreetmap.org/node/5451497375	{"id": 5451497375, "lat": -6.9139162, "lon": 107.604332, "tags": {"name": "Hotel Lini", "stars": "4", "tourism": "hotel", "addr:city": "Bandung", "addr:housename": "Lini Hootel", "addr:housenumber": "4"}, "type": "node", "_source": "overpass_osm"}	9931066d6cb300dbe44f776833ed8b24f67013b17bc17de19a901fc5eccfcacb	approved	2026-09-30 09:14:51.059384+00
196	1	https://www.openstreetmap.org/node/5503920859	{"id": 5503920859, "lat": -6.9207697, "lon": 107.6085001, "tags": {"name": "Sumur Bandung", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	7bd1fbce1160984022ee151797de76c71f5bffd6c000d87c8da8d4c84a4bd629	approved	2026-09-30 09:14:51.059384+00
197	1	https://www.openstreetmap.org/node/5506699714	{"id": 5506699714, "lat": -6.8773023, "lon": 107.5947081, "tags": {"fee": "yes", "name": "Bandung Science Center", "phone": "+62222060412", "tourism": "museum", "facebook": "https://m.facebook.com/bandungsciencecenter", "addr:street": "Jalan Sirnagalih", "opening_hours": "Mo-Su 09:00-17:00", "addr:housenumber": "15"}, "type": "node", "_source": "overpass_osm"}	b2229b7be9ae4b8b6cf4148398270247ba24ec063294899cfc34ab33a1d5a8e4	approved	2026-09-30 09:14:51.059384+00
198	1	https://www.openstreetmap.org/node/5554688585	{"id": 5554688585, "lat": -6.9025816, "lon": 107.6190825, "tags": {"fee": "yes", "name": "Museum Gedung Sate", "phone": "+62224267753", "tourism": "museum", "website": "http://museumgedungsate.jabarprov.go.id", "wikidata": "Q108991304", "wheelchair": "yes", "addr:street": "Jalan Diponegoro", "opening_hours": "Tu-Su 09:30-16:00", "addr:housenumber": "22"}, "type": "node", "_source": "overpass_osm"}	e3bf1e17c4c88ebc52b967b9a6c6a174e13aaa0506b2546597ff251fea24d67c	approved	2026-09-30 09:14:51.059384+00
199	1	https://www.openstreetmap.org/node/5564292643	{"id": 5564292643, "lat": -6.9043663, "lon": 107.6043675, "tags": {"name": "Patung Maung Bandung", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	a7556e0c2c883c5db3baa918cfd2d0650a323e3ebe33faea1c951d3d5a38bceb	approved	2026-09-30 09:14:51.059384+00
200	1	https://www.openstreetmap.org/node/5586548849	{"id": 5586548849, "lat": -6.9020925, "lon": 107.6198013, "tags": {"fee": "no", "name": "Museum Pos Indonesia", "name:en": "Indonesia Postal Museum", "tourism": "museum", "wikidata": "Q10986546", "addr:city": "Bandung", "wikipedia": "id:Museum Pos", "addr:street": "Jalan Cilaki", "opening_hours": "Mo-Fr 08:00-16:00; Sa 09:00-13:00", "addr:housenumber": "73", "wikimedia_commons": "File:Kantor Pusat Pos Indonesia.JPG"}, "type": "node", "_source": "overpass_osm"}	8b2c7940a7c1a2fce111c700229235698eddbc5cc92c35c287fe4dcd471c3d1f	approved	2026-09-30 09:14:51.059384+00
201	1	https://www.openstreetmap.org/node/5591673207	{"id": 5591673207, "lat": -6.8783006, "lon": 107.5951986, "tags": {"name": "Karang Setra", "leisure": "water_park", "alt_name": "Bandung Carnival Land"}, "type": "node", "_source": "overpass_osm"}	60cf1150ae0726844107c4ed9fe3fb8e126f966d9fe2e65091901cbc2f7ab5ac	approved	2026-09-30 09:14:51.059384+00
202	1	https://www.openstreetmap.org/node/5638762921	{"id": 5638762921, "lat": -6.9238106, "lon": 107.7061898, "tags": {"name": "Jalan Sukamaju", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	05fafb1ef1d12b5251ded6d46f70f92b0d65fbc40c8ced050e88d1175403ad3d	approved	2026-09-30 09:14:51.059384+00
203	1	https://www.openstreetmap.org/node/5654460921	{"id": 5654460921, "lat": -6.9137166, "lon": 107.6437018, "tags": {"name": "Flyover Pelangi Antapani", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	603fdd75aeaceaec5ca40a8c6a62d3b6f5fafcbad58b4d09ab50c09f1b71380d	approved	2026-09-30 09:14:51.059384+00
204	1	https://www.openstreetmap.org/node/5686426821	{"id": 5686426821, "lat": -6.9492258, "lon": 107.5940721, "tags": {"name": "Shoes and bags shopping street", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	c18d03a1f46ff01f92ab981e10bd1102a1f7b1ec2bd9d96d24de208ed7f8dc05	approved	2026-09-30 09:14:51.059384+00
205	1	https://www.openstreetmap.org/node/5698297022	{"id": 5698297022, "lat": -6.9256193, "lon": 107.6185057, "tags": {"name": "Pondok E7", "phone": "+62 821 2197 9826", "tourism": "hostel", "addr:street": "Jalan Emung", "internet_access": "wlan", "addr:housenumber": "7"}, "type": "node", "_source": "overpass_osm"}	7de086ef1809d325057b34bdc7dcdd897f364ad2d448e3e01f33f40f99f0bae7	approved	2026-09-30 09:14:51.059384+00
206	1	https://www.openstreetmap.org/node/5750040967	{"id": 5750040967, "lat": -6.8934438, "lon": 107.5872882, "tags": {"name": "Aston Pasteur", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8201d532caded3c925be67c2a00d8ff223560661802bcbb69a641a9044319541	approved	2026-09-30 09:14:51.059384+00
207	1	https://www.openstreetmap.org/node/5778956253	{"id": 5778956253, "lat": -6.9400217, "lon": 107.6450405, "tags": {"name": "Gedung Denzibang", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	bb4f19c703fe43c270be899749d5f7af6e9c31e5870d2843255db2f9a33d0ac5	approved	2026-09-30 09:14:51.059384+00
208	1	https://www.openstreetmap.org/node/5824553653	{"id": 5824553653, "lat": -6.907019, "lon": 107.6860279, "tags": {"name": "Perumahan Sukaasih", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	871bb16899d3e84f7dfa9230425d717bede7d7d261c1175c5fb89c147cfc5c8d	approved	2026-09-30 09:14:51.059384+00
209	1	https://www.openstreetmap.org/node/5833680550	{"id": 5833680550, "lat": -6.8669072, "lon": 107.6034675, "tags": {"name": "The House Tour Hotel", "rooms": "20", "smoking": "separated", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Panumbang Jaya", "addr:postcode": "40142", "internet_access": "wlan", "addr:housenumber": "5"}, "type": "node", "_source": "overpass_osm"}	27af39b3c414c5921d7b9ccdc851612e26887a519afa9832b5c445db570d6462	approved	2026-09-30 09:14:51.059384+00
225	1	https://www.openstreetmap.org/node/6725832656	{"id": 6725832656, "lat": -6.9099799, "lon": 107.6149205, "tags": {"name": "Patung Inovasi", "historic": "memorial", "material": "stone", "memorial": "statue", "description": "Triangle of managing Bandung: Innovation, decentralization, and collaboration."}, "type": "node", "_source": "overpass_osm"}	88253c5d5bb31f012fc9d4e6e56e9d670dc08ddf5152daaff798726ef3cc6119	approved	2026-09-30 09:14:51.059384+00
210	1	https://www.openstreetmap.org/node/5849852581	{"id": 5849852581, "lat": -6.9103665, "lon": 107.5979685, "tags": {"name": "Bobopod Paskal", "brand": "Bobobox", "email": "info@bobobox.co.id", "phone": "+62224266430", "rooms": "62", "stars": "0", "smoking": "outside", "tourism": "hotel", "website": "https://bobobox.co.id/", "operator": "PT. Bobobox Mitra Indonesia", "addr:city": "Bandung", "start_date": "07/01/2018", "addr:street": "Jalan HOS. Tjokroaminoto", "description": "Bobobox is the first high technology capsule hotel in Indonesia.", "payment:cash": "yes", "payment:visa": "yes", "addr:postcode": "40171", "internet_access": "wlan", "payment:maestro": "yes", "addr:housenumber": "76A", "payment:gpn_debit": "yes", "payment:mastercard": "yes", "payment:visa_debit": "yes", "internet_access:fee": "no", "payment:visa_electron": "yes"}, "type": "node", "_source": "overpass_osm"}	a737368085d2164a1c23fa5b31318118dfc6e3e6d9fb51638eb5a710626f0bf7	approved	2026-09-30 09:14:51.059384+00
211	1	https://www.openstreetmap.org/node/5885293835	{"id": 5885293835, "lat": -6.9348098, "lon": 107.6632081, "tags": {"name": "Hall of Fame Jawa Barat", "name:en": "Hall of Fame West Java", "tourism": "museum", "opening_hours": "Mo-Sa 08:00-17:00"}, "type": "node", "_source": "overpass_osm"}	ca5c6d17976486ee77562723e2032a9fa453d8e427f278ffd3aa08a620f7af93	approved	2026-09-30 09:14:51.059384+00
212	1	https://www.openstreetmap.org/node/6009237968	{"id": 6009237968, "lat": -6.8892711, "lon": 107.603128, "tags": {"name": "Lapang Karet", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	ef50fe433483041a170052f821915eef58b9637a148b13f2744b0349b24e5241	approved	2026-09-30 09:14:51.059384+00
213	1	https://www.openstreetmap.org/node/6123051585	{"id": 6123051585, "lat": -6.9216966, "lon": 107.6242637, "tags": {"name": "Jalan Cipaera", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	ec934f214faedbc76fd28f76bfdb456225e14dcdf676e457b224c4021812d08a	approved	2026-09-30 09:14:51.059384+00
214	1	https://www.openstreetmap.org/node/6149684552	{"id": 6149684552, "lat": -6.8982253, "lon": 107.6128252, "tags": {"name": "Dago Car Free Day", "tourism": "attraction", "description": "Road closed for cars and street full of food, music, dance and other activities.", "opening_hours": "Su 06:00-10:00"}, "type": "node", "_source": "overpass_osm"}	dced75cf94be6e6db8b8fe72c14ec4b44b034736a506dfab554a4eade3bafb02	approved	2026-09-30 09:14:51.059384+00
215	1	https://www.openstreetmap.org/node/6151203590	{"id": 6151203590, "lat": -6.8806352, "lon": 107.6040432, "tags": {"name": "Hotel Harris", "brand": "Harris", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9dcea98b2e5661572ebcd72475a6b80f4ee77065acec940aef4cdb03f9588865	approved	2026-09-30 09:14:51.059384+00
216	1	https://www.openstreetmap.org/node/6155111485	{"id": 6155111485, "lat": -6.9117485, "lon": 107.6245674, "tags": {"name": "Rusun Tongkeng", "tourism": "apartment"}, "type": "node", "_source": "overpass_osm"}	5748903f955edb487f32b355babdf78250a3797ec38ae96512202e5dbb7ab0de	approved	2026-09-30 09:14:51.059384+00
217	1	https://www.openstreetmap.org/node/6265263186	{"id": 6265263186, "lat": -6.919637, "lon": 107.6304563, "tags": {"name": "Jalan Majalengka Dalam", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	dbb731cfab3d6aa6fa8f84c973cd847746e9f53faee5756f57150838196362c4	approved	2026-09-30 09:14:51.059384+00
218	1	https://www.openstreetmap.org/node/6278571391	{"id": 6278571391, "lat": -6.9098781, "lon": 107.5980272, "tags": {"name": "Pinisi Backpacker", "email": "paskal@pinisirelaxation.com", "phone": "+622286868610", "tourism": "hostel", "website": "http://www.pinisibackpacker.com", "addr:street": "Jalan Musen", "addr:postcode": "40173", "opening_hours": "Mo-Su 08:00-23:00", "internet_access": "wlan", "addr:housenumber": "92 / 6A"}, "type": "node", "_source": "overpass_osm"}	8a7a3d8be5074690e58abca7940f415ab035746a8067979ed433aaa03c27d2ef	approved	2026-09-30 09:14:51.059384+00
219	1	https://www.openstreetmap.org/node/6342441385	{"id": 6342441385, "lat": -6.8923537, "lon": 107.6207279, "tags": {"name": "Jalan Sukasari II", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	77f5ea7e07ee3dbbb47b6502601b17ebb49406c6070549b0e90bc117c63acb7c	approved	2026-09-30 09:14:51.059384+00
220	1	https://www.openstreetmap.org/node/6466097818	{"id": 6466097818, "lat": -6.9106346, "lon": 107.5692022, "tags": {"name": "Tugu Selamat Datang di Kota Bandung", "access": "yes", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	0f3e0ff6af605fe3a27085bbfe55beb1bc8cafcab8157ac47623689324800df8	approved	2026-09-30 09:14:51.059384+00
221	1	https://www.openstreetmap.org/node/6657073006	{"id": 6657073006, "lat": -6.8943292, "lon": 107.6839832, "tags": {"ele": "793", "name": "Kebun Dinas Sindanglaya", "phone": "+62 22 7831 287", "access": "permissive", "leisure": "garden", "website": "https://bpbtpbdg.wordpress.com/?s=sindanglaya", "operator": "Balai Pengembangan dan Produksi Benih Perkebunan (BPPBP)", "description": "Kebun Dinas Sindanglaya. Kebun Dinas Sindanglaya berlokasi di Kelurahan Sindangjaya, Kecamatan Mandalajati, Kota Bandung, mempunyai fungsi kebun sebagai kebun produksi dan kebun koleksi seluas 1,84 ha, dengan komoditas yang dikembangkan 12 Komoditas"}, "type": "node", "_source": "overpass_osm"}	cbc7034e57521e97d01fcaa1d34516dee1c289d2122e97bf8e2b4194ce27cd62	approved	2026-09-30 09:14:51.059384+00
222	1	https://www.openstreetmap.org/node/6714107763	{"id": 6714107763, "lat": -6.9006473, "lon": 107.6228648, "tags": {"fee": "no", "name": "Museum Perbendaharaan", "name:en": "Treasury museum", "tourism": "museum", "addr:street": "Jalan Diponegoro", "opening_hours": "Mo, Sa, Su 09:00-16:00", "addr:housenumber": "45B"}, "type": "node", "_source": "overpass_osm"}	97daf91a74e689f234611aade552bbd6e0d114e14dd88810a4cb4e2dddd83936	approved	2026-09-30 09:14:51.059384+00
223	1	https://www.openstreetmap.org/node/6725618307	{"id": 6725618307, "lat": -6.9141709, "lon": 107.6070778, "tags": {"name": "Kereta Api TD 1002", "name:en": "Steam locomotive", "historic": "locomotive", "description": "Steam locomotive Werkspoor TD1002 was used on 600 mm railroad rail built by the Dutch East Indies Staatsspoorwegen (SS), around Cikampek and Krawang in 1912-1920. SS brought 3 units of TD10 steam locomotive from Werkspoor factory in 1926.", "opening_hours": "24/7"}, "type": "node", "_source": "overpass_osm"}	5c9ad78bcfe66fda40dcf5572ca3c4301cd381086a8e62065cf1f326dfef9ecb	approved	2026-09-30 09:14:51.059384+00
224	1	https://www.openstreetmap.org/node/6725758915	{"id": 6725758915, "lat": -6.9199749, "lon": 107.6176886, "tags": {"name": "Zerotoys Museum Mainan", "name:en": "Zerotoys Toy Museum", "tourism": "museum", "website": "https://m.facebook.com/zerotoys", "addr:street": "Jalan Sunda", "opening_hours": "Mo-We, Fr-Su 11:00-20:00", "addr:housenumber": "39a"}, "type": "node", "_source": "overpass_osm"}	abb01e8f32947b558a43b2d1e146c7bc6a30e643eb4ae409b74e43d3b17c1a3a	approved	2026-09-30 09:14:51.059384+00
245	1	https://www.openstreetmap.org/node/9805277511	{"id": 9805277511, "lat": -6.9232784, "lon": 107.6098741, "tags": {"name": "Hotel Pangarang Sari", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	fe17d503d411307316c97f36eb4ac8b7522c5bd4dbdaad3b48d612fa87e40f09	approved	2026-09-30 09:14:51.059384+00
226	1	https://www.openstreetmap.org/node/6777587530	{"id": 6777587530, "lat": -6.8858561, "lon": 107.6057267, "tags": {"name": "Kos Pak H.E Sukendar", "tourism": "guest_house", "addr:street": "Jl. Siliwangi Dalam Gang 3 No.19 RT08/RW01, Cipaganti, Coblong, Bandung", "addr:housenumber": "19"}, "type": "node", "_source": "overpass_osm"}	1a49c4ba4d521293d49c099b8a0914e8de6c96df93344258ed5e1e935b4dacd1	approved	2026-09-30 09:14:51.059384+00
227	1	https://www.openstreetmap.org/node/6854504885	{"id": 6854504885, "lat": -6.8957688, "lon": 107.567658, "tags": {"name": "Home Mr Syarif Bastaman", "tourism": "guest_house", "addr:street": "Jalan Dakota", "addr:housenumber": "A20"}, "type": "node", "_source": "overpass_osm"}	2bc031ff2d58fed042b25754378676eaf4d780d87b156973811945b9a479fb4c	approved	2026-09-30 09:14:51.059384+00
228	1	https://www.openstreetmap.org/node/7076351776	{"id": 7076351776, "lat": -6.9071595, "lon": 107.5958223, "tags": {"name": "Ostel by Ostic", "tourism": "guest_house", "wikidata": "Q111078139", "addr:street": "Jalan Tanjung Anom", "addr:housenumber": "12"}, "type": "node", "_source": "overpass_osm"}	7366956c09bf4c3dfe1f44df1c07dffdf756be48cbd056fb46b8dd5b6692e6ea	approved	2026-09-30 09:14:51.059384+00
229	1	https://www.openstreetmap.org/node/7081714941	{"id": 7081714941, "lat": -6.9065098, "lon": 107.6091, "tags": {"name": "Serelah", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d4d710dcb0f32171de3ed8373a03490bff8b42da3ddd5d0d35d700296068873a	approved	2026-09-30 09:14:51.059384+00
230	1	https://www.openstreetmap.org/node/7081727464	{"id": 7081727464, "lat": -6.9037995, "lon": 107.5982038, "tags": {"name": "Yokotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	111e52680e263b7e62154e2a44b0d6a6d5c22ea9df38706444f4d7f5c964c7a4	approved	2026-09-30 09:14:51.059384+00
231	1	https://www.openstreetmap.org/node/7083339722	{"id": 7083339722, "lat": -6.9103103, "lon": 107.6098121, "tags": {"fee": "no", "name": "Bandung Planning Gallery", "tourism": "museum", "opening_hours": "Mo-Sa 09:00-16:00"}, "type": "node", "_source": "overpass_osm"}	48d3928ea51a6df5f216a798fd0cc5e6a2f2d30b41bc83d143ad4db38352c676	approved	2026-09-30 09:14:51.059384+00
232	1	https://www.openstreetmap.org/node/7087017045	{"id": 7087017045, "lat": -6.8919497, "lon": 107.5695634, "tags": {"name": "Sukaraja", "tourism": "guest_house"}, "type": "node", "_source": "overpass_osm"}	8ec8f4c44cf0f3cae2aaeee4fdf3d04fccb8115ac4bf3432b4d95a2382ba2d11	approved	2026-09-30 09:14:51.059384+00
233	1	https://www.openstreetmap.org/node/7246694685	{"id": 7246694685, "lat": -6.8893846, "lon": 107.6205837, "tags": {"name": "Mesjid Al-Hidayah", "amenity": "place_of_worship", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	8adeb8322468f6ab3dfa9d9621ea83992cf0b3472bf458380c58d4fd74399d2b	approved	2026-09-30 09:14:51.059384+00
234	1	https://www.openstreetmap.org/node/7466927526	{"id": 7466927526, "lat": -6.8922483, "lon": 107.6250383, "tags": {"name": "Lapangan Volly Sadang Serang", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	f9d5d057381a5c5914ef16837600cd4271a47685a6c195a4581a6445f6e62652	approved	2026-09-30 09:14:51.059384+00
235	1	https://www.openstreetmap.org/node/7466927551	{"id": 7466927551, "lat": -6.8927674, "lon": 107.6246856, "tags": {"name": "Lapangan Bulutangkis", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	151134218588d33d5bf21222d1112f0eface8d35c99f479bf1dd52f04b250403	approved	2026-09-30 09:14:51.059384+00
257	1	https://www.openstreetmap.org/node/9805777954	{"id": 9805777954, "lat": -6.8818003, "lon": 107.5812672, "tags": {"name": "Setrasari Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	069e3e584e4ddafaf07e02e7febc716440ec2dfb4f8d4c6ce9288c1ac106d015	approved	2026-09-30 09:14:51.059384+00
236	1	https://www.openstreetmap.org/node/7661595392	{"id": 7661595392, "lat": -6.9042201, "lon": 107.6104174, "tags": {"name": "Courtyard Bandung Dago", "brand": "Courtyard", "rooms": "192", "tourism": "hotel", "addr:city": "Bandung", "check_date": "2026-03-14", "addr:street": "Jalan Ir H Juanda", "addr:postcode": "40116", "official_name": "Courtyard by Marriott", "brand:wikidata": "Q1053170", "addr:housenumber": "33"}, "type": "node", "_source": "overpass_osm"}	cac58149584ceb43c0fe1859161c2e49affe1f300c71fe9ce70d8053f2346a7c	approved	2026-09-30 09:14:51.059384+00
237	1	https://www.openstreetmap.org/node/7661597002	{"id": 7661597002, "lat": -6.9003149, "lon": 107.612072, "tags": {"name": "Moxy Bandung", "brand": "Moxy", "rooms": "109", "stars": "3", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Ir H Djuanda", "addr:postcode": "40116", "brand:wikidata": "Q70287020", "addr:housenumber": "69"}, "type": "node", "_source": "overpass_osm"}	ea92e86c2ab3d8b7daac193f4d4c6ef1a238edd3481a6d6699ddb4836dd92752	approved	2026-09-30 09:14:51.059384+00
238	1	https://www.openstreetmap.org/node/7890431757	{"id": 7890431757, "lat": -6.9013094, "lon": 107.5991223, "tags": {"name": "ottenway hostel", "brand": "ottenway hostel", "tourism": "motel"}, "type": "node", "_source": "overpass_osm"}	9851d0527e30f329ac7e737c3c416901934b1fa0ee6982df071018a3e877d8de	approved	2026-09-30 09:14:51.059384+00
239	1	https://www.openstreetmap.org/node/8050910212	{"id": 8050910212, "lat": -6.8557726, "lon": 107.6214015, "tags": {"name": "Kost Putra Nyalindung ITB", "tourism": "guest_house", "addr:street": "PPR ITB Blok L, Jalan Nyalindung , 40142", "description": "A dorm / flat for students of Institut Teknologi Bandung, and or other universities.", "opening_hours": "Mo-Su 08:00-16:00, 08:00-16:00", "addr:housenumber": "4"}, "type": "node", "_source": "overpass_osm"}	5db2d7bb9437a092eabf62580d26510fc18d2fa15bcd8d05891b50685aba3298	approved	2026-09-30 09:14:51.059384+00
240	1	https://www.openstreetmap.org/node/8434131078	{"id": 8434131078, "lat": -6.9220421, "lon": 107.6780591, "tags": {"name": "Taman Permata Permai", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	1dd30958f987d37f0e0a6687560b5ecb984810fb76247ec52a7cc68f25ddd5a5	approved	2026-09-30 09:14:51.059384+00
241	1	https://www.openstreetmap.org/node/9269437521	{"id": 9269437521, "lat": -6.9358185, "lon": 107.6027267, "tags": {"name": "Bandung Lautan Api", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	3d38d6be7403e06889b13c86f4eebcf74ab546e63a68a694b28a67663aa9dd20	approved	2026-09-30 09:14:51.059384+00
242	1	https://www.openstreetmap.org/node/9726770690	{"id": 9726770690, "lat": -6.9354175, "lon": 107.7192431, "tags": {"name": "Open Space", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	a2062c4b2cd4f1db4ab2cdcd5b5d5aeb2ea24e7870233fd1ffe1f1a0ef42c02c	approved	2026-09-30 09:14:51.059384+00
243	1	https://www.openstreetmap.org/node/9800515672	{"id": 9800515672, "lat": -6.9328758, "lon": 107.5905365, "tags": {"name": "Hotel Santika Pasir Koja", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9c97f342e5f5234d64aaabf92ca54829cdbca78a50e5e719a32db7fa2e132255	approved	2026-09-30 09:14:51.059384+00
244	1	https://www.openstreetmap.org/node/9803556199	{"id": 9803556199, "lat": -6.9114101, "lon": 107.597972, "tags": {"name": "Zodiak Taurus Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	94e43d03ff43f1ba9f37de6f349d2c2dd76a23876670a27ae55d03b22d64023d	approved	2026-09-30 09:14:51.059384+00
246	1	https://www.openstreetmap.org/node/9805299566	{"id": 9805299566, "lat": -6.8897003, "lon": 107.5781911, "tags": {"name": "Cassadua Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	c919570ea9e151062800ba51476fbd6f44de3f487b3520891a024e1797132b2a	approved	2026-09-30 09:14:51.059384+00
247	1	https://www.openstreetmap.org/node/9805312659	{"id": 9805312659, "lat": -6.9138883, "lon": 107.6338258, "tags": {"name": "Hotel Bandung Permai", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	40fe693949295c8d80e02dd0250606325b9130bf1b176dfc813a2e8301eaabb9	approved	2026-09-30 09:14:51.059384+00
248	1	https://www.openstreetmap.org/node/9805316457	{"id": 9805316457, "lat": -6.8807048, "lon": 107.599154, "tags": {"name": "Hemangini Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	86fbe56b08478e44d45e1169845c58d5e7bca74e5a2d50ba3fbcf9ce2a704fc6	approved	2026-09-30 09:14:51.059384+00
249	1	https://www.openstreetmap.org/node/9805337893	{"id": 9805337893, "lat": -6.8700507, "lon": 107.6076831, "tags": {"name": "Art Deco Luxury Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	86b09bf35f60598fc18809bb8b5512cbe1499d1df747ff2d27b7db415b94535e	approved	2026-09-30 09:14:51.059384+00
250	1	https://www.openstreetmap.org/node/9805348926	{"id": 9805348926, "lat": -6.9311501, "lon": 107.6126483, "tags": {"name": "Hotel Image", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d69cc023981361f14f13069dd9feb3800dc83267ba6c80a38878587ba82d1614	approved	2026-09-30 09:14:51.059384+00
251	1	https://www.openstreetmap.org/node/9805414865	{"id": 9805414865, "lat": -6.8725627, "lon": 107.5889075, "tags": {"name": "Hotel Ammeerra", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	45867672ab028cb99e74d10f176a619e59ff2a020065a28a5cb5a518f2ff166a	approved	2026-09-30 09:14:51.059384+00
252	1	https://www.openstreetmap.org/node/9805536597	{"id": 9805536597, "lat": -6.9124558, "lon": 107.603268, "tags": {"name": "Geary Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d8c3f92c16ec7804bff2a40a13534a9d98b6bb3d1cce9a3972648df455ffaba7	approved	2026-09-30 09:14:51.059384+00
253	1	https://www.openstreetmap.org/node/9805540456	{"id": 9805540456, "lat": -6.8990997, "lon": 107.6042331, "tags": {"name": "Kembang Hotel Cihampelas Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	a6bf0f66f46fe5b6d04abd6a90969c56fe737bcdbfa43d52eff919dd0f80ec19	approved	2026-09-30 09:14:51.059384+00
254	1	https://www.openstreetmap.org/node/9805578775	{"id": 9805578775, "lat": -6.9173347, "lon": 107.6068068, "tags": {"name": "Hotel Negla Sari Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	4653f47fd5f97ab040d20e3cdb484035c16fe8582c52e973a76936e91a9b8d4a	approved	2026-09-30 09:14:51.059384+00
255	1	https://www.openstreetmap.org/node/9805664420	{"id": 9805664420, "lat": -6.9114999, "lon": 107.6002599, "tags": {"name": "Hotel Unik Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	edd370799550c893f3bbdf5901259230d2f292ac92387439cf80e3ffdcbb3924	approved	2026-09-30 09:14:51.059384+00
256	1	https://www.openstreetmap.org/node/9805727870	{"id": 9805727870, "lat": -6.9343535, "lon": 107.6203907, "tags": {"name": "Hotel 10 Buah Batu", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	82373a900920ee66b4386c00b4e20047a97d2b55f828b435d647a3e4e4b8d1ee	approved	2026-09-30 09:14:51.059384+00
258	1	https://www.openstreetmap.org/node/9805811387	{"id": 9805811387, "lat": -6.9054342, "lon": 107.5989769, "tags": {"name": "Ruby Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	36668763afc561b7ef86f0adbf422db02deca70459c7231733a65ebf70f31d50	approved	2026-09-30 09:14:51.059384+00
259	1	https://www.openstreetmap.org/node/9807670497	{"id": 9807670497, "lat": -6.9250651, "lon": 107.6191501, "tags": {"name": "Sentra Inn Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	8a3e6b299f2e7283ea31c4c4e58b06f7f44dbb2344bf224c0f677586bfa7ce87	approved	2026-09-30 09:14:51.059384+00
260	1	https://www.openstreetmap.org/node/9807694443	{"id": 9807694443, "lat": -6.9547965, "lon": 107.5834362, "tags": {"name": "Hostel Intech Kopo 538", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9d29eb2d2c11109413372e93452f1248de96b5ccc4f4e1f412126b34d15824aa	approved	2026-09-30 09:14:51.059384+00
261	1	https://www.openstreetmap.org/node/9807795332	{"id": 9807795332, "lat": -6.8923149, "lon": 107.6317452, "tags": {"name": "Pratidina Business Residence", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	2c804408476e59cd6bf838bc0c9428811c6b926b4802cd98c8f479a76f80225e	approved	2026-09-30 09:14:51.059384+00
262	1	https://www.openstreetmap.org/node/9807817528	{"id": 9807817528, "lat": -6.9203601, "lon": 107.6100633, "tags": {"name": "De Braga By Artotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	fb4cc844751839f8b8f9caa32398e5807126c7f7788ea1b201bc0abfd0a4a2fc	approved	2026-09-30 09:14:51.059384+00
263	1	https://www.openstreetmap.org/node/9808094311	{"id": 9808094311, "lat": -6.9349796, "lon": 107.7176635, "tags": {"name": "Bunderan Cibiru", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	ad420971106f2c9e58e68da983ff88fc38952c0eb3176c3d5b6a2babdf80380d	approved	2026-09-30 09:14:51.059384+00
264	1	https://www.openstreetmap.org/node/9808104016	{"id": 9808104016, "lat": -6.943745, "lon": 107.621098, "tags": {"name": "Pass Hill House", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9b946f04a2d138cb16d1e08397b78929919b79ed9d3cb60bf52eecd1f9d1d54a	approved	2026-09-30 09:14:51.059384+00
265	1	https://www.openstreetmap.org/node/9809020563	{"id": 9809020563, "lat": -6.9207546, "lon": 107.6217651, "tags": {"name": "Greko Creative Hub Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6296fda7ec02b57d5b18f3737377e71ee59464006411e2260a31acab16d1eecb	approved	2026-09-30 09:14:51.059384+00
266	1	https://www.openstreetmap.org/node/9813954095	{"id": 9813954095, "lat": -6.9105986, "lon": 107.5688325, "tags": {"name": "OYO 2183 Cibeureum Residence", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	319dac417ef9be76f6b5d4ed1f730e3a974caf2637f69ba710a32467cb964dce	approved	2026-09-30 09:14:51.059384+00
267	1	https://www.openstreetmap.org/node/9816386508	{"id": 9816386508, "lat": -6.8887597, "lon": 107.6042216, "tags": {"name": "The Regia by Ultimo", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	9b51320002748c14881af24b59003012dd1601f85ef035c05c1239b2ccde50f1	approved	2026-09-30 09:14:51.059384+00
268	1	https://www.openstreetmap.org/node/9816492337	{"id": 9816492337, "lat": -6.9146486, "lon": 107.6129062, "tags": {"name": "Fox Harris Hotel Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d283eeef84d99ab80a9408ca9884a912fa6ed644fcbcbb4a7a70612b74f68972	approved	2026-09-30 09:14:51.059384+00
269	1	https://www.openstreetmap.org/node/9816621944	{"id": 9816621944, "lat": -6.9474505, "lon": 107.5952938, "tags": {"name": "Tugu Sepatu Cibaduyut", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	c03b678829ef091378b7416febf67477bff65a487217e3600d680286d3dc9399	approved	2026-09-30 09:14:51.059384+00
270	1	https://www.openstreetmap.org/node/9843372844	{"id": 9843372844, "lat": -6.9095807, "lon": 107.6114617, "tags": {"name": "U Janevalla Bandung", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	ee9d395ac97bfd0972af14c219ca4cbc891bb498127c710d9f9247926a68df9d	approved	2026-09-30 09:14:51.059384+00
271	1	https://www.openstreetmap.org/node/9938445753	{"id": 9938445753, "lat": -6.9155688, "lon": 107.6406431, "tags": {"name": "Kampung Korea Bandung", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	a0626e4db75832cd576fdff73b0c37b6a30188d01ad672110e47d354e82285d3	approved	2026-09-30 09:14:51.059384+00
272	1	https://www.openstreetmap.org/node/9938653539	{"id": 9938653539, "lat": -6.9165381, "lon": 107.6423465, "tags": {"name": "Taman Asia Africa", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	4faca4e11d31bb7c5125c825ac2d8f9768b6a48b3500953a42b57ab895f1b2d9	approved	2026-09-30 09:14:51.059384+00
273	1	https://www.openstreetmap.org/node/9942070649	{"id": 9942070649, "lat": -6.8857564, "lon": 107.5966206, "tags": {"name": "Taman Metrologi", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	628559df360a1d1e11bc94288a5f8791f8ebfbf41386a8cd403071ce4acc8cfb	approved	2026-09-30 09:14:51.059384+00
274	1	https://www.openstreetmap.org/node/9942077640	{"id": 9942077640, "lat": -6.8810174, "lon": 107.5989885, "tags": {"name": "Taman Gaya", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	0a02257b3667386c92cb6284c6e1bb811d87910c423d0550e518087977076498	approved	2026-09-30 09:14:51.059384+00
275	1	https://www.openstreetmap.org/node/9943969629	{"id": 9943969629, "lat": -6.9006929, "lon": 107.6045328, "tags": {"name": "Grandia", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	d0d37edfe2f98f088ae3821c6fbd1f3a7062f957798f23ffd8654922c930dc36	approved	2026-09-30 09:14:51.059384+00
276	1	https://www.openstreetmap.org/node/10277073758	{"id": 10277073758, "lat": -6.8912847, "lon": 107.6097021, "tags": {"name": "Tembok Ratapan", "website": "https://rinaldimunir.wordpress.com/2017/07/11/tembok-ratapan-di-kampus-itb/", "historic": "memorial", "memorial": "plaque"}, "type": "node", "_source": "overpass_osm"}	8b5ad0407c1cf023392ec1e4025ec1ac49abbbe3d6de2cd974dbcf521baed2cc	approved	2026-09-30 09:14:51.059384+00
277	1	https://www.openstreetmap.org/node/10280227881	{"id": 10280227881, "lat": -6.9405148, "lon": 107.6725146, "tags": {"name": "Museum Nike Ardilla", "phone": "+6281572115999", "tourism": "museum", "wikidata": "Q115794539", "addr:city": "Bandung", "addr:street": "Jalan Aria Utama", "addr:postcode": "40292", "addr:housenumber": "5"}, "type": "node", "_source": "overpass_osm"}	5d651ed19f9367920e7b2c4cf26193f316079e8c2fde5b4bc7897ecb8f2345db	approved	2026-09-30 09:14:51.059384+00
278	1	https://www.openstreetmap.org/node/10280251596	{"id": 10280251596, "lat": -6.9217089, "lon": 107.5773807, "tags": {"fee": "no", "name": "Museum Kebudayaan Tionghoa", "tourism": "museum", "wikidata": "Q115794648", "addr:city": "Bandung", "addr:street": "Jalan Nana Rohana", "addr:postcode": "40211", "addr:housenumber": "37"}, "type": "node", "_source": "overpass_osm"}	42b434f0e513c9a37efa0a2295e6b7a6d768e685380d17ad7735dc6d78676040	approved	2026-09-30 09:14:51.059384+00
279	1	https://www.openstreetmap.org/node/10284195908	{"id": 10284195908, "lat": -6.8848947, "lon": 107.6105402, "tags": {"name": "Sanggar Olah Seni Babakan Siliwangi", "tourism": "gallery"}, "type": "node", "_source": "overpass_osm"}	6af8a43be2a4b622b1122bdd950b0fdc7e62935fdc2c99b10f44c87ddcb0c68a	approved	2026-09-30 09:14:51.059384+00
280	1	https://www.openstreetmap.org/node/10284202116	{"id": 10284202116, "lat": -6.8924546, "lon": 107.6115175, "tags": {"name": "Galeri Soermardja", "tourism": "gallery", "wikidata": "Q65212157", "contact:instagram": "https://www.instagram.com/galeri_soemardja/?hl=en"}, "type": "node", "_source": "overpass_osm"}	dfa164082f06ec2166b39278a8b4221e5db67fb475e659962391f9185091f8e8	approved	2026-09-30 09:14:51.059384+00
281	1	https://www.openstreetmap.org/node/10653924700	{"id": 10653924700, "lat": -6.8887947, "lon": 107.6078554, "tags": {"name": "Galeri Kebun Seni Tamansari Bandung", "tourism": "gallery", "addr:city": "Bandung", "addr:street": "Jl. Tamansari, Lb. Siliwangi, Kec. Coblong", "addr:postcode": "40132"}, "type": "node", "_source": "overpass_osm"}	59352810dd626ade738f3c1e73f40925a2fb72ec4b9da20f5cf39faf266b10ce	approved	2026-09-30 09:14:51.059384+00
282	1	https://www.openstreetmap.org/node/10656979386	{"id": 10656979386, "lat": -6.9010128, "lon": 107.612598, "tags": {"name": "Gloya by Krida Nusantara", "tourism": "gallery", "addr:city": "Bandung", "wheelchair": "no", "addr:street": "Jalan Insinyur Haji Juanda", "addr:postcode": "40115", "addr:housenumber": "386"}, "type": "node", "_source": "overpass_osm"}	65a13e30348d6f0bb28e864dca2db93762a8512db9341252858fc658b4c5a373	approved	2026-09-30 09:14:51.059384+00
283	1	https://www.openstreetmap.org/node/10740506117	{"id": 10740506117, "lat": -6.9052842, "lon": 107.6287133, "tags": {"name": "Hotel Sanira", "phone": "+62 227208480", "tourism": "hotel", "alt_name": "RedDoorz @ Supratman Street", "addr:street": "Jalan W. R. Supratman", "opening_hours": "Mo-Su 14:00-12:00", "addr:housenumber": "37"}, "type": "node", "_source": "overpass_osm"}	30f7dd4c0a7ad3b841ce4a79d407bc09f67b94e7d102962837adc71bfb92b2c4	approved	2026-09-30 09:14:51.059384+00
284	1	https://www.openstreetmap.org/node/10793588346	{"id": 10793588346, "lat": -6.9211786, "lon": 107.6079663, "tags": {"name": "Kutipan Pidi Baiq", "tourism": "attraction", "inscription": "\\"Dan Bandung bagiku bukan cuma masalah geografis, lebih jauh dari itu melibatkan perasaan, yang bersamaku ketika sunyi\\" -Pidi Baiq"}, "type": "node", "_source": "overpass_osm"}	28ac2591d610b8b446ac7115a821c5132352f1b699612288cdf0e62f10873bf8	approved	2026-09-30 09:14:51.059384+00
285	1	https://www.openstreetmap.org/node/10793588347	{"id": 10793588347, "lat": -6.9213235, "lon": 107.6079412, "tags": {"name": "Kutipan M.A.W. Brouwer", "tourism": "attraction", "inscription": "\\"Bumi Pasundan lahir ketika Tuhan sedang tersenyum\\" -M.A.W. Brouwer"}, "type": "node", "_source": "overpass_osm"}	35c7c567a99235c744f6ddab9988f9923406b55e83c19a4509af52e48a24de4b	approved	2026-09-30 09:14:51.059384+00
286	1	https://www.openstreetmap.org/node/10796527130	{"id": 10796527130, "lat": -6.9278999, "lon": 107.7236, "tags": {"name": "Taman tingkat RW", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no", "garden:type": "green_wall"}, "type": "node", "_source": "overpass_osm"}	3cc051fd3f5333eaf79d8a158ef61648992a5903b0144f8292f32598d0ba6f61	approved	2026-09-30 09:14:51.059384+00
287	1	https://www.openstreetmap.org/node/10796580135	{"id": 10796580135, "lat": -6.9270659, "lon": 107.7223742, "tags": {"name": "RTH Posyandu Tanjung", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	65ef02e1a32210a2e430c6c43f65eed6b52dc0305dd3614c82a55c28bd6b019a	approved	2026-09-30 09:14:51.059384+00
288	1	https://www.openstreetmap.org/node/10796647093	{"id": 10796647093, "lat": -6.9038205, "lon": 107.7277225, "tags": {"name": "RTH Bukit Mbah Garut", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	c7e86dcc01c180bba6a3d22017419f3dd8596524a0e5c4d99d26dba002b29adb	approved	2026-09-30 09:14:51.059384+00
289	1	https://www.openstreetmap.org/node/10798900144	{"id": 10798900144, "lat": -6.912312, "lon": 107.647448, "tags": {"name": "Taman Sempadan Sungai Babakan Surabaya", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	2e7bd46d2ae132b774d01b2cf46ae118798e56c55d7cb529f65fcc735cf82042	approved	2026-09-30 09:14:51.059384+00
290	1	https://www.openstreetmap.org/node/10798911771	{"id": 10798911771, "lat": -6.9150466, "lon": 107.6492304, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	6c2a84afc78635e9a97136f55759e1bdc9e0cb67541749522798ed24e28c921d	approved	2026-09-30 09:14:51.059384+00
291	1	https://www.openstreetmap.org/node/10798912395	{"id": 10798912395, "lat": -6.9146832, "lon": 107.6492022, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	98ad7f07d1e804d985eaad041ce76538df2b08d41aa7d89d82138cd256327890	duplicate	2026-09-30 09:14:51.059384+00
292	1	https://www.openstreetmap.org/node/10798931990	{"id": 10798931990, "lat": -6.908489, "lon": 107.6471141, "tags": {"name": "Taman Bermain Anak Wisata Sungai", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	eb8c93ad127c0725e621a7e79b09ee4cc6d5ce0959cda3c1a09a65c9ff9e56fe	approved	2026-09-30 09:14:51.059384+00
293	1	https://www.openstreetmap.org/node/10798961359	{"id": 10798961359, "lat": -6.9394523, "lon": 107.6051268, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	d6549ffd29dceca7e312f34546c74a3a7719331e42069a34fda04bb6a31a5bfa	approved	2026-09-30 09:14:51.059384+00
294	1	https://www.openstreetmap.org/node/10798971702	{"id": 10798971702, "lat": -6.9394376, "lon": 107.60453, "tags": {"name": "Taman Lingkungan Kurdi Cempaka", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	7f322c73f40318a2a32482c7600ac1fab0029823df1b2d97756af2568cc96d1b	approved	2026-09-30 09:14:51.059384+00
295	1	https://www.openstreetmap.org/node/10798980720	{"id": 10798980720, "lat": -6.9441037, "lon": 107.6028362, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "abandoned": "yes", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	3f9dbc32b65e077eca03e57fca5a1c2da53339e8ab80c365929444fd69b961b5	approved	2026-09-30 09:14:51.059384+00
296	1	https://www.openstreetmap.org/node/10798991642	{"id": 10798991642, "lat": -6.9433842, "lon": 107.6045937, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	bd85de945dfa736293d426a31847f86edb72970576a80960c968613bd84ef059	approved	2026-09-30 09:14:51.059384+00
297	1	https://www.openstreetmap.org/node/10798991953	{"id": 10798991953, "lat": -6.9358099, "lon": 107.6030038, "tags": {"name": "Taman Lingkungan RW 03", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	beebe2b2bb4e740da3891c8a106b488632d994943b0322990e61e73ce5d81b9b	approved	2026-09-30 09:14:51.059384+00
298	1	https://www.openstreetmap.org/node/10798993838	{"id": 10798993838, "lat": -6.9432198, "lon": 107.6046527, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	0ddfed1b557ec63a6125318f2734e0f2e7817995b14f6e777c6171d77dabe091	duplicate	2026-09-30 09:14:51.059384+00
299	1	https://www.openstreetmap.org/node/10799012026	{"id": 10799012026, "lat": -6.9401951, "lon": 107.5994915, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	d69b05257c0872f92a4d24ebecc0c373e1029fcc6fa97aac147722ea15374cc4	approved	2026-09-30 09:14:51.059384+00
300	1	https://www.openstreetmap.org/node/10799022176	{"id": 10799022176, "lat": -6.9229707, "lon": 107.5954306, "tags": {"name": "Taman Ulekan BRI", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	9e2680fb2306b151cf8ebeef2aa7ec62e558681b4d408be7219765618238359c	approved	2026-09-30 09:14:51.059384+00
301	1	https://www.openstreetmap.org/node/10799032132	{"id": 10799032132, "lat": -6.9372477, "lon": 107.599407, "tags": {"name": "Taman Kali Citepus", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	d408162cd4d0234a79ce1d437788cd40e696bfa3c127f88b81a5f31916c8a73d	approved	2026-09-30 09:14:51.059384+00
302	1	https://www.openstreetmap.org/node/10799041423	{"id": 10799041423, "lat": -6.9251754, "lon": 107.5989973, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	077fd0e7a7c1cccf15c5506ab27b54f66aeb4799127136cd5414b5f827922afa	approved	2026-09-30 09:14:51.059384+00
303	1	https://www.openstreetmap.org/node/10799055980	{"id": 10799055980, "lat": -6.9235272, "lon": 107.5952777, "tags": {"name": "Taman Lingkungan RW", "source": "POI_WRI_Survey_2023", "leisure": "garden", "abandoned": "yes"}, "type": "node", "_source": "overpass_osm"}	8079062bc227d59be370e0bb076cdc0fcf35e2cde907d47a8b7b8858d155e3d3	approved	2026-09-30 09:14:51.059384+00
304	1	https://www.openstreetmap.org/node/10800366668	{"id": 10800366668, "lat": -6.9162981, "lon": 107.6162928, "tags": {"name": "RTH Sempadan Rel Kereta", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	1ba1fb8af53a0d7886f7f37518ebc61d8f57dc4ca82bd470678b0ce1aa512d18	approved	2026-09-30 09:14:51.059384+00
305	1	https://www.openstreetmap.org/node/10800368855	{"id": 10800368855, "lat": -6.8879289, "lon": 107.5824514, "tags": {"name": "Taman Bermain Anak", "source": "POI_WRI_Survey_2023", "leisure": "garden"}, "type": "node", "_source": "overpass_osm"}	219ef928330883d315a8dd1f576226951ce98368e6706dd7e1e111aa6ce9e3c1	approved	2026-09-30 09:14:51.059384+00
306	1	https://www.openstreetmap.org/node/10801192061	{"id": 10801192061, "lat": -6.9031762, "lon": 107.6329561, "tags": {"name": "Taman Bola", "source": "POI_WRI_Survey_2023", "leisure": "garden", "abandoned": "yes", "wheelchair": "no"}, "type": "node", "_source": "overpass_osm"}	6570066176e7ece00f940875dbfd4095b284e85e2225df3e1e1a6b6ce9e8f4a3	approved	2026-09-30 09:14:51.059384+00
307	1	https://www.openstreetmap.org/node/10996585701	{"id": 10996585701, "lat": -6.9083679, "lon": 107.6110814, "tags": {"name": "Seasons Playground", "leisure": "park", "operator": "Seasons Playground", "addr:city": "Kota Bandung", "addr:street": "Bandung Indah Plaza - Lantai 3, Jl. Merdeka No.56, Citarum, Kec. Bandung Wetan", "addr:postcode": "40115", "operator:type": "public", "addr:housenumber": "Lantai 3"}, "type": "node", "_source": "overpass_osm"}	b184f0a81a3fb95951e89b4212077f56dc16ad487a3f674e86e9a930f8434979	approved	2026-09-30 09:14:51.059384+00
308	1	https://www.openstreetmap.org/node/11047765437	{"id": 11047765437, "lat": -6.9065906, "lon": 107.6132795, "tags": {"name": "Lucia Premium Kost", "tourism": "hostel"}, "type": "node", "_source": "overpass_osm"}	b229c2cc9b6d984831ddfc52dcc86f5752f9fab70767afb4d95bfc42f744eeaa	approved	2026-09-30 09:14:51.059384+00
309	1	https://www.openstreetmap.org/node/11048805968	{"id": 11048805968, "lat": -6.9015419, "lon": 107.6187689, "tags": {"name": "Gedung Sate", "tourism": "viewpoint", "direction": "S", "advertising": "sign", "inscription": "Gedung Sate"}, "type": "node", "_source": "overpass_osm"}	581b2b23523856e14e211b9457bc729bdc39db682d017e28efb893d295650604	approved	2026-09-30 09:14:51.059384+00
310	1	https://www.openstreetmap.org/node/11052507720	{"id": 11052507720, "lat": -6.9064515, "lon": 107.6077688, "tags": {"name": "Bandung sister cities - Braunschweig", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	175edadaca45dbb2838ffd5a4a02d03c5375038914937404678bf1d19134a489	approved	2026-09-30 09:14:51.059384+00
311	1	https://www.openstreetmap.org/node/11052532594	{"id": 11052532594, "lat": -6.9011966, "lon": 107.6250958, "tags": {"name": "Tugu PKK", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	31b291967bdb26254e1cb94130383c77aea9649a5ce00953a55d05cf363afcd6	approved	2026-09-30 09:14:51.059384+00
312	1	https://www.openstreetmap.org/node/11061286364	{"id": 11061286364, "lat": -6.9199099, "lon": 107.6313852, "tags": {"name": "Train", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	fd9834997b103dc429460e0c1f5e381449f46276b32d1afb327452bd4489ae2d	approved	2026-09-30 09:14:51.059384+00
313	1	https://www.openstreetmap.org/node/11064477660	{"id": 11064477660, "lat": -6.9007876, "lon": 107.6175076, "tags": {"name": "ibis Styles", "brand": "Ibis Styles", "stars": "3", "tourism": "hotel", "brand:wikidata": "Q3147425"}, "type": "node", "_source": "overpass_osm"}	b4c26117ff760d6072f43e146d10fb0d7894422d104e30377756a131c270c781	approved	2026-09-30 09:14:51.059384+00
314	1	https://www.openstreetmap.org/node/11064992945	{"id": 11064992945, "lat": -6.9232638, "lon": 107.6134721, "tags": {"name": "Lengkong Night Street Food", "tourism": "attraction", "opening_hours": "Mo-Su 18:00-00:00"}, "type": "node", "_source": "overpass_osm"}	2cf603186a2c9ca34c7edc304abf5479c5fd6d2dfb7f181306832c8304124316	approved	2026-09-30 09:14:51.059384+00
315	1	https://www.openstreetmap.org/node/11070277751	{"id": 11070277751, "lat": -6.9238563, "lon": 107.6112694, "tags": {"name": "Mercure Bandung City Centre", "stars": "4", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	2fffc8ed5b7d88a5f3fb1a647d482f3eabfdbfefb67e8f50125005a666b72c03	approved	2026-09-30 09:14:51.059384+00
316	1	https://www.openstreetmap.org/node/11337699136	{"id": 11337699136, "lat": -6.9375474, "lon": 107.6094128, "tags": {"name": "Patung Ikan", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	3ad305366a36463f50915bfabbd98d023d81e90dd6c38a5763e65739a3e06331	approved	2026-09-30 09:14:51.059384+00
317	1	https://www.openstreetmap.org/node/11415319631	{"id": 11415319631, "lat": -6.9179729, "lon": 107.5976408, "tags": {"name": "Saritem Redlight Disrtict", "min_age": "18", "name:ja": "πé╡πâ¬πâåπâáτ╜«σ▒ïΦíù", "name:ko": "δºñ∞¥îΩ╡┤ ∞ºæ∞ñæ ∞ºÇ∞ù¡", "name:zh": "σªôΘÖóΘ¢åΣ╕¡σî║σƒƒ", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	8160b85b19b1bd86676ef127c74cd6c5f3ad4125c23cb7b6955e85a07fc24314	approved	2026-09-30 09:14:51.059384+00
318	1	https://www.openstreetmap.org/node/11459991301	{"id": 11459991301, "lat": -6.9229338, "lon": 107.6734935, "tags": {"name": "Kelompok Seni Tani", "leisure": "garden", "education": "courses"}, "type": "node", "_source": "overpass_osm"}	62395c1dd9fab13dd4a430c837ac4447e2390c59e31da5ff534467a5328a9120	approved	2026-09-30 09:14:51.059384+00
319	1	https://www.openstreetmap.org/node/11491738070	{"id": 11491738070, "lat": -6.885727, "lon": 107.6189392, "tags": {"name": "Kostan Syifa", "tourism": "apartment"}, "type": "node", "_source": "overpass_osm"}	d6801a09365dc96858eea1e5eccc3a4388aa6ff866a4c01310c60fd4020be4ce	approved	2026-09-30 09:14:51.059384+00
320	1	https://www.openstreetmap.org/node/11539070161	{"id": 11539070161, "lat": -6.9552652, "lon": 107.6986145, "tags": {"name": "Atrium Cibadag", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	08ed50287fea51ebe1f3b9dfa42292dba749b157546a54088be077c08789f578	approved	2026-09-30 09:14:51.059384+00
321	1	https://www.openstreetmap.org/node/11539070162	{"id": 11539070162, "lat": -6.9544364, "lon": 107.6982601, "tags": {"name": "Atrium Cileutik", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	a0129b0fab7f0ac93012d0455b71c8201d6df8237193fd8baca71747c0ddf184	approved	2026-09-30 09:14:51.059384+00
322	1	https://www.openstreetmap.org/node/11539070163	{"id": 11539070163, "lat": -6.9558207, "lon": 107.697333, "tags": {"name": "Atrium Ciunik", "tourism": "viewpoint"}, "type": "node", "_source": "overpass_osm"}	98d5f5217eb54405d5992c4690b76ff5caf70fb8022c3b086323d71770ce05b2	approved	2026-09-30 09:14:51.059384+00
323	1	https://www.openstreetmap.org/node/11546593921	{"id": 11546593921, "lat": -6.8736512, "lon": 107.6080358, "tags": {"name": "Kost Bu Nia", "email": "farizzia32@gmail.com", "phone": "+6282116959928", "rooms": "11", "tourism": "hostel", "website": "https://mamikos.com/room/kost-kota-bandung-kost-campur-murah-kost-bu-nia-cidadap-bandung-2", "operator": "Mohammad Fariz Zia", "addr:city": "Bandung", "addr:street": "Jalan Rancabentang II", "guest_house": "guest_house", "addr:postcode": "40142", "internet_access": "yes", "addr:housenumber": "No.1", "internet_access:fee": "customers"}, "type": "node", "_source": "overpass_osm"}	b23d63fbc54a52bf4f1bdb36c906825c4cb9ca2af5ced54d034b9ef090880c19	approved	2026-09-30 09:14:51.059384+00
324	1	https://www.openstreetmap.org/node/11608070660	{"id": 11608070660, "lat": -6.9164956, "lon": 107.5988392, "tags": {"name": "Gino Feruci Kebonjati Hotel", "name:ja": "πé╕πâÄ πâòπéºπâ½πâü πé▒πâ£πâ│ πé╕πâúπâåπéú πâÉπâ│πâëπâ│", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	1a2217d5cc8a62a936bfa3c695f16be9f55ae0fc6249c9561bea8c2f478fffc4	approved	2026-09-30 09:14:51.059384+00
325	1	https://www.openstreetmap.org/node/11915115699	{"id": 11915115699, "lat": -6.8828173, "lon": 107.5794872, "tags": {"name": "Skyland Guest House Bandung", "smoking": "outside", "tourism": "hotel", "wheelchair": "no", "internet_access": "wlan", "internet_access:fee": "no", "internet_access:ssid": "SKYLAND_T1;SKYLAND_T2"}, "type": "node", "_source": "overpass_osm"}	a63313c68c9923038308e0fa6eaac249dd8881c8a70312ac5a1b3fafdbc16203	approved	2026-09-30 09:14:51.059384+00
326	1	https://www.openstreetmap.org/node/11984843791	{"id": 11984843791, "lat": -6.9111293, "lon": 107.6059106, "tags": {"name": "Little Mykonos", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	f736fd4b208773cb413238bfae0976f1e69ef2bafb80cc1634392811e1b1a86c	approved	2026-09-30 09:14:51.059384+00
327	1	https://www.openstreetmap.org/node/11990031883	{"id": 11990031883, "lat": -6.9068721, "lon": 107.6683225, "tags": {"name": "Tugu Perjuangan Bandung Timur", "historic": "memorial", "material": "concrete", "memorial": "war_memorial", "inscription": "(1945-1946)"}, "type": "node", "_source": "overpass_osm"}	585678acba37ac725a6c18bf58286eafee3180497fa24a2c0febc523e7603f35	approved	2026-09-30 09:14:51.059384+00
328	1	https://www.openstreetmap.org/node/12006584835	{"id": 12006584835, "lat": -6.9126182, "lon": 107.5974812, "tags": {"fax": "+62 22 8606 6999", "name": "Hilton Bandung", "brand": "Hilton", "email": "bandung.reservations@hilton.com", "phone": "+62 22 86051300", "rooms": "186", "stars": "5", "smoking": "separated", "tourism": "hotel", "website": "https://www.hilton.com/en/hotels/bdohihi-hilton-bandung/", "operator": "Hilton", "wikidata": "Q2141411", "addr:city": "Bandung", "wikipedia": "id:Hilton Bandung", "addr:street": "Jalan HOS. Tjokroaminoto", "addr:postcode": "40172", "opening_hours": "24/7", "brand:wikidata": "Q598884", "internet_access": "yes", "addr:housenumber": "41-43", "contact:facebook": "https://www.facebook.com/HiltonBandung", "internet_access:fee": "no"}, "type": "node", "_source": "overpass_osm"}	8b9f371e07e5f180af6d26a824e316fadaabd7416d967261d54ebd4d1b899f8a	approved	2026-09-30 09:14:51.059384+00
329	1	https://www.openstreetmap.org/node/12029263569	{"id": 12029263569, "lat": -6.9094845, "lon": 107.609759, "tags": {"name": "LaGrande", "tourism": "apartment"}, "type": "node", "_source": "overpass_osm"}	73ac77a732277bdd02ea32c6b346777f828efd5cf48ac3678e3e857b3d831d38	approved	2026-09-30 09:14:51.059384+00
330	1	https://www.openstreetmap.org/node/12051490449	{"id": 12051490449, "lat": -6.9489111, "lon": 107.705261, "tags": {"name": "Monumen Al Jabbar", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	679cbfda1215f8a74a93293695c8075a49a08a20af813fe2ee840c4a4a4741ba	approved	2026-09-30 09:14:51.059384+00
331	1	https://www.openstreetmap.org/node/12064373925	{"id": 12064373925, "lat": -6.8940622, "lon": 107.6039465, "tags": {"name": "Puma Hotel", "tourism": "hotel", "check_date": "2026-04-17"}, "type": "node", "_source": "overpass_osm"}	1040a023b9587d38677a844f0b55eddaf2d5b3c7633f21284b8e962227d36cac	approved	2026-09-30 09:14:51.059384+00
332	1	https://www.openstreetmap.org/node/12064456186	{"id": 12064456186, "lat": -6.9018405, "lon": 107.58486, "tags": {"name": "PTDI Factory tour Bandros start", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	1c0334018d059ee383186433595b7e6b5f2c0e2742b07d4b418774cb4468f2e6	approved	2026-09-30 09:14:51.059384+00
333	1	https://www.openstreetmap.org/node/12073059377	{"id": 12073059377, "lat": -6.9071181, "lon": 107.6130041, "tags": {"name": "Sister City Park", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	ec1ba2b78a7dacf3284317d6930874a5e5890117befca8fefce6760d769b9b1a	approved	2026-09-30 09:14:51.059384+00
334	1	https://www.openstreetmap.org/node/12090548597	{"id": 12090548597, "lat": -6.9234612, "lon": 107.6069163, "tags": {"name": "Gong", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	33e1c141ac21931fcb7b5385c055f6161352a0c8284d036bd75ef0a6e696737a	approved	2026-09-30 09:14:51.059384+00
335	1	https://www.openstreetmap.org/node/12090565556	{"id": 12090565556, "lat": -6.8877461, "lon": 107.5958408, "tags": {"name": "Dunia Antariksa", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	2aabb98103999265226aed0aaf036681cb8ed74804498c41fe97828be727fad0	approved	2026-09-30 09:14:51.059384+00
336	1	https://www.openstreetmap.org/node/12488357574	{"id": 12488357574, "lat": -6.9452117, "lon": 107.6536103, "tags": {"name": "Kontrakan bp dodo", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	ce2b4a24acd77ba22c7fa418420a1785dcb6b728cb745807bb79dc16b1ca6089	approved	2026-09-30 09:14:51.059384+00
337	1	https://www.openstreetmap.org/node/12624763934	{"id": 12624763934, "lat": -6.9038284, "lon": 107.6359433, "tags": {"name": "Taman SD dan SMA 14", "access": "yes", "leisure": "park", "addr:city": "Bandung", "addr:street": "Jalan Pramukha XIII", "addr:district": "Cicadas", "addr:province": "Jawa Barat"}, "type": "node", "_source": "overpass_osm"}	d23e17a702fa9d31092451a181f908597cfe2201353101a107b4ea213867b7ad	approved	2026-09-30 09:14:51.059384+00
338	1	https://www.openstreetmap.org/node/12637947272	{"id": 12637947272, "lat": -6.9133823, "lon": 107.6043728, "tags": {"name": "Arion Suites Hotel", "phone": "+6281212120248", "tourism": "hotel", "website": "https://arionsuiteshotel.com/", "addr:street": "Jl. Otto Iskander Dirata", "addr:housenumber": "16"}, "type": "node", "_source": "overpass_osm"}	cd1fa65ddcad9b2ad20c3c0850514786dbae4e106408ce8bf6def0179e906e12	approved	2026-09-30 09:14:51.059384+00
339	1	https://www.openstreetmap.org/node/13031340642	{"id": 13031340642, "lat": -6.9145707, "lon": 107.6070682, "tags": {"name": "Monumen Tentara Pelajar", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	98b461a0279b82f1662183aa81807f29d62a5e7893139754033b797fdee0f33c	duplicate	2026-09-30 09:14:51.059384+00
340	1	https://www.openstreetmap.org/node/13036991649	{"id": 13036991649, "lat": -6.9042257, "lon": 107.6239578, "tags": {"name": "Tank", "historic": "tank"}, "type": "node", "_source": "overpass_osm"}	a513577a22c016ba7cd99f0b197d88de51ef7e7d0b95582cde538d7b0debb6d8	approved	2026-09-30 09:14:51.059384+00
341	1	https://www.openstreetmap.org/node/13042314420	{"id": 13042314420, "lat": -6.9254976, "lon": 107.6302176, "tags": {"fee": "no", "name": "Museum Kavaleri", "tourism": "museum", "opening_hours": "Tu-Su 10:00-15:00"}, "type": "node", "_source": "overpass_osm"}	4e3712550f1537b618aa03268aeaf9aad57a572433ca19e48057d3ea4547ddbf	approved	2026-09-30 09:14:51.059384+00
342	1	https://www.openstreetmap.org/node/13306436431	{"id": 13306436431, "lat": -6.8991492, "lon": 107.6066358, "tags": {"name": "Taman Ulin", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	e7877be742846cde962e36b48792be2fada91835a838a0a29378ed8588471c23	approved	2026-09-30 09:14:51.059384+00
343	1	https://www.openstreetmap.org/node/13306436432	{"id": 13306436432, "lat": -6.8990507, "lon": 107.6068156, "tags": {"name": "Caskade Park", "leisure": "park"}, "type": "node", "_source": "overpass_osm"}	3591c3dc3c0a434e66744d3d75cf081b07ef9bb0d2ea33fd3a753af176e37d07	approved	2026-09-30 09:14:51.059384+00
344	1	https://www.openstreetmap.org/node/13456067401	{"id": 13456067401, "lat": -6.9091331, "lon": 107.62471, "tags": {"name": "Panen Hotel Bandung (By Tebu Group)", "phone": "+62 22 20507474", "tourism": "hotel", "website": "https://panenhotels.com/", "addr:street": "Jalan L.L. RE. Martadinata", "self_service": "no", "addr:postcode": "40113", "internet_access": "wlan", "addr:housenumber": "100", "contact:instagram": "panenhotels"}, "type": "node", "_source": "overpass_osm"}	8c510e5e9febb7f62c955287f588cb501eaca905accb8a9ffa643788fcc89260	approved	2026-09-30 09:14:51.059384+00
345	1	https://www.openstreetmap.org/node/13460475168	{"id": 13460475168, "lat": -6.9292634, "lon": 107.5857903, "tags": {"name": "pop hotels", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	86d781a0374afbeea1106a1564e125095e131965b6f0d40cb3b86a5c39271377	approved	2026-09-30 09:14:51.059384+00
346	1	https://www.openstreetmap.org/node/13514149101	{"id": 13514149101, "lat": -6.9085286, "lon": 107.6948095, "tags": {"name": "Rumah Oren", "tourism": "guest_house", "addr:street": "Jalan Segar", "addr:postcode": "40611", "addr:housenumber": "F10"}, "type": "node", "_source": "overpass_osm"}	a6cad804c37ffd3182e00f35daf5970127fdc5abb023744201c7fc2683d72d44	approved	2026-09-30 09:14:51.059384+00
347	1	https://www.openstreetmap.org/node/13535911147	{"id": 13535911147, "lat": -6.884874, "lon": 107.6107019, "tags": {"name": "Lost in Clay", "craft": "pottery", "tourism": "attraction"}, "type": "node", "_source": "overpass_osm"}	260531657108d3d5f9f88d348012dc4fe4aef4c2f2c91bf712003284707385a6	approved	2026-09-30 09:14:51.059384+00
348	1	https://www.openstreetmap.org/node/13621753513	{"id": 13621753513, "lat": -6.8969243, "lon": 107.6376254, "tags": {"name": "Taman Plano", "leisure": "park", "opening_hours": "Mo-Su 07:00-22:00", "addr:housename": "Itenas"}, "type": "node", "_source": "overpass_osm"}	79ae061419082bc8c83aef748f9ce07dc1aa4d19003cbd8cbb2add7d0c8b8b33	approved	2026-09-30 09:14:51.059384+00
349	1	https://www.openstreetmap.org/node/13622908680	{"id": 13622908680, "lat": -6.8900964, "lon": 107.615191, "tags": {"name": "Rumah Aca.com", "tourism": "hostel"}, "type": "node", "_source": "overpass_osm"}	38f51ebbb6e8f68e3545ee8d900616960e912b1ee0c97612d8e85e86207dcbda	approved	2026-09-30 09:14:51.059384+00
350	1	https://www.openstreetmap.org/node/13650694532	{"id": 13650694532, "lat": -6.9481559, "lon": 107.7035885, "tags": {"fee": "no", "name": "Galeri Rasulullah", "museum": "history", "tourism": "museum", "opening_hours": "We-Su 09:00-15:00"}, "type": "node", "_source": "overpass_osm"}	707ada816dfcfc21a025481aa51edac14fa39dd164006012e53a51d3af5facd3	approved	2026-09-30 09:14:51.059384+00
351	1	https://www.openstreetmap.org/node/13713723687	{"id": 13713723687, "lat": -6.8927843, "lon": 107.5989409, "tags": {"name": "Arwiga Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	6f214c5ba3e9e89e9440e0e1646b33b2779be3835d20631bde303fc60b0e28ac	approved	2026-09-30 09:14:51.059384+00
352	1	https://www.openstreetmap.org/node/13730213277	{"id": 13730213277, "lat": -6.8925507, "lon": 107.6140648, "tags": {"name": "Suryakencana Boutique Guest House", "tourism": "guest_house"}, "type": "node", "_source": "overpass_osm"}	8a3043ce23e42327c9acba2be57fea587f27e05063cdc888b1eaad769f296e5e	approved	2026-09-30 09:14:51.059384+00
353	1	https://www.openstreetmap.org/node/13737191450	{"id": 13737191450, "lat": -6.8946224, "lon": 107.6038409, "tags": {"name": "Serela Hotel", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	48ba5317092e78b4bc0d85e0d4ab84f31abc62b7c8c6c3ecfd8d450cfff1a3e7	approved	2026-09-30 09:14:51.059384+00
397	1	https://www.openstreetmap.org/way/155189909	{"id": 155189909, "tags": {"name": "Casa D'Ladera", "tourism": "hotel", "check_date": "2025-08-17"}, "type": "way", "center": {"lat": -6.861819, "lon": 107.5963787}, "_source": "overpass_osm"}	6c8d213dae619ef8287b44a430d77ab0e54f26f16c099d2ffbb6299b045cd133	approved	2026-09-30 09:14:51.059384+00
354	1	https://www.openstreetmap.org/node/13770681054	{"id": 13770681054, "lat": -6.8994435, "lon": 107.6039069, "tags": {"name": "Truntum", "email": "stay.cihampelas@truntumhotels.com", "phone": "+622263170000", "tourism": "hotel", "website": "https://truntumhotels.com/hotels/truntum-cihampelas-bandung", "addr:street": "Jalan Cihampelas", "addr:postcode": "40131", "addr:housenumber": "91"}, "type": "node", "_source": "overpass_osm"}	33eae116bfce7b1a349983ca8b7404d4faf58500f9a7489bcad478d245b49eb5	approved	2026-09-30 09:14:51.059384+00
355	1	https://www.openstreetmap.org/node/13801732632	{"id": 13801732632, "lat": -6.9088213, "lon": 107.6242604, "tags": {"name": "Hotel Madju", "tourism": "hotel"}, "type": "node", "_source": "overpass_osm"}	f10d8e77516dd1b173b4a2e2826cd4b9f41dd0462b2a9ee8d66b6fc92954b1bf	approved	2026-09-30 09:14:51.059384+00
356	1	https://www.openstreetmap.org/node/13833618295	{"id": 13833618295, "lat": -6.9545526, "lon": 107.6479533, "tags": {"name": "Margacinta Park", "leisure": "water_park", "website": "https://msha.ke/margacintapark", "opening_hours": "Mo-Su 08:00-18:00"}, "type": "node", "_source": "overpass_osm"}	b55f8bb77c5adc130487732907337269b54be9b0c04e19917f2d59c10ed0a71a	approved	2026-09-30 09:14:51.059384+00
357	1	https://www.openstreetmap.org/node/13834358543	{"id": 13834358543, "lat": -6.8762768, "lon": 107.6168981, "tags": {"name": "The Kamalaya Hotel Wedding & Guest House", "brand": "Tebu Hotel Group", "email": "reservation@thekamalayahotel.com", "phone": "+62 852-5000-0538", "rooms": "31", "smoking": "outside", "tourism": "hotel", "website": "https://thekamalayahotel.com/", "addr:city": "Bandung, Jawa Barat", "addr:unit": "Hotel", "addr:street": "Jl. The Kamalaya Hotel Wedding & Guest House", "addr:district": "Coblong", "addr:postcode": "40135", "addr:province": "Jawa Barat", "addr:housename": "The Kamalaya Hotel", "internet_access": "yes", "addr:housenumber": "319", "addr:subdistrict": "Dago", "internet_access:fee": "no"}, "type": "node", "_source": "overpass_osm"}	96985a5beb38a4ba8a9567f1a08cb23303ae2b9715c315bc2bd7753ac9dc9d0c	approved	2026-09-30 09:14:51.059384+00
358	1	https://www.openstreetmap.org/node/13990557159	{"id": 13990557159, "lat": -6.9181825, "lon": 107.6462471, "tags": {"name": "KOST ELHAZ BANDUNG", "tourism": "hostel", "addr:city": "Kel. Babakan Sari", "addr:unit": "5", "addr:street": "Jalan Pare Pandan II 4, Bandung Kota, 40283, ID", "addr:district": "Kiaracondong", "addr:postcode": "40283", "addr:province": "JAWA BARAT", "addr:housename": "KOST ELHAZ BANDUNG", "addr:housenumber": "4", "addr:subdistrict": "Babakan Sari", "addr:neighbourhood": "05"}, "type": "node", "_source": "overpass_osm"}	59c73a3340dd867e824bd02eb80f1f2fe31fd671bb6a796cd0432bd1675e9dba	approved	2026-09-30 09:14:51.059384+00
359	1	https://www.openstreetmap.org/node/14023644201	{"id": 14023644201, "lat": -6.9109944, "lon": 107.6000419, "tags": {"name": "Buton Backpacker Lodge", "tourism": "hostel", "check_date": "2026-07-18", "addr:street": "Jalan Haji Akbar", "addr:postcode": "40171", "addr:housenumber": "19"}, "type": "node", "_source": "overpass_osm"}	c465c362b699fa6675b7de9d03c3c19399ab825837bd5b69ca8c57f8eeb80edf	approved	2026-09-30 09:14:51.059384+00
360	1	https://www.openstreetmap.org/node/14041350074	{"id": 14041350074, "lat": -6.8862383, "lon": 107.6085713, "tags": {"fee": "yes", "name": "Museum ITB", "tourism": "museum", "website": "https://museum.itb.ac.id/", "opening_hours": "Tu-Su 10:00-15:00"}, "type": "node", "_source": "overpass_osm"}	b47955d9d425cfaa4313f5741df1e0e4e81ed36fdb4f40bd818cd085e30ab799	approved	2026-09-30 09:14:51.059384+00
361	1	https://www.openstreetmap.org/node/14085713330	{"id": 14085713330, "lat": -6.8904868, "lon": 107.6103678, "tags": {"name": "Sekali Teman Tetap Teman", "image": "https://albadr.blog/wp-content/uploads/2012/06/friendship-monument.jpg", "historic": "monument"}, "type": "node", "_source": "overpass_osm"}	1f06a4bdd76f7b6d15b31a5e4fcbd9fd10de5b50b3f30cfaa1cc7359a573cdf3	approved	2026-09-30 09:14:51.059384+00
362	1	https://www.openstreetmap.org/node/14085922101	{"id": 14085922101, "lat": -6.8698425, "lon": 107.6132904, "tags": {"name": "Kos kos kos dago", "tourism": "guest_house", "addr:street": "capitol dago valley", "addr:postcode": "40135", "opening_hours": "24/7", "addr:housenumber": "36", "contact:instagram": "koskoskosdago"}, "type": "node", "_source": "overpass_osm"}	9806afbcc79ad2a040152c6f773abadea793f94b78a0a6994318b6e9690fb9aa	approved	2026-09-30 09:14:51.059384+00
363	1	https://www.openstreetmap.org/node/14179825202	{"id": 14179825202, "lat": -6.9013413, "lon": 107.6144853, "tags": {"name": "Kosan Rangga Gempol RG10A", "tourism": "guest_house", "addr:street": "Jalan Ranggagempol", "addr:housenumber": "10A"}, "type": "node", "_source": "overpass_osm"}	9bbfefc5452746af66ace26567ae7bc8a6118fe776b01286b86b0f93b60d80ef	approved	2026-09-30 09:14:51.059384+00
364	1	https://www.openstreetmap.org/way/27807705	{"id": 27807705, "tags": {"name": "Taman Prabuwangi", "landuse": "recreation_ground", "leisure": "park", "surface": "grass"}, "type": "way", "center": {"lat": -6.9129723, "lon": 107.6722955}, "_source": "overpass_osm"}	162a72c8dbfd180b43274c293ace4ee06e6e79f0297ae28daba81e182329385c	approved	2026-09-30 09:14:51.059384+00
365	1	https://www.openstreetmap.org/way/87148716	{"id": 87148716, "tags": {"lit": "yes", "name": "Alun-Alun Kota Bandung", "leisure": "park", "wikidata": "Q12471672", "wikipedia": "id:Alun-alun Bandung", "description": "Lush and shaded by trees urban city park, build using synthetic grass.", "wikimedia_commons": "Category:Alun-alun Bandung"}, "type": "way", "center": {"lat": -6.9218356, "lon": 107.6070471}, "_source": "overpass_osm"}	f99403f83897408e4fa81b7c09e1c7fe8c76ef628b5ce7d4add7fe97c88a2a1e	approved	2026-09-30 09:14:51.059384+00
366	1	https://www.openstreetmap.org/way/95526288	{"id": 95526288, "tags": {"lit": "yes", "name": "Lapangan Supratman", "source": "POI_WRI_Survey_2023", "leisure": "park", "surface": "artificial_turf", "alt_name": "Taman PERSIB", "wikidata": "Q62078992", "addr:city": "Bandung", "addr:full": "Jl. Supratman No. 24, Cihapit, Bandung Wetan", "opening_hours": "24/7", "tactile_paving": "yes", "name:etymology:wikidata": "Q1144049", "name:etymology:wikipedia": "id:Wage Rudolf Soepratman"}, "type": "way", "center": {"lat": -6.9076574, "lon": 107.6298782}, "_source": "overpass_osm"}	b942e5f585be980b17159ebc5140c3b09cf29d51aa79f520067faf1f91563196	approved	2026-09-30 09:14:51.059384+00
367	1	https://www.openstreetmap.org/way/95604245	{"id": 95604245, "tags": {"name": "Taman Radio", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl Ir H Djuanda", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9025114, "lon": 107.6112733}, "_source": "overpass_osm"}	11329c096b77826fd04adf5432b3e74f43b55e716f8a01e010a6f14dc3fda87b	approved	2026-09-30 09:14:51.059384+00
398	1	https://www.openstreetmap.org/way/155190112	{"id": 155190112, "tags": {"name": "Ponty", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.8603174, "lon": 107.5952227}, "_source": "overpass_osm"}	a1d0a2fdec9b91df800a42a849b999bbec6012167c2a299a9dfbd447048bfc65	approved	2026-09-30 09:14:51.059384+00
368	1	https://www.openstreetmap.org/way/95610582	{"id": 95610582, "tags": {"fee": "yes", "name": "Kebun Binatang Bandung", "landuse": "forest", "name:nl": "Dierentuin", "tourism": "zoo", "website": "https://www.bandung-zoo.com/", "addr:street": "Jalan Taman Sari", "opening_hours": "Mo-Su 08:00-16:00", "addr:housenumber": "6"}, "type": "way", "center": {"lat": -6.8910285, "lon": 107.6068745}, "_source": "overpass_osm"}	78cee4ef28a581749c2cd99bf9a9a2b2feeb99c0a29db1e22cb8ba78fca32e41	approved	2026-09-30 09:14:51.059384+00
369	1	https://www.openstreetmap.org/way/119439014	{"id": 119439014, "tags": {"name": "Hotel Scarlet Dago", "stars": "5", "tourism": "hotel", "building": "yes", "building:use": "commercial", "building:roof": "concrete", "building:walls": "brick", "building:levels": "6", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.8852565, "lon": 107.6121068}, "_source": "overpass_osm"}	f50b86d6253c8387b5f105bfc7d9acd4ffc96c325ce61256ade759601676cee2	approved	2026-09-30 09:14:51.059384+00
370	1	https://www.openstreetmap.org/way/119441848	{"id": 119441848, "tags": {"name": "Taman Cikapayang Dago", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Ciungwanara", "wheelchair": "yes", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8985154, "lon": 107.6123633}, "_source": "overpass_osm"}	9926d966ea273aab8f0a158ce8af50fc0fed6346c6327387434a68eb406c295a	approved	2026-09-30 09:14:51.059384+00
371	1	https://www.openstreetmap.org/way/119445946	{"id": 119445946, "tags": {"name": "The Palais Dago", "stars": "2", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "check_date": "2025-12-25", "addr:street": "Jalan Ir. H. Juanda", "building:use": "commercial", "building:roof": "concrete", "building:walls": "brick", "building:levels": "4", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.8962781, "lon": 107.6133185}, "_source": "overpass_osm"}	07fa928bb9bd00a8bb82b68f44af7d17b276a81bfdcdd45fb0927d5b65fc3129	approved	2026-09-30 09:14:51.059384+00
372	1	https://www.openstreetmap.org/way/119549570	{"id": 119549570, "tags": {"name": "Hotel Aryaduta", "brand": "Aryaduta", "rooms": "254", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "check_date": "2024-06-24", "start_date": "1997", "addr:street": "Jalan Merdeka", "building:use": "accommodation", "building:roof": "concrete", "building:walls": "brick", "building:levels": "15", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9093756, "lon": 107.6118246}, "_source": "overpass_osm"}	dd62c3a52010bf07d1a8d666959978f7ce8502912a4860939603477baf9f4023	approved	2026-09-30 09:14:51.059384+00
373	1	https://www.openstreetmap.org/way/119549571	{"id": 119549571, "tags": {"name": "Hotel The 101", "tourism": "hotel", "building": "hotel", "check_date": "2025-12-13", "building:use": "commercial", "building:roof": "concrete", "building:walls": "brick", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9063726, "lon": 107.6102339}, "_source": "overpass_osm"}	47c9d070b6fb60334e2a3ab9e2895f88cf03c2b31f69d05501837627e6a4f417	approved	2026-09-30 09:14:51.059384+00
374	1	https://www.openstreetmap.org/way/119756601	{"id": 119756601, "tags": {"name": "Santika Hotel", "stars": "3", "tourism": "hotel", "building": "yes", "check_date": "2024-03-11", "building:use": "accommodation", "building:roof": "concrete", "building:walls": "brick", "building:levels": "3", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9075937, "lon": 107.6120231}, "_source": "overpass_osm"}	d356b976d5271b7fecde39c1c3a8dd245d8626f5de6592a1e0e63f1b876f93a9	approved	2026-09-30 09:14:51.059384+00
375	1	https://www.openstreetmap.org/way/119763516	{"id": 119763516, "tags": {"name": "Posters Hotel", "tourism": "hotel", "building": "yes", "building:use": "accommodation", "building:roof": "asbestos", "building:walls": "brick", "building:levels": "5", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.8982098, "lon": 107.6384929}, "_source": "overpass_osm"}	cf334f12a4411ac0a3f7b0e116a2bc84c734b580978b12540ac2faf091dd7799	approved	2026-09-30 09:14:51.059384+00
376	1	https://www.openstreetmap.org/way/119880466	{"id": 119880466, "tags": {"name": "Bandung Sister Cities -  Fort Worth, Texas", "historic": "monument"}, "type": "way", "center": {"lat": -6.9091794, "lon": 107.608402}, "_source": "overpass_osm"}	7dd8f612dee8e47cf03a008a9b683b138133c4a710d357903b6f3008ecf1faf5	approved	2026-09-30 09:14:51.059384+00
377	1	https://www.openstreetmap.org/way/119880736	{"id": 119880736, "tags": {"fee": "no", "name": "Gedung Indonesia Menggugat", "tourism": "museum", "building": "yes", "building:use": "multipurpose", "building:roof": "tile", "opening_hours": "Mo-Fr 08:00-17:00", "building:walls": "brick", "building:levels": "1", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9134169, "lon": 107.6079414}, "_source": "overpass_osm"}	a9f2542b645cd522cdbfc85df2f5e2e6e6e0c5e2294909ca7e09d8b705f3610f	approved	2026-09-30 09:14:51.059384+00
378	1	https://www.openstreetmap.org/way/120331569	{"id": 120331569, "tags": {"name": "Wisma Pradana Bank BTN", "tourism": "guest_house", "building": "yes", "check_date": "2025-08-11", "addr:street": "Jalan Ir. H. Djuanda", "building:use": "accommodation", "building:roof": "tile", "building:walls": "brick", "building:levels": "1", "addr:housenumber": "142", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.8880782, "lon": 107.613961}, "_source": "overpass_osm"}	b17be04e840ecaec7f8bf4bbd6dfb2a920892493971e9077654406461ad77ee0	approved	2026-09-30 09:14:51.059384+00
379	1	https://www.openstreetmap.org/way/120339378	{"id": 120339378, "tags": {"name": "Amaris Hotel", "tourism": "hotel", "building": "yes", "building:use": "accommodation", "building:roof": "concrete", "building:walls": "brick", "building:levels": "4", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.8902546, "lon": 107.603809}, "_source": "overpass_osm"}	918d64cfe51f4e02c27142d610d74ca831b2ceaea0274289950b323762b3477c	approved	2026-09-30 09:14:51.059384+00
380	1	https://www.openstreetmap.org/way/125174070	{"id": 125174070, "tags": {"fee": "yes", "name": "Museum Geologi", "phone": "+62 22-7213822", "museum": "history", "tourism": "museum", "website": "http://museum.geology.esdm.go.id", "building": "yes", "operator": "Goverment", "wikidata": "Q7475825", "addr:city": "Bandung", "wikipedia": "en:Bandung Geological Museum", "start_date": "1929-05-16", "wheelchair": "yes", "addr:street": "Jalan Diponegoro", "addr:postcode": "40122", "opening_hours": "Mo-Th 08:00-16:00; Sa, Su 08:00-14:00", "operator:type": "public/government", "tactile_paving": "yes", "building:levels": "3", "addr:housenumber": "57", "wikimedia_commons": "Category:Geology Museum in Bandung"}, "type": "way", "center": {"lat": -6.900453, "lon": 107.6214745}, "_source": "overpass_osm"}	f4ecb4545f0bf65a98f01266d9adeb01f840fa159fcece03cac749f9ca8afc6f	approved	2026-09-30 09:14:51.059384+00
381	1	https://www.openstreetmap.org/way/125806416	{"id": 125806416, "tags": {"name": "Taman Kandaga Puspa", "leisure": "park", "alt_name": "Taman Cilaki", "addr:street": "Jalan Cisangkuy", "description": "The park is recently revamped and revitalized by the government (in progress) with new plants and amenities. River flows in the middle of the park. Good for morning walk and popular among community members. meadow, park, recreational, grass, trees, river", "addr:postcode": "40114"}, "type": "way", "center": {"lat": -6.9032474, "lon": 107.6224659}, "_source": "overpass_osm"}	19e101081f87f201b50a3dd383db38a42403bca3a236bd1c77ac3a7071ecb8c7	approved	2026-09-30 09:14:51.059384+00
382	1	https://www.openstreetmap.org/way/125806418	{"id": 125806418, "tags": {"name": "Taman Lansia", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "surface": "ground, with paved walkway circling the Lansia park", "wikidata": "Q31173292", "addr:city": "Bandung", "addr:full": "Jl. Cisangkuy, Citarum, Bandung Wetan", "wheelchair": "yes", "description": "meadow, park, recreational, grass, trees, river", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9021588, "lon": 107.6207901}, "_source": "overpass_osm"}	45e7841a1b9759ab01aa93e95b43896a198259fe470d90e3f3a2ac2e71c79813	approved	2026-09-30 09:14:51.059384+00
383	1	https://www.openstreetmap.org/way/125806419	{"id": 125806419, "tags": {"name": "Pet Park", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Ciliwung, Cihapit, Bandung Wetan", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9042277, "lon": 107.625098}, "_source": "overpass_osm"}	ae916664c74a51604d2946bc2c6952924c33ec96c0fa3b0464db8549f8c08d9d	approved	2026-09-30 09:14:51.059384+00
384	1	https://www.openstreetmap.org/way/152648494	{"id": 152648494, "tags": {"name": "Isola Resort UPI", "tourism": "hotel", "building": "university", "roof:colour": "grey", "building:part": "yes", "building:colour": "grey", "building:levels": "6"}, "type": "way", "center": {"lat": -6.8623979, "lon": 107.5897381}, "_source": "overpass_osm"}	51b0237f23108a9fe41f22fbe77f25327b37ad528fae2c27c1e64b35ca116255	approved	2026-09-30 09:14:51.059384+00
385	1	https://www.openstreetmap.org/way/152934589	{"id": 152934589, "tags": {"name": "Rossan Villa", "source": "Agoda", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8496448, "lon": 107.5907805}, "_source": "overpass_osm"}	e52c479f776e2df7ef70de14f6cfb1ef3a46582fd2d2e1a227b0c46aed8a8248	approved	2026-09-30 09:14:51.059384+00
386	1	https://www.openstreetmap.org/way/152934590	{"id": 152934590, "tags": {"name": "GH Universal Hotel", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.8505181, "lon": 107.598007}, "_source": "overpass_osm"}	117f67ee93fff22cf86eec77f960271e7d9b6c85d709527ac67a25d1a6cfe9d7	approved	2026-09-30 09:14:51.059384+00
387	1	https://www.openstreetmap.org/way/152936381	{"id": 152936381, "tags": {"name": "Banana Inn", "tourism": "hotel", "building": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40153", "addr:housenumber": "191"}, "type": "way", "center": {"lat": -6.8669129, "lon": 107.5930743}, "_source": "overpass_osm"}	6ddec0d3eee860fbf31121f5481d92a969af093cd8e1da8b0c346903f97ebab8	approved	2026-09-30 09:14:51.059384+00
388	1	https://www.openstreetmap.org/way/152982392	{"id": 152982392, "tags": {"name": "Museum Barli", "phone": "+62 22 2011898", "museum": "art", "tourism": "museum", "building": "yes", "operator": "Government", "wikidata": "Q97241063", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Profesor Dokter Sutami", "addr:postcode": "40152", "opening_hours": "Mo-Sa 10:00-17:00", "operator:type": "public/government", "tactile_paving": "no", "addr:housenumber": "91"}, "type": "way", "center": {"lat": -6.878398, "lon": 107.5875461}, "_source": "overpass_osm"}	2f41d7b143ac1e2734b1470cac9029de1694b93c5d95162190ca835c73ec323c	approved	2026-09-30 09:14:51.059384+00
389	1	https://www.openstreetmap.org/way/152991392	{"id": 152991392, "tags": {"name": "Hotel Karangsetra", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.8829107, "lon": 107.5955647}, "_source": "overpass_osm"}	58e2c834b60f51ff745dbc577f38f0671dbe517ed9546290c8d40ef5af3366fe	approved	2026-09-30 09:14:51.059384+00
390	1	https://www.openstreetmap.org/way/153285183	{"id": 153285183, "tags": {"name": "Pondok Sany Rosa", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.8825427, "lon": 107.6026103}, "_source": "overpass_osm"}	52345b5ef843da9b54f935d014ff532467b9e537eaf60d7115a31c0af0f9e558	approved	2026-09-30 09:14:51.059384+00
391	1	https://www.openstreetmap.org/way/153883975	{"id": 153883975, "tags": {"name": "Fabu Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9159231, "lon": 107.6009332}, "_source": "overpass_osm"}	a39890e7ede4b8273a43542c7f215670de84642b2b8b56740f93b5c02f13b55e	approved	2026-09-30 09:14:51.059384+00
392	1	https://www.openstreetmap.org/way/154007026	{"id": 154007026, "tags": {"fee": "yes", "name": "Taman Lalu Lintas Ade Irma Suryani", "access": "yes", "landuse": "recreation_ground", "leisure": "park", "tourism": "theme_park"}, "type": "way", "center": {"lat": -6.9112176, "lon": 107.6134405}, "_source": "overpass_osm"}	6015c4bb43e04761d95c0b5bf3e91e13b2a34c2944697f0bcce107ce78fedf11	approved	2026-09-30 09:14:51.059384+00
393	1	https://www.openstreetmap.org/way/154066275	{"id": 154066275, "tags": {"name": "Hotel Nyland", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Doktor Djunjunan", "addr:postcode": "40162", "addr:housenumber": "125"}, "type": "way", "center": {"lat": -6.8949313, "lon": 107.5873115}, "_source": "overpass_osm"}	9390669c7378fcc8ce39c6e4bab10c5697b4a73724775195aa60da37c0ddb38b	approved	2026-09-30 09:14:51.059384+00
394	1	https://www.openstreetmap.org/way/154204630	{"id": 154204630, "tags": {"fee": "yes", "name": "Trans Studio Bandung", "tourism": "theme_park", "website": "https://www.transentertainment.com/transstudio/bandung", "building": "yes", "wikidata": "Q4210050", "addr:city": "Bandung", "wikipedia": "en:Trans Studio Bandung", "wikimedia_commons": "Category:Trans Studio Bandung"}, "type": "way", "center": {"lat": -6.9245691, "lon": 107.6365354}, "_source": "overpass_osm"}	6a6772088d746428474547a61bfe352272ead264f78a411c85af9a0321009b47	approved	2026-09-30 09:14:51.059384+00
395	1	https://www.openstreetmap.org/way/154217968	{"id": 154217968, "tags": {"name": "Bali World Hotel", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "building:levels": "4", "internet_access": "wlan", "internet_access:fee": "customers"}, "type": "way", "center": {"lat": -6.9384114, "lon": 107.6632349}, "_source": "overpass_osm"}	4b4abfaaecc440463643762928831a1297b042d9f7aa80ac710bc56c53ae53b6	approved	2026-09-30 09:14:51.059384+00
396	1	https://www.openstreetmap.org/way/154435842	{"id": 154435842, "tags": {"name": "Ahadiat Hotel & Bungalow", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.8803495, "lon": 107.5882717}, "_source": "overpass_osm"}	9b142e574afbc42fe1b33f09883430b12b98f8eb2be17d8b4c53912237a3d2b3	approved	2026-09-30 09:14:51.059384+00
399	1	https://www.openstreetmap.org/way/155190113	{"id": 155190113, "tags": {"name": "Setiabudhi Indah Hotel", "tourism": "hotel", "building": "yes", "addr:city": "Bandung, Jawa Barat", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40143", "internet_access": "wlan", "addr:housenumber": "266"}, "type": "way", "center": {"lat": -6.8613703, "lon": 107.5958651}, "_source": "overpass_osm"}	004febf7236a332b40efcc8214e836f18cc9d9b544f3720aff43817a926db775	approved	2026-09-30 09:14:51.059384+00
400	1	https://www.openstreetmap.org/way/155228864	{"id": 155228864, "tags": {"name": "Wisma Angkasa", "tourism": "motel", "check_date": "2025-08-17"}, "type": "way", "center": {"lat": -6.8735779, "lon": 107.5950977}, "_source": "overpass_osm"}	20ba80cd9817652960e758ee07e9001870e322da67f790831331cd22b5b147a7	approved	2026-09-30 09:14:51.059384+00
401	1	https://www.openstreetmap.org/way/155777651	{"id": 155777651, "tags": {"name": "Nalendra", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8853573, "lon": 107.6040187}, "_source": "overpass_osm"}	1f1f9ca875dfbe1ca747263c03e7967c6d4a345a78a4cb6c3fbabcf70a7a4e1d	approved	2026-09-30 09:14:51.059384+00
402	1	https://www.openstreetmap.org/way/166968558	{"id": 166968558, "tags": {"name": "Gedung Merdeka", "building": "yes", "historic": "building", "wikidata": "Q2622475", "addr:city": "Bandung", "wikipedia": "en:Merdeka Building", "addr:street": "Jalan Asia Afrika", "wikimedia_commons": "Category:Gedung Merdeka"}, "type": "way", "center": {"lat": -6.9209518, "lon": 107.6092807}, "_source": "overpass_osm"}	7b2c965fb2fbef2a02af49ad5f2f09e071487e748e6b0e4d24340be5b6ba350b	approved	2026-09-30 09:14:51.059384+00
403	1	https://www.openstreetmap.org/way/166968559	{"id": 166968559, "tags": {"fee": "no", "name": "Museum Konferensi Asia-Afrika", "phone": "+62 22 4233564", "museum": "history", "name:ja": "πéóπé╕πéóπâ╗πéóπâòπâ¬πé½Σ╝ÜΦ¡░σìÜτë⌐Θñ¿", "tourism": "museum", "website": "https://mkaa.kemlu.go.id/", "building": "yes", "operator": "government", "wikidata": "Q10972781", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Asia Afrika", "reservation": "required", "addr:postcode": "40111", "opening_hours": "We, Th, Sa 09:00-12:00; We, Th, Sa 13:00-15:00; Fr 13:30-15:30, 09:00-11:30", "operator:type": "public/government", "tactile_paving": "yes", "addr:housenumber": "65"}, "type": "way", "center": {"lat": -6.9210718, "lon": 107.6095551}, "_source": "overpass_osm"}	275801e0e729fedb5ab20f250bde9a1a8897adffb6e5808c934757ba8dabe7b0	approved	2026-09-30 09:14:51.059384+00
404	1	https://www.openstreetmap.org/way/167064114	{"id": 167064114, "tags": {"name": "Saung Angklung Udjo", "phone": "+62 821-8282-1200", "parking": "surface", "toilets": "yes", "tourism": "attraction", "website": "https://www.angklung-udjo.co.id/", "wheelchair": "no", "reservation": "yes", "payment:cash": "yes", "changing_table": "no", "toilets:access": "customers", "contact:twitter": "@angklungudjo", "contact:facebook": "https://www.facebook.com/AngklungUdjo", "contact:whatsapp": "+62 821-8282-1200", "contact:instagram": "angklungudjo", "toilets:wheelchair": "no"}, "type": "way", "center": {"lat": -6.8982333, "lon": 107.6552009}, "_source": "overpass_osm"}	ee36b852773b9f5255c5f3e6be6fda34702964ab14b0348900294376bc7a7bd5	approved	2026-09-30 09:14:51.059384+00
420	1	https://www.openstreetmap.org/way/185437317	{"id": 185437317, "tags": {"name": "lap STKS BANDUNG", "leisure": "park", "building": "yes"}, "type": "way", "center": {"lat": -6.8719638, "lon": 107.6189064}, "_source": "overpass_osm"}	4e760521ca424a66d7f20cb012e61aaded5bd31433ae3a6a4378c7557bb6357a	approved	2026-09-30 09:14:51.059384+00
405	1	https://www.openstreetmap.org/way/168566326	{"id": 168566326, "tags": {"name": "Taman Panatayuda", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "wikidata": "Q62078991", "addr:city": "Bandung", "addr:full": "Jalan Panatayuda", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8979582, "lon": 107.6157027}, "_source": "overpass_osm"}	aefe2d02a5c0e54e0b408bdab9614fb1bfd82ca67b8b5ee12f49c80a4840c9d3	approved	2026-09-30 09:14:51.059384+00
406	1	https://www.openstreetmap.org/way/168567649	{"id": 168567649, "tags": {"name": "Taman Patung Laskar Wanita", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.91506, "lon": 107.6068595}, "_source": "overpass_osm"}	ed87a9cbbfcdeead057ab1b9162ae026cef15487fd042c920f8d527ddf04a2e3	approved	2026-09-30 09:14:51.059384+00
407	1	https://www.openstreetmap.org/way/168567650	{"id": 168567650, "tags": {"name": "Taman Patung Pelajar Pejuang", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9146765, "lon": 107.606964}, "_source": "overpass_osm"}	804cb86f204c48851f0948ffdea8f5c0b28f2af58fa51617aa25761ca9a06e0b	approved	2026-09-30 09:14:51.059384+00
408	1	https://www.openstreetmap.org/way/182847335	{"id": 182847335, "tags": {"name": "Citarum Hotel", "source": "survery", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Citarum", "addr:country": "ID", "addr:postcode": "40114", "building:levels": "4", "addr:housenumber": "16"}, "type": "way", "center": {"lat": -6.9044332, "lon": 107.623114}, "_source": "overpass_osm"}	333a7036cbd32ba6617da2784d70e034b937d389de367b7b92785f664078e518	approved	2026-09-30 09:14:51.059384+00
409	1	https://www.openstreetmap.org/way/183473029	{"id": 183473029, "tags": {"name": "Taman Komplek DDK 369", "sport": "volleyball", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Ir. H. Djuanda", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8714788, "lon": 107.6190893}, "_source": "overpass_osm"}	147325d38510defd5000277c779c22a4daff10642d1d1c4f79778906ff5f359a	approved	2026-09-30 09:14:51.059384+00
410	1	https://www.openstreetmap.org/way/183513819	{"id": 183513819, "tags": {"name": "Taman PDAM", "access": "no", "office": "government", "source": "S2City_POI_2022", "leisure": "park", "operator": "PDAM", "addr:city": "Bandung", "addr:full": "Jalan Bukit Dago Selatan", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8713928, "lon": 107.6185119}, "_source": "overpass_osm"}	40004adda0236133b9a8d70a3c0d6965a9558c13ff4aea0b852c2c5c6db9d6b1	approved	2026-09-30 09:14:51.059384+00
411	1	https://www.openstreetmap.org/way/183513822	{"id": 183513822, "tags": {"name": "The Jayakarta Suites Bandung", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda No.381A, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.8709116, "lon": 107.6193567}, "_source": "overpass_osm"}	bfeafaa018ace5398429d45004cfc79c22a4eeb4be2f30904af9d83a0005022a	approved	2026-09-30 09:14:51.059384+00
463	1	https://www.openstreetmap.org/way/418955041	{"id": 418955041, "tags": {"name": "Hotel Pasar Baru Heritage Bandung", "landuse": "recreation_ground", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.917979, "lon": 107.6037863}, "_source": "overpass_osm"}	1e576ae1c07f0516b66d2b4c6509bdde581eaf9316eceddd85fa2a69e40e28a8	approved	2026-09-30 09:14:51.059384+00
412	1	https://www.openstreetmap.org/way/184714612	{"id": 184714612, "tags": {"name": "Taman Budaya Jawa Barat", "leisure": "park", "addr:city": "Bandung", "addr:street": "Jalan Bukit Dago Selatan No. 53A", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.8700448, "lon": 107.6196683}, "_source": "overpass_osm"}	fbba5b816be2417ba83f0d2d552a982016db78d347a77cfe1dd418635a9d262f	approved	2026-09-30 09:14:51.059384+00
413	1	https://www.openstreetmap.org/way/185080150	{"id": 185080150, "tags": {"name": "Hotel Bukit Dago", "tourism": "motel", "building": "yes"}, "type": "way", "center": {"lat": -6.8770186, "lon": 107.6169686}, "_source": "overpass_osm"}	5961be72b7b0dbd2280ab5e6774034f7e303d5ebf5c22c4d890b7373d178e5dc	duplicate	2026-09-30 09:14:51.059384+00
414	1	https://www.openstreetmap.org/way/185123551	{"id": 185123551, "tags": {"name": "Taman Tunas Kelapa", "leisure": "park", "addr:street": "Jalan R.E. Martadinata", "description": "Fountain park located between LLRE Martadinata & Gandapura street. It has picnic benches,fountain and trees on both end of the park. Situated right across the lush green Taman Pramuka.", "addr:postcode": "40113"}, "type": "way", "center": {"lat": -6.9106726, "lon": 107.626505}, "_source": "overpass_osm"}	11d9a8840fa40487d254753c659b95d7159feaf054fcf5c7a86ac620a091b57b	approved	2026-09-30 09:14:51.059384+00
415	1	https://www.openstreetmap.org/way/185126823	{"id": 185126823, "tags": {"name": "Taman Balai Kota Bandung", "leisure": "park", "old_name": "Pieters Park", "addr:city": "Bandung", "addr:street": "Jalan Wastukencana", "description": "Lush green City park located within the compound of Balai Kota Bandung (Bandung City Hall). Integrated with Bandros shelter, Bandung City Tour on Bus.", "addr:postcode": "40117", "tactile_paving": "yes", "addr:housenumber": "2"}, "type": "way", "center": {"lat": -6.9131583, "lon": 107.6097373}, "_source": "overpass_osm"}	846df6cac6dcff07b01479c1a56d920ad891720ad9c3d2cc4a9255bcf812d7e6	approved	2026-09-30 09:14:51.059384+00
416	1	https://www.openstreetmap.org/way/185126847	{"id": 185126847, "tags": {"name": "Taman Foto", "source": "POI_WRI_Survey_2023", "leisure": "park", "alt_name": "Taman Fotografi", "wikidata": "Q64759460", "description": "Local recreational park with meadow, and trees.", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9134856, "lon": 107.6271179}, "_source": "overpass_osm"}	e96ffc02eb21bf5e3424b964ede57139034dd8eb29c4fbc16b4c79858d998505	approved	2026-09-30 09:14:51.059384+00
417	1	https://www.openstreetmap.org/way/185127241	{"id": 185127241, "tags": {"name": "Tugu PERSIB", "leisure": "park"}, "type": "way", "center": {"lat": -6.9179395, "lon": 107.6125094}, "_source": "overpass_osm"}	da8dafda9e5e34c6c75e142522db3bbe579458a879c309d6823e352cda0eeeb3	approved	2026-09-30 09:14:51.059384+00
418	1	https://www.openstreetmap.org/way/185407983	{"id": 185407983, "tags": {"name": "Taman Budaya", "access": "yes", "source": "S2City_POI_2022", "amenity": "arts_centre", "leisure": "park", "building": "yes", "addr:city": "Bandung", "addr:full": "Jalan Bukit Dago", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8698659, "lon": 107.6176954}, "_source": "overpass_osm"}	08dcdbe330d0ce224abb8830f0f0c25d5666e333d9cf8ac61d2884199abc6cc7	approved	2026-09-30 09:14:51.059384+00
419	1	https://www.openstreetmap.org/way/185428752	{"id": 185428752, "tags": {"name": "Sheraton Bandung Hotel & Towers", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda No.390, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.8745329, "lon": 107.620065}, "_source": "overpass_osm"}	d35903dc7110478611c01086ec1dfcdc82ab3be2192fe5afafbd8d38e1f31ee5	approved	2026-09-30 09:14:51.059384+00
421	1	https://www.openstreetmap.org/way/185442864	{"id": 185442864, "tags": {"name": "Hutan Kota Babakan Siliwangi", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "natural": "wood", "wikidata": "Q16874988", "addr:city": "Bandung", "addr:full": "Jalan Siliwangi (Depan Lapangan Sabuga)", "leaf_type": "needleleaved", "wikipedia": "en:Babakan Siliwangi", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.886102, "lon": 107.6101977}, "_source": "overpass_osm"}	4b47184dc0ec65cb7115a4ccdd1d755a3c83a98151bb889f1ed237fd9966eba9	approved	2026-09-30 09:14:51.059384+00
422	1	https://www.openstreetmap.org/way/185930431	{"id": 185930431, "tags": {"name": "Taman RW 13", "leisure": "garden", "building": "yes"}, "type": "way", "center": {"lat": -6.9604761, "lon": 107.6518295}, "_source": "overpass_osm"}	064ce4e563fd2c443ff103e81ef4131c12f73e19367824f01c037fc890646d91	approved	2026-09-30 09:14:51.059384+00
423	1	https://www.openstreetmap.org/way/185934075	{"id": 185934075, "tags": {"area": "yes", "name": "Pemakaman Keluarga", "historic": "memorial"}, "type": "way", "center": {"lat": -6.9608414, "lon": 107.6584372}, "_source": "overpass_osm"}	687f96f3fd4dfa32d5a8da162df031b3c5218978fdbb9784324413eddf8c5cfa	approved	2026-09-30 09:14:51.059384+00
424	1	https://www.openstreetmap.org/way/185937173	{"id": 185937173, "tags": {"ele": "20", "name": "Ghotic", "tourism": "hotel", "addr:full": "Jl. Sukarno Hatta", "access:roof": "yes", "building:roof": "tile", "building:walls": "brick", "capacity:persons": "300", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9443095, "lon": 107.6470632}, "_source": "overpass_osm"}	5481cb01e61b258d9d519f5da5c51e849c560807a862dc3963564cc66ee5cd72	approved	2026-09-30 09:14:51.059384+00
425	1	https://www.openstreetmap.org/way/187367314	{"id": 187367314, "tags": {"name": "Wisma PLN", "tourism": "guest_house"}, "type": "way", "center": {"lat": -6.9383289, "lon": 107.6276487}, "_source": "overpass_osm"}	951f63fddf36b3c95b4fd29e3b5f37d28f873dc6bd69aa914a5b34d69a03d100	approved	2026-09-30 09:14:51.059384+00
426	1	https://www.openstreetmap.org/way/194709221	{"id": 194709221, "tags": {"fax": "+62 22 7104704", "name": "Bumi Kitri", "email": "hotelbkp@yahoo.com", "phone": "+62 22 7216913", "stars": "3", "smoking": "separated", "tourism": "hotel", "website": "https://www.hotelbumikitri.com/", "building": "yes", "operator": "Kwarda Gerakan Pramuka Jawa Barat", "wheelchair": "yes", "internet_access": "yes", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.892691, "lon": 107.6411098}, "_source": "overpass_osm"}	88bcd8e0b0d19cbe9725dc1ec2ed96f6ec8df760423000c4bce03f3d8174b566	approved	2026-09-30 09:14:51.059384+00
427	1	https://www.openstreetmap.org/way/222621719	{"id": 222621719, "tags": {"name": "ASOKA Inn", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8807157, "lon": 107.5808554}, "_source": "overpass_osm"}	80410e290b9357e8483e1325509e49bf31cdee95020b2f073cffe1186568caee	approved	2026-09-30 09:14:51.059384+00
479	1	https://www.openstreetmap.org/way/512276736	{"id": 512276736, "tags": {"name": "Kampioen Bed And Breakfast", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9042999, "lon": 107.6016617}, "_source": "overpass_osm"}	56a04457777d3fe3249e2dbee9018e0354837d505be4211840a68344f8b1bfd8	approved	2026-09-30 09:14:51.059384+00
428	1	https://www.openstreetmap.org/way/243451182	{"id": 243451182, "tags": {"name": "Taman Superhero", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "surface": "grass", "wikidata": "Q64759467", "addr:city": "Bandung", "addr:full": "Jl. Bengawan, Cihapit, Bandung Wetan", "wheelchair": "limited", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9108526, "lon": 107.6304931}, "_source": "overpass_osm"}	eec1e02d8b57bcbbfd7f4bc66fb626e3d568cc77cb68ab51978666df9c20d0ae	approved	2026-09-30 09:14:51.059384+00
429	1	https://www.openstreetmap.org/way/244694107	{"id": 244694107, "tags": {"name": "Gasmin", "leisure": "park"}, "type": "way", "center": {"lat": -6.9168252, "lon": 107.6613509}, "_source": "overpass_osm"}	ee3640efe13842a7552b2b8014ffccd754cce08cc3401514f4871834b4197fbe	approved	2026-09-30 09:14:51.059384+00
430	1	https://www.openstreetmap.org/way/297868568	{"id": 297868568, "tags": {"name": "Lapangan Cinta", "leisure": "park"}, "type": "way", "center": {"lat": -6.8916609, "lon": 107.6106721}, "_source": "overpass_osm"}	a8bf1b26d0f72ebaf0e89026289a57574053b2facca45d3c3df7e15fc9a99961	approved	2026-09-30 09:14:51.059384+00
431	1	https://www.openstreetmap.org/way/297869547	{"id": 297869547, "tags": {"name": "Taman Ganesha", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Ganesha", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.894052, "lon": 107.6104448}, "_source": "overpass_osm"}	45d12e670f3fa8a273ce87dea59ee70ef38d7c054ebef7465e1ba499dc77c54d	approved	2026-09-30 09:14:51.059384+00
432	1	https://www.openstreetmap.org/way/303890876	{"id": 303890876, "tags": {"name": "Lapangan panggung", "leisure": "park"}, "type": "way", "center": {"lat": -6.8927906, "lon": 107.6062052}, "_source": "overpass_osm"}	0e377fe742e9a3f09aaa71499e886f65e48e07dd080ca89624c2991477d8451a	approved	2026-09-30 09:14:51.059384+00
433	1	https://www.openstreetmap.org/way/318932227	{"id": 318932227, "tags": {"name": "Rusa Tutul", "leisure": "park"}, "type": "way", "center": {"lat": -6.8892728, "lon": 107.6064057}, "_source": "overpass_osm"}	b6155f58fc0123a00e0f5384b1b56b8794a6ce5019e8088b22e6b8526b786959	approved	2026-09-30 09:14:51.059384+00
434	1	https://www.openstreetmap.org/way/318932228	{"id": 318932228, "tags": {"name": "Betet", "leisure": "park"}, "type": "way", "center": {"lat": -6.8909656, "lon": 107.6073674}, "_source": "overpass_osm"}	7842ae777377c9d42097ba900c154169efc2d72e22b2b5dd6a033b934db1c58e	approved	2026-09-30 09:14:51.059384+00
435	1	https://www.openstreetmap.org/way/318932229	{"id": 318932229, "tags": {"name": "Kakaktua Raja Hitam", "leisure": "park"}, "type": "way", "center": {"lat": -6.8917048, "lon": 107.6071628}, "_source": "overpass_osm"}	90f8846edc62666d634d24173dc369413d604d0050e0d6b61e92082c3746f66a	approved	2026-09-30 09:14:51.059384+00
436	1	https://www.openstreetmap.org/way/318932975	{"id": 318932975, "tags": {"name": "Kura - Kura", "leisure": "park"}, "type": "way", "center": {"lat": -6.8926788, "lon": 107.6072722}, "_source": "overpass_osm"}	fe54ea1574299eb55e350c3e32f22da02e227db29bd69c93ca6b64ef2e29ad04	approved	2026-09-30 09:14:51.059384+00
437	1	https://www.openstreetmap.org/way/318937147	{"id": 318937147, "tags": {"name": "Orang Utan", "leisure": "park"}, "type": "way", "center": {"lat": -6.8903436, "lon": 107.6073311}, "_source": "overpass_osm"}	648343d62741c1c36901d9829f7ea51457637a474e626dc39a68265386e4a981	approved	2026-09-30 09:14:51.059384+00
438	1	https://www.openstreetmap.org/way/318937148	{"id": 318937148, "tags": {"name": "Kasuari", "leisure": "park"}, "type": "way", "center": {"lat": -6.8893409, "lon": 107.6067028}, "_source": "overpass_osm"}	d030d006ba83f679d8a027b2ffe6d459ed99455e0ba113e37f12a2c61b776ff4	approved	2026-09-30 09:14:51.059384+00
439	1	https://www.openstreetmap.org/way/318937155	{"id": 318937155, "tags": {"name": "Koak Biru", "leisure": "park"}, "type": "way", "center": {"lat": -6.8914404, "lon": 107.6071175}, "_source": "overpass_osm"}	88e6df3edf272b77d30d4e384fa564889968213bcc9bd02cb3ac08ab114d55df	approved	2026-09-30 09:14:51.059384+00
440	1	https://www.openstreetmap.org/way/321028422	{"id": 321028422, "tags": {"name": "Taman Vanda", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9140803, "lon": 107.6100658}, "_source": "overpass_osm"}	65008b491494a8f5241b85bbe03d4d56412a0ef3498fb3f5057b5b40106c0d57	approved	2026-09-30 09:14:51.059384+00
441	1	https://www.openstreetmap.org/way/327980246	{"id": 327980246, "tags": {"name": "Taman Pasopati", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "alt_name": "Taman Jomblo", "addr:city": "Bandung", "addr:full": "Bawah jembatan pasopati", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8981061, "lon": 107.6092197}, "_source": "overpass_osm"}	8a7ad90b3df15c1201f7dab23a0d0772f08a2bbcfb0365945bcb9c94274af10b	approved	2026-09-30 09:14:51.059384+00
442	1	https://www.openstreetmap.org/way/327985080	{"id": 327985080, "tags": {"name": "Taman Musik Centrum", "source": "POI_WRI_Survey_2023", "leisure": "park", "wikidata": "Q64759465", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9119872, "lon": 107.6160084}, "_source": "overpass_osm"}	875513751705348fd62ef50a62af09ab6dd5fc4ce0a2c41c95df2df8628acfb0	approved	2026-09-30 09:14:51.059384+00
443	1	https://www.openstreetmap.org/way/327986858	{"id": 327986858, "tags": {"name": "Taman Film", "leisure": "park", "wikidata": "Q24039069"}, "type": "way", "center": {"lat": -6.8985383, "lon": 107.6076999}, "_source": "overpass_osm"}	eec2a66d56e1096c44ca1498d15daf2c7432252926635cfd006f4ba012da12ca	approved	2026-09-30 09:14:51.059384+00
444	1	https://www.openstreetmap.org/way/340592887	{"id": 340592887, "tags": {"name": "Taman Skate", "leisure": "park"}, "type": "way", "center": {"lat": -6.8981274, "lon": 107.6086919}, "_source": "overpass_osm"}	6db0a883eac5f05906f5bd71fa741bb3696315d786f236be211042aaa2923942	approved	2026-09-30 09:14:51.059384+00
445	1	https://www.openstreetmap.org/way/342532165	{"id": 342532165, "tags": {"name": "Taman Cibeunying", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "name:en": "Robotic Park", "name:nl": "Robot Park", "int_name": "Robotic Park", "wikidata": "Q62082793", "addr:city": "Bandung", "addr:full": "Jl. Taman Cibeunying Selatan, Cihapit, Bandung Wetan", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.904562, "lon": 107.6241503}, "_source": "overpass_osm"}	6bc9f2c5decbeaf0a8eb477169e79730b1d25734f6b0c291ecd6e75f455e7b51	approved	2026-09-30 09:14:51.059384+00
498	1	https://www.openstreetmap.org/way/516636636	{"id": 516636636, "tags": {"name": "Hotel Anugerah", "tourism": "guest_house", "building": "yes"}, "type": "way", "center": {"lat": -6.8500107, "lon": 107.5932501}, "_source": "overpass_osm"}	8818893652ae72876cf7fb1a3447481be77a2c91365a911115ddcb672cb9d150	approved	2026-09-30 09:14:51.059384+00
446	1	https://www.openstreetmap.org/way/372063342	{"id": 372063342, "tags": {"name": "Hotel Golden Flower", "rooms": "193", "smoking": "outside", "tourism": "hotel", "website": "https://golden-flower.co.id/", "building": "hotel", "operator": "Kagum Group", "addr:city": "Bandung", "addr:street": "Jalan Asia Afrika", "addr:postcode": "40111", "addr:housenumber": "15-17"}, "type": "way", "center": {"lat": -6.9204882, "lon": 107.604801}, "_source": "overpass_osm"}	5007568ae606a31d13a585c1e1b165645ba43e81ea11f1876e2e0d40ec2a10af	approved	2026-09-30 09:14:51.059384+00
447	1	https://www.openstreetmap.org/way/376352094	{"id": 376352094, "tags": {"name": "Kalya Hotel", "tourism": "hotel", "building": "yes", "addr:street": "Jalan Sumur Bandung", "addr:housenumber": "7"}, "type": "way", "center": {"lat": -6.8857376, "lon": 107.6123845}, "_source": "overpass_osm"}	70e1d3df9c5b8cbfd203e31db35c74d4e8cf46aff6341d562dce23221432b96f	approved	2026-09-30 09:14:51.059384+00
448	1	https://www.openstreetmap.org/way/376352112	{"id": 376352112, "tags": {"name": "Taman kota di jalan gempol", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Sultan Tirtayasa, Citarum, Bandung Wetan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9037546, "lon": 107.6150227}, "_source": "overpass_osm"}	d0281a21f41498516d3aa1d77f48dcbf136a9e27a060bd85a7f5a0c5b0d129d6	approved	2026-09-30 09:14:51.059384+00
449	1	https://www.openstreetmap.org/way/376352123	{"id": 376352123, "tags": {"name": "Wisma Kartini", "tourism": "hotel", "building": "yes", "operator": "Wisma Kartini", "internet_access": "wlan", "internet_access:fee": "no", "name:etymology:wikidata": "Q1373764", "name:etymology:wikipedia": "id:Kartini"}, "type": "way", "center": {"lat": -6.9177729, "lon": 107.6165329}, "_source": "overpass_osm"}	61d563d3e5029a35fed410fab80d3f513b7f4138ad0a52207b1be71d732c922c	approved	2026-09-30 09:14:51.059384+00
450	1	https://www.openstreetmap.org/way/376626831	{"id": 376626831, "tags": {"name": "Tugu Soekarno", "access": "yes", "highway": "footway", "historic": "monument", "junction": "roundabout"}, "type": "way", "center": {"lat": -6.8909125, "lon": 107.6103705}, "_source": "overpass_osm"}	294e1ad42364a60594083394857850bcd4c31f7725dcc6b752588e209c8a7b0a	approved	2026-09-30 09:14:51.059384+00
451	1	https://www.openstreetmap.org/way/377400031	{"id": 377400031, "tags": {"name": "Parking Area Outdoor", "leisure": "park"}, "type": "way", "center": {"lat": -6.8721848, "lon": 107.6203336}, "_source": "overpass_osm"}	eff69238990eb99b272d081ef786de593ee2104560543955c7314041ee04cb5b	approved	2026-09-30 09:14:51.059384+00
452	1	https://www.openstreetmap.org/way/377559023	{"id": 377559023, "tags": {"name": "Taman Rumah Anggrek", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Bukit Dago Selatan 3", "wheelchair": "yes", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.868265, "lon": 107.6197275}, "_source": "overpass_osm"}	f863e27c60a0a0e38af1691360ff977ae31d690ace0d33db73b83e5e527d2ec0	approved	2026-09-30 09:14:51.059384+00
453	1	https://www.openstreetmap.org/way/380223188	{"id": 380223188, "tags": {"name": "Taman Fitness", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wikidata": "Q62078988", "addr:city": "Bandung", "addr:full": "Jalan Teuku Umar", "wheelchair": "yes", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.8919509, "lon": 107.6157726}, "_source": "overpass_osm"}	30b8a7e35e8b4c78c8e08b97f35e1415baa1d91998189b28d5383b5b3e402687	approved	2026-09-30 09:14:51.059384+00
454	1	https://www.openstreetmap.org/way/381032769	{"id": 381032769, "tags": {"name": "Bumi Sawunggaling", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9008395, "lon": 107.6092761}, "_source": "overpass_osm"}	51ab5330f7eb8e104e1f526047888c1c61e5a5f66b78ec92330fabea119bec29	approved	2026-09-30 09:14:51.059384+00
523	1	https://www.openstreetmap.org/way/545984956	{"id": 545984956, "tags": {"name": "Dago North Pedestrian 1", "leisure": "park"}, "type": "way", "center": {"lat": -6.8859947, "lon": 107.6133833}, "_source": "overpass_osm"}	5ad6c8c489d1efff301e38edbe94da54ffe4c70e1a51dfcbe2d4b8a68aeb32f8	approved	2026-09-30 09:14:51.059384+00
455	1	https://www.openstreetmap.org/way/381033009	{"id": 381033009, "tags": {"name": "Sapadia", "tourism": "hostel", "building": "yes", "check_date": "2026-08-22"}, "type": "way", "center": {"lat": -6.898026, "lon": 107.6107628}, "_source": "overpass_osm"}	e2652dce39e7dbc6ab89a201fdfb7db5a0c69a6a100d9706ffbec2a686d9f57a	approved	2026-09-30 09:14:51.059384+00
456	1	https://www.openstreetmap.org/way/381616655	{"id": 381616655, "tags": {"name": "Hotel Pelangi Indah", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9098226, "lon": 107.597969}, "_source": "overpass_osm"}	d61f14cd38930b4b7351c7d8bb234bbbfded0b0f38f70833661d7414fdde96cd	approved	2026-09-30 09:14:51.059384+00
457	1	https://www.openstreetmap.org/way/381642374	{"id": 381642374, "tags": {"name": "Pia Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9499631, "lon": 107.6238004}, "_source": "overpass_osm"}	b48253003d755c8ff9ffcc4e542da412a07dd1925f1c6741510c23614e74d89c	approved	2026-09-30 09:14:51.059384+00
458	1	https://www.openstreetmap.org/way/390192526	{"id": 390192526, "tags": {"name": "Taman Cikapundung Riverside", "leisure": "park"}, "type": "way", "center": {"lat": -6.9201958, "lon": 107.608748}, "_source": "overpass_osm"}	0c4ca5343badd1b6f4aa9bbb7cd8182f373ea0e9ac035a494a6a3671591decde	approved	2026-09-30 09:14:51.059384+00
459	1	https://www.openstreetmap.org/way/409819040	{"id": 409819040, "tags": {"fee": "no", "name": "Taman Teras Cikapundung", "leisure": "park"}, "type": "way", "center": {"lat": -6.8842965, "lon": 107.606917}, "_source": "overpass_osm"}	01258dfbd84bd936080332f7712372bad919cc07a67808d4bfcb0c768e0a359f	approved	2026-09-30 09:14:51.059384+00
460	1	https://www.openstreetmap.org/way/410281036	{"id": 410281036, "tags": {"name": "Taman Rajiman", "leisure": "park"}, "type": "way", "center": {"lat": -6.9037705, "lon": 107.6012117}, "_source": "overpass_osm"}	b6c6d8bda8ad7a4ce689c21447831838033e8bf466fb3ef21861b34268c3d828	approved	2026-09-30 09:14:51.059384+00
461	1	https://www.openstreetmap.org/way/413568982	{"id": 413568982, "tags": {"name": "Triple C Guest House", "tourism": "guest_house", "addr:city": "Bandung", "addr:street": "Jalan Setra Indah Utara 2", "addr:housenumber": "1"}, "type": "way", "center": {"lat": -6.880483, "lon": 107.5888447}, "_source": "overpass_osm"}	20096b0c3e9137d9727286f21fee292006d1d48fc93fe15df1e6a3a2c05faa69	approved	2026-09-30 09:14:51.059384+00
462	1	https://www.openstreetmap.org/way/413681134	{"id": 413681134, "tags": {"name": "Alun Alun Pinus", "leisure": "park"}, "type": "way", "center": {"lat": -6.9655908, "lon": 107.6982188}, "_source": "overpass_osm"}	ad8ff59489db7ae5bc0c7abc297c55548edbdc07d6881532c198144ca6d332f9	approved	2026-09-30 09:14:51.059384+00
464	1	https://www.openstreetmap.org/way/421572123	{"id": 421572123, "tags": {"name": "Hotel New Naripan", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Naripan", "addr:postcode": "40111", "addr:housenumber": "31-35"}, "type": "way", "center": {"lat": -6.920287, "lon": 107.6118116}, "_source": "overpass_osm"}	ea1de55c35dd88f1d7260738ac487de013cff423ee367ca67b6dc8efcf388890	duplicate	2026-09-30 09:14:51.059384+00
465	1	https://www.openstreetmap.org/way/421572125	{"id": 421572125, "tags": {"name": "Kimaya", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Braga"}, "type": "way", "center": {"lat": -6.9207728, "lon": 107.6104182}, "_source": "overpass_osm"}	037fae73a7da5bb04b3324d903c0d3da902bcabdf37fee47d82421da45babcc0	approved	2026-09-30 09:14:51.059384+00
466	1	https://www.openstreetmap.org/way/421572126	{"id": 421572126, "tags": {"name": "Gedung DENIS", "building": "commercial", "historic": "building", "addr:city": "Bandung", "addr:street": "Jalan Braga", "official_name": "Bank BJB", "building:levels": "3"}, "type": "way", "center": {"lat": -6.9199692, "lon": 107.610323}, "_source": "overpass_osm"}	747d8e9603d50b719a09f68f57b4a8574b0b07bdca48540c675f7e183cd26f30	approved	2026-09-30 09:14:51.059384+00
467	1	https://www.openstreetmap.org/way/421572129	{"id": 421572129, "tags": {"name": "Hotel Gino Feruci", "tourism": "hotel", "building": "yes", "operator": "Kagum Group", "addr:city": "Bandung", "addr:street": "Jalan Braga", "building:levels": "14"}, "type": "way", "center": {"lat": -6.917868, "lon": 107.6089891}, "_source": "overpass_osm"}	f5913e27d92d09f3c72703481709b9c38da2c59ed2e2d29a31dc1396d53be462	approved	2026-09-30 09:14:51.059384+00
468	1	https://www.openstreetmap.org/way/421576674	{"id": 421576674, "tags": {"name": "Vue Palace Artotel Curated", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Kebon Jukut", "designation": "Hotel Planet"}, "type": "way", "center": {"lat": -6.9130408, "lon": 107.6051334}, "_source": "overpass_osm"}	312e2e489210a8d80842687930554d8a7a724f588757d65198d7cb6b31a5e288	approved	2026-09-30 09:14:51.059384+00
469	1	https://www.openstreetmap.org/way/421576677	{"id": 421576677, "tags": {"name": "Hotel Bidakara Savoy Homann", "landuse": "commercial", "name:en": "Savoy Homann Bidakara Hotel", "tourism": "hotel", "website": "http://www.savoyhomann-hotel.com", "wikidata": "Q1330669", "addr:city": "Bandung", "wikipedia": "en:Savoy Homann Bidakara Hotel", "addr:street": "Jalan Asia Afrika", "wikimedia_commons": "Category:Hotel Savoy Homann"}, "type": "way", "center": {"lat": -6.9221986, "lon": 107.6103144}, "_source": "overpass_osm"}	fd3d8834f0346d988ff24609a1b2bcee4668b8d9b5c33bfb9946aad2515aeabc	approved	2026-09-30 09:14:51.059384+00
470	1	https://www.openstreetmap.org/way/421576684	{"id": 421576684, "tags": {"name": "Hotel Kumala", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Asia Afrika"}, "type": "way", "center": {"lat": -6.9223776, "lon": 107.6139727}, "_source": "overpass_osm"}	245226a6565781cae0f253d4221f79c1d0b99832edb93621f4d23bac125e9936	approved	2026-09-30 09:14:51.059384+00
471	1	https://www.openstreetmap.org/way/421576685	{"id": 421576685, "tags": {"name": "The Suddha Asia Afrika Bandung", "stars": "2", "tourism": "hotel", "building": "hotel", "addr:city": "Bandung", "addr:street": "Jalan Asia Afrika", "addr:housenumber": "128"}, "type": "way", "center": {"lat": -6.9222618, "lon": 107.6132759}, "_source": "overpass_osm"}	f5446318e5e6ee1d84514c896f5f321d383a942f61c8515ea5586bf10c048871	approved	2026-09-30 09:14:51.059384+00
506	1	https://www.openstreetmap.org/way/522949390	{"id": 522949390, "tags": {"name": "Grha Ciumbuleuit Guest House", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.866601, "lon": 107.6062993}, "_source": "overpass_osm"}	25a8d3562e2770f0c5a52a361185bb85a9a83e32108d85e77bb314e899a98c76	approved	2026-09-30 09:14:51.059384+00
472	1	https://www.openstreetmap.org/way/421614232	{"id": 421614232, "tags": {"name": "Gereja Katedral Santo Petrus Bandung", "amenity": "place_of_worship", "building": "cathedral", "historic": "church", "religion": "christian"}, "type": "way", "center": {"lat": -6.9148243, "lon": 107.6106798}, "_source": "overpass_osm"}	7edb78a14a068e780fd811bca54a6abc02ac249616d124971732ca79fab77626	approved	2026-09-30 09:14:51.059384+00
473	1	https://www.openstreetmap.org/way/422236650	{"id": 422236650, "tags": {"name": "Trans Studio Bandung", "landuse": "commercial", "tourism": "attraction", "website": "https://www.transstudiobandung.com/"}, "type": "way", "center": {"lat": -6.9255506, "lon": 107.6362988}, "_source": "overpass_osm"}	c8b2db04b619f5eb68187189c645cbd12c20c04ea324e13e7583b3ed9219f4a8	approved	2026-09-30 09:14:51.059384+00
474	1	https://www.openstreetmap.org/way/422236651	{"id": 422236651, "tags": {"name": "Ibis Trans Studio Bandung", "brand": "Ibis", "tourism": "hotel", "building": "hotel", "addr:city": "Bandung", "addr:street": "Jenderal Gatot Subroto", "designation": "3", "brand:wikidata": "Q920166", "brand:wikipedia": "en:Ibis (hotel)", "building:levels": "24"}, "type": "way", "center": {"lat": -6.9272422, "lon": 107.6365505}, "_source": "overpass_osm"}	c63e1418e525831b9e4127784edf1c1c1e4b8a5e350ce84a57b77227d06783b3	approved	2026-09-30 09:14:51.059384+00
475	1	https://www.openstreetmap.org/way/422236652	{"id": 422236652, "tags": {"name": "The Trans Luxury Hotel", "tourism": "hotel", "building": "hotel", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Gatot Subroto", "designation": "5", "building:levels": "20"}, "type": "way", "center": {"lat": -6.9271024, "lon": 107.636219}, "_source": "overpass_osm"}	58d8843c57ec9d2d38ff3a0f58ecafd4ea31c1ecd9ef38f7ba2c052fd1add12e	approved	2026-09-30 09:14:51.059384+00
476	1	https://www.openstreetmap.org/way/425693199	{"id": 425693199, "tags": {"name": "Atlantic City Hotel Bandung", "phone": "+62224208222", "smoking": "separated", "tourism": "hotel", "website": "http://www.atlanticcityhotelbandung.com", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Pasir Kaliki", "addr:postcode": "40171", "addr:housenumber": "126"}, "type": "way", "center": {"lat": -6.9069293, "lon": 107.5979504}, "_source": "overpass_osm"}	5b7d2ff80f638bf97d7f0013085ab3ba6342246b927590afdd58ff3b93a46dc9	approved	2026-09-30 09:14:51.059384+00
477	1	https://www.openstreetmap.org/way/512057463	{"id": 512057463, "tags": {"name": "Hotel Chrysanta", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9005946, "lon": 107.5979326}, "_source": "overpass_osm"}	0c695a78e9a29fd4c0ae98797ebe3a0bc0f891333c27ad0c9df532cee375ec28	approved	2026-09-30 09:14:51.059384+00
478	1	https://www.openstreetmap.org/way/512168582	{"id": 512168582, "tags": {"name": "Tama Boutique Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.903776, "lon": 107.5986125}, "_source": "overpass_osm"}	a4362936f22d0f5b86bb1b456a6146530f4edd63323b99b047111131f13883ea	approved	2026-09-30 09:14:51.059384+00
480	1	https://www.openstreetmap.org/way/512353719	{"id": 512353719, "tags": {"name": "The Luxton Bandung Hotel", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda No.18", "addr:district": "Bandung Wetan", "addr:postcode": "40115", "addr:province": "Jawa Barat", "internet_access": "wlan", "addr:subdistrict": "Citarum", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.9037378, "lon": 107.6113318}, "_source": "overpass_osm"}	923c1b95e1da82276477a18508e16977c32bc789374d9bbe246df767ebf44fa5	approved	2026-09-30 09:14:51.059384+00
481	1	https://www.openstreetmap.org/way/512353748	{"id": 512353748, "tags": {"name": "Hay Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9033172, "lon": 107.6131155}, "_source": "overpass_osm"}	4ac2b18203ed48a4a9bf6c5369e30c62334203422d867b21a5ba854297cf1909	approved	2026-09-30 09:14:51.059384+00
482	1	https://www.openstreetmap.org/way/512704804	{"id": 512704804, "tags": {"name": "De Paviljoen", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9062605, "lon": 107.6205281}, "_source": "overpass_osm"}	8031cd4e04abf1058acdda239773f096332b9bac510c16478428afb3c03a7d6d	approved	2026-09-30 09:14:51.059384+00
483	1	https://www.openstreetmap.org/way/512704810	{"id": 512704810, "tags": {"name": "Hotel Serela Riau Bandung", "tourism": "hotel", "building": "yes", "check_date": "2026-05-04"}, "type": "way", "center": {"lat": -6.9062632, "lon": 107.6199144}, "_source": "overpass_osm"}	0fc8593ab3289839b034e8422b671c283dcb3eb354b76071f3808294a9dbad6f	approved	2026-09-30 09:14:51.059384+00
484	1	https://www.openstreetmap.org/way/512932720	{"id": 512932720, "tags": {"name": "Kytos Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8694282, "lon": 107.593376}, "_source": "overpass_osm"}	31f2ea2b1597fdd391c95c0b6eab839ffcda8d9f80567b8d89766077aa80c2aa	approved	2026-09-30 09:14:51.059384+00
485	1	https://www.openstreetmap.org/way/513014413	{"id": 513014413, "tags": {"name": "Hotel Latief Inn Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9173071, "lon": 107.6173797}, "_source": "overpass_osm"}	e356657f535d2fc75fa9f763f9f0db2911c811e800eb3126871cf90cf2bb397c	approved	2026-09-30 09:14:51.059384+00
486	1	https://www.openstreetmap.org/way/513238429	{"id": 513238429, "tags": {"name": "Crowne Plaza Hotel Bandung", "brand": "Crowne Plaza", "tourism": "hotel", "building": "yes", "brand:wikidata": "Q2746220"}, "type": "way", "center": {"lat": -6.9170796, "lon": 107.6120171}, "_source": "overpass_osm"}	a4081100a4c6a51b0ae93a9ba8f5465acbd553d3390fc2df607b64f95d3f92cb	approved	2026-09-30 09:14:51.059384+00
487	1	https://www.openstreetmap.org/way/513259571	{"id": 513259571, "tags": {"name": "Latief Inn Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9170244, "lon": 107.6163035}, "_source": "overpass_osm"}	9a94ebba20e3a2ac4eb384183cda70ae9e88c0de0c2a7d12cf73a14ac6455f5e	approved	2026-09-30 09:14:51.059384+00
488	1	https://www.openstreetmap.org/way/513259587	{"id": 513259587, "tags": {"fax": "+62 22 4264245", "name": "Rumah Tawa Hotel", "email": "rumahtawa@ymail.com", "phone": "+62 22 4264244", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Cibuntut"}, "type": "way", "center": {"lat": -6.9169663, "lon": 107.6149261}, "_source": "overpass_osm"}	3894ca66e1c3ab528bd0cd8ed9ada51370a8fa9ecb433d94d80674ffde205af1	approved	2026-09-30 09:14:51.059384+00
489	1	https://www.openstreetmap.org/way/513325733	{"id": 513325733, "tags": {"name": "Hotel Kedaton", "email": "reception@kedatonhotel.com", "phone": "+62 22 4219898", "rooms": "116", "tourism": "hotel", "website": "https://kedatonhotel.com/", "building": "yes", "addr:city": "Bandung", "architect": "CV Griya Kharisma", "start_date": "1997", "addr:street": "Jalan Suniaraja", "addr:postcode": "40111", "building:levels": "7", "internet_access": "wlan", "addr:housenumber": "14", "internet_access:fee": "customers", "year_of_construction": "1994-12..1996-12"}, "type": "way", "center": {"lat": -6.915551, "lon": 107.6078988}, "_source": "overpass_osm"}	8b300211a8035cf4b5b2411aa333e78abbf7e70a05421134e2bf20ee85068e8d	approved	2026-09-30 09:14:51.059384+00
490	1	https://www.openstreetmap.org/way/513325815	{"id": 513325815, "tags": {"name": "Mogens Guest House Bandung", "tourism": "hotel", "building": "yes", "check_date": "2026-09-24"}, "type": "way", "center": {"lat": -6.9119667, "lon": 107.6062832}, "_source": "overpass_osm"}	3388380ce72996a7904bd4626b406c3f562fb12241306908f241c68c32d7d8bc	approved	2026-09-30 09:14:51.059384+00
491	1	https://www.openstreetmap.org/way/513432777	{"id": 513432777, "tags": {"name": "Hotel Kurnia", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9284057, "lon": 107.6167262}, "_source": "overpass_osm"}	0e4dc94753052ba9414b1133633986fd4643556c6ea3d82a72c7025f9dbcc1d2	approved	2026-09-30 09:14:51.059384+00
492	1	https://www.openstreetmap.org/way/513439349	{"id": 513439349, "tags": {"name": "Hotel Montameri Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.930177, "lon": 107.6266441}, "_source": "overpass_osm"}	9cf4d6205bdc8ccdf75d08111dbcd68cc2f5dd4306c163ecd35e4caf7fec65fa	approved	2026-09-30 09:14:51.059384+00
493	1	https://www.openstreetmap.org/way/513524062	{"id": 513524062, "tags": {"name": "Yokotel Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9163547, "lon": 107.6016796}, "_source": "overpass_osm"}	4a722fea679dd14f318b1e407626368cada53cb4ac4d06bc621bea4fb6f4a2c2	approved	2026-09-30 09:14:51.059384+00
494	1	https://www.openstreetmap.org/way/513569070	{"id": 513569070, "tags": {"name": "OYO 944 Doorman Guest House", "brand": "OYO", "tourism": "hotel", "building": "yes", "brand:wikidata": "Q24906315"}, "type": "way", "center": {"lat": -6.9175187, "lon": 107.5996807}, "_source": "overpass_osm"}	02c5074d24eaae43a7071990a422863cff2d858105f997bc8a031ebea9b6cf15	approved	2026-09-30 09:14:51.059384+00
495	1	https://www.openstreetmap.org/way/513810440	{"id": 513810440, "tags": {"name": "Chara Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9223207, "lon": 107.6197044}, "_source": "overpass_osm"}	700913bfcc71daaa4262597a3315faef320197e304b8b825215985a05c6e9f91	approved	2026-09-30 09:14:51.059384+00
496	1	https://www.openstreetmap.org/way/514105041	{"id": 514105041, "tags": {"name": "Hotel Zodiak Asia Afrika Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9211519, "lon": 107.6048829}, "_source": "overpass_osm"}	843770393a3007f1bafe9810f0d4e06aef071711fd1ac64ea3052a53a13ecf1e	approved	2026-09-30 09:14:51.059384+00
497	1	https://www.openstreetmap.org/way/514640354	{"id": 514640354, "tags": {"name": "Andelir Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8962022, "lon": 107.601104}, "_source": "overpass_osm"}	0ab0890c05a24c2c02c9996dee7cc4a872fe631167914c66015f482a9304cb98	approved	2026-09-30 09:14:51.059384+00
499	1	https://www.openstreetmap.org/way/516640017	{"id": 516640017, "tags": {"name": "Gumilang Regency Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8458278, "lon": 107.599553}, "_source": "overpass_osm"}	30b83e80c02b56cd24998b3a6bb6c493f7736ee21b209da3a89045ea471cb37d	approved	2026-09-30 09:14:51.059384+00
500	1	https://www.openstreetmap.org/way/519057340	{"id": 519057340, "tags": {"name": "Cinnamon Hotel Boutique Syariah", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8586379, "lon": 107.595254}, "_source": "overpass_osm"}	29f64c7e93b3c1466b145ae2922238db59db1800b7393975ecb76613902e1ee4	approved	2026-09-30 09:14:51.059384+00
501	1	https://www.openstreetmap.org/way/519673073	{"id": 519673073, "tags": {"name": "Galeri Pusat Kebudayaan", "tourism": "gallery", "building": "yes", "wikidata": "Q10976493", "addr:city": "Bandung", "addr:street": "Jalan Naripan", "addr:postcode": "40111", "opening_hours": "Mo-Su 10:00-18:00", "addr:housenumber": "7-9"}, "type": "way", "center": {"lat": -6.919651, "lon": 107.6103097}, "_source": "overpass_osm"}	4316b00e59d3229dc537f3a83d3d2312878c00735fbb3149076688a991c30558	approved	2026-09-30 09:14:51.059384+00
502	1	https://www.openstreetmap.org/way/520137248	{"id": 520137248, "tags": {"name": "Salis Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8610847, "lon": 107.5951923}, "_source": "overpass_osm"}	fbb1857184cc93cac0eabed742955929016d1bf0a8dd9c873c44698fc33ec102	approved	2026-09-30 09:14:51.059384+00
503	1	https://www.openstreetmap.org/way/520137332	{"id": 520137332, "tags": {"fax": "+62 22 2008975", "name": "Hotel Augusta Valley", "phone": "+62 22 2005036", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Cipaku I", "internet_access": "wlan", "addr:housenumber": "19", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.8639199, "lon": 107.598294}, "_source": "overpass_osm"}	b7e8921857d597d17cbe850c3ff3ebe3aa5ca57b9462627a9b65500f9f941797	approved	2026-09-30 09:14:51.059384+00
504	1	https://www.openstreetmap.org/way/522949322	{"id": 522949322, "tags": {"fee": "yes", "name": "Rabbit Town", "phone": "+622264404848", "tourism": "attraction", "building": "yes", "addr:street": "Jalan Ranca Bentang", "opening_hours": "Su 09:00-20:00; Mo-Sa 10:00-20:00", "addr:housenumber": "30 - 32"}, "type": "way", "center": {"lat": -6.8671824, "lon": 107.6102068}, "_source": "overpass_osm"}	dcc9426b30fa967828b48e4ae7ea7422c133fca3d79a89cb0741f3f2ff329c6a	approved	2026-09-30 09:14:51.059384+00
505	1	https://www.openstreetmap.org/way/522949382	{"id": 522949382, "tags": {"name": "SHEO Resort Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8671645, "lon": 107.6064713}, "_source": "overpass_osm"}	071012b9f86d994bd668efd37dc01d29b6e749368f3e729aa7a723b081989c69	approved	2026-09-30 09:14:51.059384+00
507	1	https://www.openstreetmap.org/way/522949417	{"id": 522949417, "tags": {"name": "Concordia Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.866686, "lon": 107.6082433}, "_source": "overpass_osm"}	1dd64a79dbe5b19c7c0e85313183d951d965b4dfb0e50be5e0fdf4b9642b9f98	approved	2026-09-30 09:14:51.059384+00
508	1	https://www.openstreetmap.org/way/529801202	{"id": 529801202, "tags": {"name": "Amanda Brownies Parking spot", "leisure": "park"}, "type": "way", "center": {"lat": -6.8868701, "lon": 107.6133985}, "_source": "overpass_osm"}	1ff8481677d95415f07005b118c755b65318479042ab761f1b818bf84244066f	approved	2026-09-30 09:14:51.059384+00
509	1	https://www.openstreetmap.org/way/530035434	{"id": 530035434, "tags": {"fee": "yes", "name": "Museum Kota Bandung", "museum": "history", "tourism": "museum", "building": "yes", "wikidata": "Q65212192", "addr:city": "Kota Bandung", "addr:full": "Jl. Aceh No. 47, Babakan Ciamis, Sumur Bandung, Kota Bandung, Jawa Barat 40117", "wikipedia": "id:Museum Kota Bandung", "wheelchair": "yes", "addr:street": "Jalan Aceh", "addr:country": "ID", "addr:postcode": "40117", "building:roof": "tile", "opening_hours": "Tu-Su 10:00-17:00", "building:walls": "brick", "building:levels": "2", "addr:housenumber": "47", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9099764, "lon": 107.6095781}, "_source": "overpass_osm"}	26faac34ec6872190af1457461c548099c5d134fea3fe32f400d38b7ea1359b2	approved	2026-09-30 09:14:51.059384+00
510	1	https://www.openstreetmap.org/way/530164131	{"id": 530164131, "tags": {"name": "Hotel California Bandung", "tourism": "hotel", "addr:full": "Jalan Wastukencana No.48, Tamansari, Bandung Wetan, Tamansari, Bandung Wetan, Kota Bandung, Jawa Barat 40116"}, "type": "way", "center": {"lat": -6.9037985, "lon": 107.6052032}, "_source": "overpass_osm"}	9d357f94c6bd5850365520856587627331741add31c54c841a4dd4b417006830	duplicate	2026-09-30 09:14:51.059384+00
511	1	https://www.openstreetmap.org/way/530304162	{"id": 530304162, "tags": {"name": "Sky City Home", "tourism": "hotel", "building": "house", "addr:street": "Jalan Dago Asri", "addr:housenumber": "C37"}, "type": "way", "center": {"lat": -6.8765997, "lon": 107.6152221}, "_source": "overpass_osm"}	71a7d2987ba8fb9198b056aaddb4b4e84c841039c268a310400b329fa3b7d201	approved	2026-09-30 09:14:51.059384+00
512	1	https://www.openstreetmap.org/way/530331484	{"id": 530331484, "tags": {"name": "Kristalia Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9088505, "lon": 107.6040083}, "_source": "overpass_osm"}	3df3ae4fac6529073d7deeff4f120f2d95fa2b6e65170a740eb2784568b274a0	approved	2026-09-30 09:14:51.059384+00
513	1	https://www.openstreetmap.org/way/530965788	{"id": 530965788, "tags": {"name": "Antapani Home Stay", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.919667, "lon": 107.6648247}, "_source": "overpass_osm"}	24135761d19d5b523f9b42d47cdcebf33274829588b03d6186ab24bdc4bfec92	approved	2026-09-30 09:14:51.059384+00
514	1	https://www.openstreetmap.org/way/536556040	{"id": 536556040, "tags": {"name": "Kos Pak Suherwan", "tourism": "guest_house", "building": "yes", "addr:block": "154B", "addr:street": "Gang Cisitu Lama VII", "guest_house": "student_accommodation", "addr:housenumber": "31"}, "type": "way", "center": {"lat": -6.8798897, "lon": 107.6128305}, "_source": "overpass_osm"}	6b61908ce5a6343ea8ea01b836a3ddc2fc7164b0069e7bf2ac4fd4a09e572eec	approved	2026-09-30 09:14:51.059384+00
515	1	https://www.openstreetmap.org/way/536660878	{"id": 536660878, "tags": {"name": "Alqueby Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9119153, "lon": 107.6510442}, "_source": "overpass_osm"}	8b8d22f561744d8bc8131de76775c7f6b992e13a8dc0a11c41f676604e39e085	approved	2026-09-30 09:14:51.059384+00
534	1	https://www.openstreetmap.org/way/546640090	{"id": 546640090, "tags": {"name": "Taman Sejarah", "source": "POI_WRI_Survey_2023", "leisure": "park", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9103676, "lon": 107.610184}, "_source": "overpass_osm"}	9c1264bbacb98d802c5c4a5851c5f7f3ad0277663a1a5feb8e9757b30eea2eba	approved	2026-09-30 09:14:51.059384+00
516	1	https://www.openstreetmap.org/way/538094726	{"id": 538094726, "tags": {"name": "Taman Saparua", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Banda No. 28, Citarum, Bandung Wetan", "wheelchair": "yes", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.90851, "lon": 107.6164262}, "_source": "overpass_osm"}	94cd03eb2e57825d84e1bc37ab6b2f95fa2d23263bfd7dc3913c801b77c3b367	approved	2026-09-30 09:14:51.059384+00
517	1	https://www.openstreetmap.org/way/538094727	{"id": 538094727, "tags": {"name": "Taman Maluku", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Seram, Citarum, Bandung Wetan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9092736, "lon": 107.6149523}, "_source": "overpass_osm"}	befcebc24f3894ae6087bbe8a42c44aca1bb8b7c5c7eff876f343d60d0d4b580	approved	2026-09-30 09:14:51.059384+00
518	1	https://www.openstreetmap.org/way/538800605	{"id": 538800605, "tags": {"name": "Chinatown Bandung", "phone": "+62 22 6038114", "tourism": "theme_park", "addr:city": "Bandung", "addr:street": "Jalan Kelenteng", "addr:housenumber": "41"}, "type": "way", "center": {"lat": -6.9172497, "lon": 107.5927736}, "_source": "overpass_osm"}	8bb9f0e3d198085a9fb2f7df4e0495475ac8c647bcfd449080364bcd1dc6804d	approved	2026-09-30 09:14:51.059384+00
519	1	https://www.openstreetmap.org/way/541314204	{"id": 541314204, "tags": {"name": "Taman TOKA (Tanaman Obat, Kosmetik dan Aromaterapi)", "leisure": "garden", "operator": "Sekolah Farmasi ITB", "garden:type": "educational", "operator:type": "university"}, "type": "way", "center": {"lat": -6.8903536, "lon": 107.61074}, "_source": "overpass_osm"}	82d49f835de63ab973fc50da29f6cc7b05a5d63ab122e3d6c1435f9c1cbb9cfc	approved	2026-09-30 09:14:51.059384+00
520	1	https://www.openstreetmap.org/way/545973406	{"id": 545973406, "tags": {"name": "Taman Parkir Umum", "leisure": "park"}, "type": "way", "center": {"lat": -6.8854379, "lon": 107.6245703}, "_source": "overpass_osm"}	8ccfdf6f8d5febe54d479a7c7aefdecb98d757fe45c95feecd459073a3a92e7b	approved	2026-09-30 09:14:51.059384+00
521	1	https://www.openstreetmap.org/way/545973409	{"id": 545973409, "tags": {"name": "Bumi Samami", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Terusan Cigadung No. 15", "wheelchair": "no", "opening_hours": "Mo-Su 08:00-16:00"}, "type": "way", "center": {"lat": -6.8840439, "lon": 107.6237325}, "_source": "overpass_osm"}	3fd59006cb7067081e40acd68d26ddff613a2fff9235a9178f1be77bac7024dd	approved	2026-09-30 09:14:51.059384+00
522	1	https://www.openstreetmap.org/way/545984955	{"id": 545984955, "tags": {"name": "Taman Binaan LPM", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Tubagus Ismail Raya", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8852061, "lon": 107.6156721}, "_source": "overpass_osm"}	ac2c5f6a84cb4ecd7503f8a05f9a8e88974e323caebcc74dfaf8261012091dd1	approved	2026-09-30 09:14:51.059384+00
524	1	https://www.openstreetmap.org/way/545984960	{"id": 545984960, "tags": {"name": "Dago North Pedestrian Park 2", "leisure": "garden"}, "type": "way", "center": {"lat": -6.8884506, "lon": 107.6139364}, "_source": "overpass_osm"}	fe9cfb867288f255906f76b1838fbcbc1a3228181ea4b8aee0fe2624e1a1cc71	approved	2026-09-30 09:14:51.059384+00
525	1	https://www.openstreetmap.org/way/545984961	{"id": 545984961, "tags": {"name": "Dago Pedestrian Park 2", "leisure": "garden"}, "type": "way", "center": {"lat": -6.8931503, "lon": 107.6136805}, "_source": "overpass_osm"}	d12ffb4ade3d86e2013957f3bc66f38dbcc6e991b8adec6709b7055bb5d30325	approved	2026-09-30 09:14:51.059384+00
526	1	https://www.openstreetmap.org/way/545984972	{"id": 545984972, "tags": {"name": "Taman Kota RTH Tirtawening", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Badaksinga depan PDAM", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8967494, "lon": 107.6105673}, "_source": "overpass_osm"}	72c336373a4cee1dd3de735928356d96b56fad5c27fb57dd5b46604e3bb38bf3	approved	2026-09-30 09:14:51.059384+00
527	1	https://www.openstreetmap.org/way/545984973	{"id": 545984973, "tags": {"name": "Taman Tugu KB", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl Cihampelas", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8846895, "lon": 107.6044583}, "_source": "overpass_osm"}	c63c8c6cdc4a89c7bdac8dbcc5babccbc5b6d337ebdf1b61e1cf436342151bca	approved	2026-09-30 09:14:51.059384+00
528	1	https://www.openstreetmap.org/way/545984974	{"id": 545984974, "tags": {"name": "Taman Hegarmanah", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.8781656, "lon": 107.6001256}, "_source": "overpass_osm"}	3997b1d6ce40e07a2db523f7d6d3e6915dcccf9aab1be0507fd159e89225fc64	approved	2026-09-30 09:14:51.059384+00
529	1	https://www.openstreetmap.org/way/546210764	{"id": 546210764, "tags": {"name": "Taman Segitiga Dago", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Siliwangi", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8852485, "lon": 107.6130272}, "_source": "overpass_osm"}	3825d6e228ad2d98a20a3f8e26133bc0eb5de71d988849055634605e74df76a8	approved	2026-09-30 09:14:51.059384+00
530	1	https://www.openstreetmap.org/way/546473715	{"id": 546473715, "tags": {"name": "V Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.881848, "lon": 107.584638}, "_source": "overpass_osm"}	52ec2e364266aa61aec26c3acffbeed725517eee54c5391750b3f278b5fcce45	approved	2026-09-30 09:14:51.059384+00
531	1	https://www.openstreetmap.org/way/546634832	{"id": 546634832, "tags": {"name": "Hotel NEO Dipatiukur", "tourism": "hotel", "building": "yes", "check_date": "2025-12-13"}, "type": "way", "center": {"lat": -6.8898497, "lon": 107.616458}, "_source": "overpass_osm"}	137b2ffac690b78843f92dd7cec9c0ff917671585bc2c5efdd614b49417d5b66	approved	2026-09-30 09:14:51.059384+00
532	1	https://www.openstreetmap.org/way/546640085	{"id": 546640085, "tags": {"name": "Taman Gasibu", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Surapati", "wheelchair": "yes", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9003224, "lon": 107.6186612}, "_source": "overpass_osm"}	73022702ca05da3631a2f27842af52b4cd7efd9a5ff5491b32ef9660a39b0ae5	approved	2026-09-30 09:14:51.059384+00
533	1	https://www.openstreetmap.org/way/546640087	{"id": 546640087, "tags": {"name": "Taman Cibeunying", "source": "POI_WRI_Survey_2023", "leisure": "park", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9054022, "lon": 107.6245492}, "_source": "overpass_osm"}	bfb7a9e8cca2a28ac48f9fc30e365bfbc9aa12410d976541541f6bc4b21c95af	approved	2026-09-30 09:14:51.059384+00
535	1	https://www.openstreetmap.org/way/546721635	{"id": 546721635, "tags": {"name": "Homy Kost Ekslusif Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8841694, "lon": 107.6119671}, "_source": "overpass_osm"}	862ed9440803f12de7cb2da3bbebd8620aca514b21b86804349a51c397878cb1	approved	2026-09-30 09:14:51.059384+00
536	1	https://www.openstreetmap.org/way/547802076	{"id": 547802076, "tags": {"name": "Ruang Terbuka Publik (RTP) Itenas", "leisure": "garden", "website": "https://www.medcom.id/pendidikan/news-pendidikan/yKXqm64N-walkot-bandung-dorong-perguruan-tinggi-ikut-jejak-itenas-bikin-ruang-terbuka-publik"}, "type": "way", "center": {"lat": -6.8979616, "lon": 107.6355806}, "_source": "overpass_osm"}	b4da82c2bbf62f89adbf8848870ba29a07c26064e68447495310d54433fbe574	approved	2026-09-30 09:14:51.059384+00
537	1	https://www.openstreetmap.org/way/547914280	{"id": 547914280, "tags": {"name": "Taman Dinas Perpus dan Arsip Bandung", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "yes"}, "type": "way", "center": {"lat": -6.9079152, "lon": 107.6136026}, "_source": "overpass_osm"}	2b2bf39c08055a8410935b6999f4a1aa037dbd1984387a4a3481e8437c161c68	approved	2026-09-30 09:14:51.059384+00
538	1	https://www.openstreetmap.org/way/547922945	{"id": 547922945, "tags": {"name": "Taman PUSDAI", "source": "POI_WRI_Survey_2023", "leisure": "park", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9001239, "lon": 107.6259415}, "_source": "overpass_osm"}	1dcce0fc7482f2c06251994fa9818dd1897b28263c218524e0bbaf97e10784de	approved	2026-09-30 09:14:51.059384+00
539	1	https://www.openstreetmap.org/way/548307336	{"id": 548307336, "tags": {"name": "Taman Sosiologi", "leisure": "park"}, "type": "way", "center": {"lat": -6.8830471, "lon": 107.6233803}, "_source": "overpass_osm"}	5b4f31eae78adccb3902c231482a10b81c14e45c22ecc3845412e9bdcf855ecf	approved	2026-09-30 09:14:51.059384+00
540	1	https://www.openstreetmap.org/way/548319227	{"id": 548319227, "tags": {"name": "Vio Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9031147, "lon": 107.6212304}, "_source": "overpass_osm"}	4113f4b592cc2dae27264f810b68e70ecd2ff51d9f059eb676f0f512fa4e05d4	approved	2026-09-30 09:14:51.059384+00
541	1	https://www.openstreetmap.org/way/548325514	{"id": 548325514, "tags": {"name": "Taman Teknik Sipil", "leisure": "park"}, "type": "way", "center": {"lat": -6.8921581, "lon": 107.6100336}, "_source": "overpass_osm"}	0e60061325bb604db0f45ae61a96ebfc25254b12d34b6c92d63857923e2cfd4f	approved	2026-09-30 09:14:51.059384+00
542	1	https://www.openstreetmap.org/way/548325515	{"id": 548325515, "tags": {"name": "Lapangan Radar", "leisure": "park"}, "type": "way", "center": {"lat": -6.8908187, "lon": 107.60841}, "_source": "overpass_osm"}	4733108257a4e73440ccb1982854209edfe5e967fa164c252754a6efedd4fced	approved	2026-09-30 09:14:51.059384+00
543	1	https://www.openstreetmap.org/way/548325516	{"id": 548325516, "tags": {"name": "Taman Parkir Sipil", "leisure": "park"}, "type": "way", "center": {"lat": -6.8922593, "lon": 107.6084799}, "_source": "overpass_osm"}	ea33495700372807a852684c8dfc3e02d035f23228170974de666cecd5397145	approved	2026-09-30 09:14:51.059384+00
544	1	https://www.openstreetmap.org/way/548325519	{"id": 548325519, "tags": {"name": "Taman Masjid Salman", "leisure": "park"}, "type": "way", "center": {"lat": -6.8936626, "lon": 107.6113308}, "_source": "overpass_osm"}	f23541e100e697fb7e66fa757514298420d1e2a7a45134464b408d29e6bba9ce	approved	2026-09-30 09:14:51.059384+00
545	1	https://www.openstreetmap.org/way/548325521	{"id": 548325521, "tags": {"name": "Kebun Botani GKU Barat", "leisure": "park", "name:en": "Botany Garden"}, "type": "way", "center": {"lat": -6.8903221, "lon": 107.6084866}, "_source": "overpass_osm"}	0a35d5d2d1ad95975e79eaf2a67018d034d9f07cd60887599f26005c15578ccb	approved	2026-09-30 09:14:51.059384+00
546	1	https://www.openstreetmap.org/way/548325522	{"id": 548325522, "tags": {"name": "DPR", "leisure": "park", "description": "Di Bawah Pohon RIndang"}, "type": "way", "center": {"lat": -6.8898116, "lon": 107.6102936}, "_source": "overpass_osm"}	b2498eec0f3fead9d0c42d736fb41e7e0e53194327c26c7dea240e47d25103c4	approved	2026-09-30 09:14:51.059384+00
547	1	https://www.openstreetmap.org/way/548325527	{"id": 548325527, "tags": {"name": "Lapangan Barrac", "leisure": "park"}, "type": "way", "center": {"lat": -6.8917022, "lon": 107.6114778}, "_source": "overpass_osm"}	a76e680da6d3dec7009fcc01f27c89d14f3412617e3534d938902c5b6ba285ed	approved	2026-09-30 09:14:51.059384+00
548	1	https://www.openstreetmap.org/way/548325529	{"id": 548325529, "tags": {"name": "Taman Planologi", "leisure": "park"}, "type": "way", "center": {"lat": -6.8916265, "lon": 107.6109556}, "_source": "overpass_osm"}	a0dedc025ea5b04aad19bc61412ed7cc8bae35c5d7d3db9b757da25c0cf10005	approved	2026-09-30 09:14:51.059384+00
549	1	https://www.openstreetmap.org/way/548325545	{"id": 548325545, "tags": {"name": "Taman Perminyakan", "leisure": "park"}, "type": "way", "center": {"lat": -6.8886618, "lon": 107.6116284}, "_source": "overpass_osm"}	aad2185f073eff14cdad8f53c705847dc5b00f58a494cd87de28736ba0cdbda2	approved	2026-09-30 09:14:51.059384+00
550	1	https://www.openstreetmap.org/way/548325557	{"id": 548325557, "tags": {"name": "Lapangan Bioskop Kampus", "leisure": "park"}, "type": "way", "center": {"lat": -6.8920448, "lon": 107.6111551}, "_source": "overpass_osm"}	66fa567bdfc3c470ba01915612b4ffbb80b31ed6b3f770cc81e506a9e07e2a20	approved	2026-09-30 09:14:51.059384+00
551	1	https://www.openstreetmap.org/way/548338829	{"id": 548338829, "tags": {"name": "Taman Lembah Tubagus", "leisure": "park"}, "type": "way", "center": {"lat": -6.8847336, "lon": 107.62496}, "_source": "overpass_osm"}	8e02464a231d8d369ff9c09550bf42233a62d98050c6276dcf25c7e405c3aef3	approved	2026-09-30 09:14:51.059384+00
552	1	https://www.openstreetmap.org/way/548474102	{"id": 548474102, "tags": {"name": "Galeri Soemardja", "tourism": "gallery", "building": "yes", "wikidata": "Q65212157", "addr:street": "Jalan Ganesha", "opening_hours": "Tu-Fr 09:00-16:00", "addr:housenumber": "10"}, "type": "way", "center": {"lat": -6.8924445, "lon": 107.6115509}, "_source": "overpass_osm"}	ef3feaf8ef515c12f4b6b55d6cccf52b4baaeb7e9b86c34b3f3dd9a3fcb76226	duplicate	2026-09-30 09:14:51.059384+00
553	1	https://www.openstreetmap.org/way/548474142	{"id": 548474142, "tags": {"name": "Pondok Bunda", "tourism": "guest_house", "building": "yes", "internet_access": "wlan"}, "type": "way", "center": {"lat": -6.8897518, "lon": 107.6214315}, "_source": "overpass_osm"}	1ade191a1c0193b6df03f64e5931100d71901f3622af1a897bcd8b84ad182259	approved	2026-09-30 09:14:51.059384+00
554	1	https://www.openstreetmap.org/way/548475475	{"id": 548475475, "tags": {"name": "Fasum SG Park", "leisure": "park", "addr:city": "Bandung", "addr:unit": "1", "addr:street": "Sutra Graha", "addr:postcode": "40267"}, "type": "way", "center": {"lat": -6.9548313, "lon": 107.6216668}, "_source": "overpass_osm"}	58217bc61a333d6ce1c29e3ffc1c1de02d371740cf45235c14cdf8731c5f3f39	approved	2026-09-30 09:14:51.059384+00
555	1	https://www.openstreetmap.org/way/548475582	{"id": 548475582, "tags": {"name": "SG Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.9556311, "lon": 107.6210756}, "_source": "overpass_osm"}	203bd520dc4d32c4ca6632739967fcdc0ed447d204411b1c8c5671a8de15f431	approved	2026-09-30 09:14:51.059384+00
556	1	https://www.openstreetmap.org/way/549277439	{"id": 549277439, "tags": {"name": "Taman RW 14 Sadang Sari", "leisure": "park"}, "type": "way", "center": {"lat": -6.8887673, "lon": 107.625412}, "_source": "overpass_osm"}	018969f34fa1da6aaf7314c0594f796988a4dab84a3d48696289db4307cdab99	approved	2026-09-30 09:14:51.059384+00
557	1	https://www.openstreetmap.org/way/549279376	{"id": 549279376, "tags": {"name": "Taman Lotus", "leisure": "park"}, "type": "way", "center": {"lat": -6.8809498, "lon": 107.6207198}, "_source": "overpass_osm"}	2e92d9042442b262766c3ad9ec0a2203e78be4f413f8fd82e921d471a25784b6	approved	2026-09-30 09:14:51.059384+00
558	1	https://www.openstreetmap.org/way/550477281	{"id": 550477281, "tags": {"name": "Taman Gamma", "leisure": "park"}, "type": "way", "center": {"lat": -6.877985, "lon": 107.6261169}, "_source": "overpass_osm"}	22e67f02c56ad6cc6be1b2832e742ef716ad1775efc0ac03b77b3709d1c7679b	approved	2026-09-30 09:14:51.059384+00
559	1	https://www.openstreetmap.org/way/550629663	{"id": 550629663, "tags": {"name": "Taman Ciwalk", "leisure": "park"}, "type": "way", "center": {"lat": -6.8940553, "lon": 107.6048889}, "_source": "overpass_osm"}	3e2cb096464f19cd14435b10af4fb5de782ad35e5801056fa0d91bc67de13e89	approved	2026-09-30 09:14:51.059384+00
560	1	https://www.openstreetmap.org/way/550633636	{"id": 550633636, "tags": {"name": "taman Rumah Mode", "leisure": "park"}, "type": "way", "center": {"lat": -6.8826903, "lon": 107.5997195}, "_source": "overpass_osm"}	2a5a451dc2a7124271a4e876a45c21f358ebcbe2b6d6dbf97d4aeb0772146e40	approved	2026-09-30 09:14:51.059384+00
561	1	https://www.openstreetmap.org/way/550634187	{"id": 550634187, "tags": {"name": "Taman Eatboss", "leisure": "park"}, "type": "way", "center": {"lat": -6.8732455, "lon": 107.6054419}, "_source": "overpass_osm"}	f1aa0f1ebe21152951fb54ab0afda0753377e50a88d7aa9dd145adc6d26d4400	approved	2026-09-30 09:14:51.059384+00
562	1	https://www.openstreetmap.org/way/551635068	{"id": 551635068, "tags": {"name": "Taman salam", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "name:en": "Salam Park", "addr:city": "Bandung", "addr:full": "Jalan Salam, Cihapit, Bandung Wetan", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.909146, "lon": 107.6295702}, "_source": "overpass_osm"}	dd7a7c9ba670eb5c20719cff0eb4f69018c934d42d6ab11aa01a808e2c364927	approved	2026-09-30 09:14:51.059384+00
563	1	https://www.openstreetmap.org/way/551635361	{"id": 551635361, "tags": {"name": "Taman Puskesmas Salam", "leisure": "park"}, "type": "way", "center": {"lat": -6.9100339, "lon": 107.6298369}, "_source": "overpass_osm"}	43277136e00c3c0c1c61dd81b2e1f6b7d458c4f924b104e04c269bfd8778d1f6	approved	2026-09-30 09:14:51.059384+00
564	1	https://www.openstreetmap.org/way/553910796	{"id": 553910796, "tags": {"name": "Karang Setra Water Park", "landuse": "commercial", "leisure": "water_park", "opening_hours": "Mo-Su 08:00-20:00"}, "type": "way", "center": {"lat": -6.8786236, "lon": 107.5948828}, "_source": "overpass_osm"}	cb581bfc6bbd809d3f647bcdd358acc9938c8b703b7674710b8d066449566797	approved	2026-09-30 09:14:51.059384+00
565	1	https://www.openstreetmap.org/way/556263229	{"id": 556263229, "tags": {"name": "Taman Veteran", "leisure": "park"}, "type": "way", "center": {"lat": -6.9214932, "lon": 107.6190523}, "_source": "overpass_osm"}	096ec47f12e30eb3f5cdd20f24848c5512df1a220e717cd0ab29a61eb0f2574d	approved	2026-09-30 09:14:51.059384+00
566	1	https://www.openstreetmap.org/way/556308928	{"id": 556308928, "tags": {"name": "Taman Depan Porwitabes", "leisure": "park"}, "type": "way", "center": {"lat": -6.9140041, "lon": 107.6104267}, "_source": "overpass_osm"}	1c72298e0bfb5ac056c13ba45113df52ae2fa6f903c533b68555da2af5307ea3	approved	2026-09-30 09:14:51.059384+00
567	1	https://www.openstreetmap.org/way/556308937	{"id": 556308937, "tags": {"name": "Taman Masjid Istiqomah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9046852, "lon": 107.6216621}, "_source": "overpass_osm"}	a98791fe20bb29cb35e2775993da24df809e3fee81e7af18afa6493ffa1d89fe	approved	2026-09-30 09:14:51.059384+00
568	1	https://www.openstreetmap.org/way/557564409	{"id": 557564409, "tags": {"name": "Alun-Alun Cicendo", "leisure": "park"}, "type": "way", "center": {"lat": -6.9107767, "lon": 107.5889522}, "_source": "overpass_osm"}	d52655334aeb2317e4441b1fd795f5b8d26eacd69549e2468fa9e6b3821f7f47	approved	2026-09-30 09:14:51.059384+00
569	1	https://www.openstreetmap.org/way/557564414	{"id": 557564414, "tags": {"name": "Taman Monumen KTT Non Blok", "leisure": "park", "name:en": "Non Block High Level Conference Monument Park", "surface": "grass", "addr:city": "Bandung", "addr:street": "Jalan Pajajaran", "description": "Taman yang didalamnya Terdapat monumen untuk memperingati diadakannya KTT Non Blok di Indonesia"}, "type": "way", "center": {"lat": -6.9073189, "lon": 107.592539}, "_source": "overpass_osm"}	7b2d74c6dbc14fd432c6e3705e9b22d657ee42fd3e6eb2b79b942e4ce04c0798	approved	2026-09-30 09:14:51.059384+00
570	1	https://www.openstreetmap.org/way/557564416	{"id": 557564416, "tags": {"name": "Taman simpang Jalan Dr. Cipto / Jalan Pajajaran", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9066179, "lon": 107.5992799}, "_source": "overpass_osm"}	e409b7c7cdb3b04d3a796d7f9c1ba5295514828a2c723ca70836e7bcc8001bb1	approved	2026-09-30 09:14:51.059384+00
571	1	https://www.openstreetmap.org/way/557564431	{"id": 557564431, "tags": {"name": "Taman Cihapit", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Cihapit, Cihapit, Bandung Wetan", "wheelchair": "limited", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9061722, "lon": 107.6247839}, "_source": "overpass_osm"}	eac213d45b143ac008dbf758d567adb83cf0b65c539aa5d9a9da0d148d288a2f	approved	2026-09-30 09:14:51.059384+00
572	1	https://www.openstreetmap.org/way/557567425	{"id": 557567425, "tags": {"name": "Taman Pandawa", "leisure": "park"}, "type": "way", "center": {"lat": -6.9091665, "lon": 107.5934}, "_source": "overpass_osm"}	9bd9f93ef7cfd6ca1cbb4727ade29636dffc6988a160057ef0c5fd1b63985aa0	approved	2026-09-30 09:14:51.059384+00
573	1	https://www.openstreetmap.org/way/557567426	{"id": 557567426, "tags": {"name": "Alun-alun Ujungberung", "leisure": "park"}, "type": "way", "center": {"lat": -6.9137329, "lon": 107.7015684}, "_source": "overpass_osm"}	502bafb893ad770b93dc2009fcb2a45a44d0262d0facdc7a349f685ed4b38d92	approved	2026-09-30 09:14:51.059384+00
574	1	https://www.openstreetmap.org/way/557965293	{"id": 557965293, "tags": {"name": "Lapangan RW 11", "leisure": "park"}, "type": "way", "center": {"lat": -6.8821557, "lon": 107.5757892}, "_source": "overpass_osm"}	5409cb71d18ccca3d4541accad27edd645f5c4bf058f15b2f621b1b459caa903	approved	2026-09-30 09:14:51.059384+00
575	1	https://www.openstreetmap.org/way/557965294	{"id": 557965294, "tags": {"name": "Taman Bermain RW 11", "leisure": "park"}, "type": "way", "center": {"lat": -6.8818323, "lon": 107.5755468}, "_source": "overpass_osm"}	05089911afd73a1286f8bfa53b3a8e6b0233e58dfa8d64fd8779455af895acdc	approved	2026-09-30 09:14:51.059384+00
576	1	https://www.openstreetmap.org/way/558554788	{"id": 558554788, "tags": {"name": "Emerald Towers Park A", "leisure": "park"}, "type": "way", "center": {"lat": -6.9322117, "lon": 107.6643576}, "_source": "overpass_osm"}	c851ab96f1bcd109eda72c45cb30882a9a0490e549abc4924249542c38c7a065	approved	2026-09-30 09:14:51.059384+00
577	1	https://www.openstreetmap.org/way/558554792	{"id": 558554792, "tags": {"name": "Emerald Towers Park B", "leisure": "park"}, "type": "way", "center": {"lat": -6.9325288, "lon": 107.6642863}, "_source": "overpass_osm"}	60d0a88acbcf2f9e75598f8e97d39f556e6acb2102150dee57191c17ee9d7a8b	duplicate	2026-09-30 09:14:51.059384+00
578	1	https://www.openstreetmap.org/way/558554796	{"id": 558554796, "tags": {"name": "JNE Parking Lot", "leisure": "park"}, "type": "way", "center": {"lat": -6.9328902, "lon": 107.6638266}, "_source": "overpass_osm"}	ab600034bcd2753fe03231c841d9fc851d4506ac2d9578e6f2b6e8cd26ae9962	approved	2026-09-30 09:14:51.059384+00
579	1	https://www.openstreetmap.org/way/558554805	{"id": 558554805, "tags": {"name": "Emerald Towers Parking Lot A", "leisure": "park"}, "type": "way", "center": {"lat": -6.9330065, "lon": 107.6642154}, "_source": "overpass_osm"}	376010c317b391669f0ae933c1668128d930a95aca8b428baddedfaaa069118f	approved	2026-09-30 09:14:51.059384+00
580	1	https://www.openstreetmap.org/way/558554808	{"id": 558554808, "tags": {"name": "Emerald Towers Parking Lot B", "leisure": "park"}, "type": "way", "center": {"lat": -6.9317844, "lon": 107.6644668}, "_source": "overpass_osm"}	31dc2bcaffc8f25955c31611503b5f5e0774179a97ec47888c485b93efac9a3b	approved	2026-09-30 09:14:51.059384+00
581	1	https://www.openstreetmap.org/way/558554827	{"id": 558554827, "tags": {"name": "Green Pedestrian", "leisure": "park"}, "type": "way", "center": {"lat": -6.9340968, "lon": 107.6638263}, "_source": "overpass_osm"}	f8571d6225cc7ddf9ff607808b499abac98c56c79d23a6219128c94a25b48b33	approved	2026-09-30 09:14:51.059384+00
582	1	https://www.openstreetmap.org/way/558556622	{"id": 558556622, "tags": {"name": "Sanggar Hurip Playground", "leisure": "park"}, "type": "way", "center": {"lat": -6.9358915, "lon": 107.666823}, "_source": "overpass_osm"}	6079b1cad11e7bf43b1cfdb01eda077cb5485bc4b3882b1a112c8e56145372a9	approved	2026-09-30 09:14:51.059384+00
583	1	https://www.openstreetmap.org/way/564995555	{"id": 564995555, "tags": {"name": "Taman Sidoluhur", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.8938399, "lon": 107.6329715}, "_source": "overpass_osm"}	74190b7006c19e9c489b9ea961bd1ca37d6a71db1353172a1b4af13a49f771d6	approved	2026-09-30 09:14:51.059384+00
584	1	https://www.openstreetmap.org/way/579485239	{"id": 579485239, "tags": {"name": "Taman Anak Tongkeng", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9117722, "lon": 107.6234409}, "_source": "overpass_osm"}	61cb36d27f89fe8b6ec51eb92bd5041631a634271f9d0fda5435fead59fae01b	approved	2026-09-30 09:14:51.059384+00
585	1	https://www.openstreetmap.org/way/622111127	{"id": 622111127, "tags": {"name": "Peta Park", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Peta No. 229", "wheelchair": "limited", "opening_hours": "Tu-Su 07:00-15:00"}, "type": "way", "center": {"lat": -6.9317303, "lon": 107.5881759}, "_source": "overpass_osm"}	595d0d02c9c1e3e56e71dc14c1c48215a6484546db567d11a143405af8249618	approved	2026-09-30 09:14:51.059384+00
586	1	https://www.openstreetmap.org/way/629346935	{"id": 629346935, "tags": {"name": "Swan House", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8730069, "lon": 107.6060528}, "_source": "overpass_osm"}	e38f65e8bd629af0b45d9e4aa201c3376145f674616351a488e417b897f82b54	approved	2026-09-30 09:14:51.059384+00
587	1	https://www.openstreetmap.org/way/632229280	{"id": 632229280, "tags": {"name": "Dbest Express Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9454353, "lon": 107.6085771}, "_source": "overpass_osm"}	8fb3a2751fa0ab59463fabe562a82790690a45166c7fc43b76f4dcfece44b817	approved	2026-09-30 09:14:51.059384+00
588	1	https://www.openstreetmap.org/way/632231657	{"id": 632231657, "tags": {"name": "The Batik Bed And Coffee Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9464426, "lon": 107.6127263}, "_source": "overpass_osm"}	d2de2ce493ef7323328960881bbc1d4a071c3557a7b191099bb2d266b6d8df43	approved	2026-09-30 09:14:51.059384+00
589	1	https://www.openstreetmap.org/way/632254939	{"id": 632254939, "tags": {"name": "P Hostel Bandung", "tourism": "hostel", "building": "yes"}, "type": "way", "center": {"lat": -6.9374995, "lon": 107.6020992}, "_source": "overpass_osm"}	43c518add68c7e330c69c418d72be61d37cdc764faa24bfb61a7e2c4ee3ea421	approved	2026-09-30 09:14:51.059384+00
590	1	https://www.openstreetmap.org/way/632544348	{"id": 632544348, "tags": {"name": "D Best Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9296455, "lon": 107.6033232}, "_source": "overpass_osm"}	8df4740275cee3758faa6e458f764b377b9cbdc5e938ac684ce70a22a32e4172	approved	2026-09-30 09:14:51.059384+00
591	1	https://www.openstreetmap.org/way/632553819	{"id": 632553819, "tags": {"name": "Hotel Grand Tulip Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9300286, "lon": 107.5975441}, "_source": "overpass_osm"}	6d44d34c933d2e4a335357f4bba7696decc4e050cb7529144278a8523b1dcf73	approved	2026-09-30 09:14:51.059384+00
592	1	https://www.openstreetmap.org/way/632681439	{"id": 632681439, "tags": {"name": "Hotel Nyland 3 Cijagra", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9484018, "lon": 107.6257272}, "_source": "overpass_osm"}	4ec009563cea0a0e7c8421b37a08b904cdf86bf79602eb9053e0e490df5e704b	approved	2026-09-30 09:14:51.059384+00
593	1	https://www.openstreetmap.org/way/632681480	{"id": 632681480, "tags": {"name": "Asri Residence", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9486533, "lon": 107.6252311}, "_source": "overpass_osm"}	ea0ca70fc1f5a59253d0a16dd81301edf2ec0103a64ac150663f619adcdc11a3	approved	2026-09-30 09:14:51.059384+00
594	1	https://www.openstreetmap.org/way/633172661	{"id": 633172661, "tags": {"name": "Hotel Arimbi Kopo", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9464709, "lon": 107.589343}, "_source": "overpass_osm"}	2535135b06f19a67dc3b7833c1629724a6ca4794933b4fdf339ff80b6933daba	approved	2026-09-30 09:14:51.059384+00
595	1	https://www.openstreetmap.org/way/633176935	{"id": 633176935, "tags": {"name": "Hotel Eve Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9485884, "lon": 107.5949695}, "_source": "overpass_osm"}	0edf0b4754d18b0bb1274b3dc0bc96b6611109342ba4974ba71b8b9b78803313	approved	2026-09-30 09:14:51.059384+00
596	1	https://www.openstreetmap.org/way/633755573	{"id": 633755573, "tags": {"name": "Taman Bermain", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Komplek C Taman Anggrek", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9338398, "lon": 107.5860405}, "_source": "overpass_osm"}	1c88a49af8bdb05aa919e7f7427e91cb68ddc2b58f801abcc052e66ef11a961a	approved	2026-09-30 09:14:51.059384+00
597	1	https://www.openstreetmap.org/way/633769488	{"id": 633769488, "tags": {"name": "Fora Guest House Suka Asih", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9371284, "lon": 107.5922782}, "_source": "overpass_osm"}	16bae6af3b2891a323362cc679bfda7a52272d2fa4b855bb9a904b4c37cea306	approved	2026-09-30 09:14:51.059384+00
598	1	https://www.openstreetmap.org/way/634270768	{"id": 634270768, "tags": {"name": "Gedung Sate", "office": "government", "tourism": "attraction", "building": "office", "addr:city": "BANDUNG", "government": "administrative", "addr:street": "Jalan Diponegoro", "building:use": "government", "addr:postcode": "40115", "building:roof": "tile", "building:walls": "brick", "building:levels": "3", "addr:housenumber": "22", "building:structure": "reinforced_masonry"}, "type": "way", "center": {"lat": -6.9026462, "lon": 107.6187751}, "_source": "overpass_osm"}	3bf50ac361901ed6f8c5554a673eb4dcf1f90ff891c4fffd381aa2192b1bca3e	duplicate	2026-09-30 09:14:51.059384+00
599	1	https://www.openstreetmap.org/way/634629051	{"id": 634629051, "tags": {"name": "Geowisata Inn", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.917279, "lon": 107.5786045}, "_source": "overpass_osm"}	8ff5081eaf9a88072ca4cc7b3e57774fadbe76216b3ed3959f6d97d6e1ee9f28	approved	2026-09-30 09:14:51.059384+00
600	1	https://www.openstreetmap.org/way/635390760	{"id": 635390760, "tags": {"name": "Parahyangan Residence Pool and Sky Garden (on 26th floor)", "leisure": "park", "addr:city": "Bandung", "check_date": "2026-08-22", "addr:street": "Jalan Ciumbuleuit", "addr:postcode": "40141", "addr:housenumber": "125"}, "type": "way", "center": {"lat": -6.8772526, "lon": 107.6030672}, "_source": "overpass_osm"}	f8350eae56b237e5ff388542291207f56630f6b4d11b81d6f8e3549e50b50362	approved	2026-09-30 09:14:51.059384+00
601	1	https://www.openstreetmap.org/way/635812821	{"id": 635812821, "tags": {"name": "Serela Waringin Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9175194, "lon": 107.5930115}, "_source": "overpass_osm"}	9a69922e553278d19b9f7415f5768c570eaa7bae2105e8719753fcb5c312312e	approved	2026-09-30 09:14:51.059384+00
602	1	https://www.openstreetmap.org/way/635900850	{"id": 635900850, "tags": {"name": "Losmen Leuwi Panjang", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9455642, "lon": 107.5949093}, "_source": "overpass_osm"}	d6b8b5a79b6767051d87e3551466610ea4dc86492c634950f32186ec7897d469	approved	2026-09-30 09:14:51.059384+00
603	1	https://www.openstreetmap.org/way/636145859	{"id": 636145859, "tags": {"name": "Grand Guci Hotel", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan HOS. Tjokroaminoto", "addr:housenumber": "53-55"}, "type": "way", "center": {"lat": -6.9111081, "lon": 107.5975315}, "_source": "overpass_osm"}	20d6df9c26eb59e3880bf24aa8d4223785a7c05ed955bce20f9b32576fd604ba	approved	2026-09-30 09:14:51.059384+00
604	1	https://www.openstreetmap.org/way/636169669	{"id": 636169669, "tags": {"name": "OYO 1308 Darmo Residence", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8970944, "lon": 107.5880202}, "_source": "overpass_osm"}	8283285747e36420d02c671f2f427a94bcb44653ea5d42648fdf1a34416f2560	approved	2026-09-30 09:14:51.059384+00
605	1	https://www.openstreetmap.org/way/636227969	{"id": 636227969, "tags": {"name": "OYO 617 Sukaraja Residence", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8938651, "lon": 107.5735463}, "_source": "overpass_osm"}	b4589c12ab0215d350573c34f1362302e7ccc997505b99c5d7c8f2d516b1096e	approved	2026-09-30 09:14:51.059384+00
606	1	https://www.openstreetmap.org/way/636241818	{"id": 636241818, "tags": {"name": "New Moonlight Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9263715, "lon": 107.5964556}, "_source": "overpass_osm"}	d1e33d77df12504af578b9d66c6920163c17bb8383cc1de81ba38be8514b21cc	approved	2026-09-30 09:14:51.059384+00
607	1	https://www.openstreetmap.org/way/636448775	{"id": 636448775, "tags": {"name": "Hotel Reddoorz Malabar 39 Samoja", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9229919, "lon": 107.6248212}, "_source": "overpass_osm"}	e14ec574f0f2ea65203e694972a2d3b1e51d174084901ba206053171aa1b035c	approved	2026-09-30 09:14:51.059384+00
608	1	https://www.openstreetmap.org/way/637420053	{"id": 637420053, "tags": {"name": "Hunian Kost Sangkuriang", "tourism": "hostel", "building": "yes"}, "type": "way", "center": {"lat": -6.8826507, "lon": 107.6122955}, "_source": "overpass_osm"}	b9064c8eb0e352c090c7ff2545a675e86951ec251cc1b028eb9779d6bf23d399	approved	2026-09-30 09:14:51.059384+00
609	1	https://www.openstreetmap.org/way/637420465	{"id": 637420465, "tags": {"name": "Hunian Kost Sangkuriang", "tourism": "hostel", "building": "yes"}, "type": "way", "center": {"lat": -6.8826931, "lon": 107.6121556}, "_source": "overpass_osm"}	9a23bc01300e9c2f2608b884402633aab30cbad4ae8f35da5ab8f774d2511681	duplicate	2026-09-30 09:14:51.059384+00
610	1	https://www.openstreetmap.org/way/637420766	{"id": 637420766, "tags": {"name": "Hunian Kost Sangkuriang", "tourism": "hostel", "building": "yes", "check_date": "2026-04-24", "addr:street": "Jalan Cisitu Lama", "addr:housenumber": "45B"}, "type": "way", "center": {"lat": -6.8826897, "lon": 107.6120461}, "_source": "overpass_osm"}	7472d516f292e53f2ea33a9a4ad02e0b7019486b20b540214ddb3a75f158dca1	duplicate	2026-09-30 09:14:51.059384+00
611	1	https://www.openstreetmap.org/way/638389091	{"id": 638389091, "tags": {"name": "Javaretro Hotel & Suite", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8885254, "lon": 107.5773756}, "_source": "overpass_osm"}	a51d81e03b2f6a9643e954bfc3fff5205bedbb468e67968733a9682d56d81acc	approved	2026-09-30 09:14:51.059384+00
612	1	https://www.openstreetmap.org/way/638394154	{"id": 638394154, "tags": {"name": "LN9 Guest House Bandung", "tourism": "hotel", "alt_name": "OYO 794", "building": "yes", "internet_access": "wlan", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.8824188, "lon": 107.5792946}, "_source": "overpass_osm"}	ad58d95418b55bd7fc45f71b569adb5824e36ab6c645f50f55fd0bdb3a04e470	duplicate	2026-09-30 09:14:51.059384+00
613	1	https://www.openstreetmap.org/way/638454858	{"id": 638454858, "tags": {"name": "Ariandri Boutique Guesthouse", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8881008, "lon": 107.5825238}, "_source": "overpass_osm"}	8be2acc62a65ada0ee044c4b2dcfdd4c4e2336dc601acaa1875e6f883d4d0a2b	approved	2026-09-30 09:14:51.059384+00
614	1	https://www.openstreetmap.org/way/638461705	{"id": 638461705, "tags": {"name": "Park View Hotel", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Sukajadi", "addr:postcode": "40162", "addr:housenumber": "153"}, "type": "way", "center": {"lat": -6.8861241, "lon": 107.5961832}, "_source": "overpass_osm"}	b2a6f3afa70449902b034dd154183344a7dfca7a49fbbcb42c0ad631b67c3c2c	approved	2026-09-30 09:14:51.059384+00
615	1	https://www.openstreetmap.org/way/638461740	{"id": 638461740, "tags": {"name": "Mess Memed Sastrawirya", "tourism": "motel", "building": "yes"}, "type": "way", "center": {"lat": -6.8863214, "lon": 107.5951149}, "_source": "overpass_osm"}	e79638908f20f2f2e71e6e110e0d5e40b65c9ccaca02e21535ed10102844e6b4	approved	2026-09-30 09:14:51.059384+00
616	1	https://www.openstreetmap.org/way/638470841	{"id": 638470841, "tags": {"name": "Grand Aquila Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8949993, "lon": 107.5898408}, "_source": "overpass_osm"}	f65daf31afd22b0be0f87034b42ee6765c08c0f00920878f6caab0ea1ec7ef35	approved	2026-09-30 09:14:51.059384+00
617	1	https://www.openstreetmap.org/way/638488952	{"id": 638488952, "tags": {"name": "Sukajadi Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8855309, "lon": 107.5971473}, "_source": "overpass_osm"}	93d513eff25b85df37788d30bfbd875fba43aeea30b70d1b3ce0b0f44bb03b1e	approved	2026-09-30 09:14:51.059384+00
618	1	https://www.openstreetmap.org/way/638489886	{"id": 638489886, "tags": {"name": "Belviu Hotel Bandung", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8828257, "lon": 107.6003041}, "_source": "overpass_osm"}	419c5f748c4f201d7b3296d41af4b977547285a5c3010280a60e6c0257cdd2e8	approved	2026-09-30 09:14:51.059384+00
619	1	https://www.openstreetmap.org/way/638490225	{"id": 638490225, "tags": {"name": "Cleo Guest House", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.884412, "lon": 107.5985616}, "_source": "overpass_osm"}	e94703e1dc6c551ccb4fd7f0d651f2a55abfb518bbd0f27ad50a6c72d97ded88	approved	2026-09-30 09:14:51.059384+00
620	1	https://www.openstreetmap.org/way/638490354	{"id": 638490354, "tags": {"name": "Naval Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8849463, "lon": 107.5969133}, "_source": "overpass_osm"}	804b432eda8be7e7dd9f23e488f2e999f45e76aaa2b4c60d91e3fb53ffbe8697	approved	2026-09-30 09:14:51.059384+00
621	1	https://www.openstreetmap.org/way/638684927	{"id": 638684927, "tags": {"name": "ibis Bandung Pasteur", "brand": "Ibis", "rooms": "147", "stars": "3", "floors": "7", "tourism": "hotel", "website": "https://all.accor.com/hotel/9397/index.en.shtml", "building": "yes", "check_date": "2026-05-22", "wheelchair": "yes", "addr:street": "Dokter Djundjunan", "brand:wikidata": "Q920166", "brand:wikipedia": "en:Ibis (hotel)", "addr:housenumber": "22"}, "type": "way", "center": {"lat": -6.8998814, "lon": 107.5960958}, "_source": "overpass_osm"}	723bab4f56240568f6998573e74e7ada3a6414114ebcbf1164287bdd45398644	approved	2026-09-30 09:14:51.059384+00
622	1	https://www.openstreetmap.org/way/639144367	{"id": 639144367, "tags": {"name": "Capital O 1044 Diemdi Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9191323, "lon": 107.6444528}, "_source": "overpass_osm"}	f857c1563ad5b2226a8c7228cd6278c171297264a59ea9652b0a2efb6df053bc	approved	2026-09-30 09:14:51.059384+00
623	1	https://www.openstreetmap.org/way/640405516	{"id": 640405516, "tags": {"name": "Mercure Bandung Nexa Supratman", "brand": "Mercure", "stars": "4", "tourism": "hotel", "building": "yes", "brand:wikidata": "Q1709809"}, "type": "way", "center": {"lat": -6.9049157, "lon": 107.6291721}, "_source": "overpass_osm"}	eb10456e44b6e3cb2004972641abd1f03ae2082679424b81c028c4ab77ca1866	approved	2026-09-30 09:14:51.059384+00
624	1	https://www.openstreetmap.org/way/640405932	{"id": 640405932, "tags": {"name": "Hotel Mitra", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9018433, "lon": 107.6272791}, "_source": "overpass_osm"}	483737f67eaf18e93f317931e759bbef3e13ebf821245178d7acdb75a51b3ffe	approved	2026-09-30 09:14:51.059384+00
625	1	https://www.openstreetmap.org/way/642148336	{"id": 642148336, "tags": {"name": "Papandayan Tower Front Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.8771601, "lon": 107.6038379}, "_source": "overpass_osm"}	329f2d4fe19d5e33f7f06a8eabf89e5a337222241e476c63276d250008d8aa7c	approved	2026-09-30 09:14:51.059384+00
626	1	https://www.openstreetmap.org/way/648346616	{"id": 648346616, "tags": {"name": "Taman", "leisure": "park"}, "type": "way", "center": {"lat": -6.8906464, "lon": 107.6070014}, "_source": "overpass_osm"}	50f5ca5fc5d2731ba04e93b3ea7c82824fe82b593805a551823e7902d4009453	approved	2026-09-30 09:14:51.059384+00
627	1	https://www.openstreetmap.org/way/648346712	{"id": 648346712, "tags": {"name": "Volleyball Field RT 06", "leisure": "park"}, "type": "way", "center": {"lat": -6.9099231, "lon": 107.6986021}, "_source": "overpass_osm"}	aac4c1336d2d6945a76599ed5412bfde889b63d47dd51ac3b60b171508c0d13b	approved	2026-09-30 09:14:51.059384+00
628	1	https://www.openstreetmap.org/way/671794992	{"id": 671794992, "tags": {"name": "Taman", "leisure": "park", "addr:city": "Kel. Pasir Wangi", "addr:postcode": "40618"}, "type": "way", "center": {"lat": -6.9011863, "lon": 107.706863}, "_source": "overpass_osm"}	a3403af5ca33fd17cc7c779ca480ccdce51f4df6fb562e658a0cb80ee9387e2e	approved	2026-09-30 09:14:51.059384+00
629	1	https://www.openstreetmap.org/way/673518847	{"id": 673518847, "tags": {"name": "Hotel Promenade", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8967405, "lon": 107.6040921}, "_source": "overpass_osm"}	635ff204b23a8a195d9ad3310b7aab5696210766536a88dc83dceecd7aa8b631	approved	2026-09-30 09:14:51.059384+00
630	1	https://www.openstreetmap.org/way/678398281	{"id": 678398281, "tags": {"name": "Best Western", "brand": "Best Western", "tourism": "hotel", "building": "yes", "brand:wikidata": "Q830334"}, "type": "way", "center": {"lat": -6.9092238, "lon": 107.6102491}, "_source": "overpass_osm"}	c1aa15e2da016a833a145d81dbf948f7fabd2713df89e3bb7a99f3b2948c3d9e	approved	2026-09-30 09:14:51.059384+00
631	1	https://www.openstreetmap.org/way/700628085	{"id": 700628085, "tags": {"name": "Museum Pendidikan Nasional UPI", "phone": "+6281321512052", "museum": "history", "tourism": "museum", "website": "https://museumpendidikannasional.upi.edu/", "building": "yes", "operator": "Universitas Pendidikan Indonesia", "wikidata": "Q109001002", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Dr. Setiabudi", "addr:postcode": "40154", "opening_hours": "Mo-Th 09:00-11:15, 12:30-15:00; Fr 09:00-11:00, 13:00-15:30", "operator:type": "public", "tactile_paving": "yes", "addr:housenumber": "229"}, "type": "way", "center": {"lat": -6.8597763, "lon": 107.5941633}, "_source": "overpass_osm"}	5016952e42a57b1c7a19fdebb05b4987bbb0f7d04d3d208817a83ff6a7b015c4	approved	2026-09-30 09:14:51.059384+00
632	1	https://www.openstreetmap.org/way/700639066	{"id": 700639066, "tags": {"name": "UPI Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.8623125, "lon": 107.5952801}, "_source": "overpass_osm"}	0b3aa9da45e8ee00e96eea19ac81ecdbf66663d7adfc13f3592af7c0c0e977de	approved	2026-09-30 09:14:51.059384+00
633	1	https://www.openstreetmap.org/way/721493913	{"id": 721493913, "tags": {"name": "Amaris Cimanuk", "tourism": "hotel", "building": "yes", "check_date": "2024-03-27"}, "type": "way", "center": {"lat": -6.9043277, "lon": 107.6207007}, "_source": "overpass_osm"}	c61fccf58d3bc5b4e441d675b16a4945556dbc9481911ba38b314dcb60fe53bd	approved	2026-09-30 09:14:51.059384+00
634	1	https://www.openstreetmap.org/way/725194613	{"id": 725194613, "tags": {"name": "Taman Karang Taruna", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9153461, "lon": 107.6296305}, "_source": "overpass_osm"}	8290a7b1fc2c0cfd4c390dd1e248f74a56e9f55eb12eeb66687d574bc3de602b	approved	2026-09-30 09:14:51.059384+00
635	1	https://www.openstreetmap.org/way/725194614	{"id": 725194614, "tags": {"name": "Gate", "layer": "1", "level": "1", "historic": "city_gate"}, "type": "way", "center": {"lat": -6.9150956, "lon": 107.6297273}, "_source": "overpass_osm"}	2e2a29c1344b62127964a9a3a94a742b373973331c8c7c267ce784682578ef14	approved	2026-09-30 09:14:51.059384+00
636	1	https://www.openstreetmap.org/way/734351252	{"id": 734351252, "tags": {"name": "Taman RW 01", "leisure": "park"}, "type": "way", "center": {"lat": -6.9462444, "lon": 107.6125689}, "_source": "overpass_osm"}	b1a21c0f90e93f9c0971220663aeccc033673581f1e6b5076fb4ff5454f51c9b	approved	2026-09-30 09:14:51.059384+00
637	1	https://www.openstreetmap.org/way/734357298	{"id": 734357298, "tags": {"name": "Taman Piset", "leisure": "park"}, "type": "way", "center": {"lat": -6.9343716, "lon": 107.6254097}, "_source": "overpass_osm"}	4d5582e578b345cbbed66d88e2a03f71766f398772aceba755bd973bab962c45	approved	2026-09-30 09:14:51.059384+00
638	1	https://www.openstreetmap.org/way/734357299	{"id": 734357299, "tags": {"name": "Taman Alifa", "leisure": "park"}, "type": "way", "center": {"lat": -6.9381233, "lon": 107.616436}, "_source": "overpass_osm"}	f437eaf6a9db157fa6536a355c6eb3a0a5a373666648406e6d1979836174ca9d	approved	2026-09-30 09:14:51.059384+00
639	1	https://www.openstreetmap.org/way/735089657	{"id": 735089657, "tags": {"name": "Sekar Manis Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.9408071, "lon": 107.6284187}, "_source": "overpass_osm"}	6ab9285534c24528317b96366594f27332c8e33b0a1e8421d684702779b837c4	approved	2026-09-30 09:14:51.059384+00
640	1	https://www.openstreetmap.org/way/735114087	{"id": 735114087, "tags": {"name": "Menara Air Metro", "barrier": "hedge", "leisure": "park", "name:en": "Metro Tower Park"}, "type": "way", "center": {"lat": -6.9399002, "lon": 107.6671049}, "_source": "overpass_osm"}	b1b7c54c73ca60747ca18ed5896a100ea376bc26b9add9ac146e12bf2ef52b1e	approved	2026-09-30 09:14:51.059384+00
641	1	https://www.openstreetmap.org/way/735115691	{"id": 735115691, "tags": {"name": "Taman Cikawao", "leisure": "park"}, "type": "way", "center": {"lat": -6.9272214, "lon": 107.6132137}, "_source": "overpass_osm"}	8bdd7e45d3db372642456a9897e232c29efd18ce7dbae02c2753963a547af05e	approved	2026-09-30 09:14:51.059384+00
642	1	https://www.openstreetmap.org/way/735116437	{"id": 735116437, "tags": {"name": "Burangrang Triangle Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.922926, "lon": 107.6201049}, "_source": "overpass_osm"}	5a1a9ae40518987f601e0593d394ccdfbf76f6b1a5f45fc35aa8bf8de7014444	approved	2026-09-30 09:14:51.059384+00
643	1	https://www.openstreetmap.org/way/737501869	{"id": 737501869, "tags": {"name": "Taman Setiabudhi Supermarket", "leisure": "park"}, "type": "way", "center": {"lat": -6.8826947, "lon": 107.6015718}, "_source": "overpass_osm"}	efc2c098aac75bc41cf465e0f97be501d9c30c561dff3bd9c366db204ba273fd	approved	2026-09-30 09:14:51.059384+00
644	1	https://www.openstreetmap.org/way/737678927	{"id": 737678927, "tags": {"name": "Taman Saturnus", "leisure": "park"}, "type": "way", "center": {"lat": -6.9529002, "lon": 107.6643521}, "_source": "overpass_osm"}	a8692629c2e6bd374ed7b981eb5ad2eb122fcca091577f89231cfb7c1f549104	approved	2026-09-30 09:14:51.059384+00
645	1	https://www.openstreetmap.org/way/737682742	{"id": 737682742, "tags": {"name": "Taman Depan Balai Sartika", "leisure": "park"}, "type": "way", "center": {"lat": -6.9428422, "lon": 107.6248724}, "_source": "overpass_osm"}	d37678b1bd803227e6a700d2b8869fa6e88e72b4b23e764c6b17cb2f6ac7f180	approved	2026-09-30 09:14:51.059384+00
646	1	https://www.openstreetmap.org/way/737683533	{"id": 737683533, "tags": {"name": "Taman RW 10 Kelurahan Turangga", "leisure": "park"}, "type": "way", "center": {"lat": -6.9367387, "lon": 107.626813}, "_source": "overpass_osm"}	c97a16ab1906d0adaea48374da9f2e98af72d0c00a25c0476edadebe9b898631	approved	2026-09-30 09:14:51.059384+00
647	1	https://www.openstreetmap.org/way/737684344	{"id": 737684344, "tags": {"name": "Taman Durma", "leisure": "park"}, "type": "way", "center": {"lat": -6.9342154, "lon": 107.6280194}, "_source": "overpass_osm"}	880503e5240ae5bece4deb879e97a7e3f14c16020ba0871d5e14f067a03d3237	approved	2026-09-30 09:14:51.059384+00
648	1	https://www.openstreetmap.org/way/739778585	{"id": 739778585, "tags": {"name": "Taman Maung Bandung", "leisure": "park"}, "type": "way", "center": {"lat": -6.907724, "lon": 107.6075148}, "_source": "overpass_osm"}	1efb5eb7378a087fa5a04eeef59ef42b6113a134c5d723babe87d2266a9aa723	approved	2026-09-30 09:14:51.059384+00
649	1	https://www.openstreetmap.org/way/739781047	{"id": 739781047, "tags": {"name": "Taman Tank", "leisure": "park"}, "type": "way", "center": {"lat": -6.9252917, "lon": 107.6300006}, "_source": "overpass_osm"}	07e5cbe72f79e7c50145c01e881a79d93d09167fbedcd6eed2e5e435beab8242	approved	2026-09-30 09:14:51.059384+00
650	1	https://www.openstreetmap.org/way/741776050	{"id": 741776050, "tags": {"name": "Taman Pembauran", "leisure": "park"}, "type": "way", "center": {"lat": -6.9425707, "lon": 107.610618}, "_source": "overpass_osm"}	fa9b164d32a95f8a2e37e759cd3f87b0fe5d051acd6c3a7cd28404614e00d739	approved	2026-09-30 09:14:51.059384+00
651	1	https://www.openstreetmap.org/way/749732420	{"id": 749732420, "tags": {"name": "Taman Kiarasari VI 24", "leisure": "garden", "addr:city": "Kel. Margasari", "addr:street": "Jalan Kiarasari VI", "addr:postcode": "40286", "opening_hours": "24/7", "addr:housenumber": "24"}, "type": "way", "center": {"lat": -6.9480766, "lon": 107.644891}, "_source": "overpass_osm"}	83c9704b15ffb8e1be63b2313d83a9e74ec1fc90400510bad2eb92083f46bb9e	approved	2026-09-30 09:14:51.059384+00
652	1	https://www.openstreetmap.org/way/749732424	{"id": 749732424, "tags": {"name": "Taman Kiarasari VI", "leisure": "garden", "addr:street": "Jalan Kiarasari VI", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9478914, "lon": 107.6449866}, "_source": "overpass_osm"}	a84551c70edcee37cc859f48cf5b7875c524493bc3559b92e36519cf6d48a1a0	duplicate	2026-09-30 09:14:51.059384+00
653	1	https://www.openstreetmap.org/way/749732425	{"id": 749732425, "tags": {"name": "Taman Kiarasari IV", "leisure": "park", "addr:city": "Kel. Margasari", "addr:street": "Jalan Kiarasai IV", "addr:postcode": "40286", "opening_hours": "24/7", "addr:housenumber": "12"}, "type": "way", "center": {"lat": -6.9485303, "lon": 107.6437833}, "_source": "overpass_osm"}	eb8670bee7221497dd7beb42f9c6a2f6e9c218d709646cfd93769aecd6d8d2a6	approved	2026-09-30 09:14:51.059384+00
654	1	https://www.openstreetmap.org/way/749732426	{"id": 749732426, "tags": {"name": "Taman Kiarasari V", "leisure": "park", "addr:city": "Kel. Margasari", "addr:street": "Jalan Kiarasari V", "addr:postcode": "40286", "opening_hours": "24/7", "addr:housenumber": "23"}, "type": "way", "center": {"lat": -6.9483121, "lon": 107.6445429}, "_source": "overpass_osm"}	983cec8c3285f17087f2bb311a9e57805e244a7a4d1d05ef7628ceacb3d6a546	duplicate	2026-09-30 09:14:51.059384+00
655	1	https://www.openstreetmap.org/way/749732427	{"id": 749732427, "tags": {"name": "Taman Kiarasari Utama", "leisure": "park"}, "type": "way", "center": {"lat": -6.9492166, "lon": 107.6446718}, "_source": "overpass_osm"}	9cd5ead0c717d6806eef79e38a1a546fde26eb0cc29725235c2da57416fbb0dd	approved	2026-09-30 09:14:51.059384+00
656	1	https://www.openstreetmap.org/way/749732428	{"id": 749732428, "tags": {"name": "Taman Kiarasari Permai", "leisure": "park", "addr:city": "Kel. Margasari", "addr:street": "Jalan Kiarasari Permai V", "addr:postcode": "40286"}, "type": "way", "center": {"lat": -6.948248, "lon": 107.6467952}, "_source": "overpass_osm"}	ed57db68c2d6e3f86f2c13203d2f140ae6f8dbefd2393d16e4504f3660f21068	approved	2026-09-30 09:14:51.059384+00
657	1	https://www.openstreetmap.org/way/750181961	{"id": 750181961, "tags": {"name": "Taman Mini Endah Cicukang", "leisure": "park", "addr:city": "Kota Bandung", "addr:street": "Jalan Cicukang"}, "type": "way", "center": {"lat": -6.9107603, "lon": 107.6836618}, "_source": "overpass_osm"}	e15e03e000ee73c84e1e2a75ac1392973e5efd0e0719e51408e6c94f2d36f77f	approved	2026-09-30 09:14:51.059384+00
658	1	https://www.openstreetmap.org/way/750184151	{"id": 750184151, "tags": {"name": "Taman Cicukang", "leisure": "park", "addr:city": "Kota Bandung", "addr:street": "Jalan Cicukang"}, "type": "way", "center": {"lat": -6.9079706, "lon": 107.6848116}, "_source": "overpass_osm"}	5b8accec3144c81710ad5bedd517174f3eb8324b34f1ad56051af6c6baa0f174	approved	2026-09-30 09:14:51.059384+00
659	1	https://www.openstreetmap.org/way/750190780	{"id": 750190780, "tags": {"fee": "yes", "name": "Kiara Artha Park", "leisure": "park", "addr:city": "Bandung", "addr:street": "Jalan Jakarta", "opening_hours": "Mo-Su 10:00-21:00"}, "type": "way", "center": {"lat": -6.916009, "lon": 107.6421899}, "_source": "overpass_osm"}	60b0f821ab681f6dcc3117b67e44e9f8c2044796e9b85b7af116022f0fde1a35	approved	2026-09-30 09:14:51.059384+00
660	1	https://www.openstreetmap.org/way/750198490	{"id": 750198490, "tags": {"name": "Karangsetra park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8779158, "lon": 107.5938436}, "_source": "overpass_osm"}	d12606581be36c222d3e0c4dcce0f5c6578e95cfb6c202e0e98e710adea3ebcd	approved	2026-09-30 09:14:51.059384+00
661	1	https://www.openstreetmap.org/way/750198977	{"id": 750198977, "tags": {"name": "Museum Pendidikan Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8597731, "lon": 107.5941668}, "_source": "overpass_osm"}	00054ebc3e2d91155346c6ca2ad4755e2c5476b88416deceac3c9cd914a19f60	approved	2026-09-30 09:14:51.059384+00
662	1	https://www.openstreetmap.org/way/750199502	{"id": 750199502, "tags": {"name": "Roeslan Abdul Gani Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8605459, "lon": 107.591624}, "_source": "overpass_osm"}	4f39614975261cbe092dfdd9df9b918fdc06903838b4678e1e6538b53f3e27a6	approved	2026-09-30 09:14:51.059384+00
663	1	https://www.openstreetmap.org/way/750200249	{"id": 750200249, "tags": {"name": "Masjid Attaqwa Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8661605, "lon": 107.586224}, "_source": "overpass_osm"}	7cca43cb2d72f58eb58f3a77c3b51c3c1ea2d8bdc2da9a9e1a4899d58232a82a	approved	2026-09-30 09:14:51.059384+00
664	1	https://www.openstreetmap.org/way/750206390	{"id": 750206390, "tags": {"name": "Al Murabbi Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8798078, "lon": 107.5834907}, "_source": "overpass_osm"}	fc50d11bb388e0382fe80516e35d351b45ef45892ce83f3378171730c90e630b	approved	2026-09-30 09:14:51.059384+00
665	1	https://www.openstreetmap.org/way/750207884	{"id": 750207884, "tags": {"name": "Jalur Hijau Cipaganti", "leisure": "park"}, "type": "way", "center": {"lat": -6.8887307, "lon": 107.6016611}, "_source": "overpass_osm"}	26b17f9b48551b1454b517237b8c1034d6fa8dd2d359995f991dd13302aa4786	approved	2026-09-30 09:14:51.059384+00
666	1	https://www.openstreetmap.org/way/750208197	{"id": 750208197, "tags": {"name": "Jalur hijau taman sari", "leisure": "park"}, "type": "way", "center": {"lat": -6.8976604, "lon": 107.6097784}, "_source": "overpass_osm"}	b1ad7ef2a0b5caf0e6a8affd42e13823d69961ccb85df18c1b550ab5aa667ca0	approved	2026-09-30 09:14:51.059384+00
667	1	https://www.openstreetmap.org/way/750209307	{"id": 750209307, "tags": {"name": "Taman PKK", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9012142, "lon": 107.6251016}, "_source": "overpass_osm"}	fc23c03ba3375e89806e4268247424d40e313c92792d2412f2baee8bb1495e51	approved	2026-09-30 09:14:51.059384+00
668	1	https://www.openstreetmap.org/way/750210743	{"id": 750210743, "tags": {"name": "Simpay asih Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9017877, "lon": 107.6900583}, "_source": "overpass_osm"}	37e74d0663e342590dea327ac5810bf22d60ccd04e6ceec45eae181bf04ad068	approved	2026-09-30 09:14:51.059384+00
669	1	https://www.openstreetmap.org/way/750210837	{"id": 750210837, "tags": {"name": "Taruna Parahyangan Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9018814, "lon": 107.6880164}, "_source": "overpass_osm"}	36ccbd38aca831d281f2d574466e7bed2cad4b29119525d8abfd3b0f7a842a3a	approved	2026-09-30 09:14:51.059384+00
670	1	https://www.openstreetmap.org/way/750215078	{"id": 750215078, "tags": {"name": "FCL front lobby park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9295617, "lon": 107.587401}, "_source": "overpass_osm"}	2ae3656af7a3ddc72adfa43d610896b66a99c1ce7a79093912142792e710dd23	approved	2026-09-30 09:14:51.059384+00
671	1	https://www.openstreetmap.org/way/750218153	{"id": 750218153, "tags": {"name": "Batununggal Molek Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9575645, "lon": 107.6323503}, "_source": "overpass_osm"}	7cf09957b53f7fd942c3ebcb366793779dd7920f2f59545b120dd5cebb036f57	approved	2026-09-30 09:14:51.059384+00
672	1	https://www.openstreetmap.org/way/750218798	{"id": 750218798, "tags": {"name": "Arcamanik Tower Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9180275, "lon": 107.674267}, "_source": "overpass_osm"}	9b0bf31f39c5d31482a25daa136c84af0f3ac155dc9e62b4d90787b715b3701c	approved	2026-09-30 09:14:51.059384+00
673	1	https://www.openstreetmap.org/way/750221930	{"id": 750221930, "tags": {"name": "Taman Abah Toto", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9266425, "lon": 107.6876573}, "_source": "overpass_osm"}	118fe3c7b9087e450b02a96b2604ec31b821807b37f5b9d6a93bdced6d9b61c5	approved	2026-09-30 09:14:51.059384+00
674	1	https://www.openstreetmap.org/way/750222268	{"id": 750222268, "tags": {"name": "Taman Bina Harapan", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9145059, "lon": 107.6849378}, "_source": "overpass_osm"}	05478da9d1da7e2d7aac97e14a733a05fbdc7659960b68addbaf2834bad020a1	approved	2026-09-30 09:14:51.059384+00
675	1	https://www.openstreetmap.org/way/750222269	{"id": 750222269, "tags": {"name": "Bina Harapan Park", "leisure": "park", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.9147713, "lon": 107.6856602}, "_source": "overpass_osm"}	aee72fcea481b1e8c0ef97d02de931cda88049a8c55bd880c14c6cfa73381f60	approved	2026-09-30 09:14:51.059384+00
676	1	https://www.openstreetmap.org/way/752098472	{"id": 752098472, "tags": {"name": "Taman Indonesia Tenggelam", "leisure": "park", "name:en": "Indonesia Tenggelam Park"}, "type": "way", "center": {"lat": -6.8905013, "lon": 107.6103474}, "_source": "overpass_osm"}	09a55fb19e4bd4fa5c7ce066ece0f8c9f7271e9efa2fa9e1740e03cf8bd4153f	approved	2026-09-30 09:14:51.059384+00
677	1	https://www.openstreetmap.org/way/753202019	{"id": 753202019, "tags": {"name": "Dago Atas Sideway", "leisure": "park"}, "type": "way", "center": {"lat": -6.8722925, "lon": 107.6197599}, "_source": "overpass_osm"}	3eb4fecdee7f4b7b8b5a924c3f323fa04484a377ca2ffb6b9ba279fd9183703c	approved	2026-09-30 09:14:51.059384+00
678	1	https://www.openstreetmap.org/way/753202021	{"id": 753202021, "tags": {"name": "DDK Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.8717919, "lon": 107.6193636}, "_source": "overpass_osm"}	73f03ec0e4cb55b7ff0a8f046e990507dbe6e85d875ed38ece6bf4b3ecb53f35	approved	2026-09-30 09:14:51.059384+00
679	1	https://www.openstreetmap.org/way/753202022	{"id": 753202022, "tags": {"name": "Kemper Park 1", "leisure": "park"}, "type": "way", "center": {"lat": -6.8714383, "lon": 107.6198371}, "_source": "overpass_osm"}	673c46d75809a0652edfc7ce66f24c80697a623a877a4039ad9b3793f6f3b8cb	approved	2026-09-30 09:14:51.059384+00
680	1	https://www.openstreetmap.org/way/753202023	{"id": 753202023, "tags": {"name": "DDK Park 2", "leisure": "park"}, "type": "way", "center": {"lat": -6.8716923, "lon": 107.6195161}, "_source": "overpass_osm"}	5fb0e15fef01a47502dfa60c3a6ef8bfc15a016affafb7d7105cf7429aa44c0f	duplicate	2026-09-30 09:14:51.059384+00
681	1	https://www.openstreetmap.org/way/753206626	{"id": 753206626, "tags": {"name": "Taman Pramuka", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. L. L. R.E. Martadinata, Cihapit, Bandung Wetan", "wheelchair": "limited", "description": "Park located on LLRE Martadinata street. Currently revamped and revitalized with two gates for entrance and exit. The lush green Taman Pramuka is popular among boy & girl scout.", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9102723, "lon": 107.6268852}, "_source": "overpass_osm"}	216660a462f81f3e99ae752aba350fc2b20178dcda36e8735591374512a4e45d	approved	2026-09-30 09:14:51.059384+00
682	1	https://www.openstreetmap.org/way/753210206	{"id": 753210206, "tags": {"name": "ITB Green Pedestrian", "leisure": "park"}, "type": "way", "center": {"lat": -6.8940827, "lon": 107.6092971}, "_source": "overpass_osm"}	340d806d5347bb7be6d4907955b9074115cc02ff87afac3002655151b429f2c7	approved	2026-09-30 09:14:51.059384+00
683	1	https://www.openstreetmap.org/way/753210207	{"id": 753210207, "tags": {"name": "Salman Green Sideway", "leisure": "park"}, "type": "way", "center": {"lat": -6.8940305, "lon": 107.6113169}, "_source": "overpass_osm"}	cb176301ddb6fb375ab35226ba43d4ec2c088dc0edc3e7b265a28524eb6107d1	approved	2026-09-30 09:14:51.059384+00
684	1	https://www.openstreetmap.org/way/798340600	{"id": 798340600, "tags": {"name": "Lapangan Volly", "leisure": "park"}, "type": "way", "center": {"lat": -6.8922529, "lon": 107.62505}, "_source": "overpass_osm"}	711ff1841779eabc642f071783c2c3400de8fecddb0158992b83058587c8f751	duplicate	2026-09-30 09:14:51.059384+00
685	1	https://www.openstreetmap.org/way/834576868	{"id": 834576868, "tags": {"name": "Angkasa Garden", "leisure": "garden", "garden:type": "public"}, "type": "way", "center": {"lat": -6.9521028, "lon": 107.6480097}, "_source": "overpass_osm"}	b1d9b145f5652f4cf1779fe1895a96bde66df6e702e07683db3e9727d4f088eb	approved	2026-09-30 09:14:51.059384+00
686	1	https://www.openstreetmap.org/way/834581158	{"id": 834581158, "tags": {"name": "Amerta Garden", "access": "yes", "leisure": "garden", "operator": "amerta", "garden:type": "public", "operator:type": "public"}, "type": "way", "center": {"lat": -6.944462, "lon": 107.6488925}, "_source": "overpass_osm"}	7d8d67f0533125ff18635571c7b67322cde2b3cf76afab3849736c7f9ff80078	approved	2026-09-30 09:14:51.059384+00
687	1	https://www.openstreetmap.org/way/857928866	{"id": 857928866, "tags": {"name": "Hotel Sofiyah Neglasari", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8937698, "lon": 107.6384566}, "_source": "overpass_osm"}	9d49782e0864ef05434b09ae0eafb5945581fd1963c180b1aceca1942579206f	approved	2026-09-30 09:14:51.059384+00
688	1	https://www.openstreetmap.org/way/858677597	{"id": 858677597, "tags": {"name": "Mandiri Kost", "tourism": "hostel", "building": "yes", "addr:city": "Bandung", "addr:street": "Manisi", "guest_house": "hostel"}, "type": "way", "center": {"lat": -6.9341389, "lon": 107.7186195}, "_source": "overpass_osm"}	6aa237aa18d51be1c339d187065c45ea1192d935049024650c36522628dfb8cd	approved	2026-09-30 09:14:51.059384+00
689	1	https://www.openstreetmap.org/way/858677599	{"id": 858677599, "tags": {"name": "Zaffirt House", "tourism": "hostel", "building": "yes", "guest_house": "hostel", "internet_access": "wlan", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.9344233, "lon": 107.7184458}, "_source": "overpass_osm"}	0702f0430a6bc5f9bae40aa7642d1129b0177a88159a1ed16188004b80572a60	approved	2026-09-30 09:14:51.059384+00
690	1	https://www.openstreetmap.org/way/858680637	{"id": 858680637, "tags": {"name": "Kostan Cipadung Permai", "shop": "laundry", "rooms": "30", "tourism": "hostel", "building": "yes", "addr:city": "Cipadung Wetan", "addr:street": "Jalan Permai II", "guest_house": "hostel", "internet_access": "wlan", "internet_access:fee": "no"}, "type": "way", "center": {"lat": -6.9282051, "lon": 107.7167167}, "_source": "overpass_osm"}	292a63204c6092236e3bd7572c4323e67decd6d6e6d22f1d39891dcbf9630961	approved	2026-09-30 09:14:51.059384+00
691	1	https://www.openstreetmap.org/way/867209820	{"id": 867209820, "tags": {"name": "Dago Suites Apartement", "tourism": "hotel", "building": "apartments", "addr:city": "Bandung", "addr:street": "Jl. Sangkuriang No.13, Dago Suites Apartment 1st Floor GF-A, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135", "addr:postcode": "40135", "addr:housenumber": "13"}, "type": "way", "center": {"lat": -6.8837342, "lon": 107.6097355}, "_source": "overpass_osm"}	c373343e79938ba8dbe07d245bcbfba7b5384339f6e0d905f7ab2e6ea2b02603	approved	2026-09-30 09:14:51.059384+00
692	1	https://www.openstreetmap.org/way/871875478	{"id": 871875478, "tags": {"name": "Kostan Koe", "tourism": "hotel", "building": "yes", "addr:street": "Jalan Dago Asri IV", "addr:housenumber": "H6"}, "type": "way", "center": {"lat": -6.8784714, "lon": 107.6141487}, "_source": "overpass_osm"}	a672b0e3c79c6214774761ad046a7646cf2947b57b7533ccabf4915860545d6d	approved	2026-09-30 09:14:51.059384+00
693	1	https://www.openstreetmap.org/way/872804190	{"id": 872804190, "tags": {"name": "Hotel Wisma Dago 22", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8733909, "lon": 107.6179777}, "_source": "overpass_osm"}	56e4bb797fca3c8e982e9d69b4ad6d09e3f8bd7addd1a5e786d96cfd0494141a	approved	2026-09-30 09:14:51.059384+00
711	1	https://www.openstreetmap.org/way/1052972734	{"id": 1052972734, "tags": {"name": "Taman Caladi", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Gg. Caladi", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8971455, "lon": 107.6229787}, "_source": "overpass_osm"}	70cce0172e6bfeb468335b7a913d9ea0e7366fe536ef0ef395dfc9fe9c5c923e	approved	2026-09-30 09:14:51.059384+00
694	1	https://www.openstreetmap.org/way/875799190	{"id": 875799190, "tags": {"name": "Sheraton Bandung Hotel & Towers", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda No.390, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.8745911, "lon": 107.619393}, "_source": "overpass_osm"}	4d5f112ed53ba240116b7efe1e3c46acdd98fbb9573c08258b4e62c5710f4f8d	duplicate	2026-09-30 09:14:51.059384+00
695	1	https://www.openstreetmap.org/way/875799191	{"id": 875799191, "tags": {"name": "Sheraton Bandung Hotel & Towers", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Ir. H. Juanda No.390, Dago, Kecamatan Coblong, Kota Bandung, Jawa Barat 40135", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.874397, "lon": 107.6195894}, "_source": "overpass_osm"}	e849651ae2476f7cdb2ee3a72e5e8197d6a0a7a8f7b10c3d5861d5b769a2e389	duplicate	2026-09-30 09:14:51.059384+00
696	1	https://www.openstreetmap.org/way/876390540	{"id": 876390540, "tags": {"name": "The Regia Dago", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.8674032, "lon": 107.6208716}, "_source": "overpass_osm"}	99e0cb2727e99a2064e25cf4a8cf629d0e85702c995c3bc62bc06b70ed75dd69	approved	2026-09-30 09:14:51.059384+00
697	1	https://www.openstreetmap.org/way/899798636	{"id": 899798636, "tags": {"name": "Thee Huis Gallery", "tourism": "gallery", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Bukit Dago Selatan No.53A", "addr:postcode": "40135"}, "type": "way", "center": {"lat": -6.8700976, "lon": 107.6187672}, "_source": "overpass_osm"}	afaf79778652fc86109c6bf3603e39bd0294c1c23b15ccd86e81e1b2b1098df1	approved	2026-09-30 09:14:51.059384+00
698	1	https://www.openstreetmap.org/way/899798638	{"id": 899798638, "tags": {"name": "Galeri Kamones", "tourism": "gallery", "building": "yes", "addr:city": "Bandung", "addr:street": "Jl. Cigadung Raya Barat No.28A, Cigadung, Kec. Cibeunying Kaler, Kota Bandung, Jawa Barat 40191", "addr:postcode": "40191"}, "type": "way", "center": {"lat": -6.8734303, "lon": 107.6229861}, "_source": "overpass_osm"}	d914635420859a5d9f2acf939f5d30f25ac4a323b55a2f4a47bdb2b356cab5a0	approved	2026-09-30 09:14:51.059384+00
699	1	https://www.openstreetmap.org/way/934223108	{"id": 934223108, "tags": {"name": "Monumen Perjuangan Rakyat Jawa Barat", "surface": "unpaved", "historic": "monument", "addr:city": "Bandung"}, "type": "way", "center": {"lat": -6.8934379, "lon": 107.6185411}, "_source": "overpass_osm"}	8a5e5e85dc7ac7f33f187d9bf7ca690ea5bbc6422907564c26dc5a356dc3b0c4	approved	2026-09-30 09:14:51.059384+00
700	1	https://www.openstreetmap.org/way/951465918	{"id": 951465918, "tags": {"name": "Hotel Horison", "brand": "Horison", "rooms": "208", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Pelajar Pejuang 45", "addr:housenumber": "121"}, "type": "way", "center": {"lat": -6.9356523, "lon": 107.6252139}, "_source": "overpass_osm"}	9c3d89465f262c639cdffc12e559f0ddf1b174b9bdcd0b86f38fe55c8657a742	approved	2026-09-30 09:14:51.059384+00
701	1	https://www.openstreetmap.org/way/961785360	{"id": 961785360, "tags": {"name": "taman bea cukai", "leisure": "park", "addr:city": "Kel. Mekar Mulya", "addr:street": "Jalan Pasanggrahan lll", "addr:postcode": "40614", "opening_hours": "24/7", "addr:housenumber": "33"}, "type": "way", "center": {"lat": -6.925135, "lon": 107.7027238}, "_source": "overpass_osm"}	09c652975041263bdccd0e19930436ff76ace59fe237a9b2fca042418c48d042	approved	2026-09-30 09:14:51.059384+00
702	1	https://www.openstreetmap.org/way/961785361	{"id": 961785361, "tags": {"name": "Taman Pojok Tilu Tilu", "leisure": "park", "operator": "Pojok Tilu Tilu", "addr:city": "Kel. Mekar Mulya", "addr:street": "Jalan Panghegar", "addr:postcode": "40614", "opening_hours": "24/7", "addr:housenumber": "no 33"}, "type": "way", "center": {"lat": -6.9250373, "lon": 107.7039367}, "_source": "overpass_osm"}	8297d1deb2e945f28ca789cdcde94b82515e8f8bdb27c283cc0fa46c9b4906ca	approved	2026-09-30 09:14:51.059384+00
750	1	https://www.openstreetmap.org/way/1160955037	{"id": 1160955037, "tags": {"name": "Taman Lingkungan Gang Arum", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.92434, "lon": 107.6544788}, "_source": "overpass_osm"}	e61c20c4e734eab842eade43d2e6651030fbbb1be4b99a8c2535d1b481496da5	approved	2026-09-30 09:14:51.059384+00
703	1	https://www.openstreetmap.org/way/961785362	{"id": 961785362, "tags": {"name": "taman rt02", "leisure": "park", "operator": "rt02", "addr:city": "Kel. Mekar Mulya", "addr:street": "Jalan Panghegar", "addr:postcode": "40614", "opening_hours": "24/7", "addr:housenumber": "15"}, "type": "way", "center": {"lat": -6.9244152, "lon": 107.702266}, "_source": "overpass_osm"}	23954ab557f972c9ddee42bf12f22a3e0b6577a34658cab9bca1501cb1c03f3b	approved	2026-09-30 09:14:51.059384+00
704	1	https://www.openstreetmap.org/way/961785363	{"id": 961785363, "tags": {"name": "Taman RW 08", "leisure": "park", "operator": "RW08", "addr:city": "Kel. Mekar Mulya", "addr:street": "Jalan Panghegar", "addr:postcode": "40614", "opening_hours": "24/7", "addr:housenumber": "10"}, "type": "way", "center": {"lat": -6.9238832, "lon": 107.7008007}, "_source": "overpass_osm"}	60343a966020565e5a22e6f62ed4616c276e93cb159062ef7a765f8a3cc22c6c	approved	2026-09-30 09:14:51.059384+00
705	1	https://www.openstreetmap.org/way/961785364	{"id": 961785364, "tags": {"name": "Taman RW 02", "leisure": "park", "operator": "rw02", "addr:city": "Kel. Mekar Mulya", "addr:street": "Jalan Pamekar", "opening_hours": "24/7", "addr:housenumber": "10"}, "type": "way", "center": {"lat": -6.9283403, "lon": 107.6998853}, "_source": "overpass_osm"}	f0c441f5bc64544174bc7f81365e31cda9520a2b9eafdf3c28f55a955119a367	approved	2026-09-30 09:14:51.059384+00
706	1	https://www.openstreetmap.org/way/961800092	{"id": 961800092, "tags": {"name": "Taman Gunung Kareumbi", "leisure": "park"}, "type": "way", "center": {"lat": -6.869062, "lon": 107.60864}, "_source": "overpass_osm"}	dfea16a3837027b928bfa6154b8691cdbe4e25161f09f244b224bfe4b8f852f5	approved	2026-09-30 09:14:51.059384+00
707	1	https://www.openstreetmap.org/way/961800093	{"id": 961800093, "tags": {"name": "Nara Park", "leisure": "park"}, "type": "way", "center": {"lat": -6.8675306, "lon": 107.6098789}, "_source": "overpass_osm"}	539f898f6ed864e88f00931f369a050a8038da4e4db5c189b9e9dcc85f533351	approved	2026-09-30 09:14:51.059384+00
708	1	https://www.openstreetmap.org/way/990640380	{"id": 990640380, "tags": {"name": "Taman Tegalega", "leisure": "park", "name:en": "Tegallega Park"}, "type": "way", "center": {"lat": -6.9347878, "lon": 107.6048017}, "_source": "overpass_osm"}	2b55a770aacc974cd1e81946f84cd4db39100fa449670c45d0e58afd4ba05abc	approved	2026-09-30 09:14:51.059384+00
709	1	https://www.openstreetmap.org/way/990640382	{"id": 990640382, "tags": {"area": "yes", "name": "Laswi Heritage", "historic": "yes"}, "type": "way", "center": {"lat": -6.9199484, "lon": 107.6360877}, "_source": "overpass_osm"}	48b1883f2013769f839df5144a976b9237afe6ed587917e9ae6f4c9dffa88d36	approved	2026-09-30 09:14:51.059384+00
710	1	https://www.openstreetmap.org/way/1052970770	{"id": 1052970770, "tags": {"name": "Kost Putri No.15D", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.886119, "lon": 107.6197563}, "_source": "overpass_osm"}	a307f154e5cc7520b483312aeac36cfdeb529ec307a9a2c682ef89087f890bc6	approved	2026-09-30 09:14:51.059384+00
712	1	https://www.openstreetmap.org/way/1052985430	{"id": 1052985430, "tags": {"name": "Taman DR Slamet", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl Dr Slamet", "wheelchair": "yes", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8991759, "lon": 107.6031586}, "_source": "overpass_osm"}	556aa627557960e5caf340c5a28ca5fe9ad62a61f2d5e357f33bf5453ea3e7b4	approved	2026-09-30 09:14:51.059384+00
713	1	https://www.openstreetmap.org/way/1061094553	{"id": 1061094553, "tags": {"name": "Taman Toga Saninten", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Saninten, Cihapit, Bandung Wetan", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9080044, "lon": 107.6274558}, "_source": "overpass_osm"}	7adcc990ae659c6f5eb2e495a25ca8ddf564db129f79242408cd4c5d3cb907b9	approved	2026-09-30 09:14:51.059384+00
714	1	https://www.openstreetmap.org/way/1061094555	{"id": 1061094555, "tags": {"name": "RTH Sempadan Jalan Citarum", "access": "no", "source": "POI_WRI_Survey_2023", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Citarum, Citarum, Bandung Wetan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9056022, "lon": 107.6214074}, "_source": "overpass_osm"}	fd55b98a956e657513b89b2ef644b5eaa7d57b49c5c349d46e4c7827452b3234	approved	2026-09-30 09:14:51.059384+00
715	1	https://www.openstreetmap.org/way/1061406086	{"id": 1061406086, "tags": {"name": "Taman Magot", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Tirta kencana", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9329507, "lon": 107.5889471}, "_source": "overpass_osm"}	0634364e9acd307f710266383e85c56ad6da62bf0f308cc015dd88e6cb4e412c	approved	2026-09-30 09:14:51.059384+00
716	1	https://www.openstreetmap.org/way/1061406087	{"id": 1061406087, "tags": {"name": "Taman Bermain Anak", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Papan Kencana", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9343418, "lon": 107.5883084}, "_source": "overpass_osm"}	d4555722f1fa49918fce6b38a01bea3f2b6e698f7b182ef98d4732ae4554c8f9	approved	2026-09-30 09:14:51.059384+00
717	1	https://www.openstreetmap.org/way/1061784121	{"id": 1061784121, "tags": {"name": "Taman Gasibu", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Wirayuda Timur", "wheelchair": "yes", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8987889, "lon": 107.6186529}, "_source": "overpass_osm"}	b5139d2a386407bcd58c6bc01b31bf5137a3ac04d8b08daa5eed67130e22e59a	approved	2026-09-30 09:14:51.059384+00
718	1	https://www.openstreetmap.org/way/1061784122	{"id": 1061784122, "tags": {"name": "Taman Segitiga", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "alt_name": "RTH Path Jalan siliwangi", "addr:city": "Bandung", "addr:full": "Jalan Dayang Sumbi", "wheelchair": "limited", "opening_hours": "24/7", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.8871961, "lon": 107.6115312}, "_source": "overpass_osm"}	fb8d2bb2ac16744d74599204ee0a2d065852b241a0e1ab2fcd8671b1ce8484cb	approved	2026-09-30 09:14:51.059384+00
719	1	https://www.openstreetmap.org/way/1061784123	{"id": 1061784123, "tags": {"name": "Taman Bagus Rangin", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Bagusrangin", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.897057, "lon": 107.6170791}, "_source": "overpass_osm"}	84c2c86cce520b85fa2fadcbad8a3b0fcd9e3e015187630c50c1935d20dc3850	approved	2026-09-30 09:14:51.059384+00
720	1	https://www.openstreetmap.org/way/1061784124	{"id": 1061784124, "tags": {"name": "Taman Monumen Perjuangan", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Dipatiukur", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8932952, "lon": 107.6185232}, "_source": "overpass_osm"}	418c7ac835f1677cf8080dc0244104bff22705f613ccc3746ad15fb273033ad1	approved	2026-09-30 09:14:51.059384+00
721	1	https://www.openstreetmap.org/way/1061784128	{"id": 1061784128, "tags": {"name": "Taman Gesit", "access": "yes", "source": "POI_WRI_Survey_2023", "leisure": "park", "wikidata": "Q25469385", "addr:city": "Bandung", "addr:full": "Jalan Dipatiukur", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8957027, "lon": 107.6166664}, "_source": "overpass_osm"}	504097f9b9afa7958b571cd8852ae45bf70259c08a2ea089eff00d78d333c019	approved	2026-09-30 09:14:51.059384+00
722	1	https://www.openstreetmap.org/way/1061865620	{"id": 1061865620, "tags": {"name": "Taman Bermain Anak", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl Tamansari", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8973397, "lon": 107.606486}, "_source": "overpass_osm"}	7b1961191281835c4707dde8ed2ea3c31c259eb8f854c0e0162d91b26d34ed38	approved	2026-09-30 09:14:51.059384+00
723	1	https://www.openstreetmap.org/way/1061865621	{"id": 1061865621, "tags": {"name": "Taman Djuanda", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl Tamansari", "wheelchair": "no", "opening_hours": "24/7", "name:etymology:wikidata": "Q2670453", "name:etymology:wikipedia": "id:Djuanda Kartawidjaja"}, "type": "way", "center": {"lat": -6.9052877, "lon": 107.6079984}, "_source": "overpass_osm"}	996652c22e8fad34ca9bf15e254b597c01e0e1ed6a405f87f21514657054ff41	approved	2026-09-30 09:14:51.059384+00
724	1	https://www.openstreetmap.org/way/1061865622	{"id": 1061865622, "tags": {"name": "Taman", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "building": "yes", "addr:city": "Bandung", "addr:full": "Jalan Sulanjana", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8997425, "lon": 107.6106095}, "_source": "overpass_osm"}	782b8e219e65a87ffdf1c73401e9aff3128b5f58d6208be4bef8a4f04b75af47	approved	2026-09-30 09:14:51.059384+00
725	1	https://www.openstreetmap.org/way/1061948058	{"id": 1061948058, "tags": {"name": "RTH Kota Tirtawening", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Badaksinga depan PDAM", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8970435, "lon": 107.611166}, "_source": "overpass_osm"}	d7a23e6b1e6cca9986b4ee38e1a10939a0af3ad50bf8f129bd61d19d0e1e5aa8	approved	2026-09-30 09:14:51.059384+00
740	1	https://www.openstreetmap.org/way/1144632064	{"id": 1144632064, "tags": {"name": "Taman Kota Tegal Lega", "leisure": "park"}, "type": "way", "center": {"lat": -6.9356427, "lon": 107.6047857}, "_source": "overpass_osm"}	15e2c62f65988e827317849f896b59762288aadda4c04ebfa7ed98e39ac2f819	approved	2026-09-30 09:14:51.059384+00
726	1	https://www.openstreetmap.org/way/1062229853	{"id": 1062229853, "tags": {"name": "Taman RW 04 Gelatik Dalam", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jl. Titimplik", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8947074, "lon": 107.622462}, "_source": "overpass_osm"}	30899b695fc3cd3fbbb549750d19782b4494bdb6aaa4e8d6cb537753791e30e7	approved	2026-09-30 09:14:51.059384+00
727	1	https://www.openstreetmap.org/way/1062272275	{"id": 1062272275, "tags": {"name": "RTH Polman", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Kanayakan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8779661, "lon": 107.6198991}, "_source": "overpass_osm"}	adb15a73b4e943eb84abd79d722de9b1b0c56feac866e678626abb556935c41c	approved	2026-09-30 09:14:51.059384+00
728	1	https://www.openstreetmap.org/way/1062272276	{"id": 1062272276, "tags": {"name": "RTH KANAYAKAN", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Kanayakan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8777114, "lon": 107.6225491}, "_source": "overpass_osm"}	94d022a27d5ba28c70a5683419d1050ec90f639e8449f55a2b92b9b3cab9b1c3	approved	2026-09-30 09:14:51.059384+00
729	1	https://www.openstreetmap.org/way/1062272277	{"id": 1062272277, "tags": {"name": "RTH KANAYAKAN", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Kanayakan", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8791601, "lon": 107.62098}, "_source": "overpass_osm"}	78c36de10c971951b143b7fec193e53f8855b5e25cc3ad395cdca927fe55bc46	approved	2026-09-30 09:14:51.059384+00
730	1	https://www.openstreetmap.org/way/1062272278	{"id": 1062272278, "tags": {"name": "RTH DAGO", "access": "no", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Raya Dago", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8708185, "lon": 107.621043}, "_source": "overpass_osm"}	dda50d39a31cea7cf01531a1eadd5d5756c4d19900429a6f3aec39ea4063ad46	approved	2026-09-30 09:14:51.059384+00
731	1	https://www.openstreetmap.org/way/1062272279	{"id": 1062272279, "tags": {"name": "RTH ITB", "access": "private", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Dago Pojok", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8668493, "lon": 107.6181019}, "_source": "overpass_osm"}	6ef2311d5ee5814ad581a5facd7525febff4588de8791b493e5a95c93410afdd	approved	2026-09-30 09:14:51.059384+00
732	1	https://www.openstreetmap.org/way/1062272280	{"id": 1062272280, "tags": {"name": "RTH Komplek", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Serambi Kencana", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9328564, "lon": 107.5878527}, "_source": "overpass_osm"}	05de27a996ba0608b15a310e9ca11081091b5af9118473a6c6a07a6a5833fb4d	approved	2026-09-30 09:14:51.059384+00
733	1	https://www.openstreetmap.org/way/1062571886	{"id": 1062571886, "tags": {"name": "Taman Bukit Dago", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Bukit Dago Selatan G5", "wheelchair": "no", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.8686399, "lon": 107.619726}, "_source": "overpass_osm"}	525ab0909821889e0d8a789bbc500174c41bff1a41d93126f53b1b1285b55ae7	approved	2026-09-30 09:14:51.059384+00
734	1	https://www.openstreetmap.org/way/1062571887	{"id": 1062571887, "tags": {"name": "TAMAN MASJID YAYASAN NURUL JAMIL", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan ir. H. Djuanda", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.870723, "lon": 107.6186368}, "_source": "overpass_osm"}	50b836c9dd625ae7533fbd6249368a423f62b1889b264a67869d5a13c465d03b	approved	2026-09-30 09:14:51.059384+00
735	1	https://www.openstreetmap.org/way/1062571888	{"id": 1062571888, "tags": {"name": "Taman RW 07", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Kopo Gang. Babakan Rahayu", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9415714, "lon": 107.5888463}, "_source": "overpass_osm"}	a346876b469a3512e4c23fa7d596fc4cddd02ff541b67ef8caf4567f8a53e88b	approved	2026-09-30 09:14:51.059384+00
736	1	https://www.openstreetmap.org/way/1062571889	{"id": 1062571889, "tags": {"name": "Taman RT 05 RW 09", "access": "yes", "source": "S2City_POI_2022", "leisure": "park", "addr:city": "Bandung", "addr:full": "Jalan Citarip Wetan RT 05 RW 09", "wheelchair": "limited", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9398616, "lon": 107.5878153}, "_source": "overpass_osm"}	4ad587b7e15bb0c569ea3c424e6dd89b2336fc5ab71f2a0445e7923595784414	approved	2026-09-30 09:14:51.059384+00
737	1	https://www.openstreetmap.org/way/1082250050	{"id": 1082250050, "tags": {"name": "New B", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9064607, "lon": 107.6294003}, "_source": "overpass_osm"}	78a8e784ace8d30c41b986dbfaa03bc906bfea7e1e3a0fffc9ca8069d1cfa0b1	approved	2026-09-30 09:14:51.059384+00
738	1	https://www.openstreetmap.org/way/1124747887	{"id": 1124747887, "tags": {"fee": "no", "name": "Museum Wolff Schoemaker (Preanger)", "museum": "art", "tourism": "museum", "building": "yes", "operator": "Government", "wikidata": "Q115861934", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Asia Afrika", "addr:postcode": "40112", "opening_hours": "Mo-Su 11:00-17:00", "operator:type": "public/government", "tactile_paving": "yes", "building:levels": "2", "addr:housenumber": "81"}, "type": "way", "center": {"lat": -6.9209532, "lon": 107.6117515}, "_source": "overpass_osm"}	62b810ba064097c9840e1fdd41b48edf3069ed4e72565e3baa03725cd4ef2bec	approved	2026-09-30 09:14:51.059384+00
739	1	https://www.openstreetmap.org/way/1124757470	{"id": 1124757470, "tags": {"name": "Museum Mandala Wangsit Siliwangi", "phone": "+62 22 4203393", "museum": "history", "tourism": "museum", "building": "yes", "operator": "Government", "wikidata": "Q3658066", "addr:city": "Bandung", "wheelchair": "yes", "addr:street": "Jalan Lembong", "description": "Army museum", "addr:postcode": "40111", "opening_hours": "Mo-Th, Sa, Su 08:00-14:30; Fr 11:00-14:30", "operator:type": "public/government", "tactile_paving": "yes", "addr:housenumber": "38", "contact:instagram": "https://www.instagram.com/mandalawangsit_museum/"}, "type": "way", "center": {"lat": -6.917316, "lon": 107.6111022}, "_source": "overpass_osm"}	768c04da1e60503ec82fd5e6b4339f89bb1e715ec3debc67ef4ab335e8d52d3b	approved	2026-09-30 09:14:51.059384+00
741	1	https://www.openstreetmap.org/way/1145009388	{"id": 1145009388, "tags": {"name": "Alun Alun Cempaka", "leisure": "park"}, "type": "way", "center": {"lat": -6.9653726, "lon": 107.6953705}, "_source": "overpass_osm"}	b82e906fda86c06f725a9edeae80a2fb67e0ba4211a4bd08158bfe44359edb05	approved	2026-09-30 09:14:51.059384+00
742	1	https://www.openstreetmap.org/way/1158955877	{"id": 1158955877, "tags": {"name": "Kos H. Ade", "rooms": "6", "tourism": "hostel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Insinyur Haji Juanda", "guest_house": "student_accommodation", "addr:postcode": "40135", "internet_access": "wlan", "addr:housenumber": "197", "air_conditioning": "no", "internet_access:fee": "customers"}, "type": "way", "center": {"lat": -6.8826033, "lon": 107.6147893}, "_source": "overpass_osm"}	318aaa248f7d118c36fcc299c793ae4de5975d9d9d113475ad07518022392fe2	approved	2026-09-30 09:14:51.059384+00
743	1	https://www.openstreetmap.org/way/1160816333	{"id": 1160816333, "tags": {"name": "Taman Shafira Pasir Biru Residence", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9204685, "lon": 107.7265303}, "_source": "overpass_osm"}	5579adf12bea223fa1c0ea9e83c0cb11950d93ae3e53b066ac4d5880e81d3db3	approved	2026-09-30 09:14:51.059384+00
744	1	https://www.openstreetmap.org/way/1160817007	{"id": 1160817007, "tags": {"name": "Taman Graha Cipadung", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9201502, "lon": 107.7190535}, "_source": "overpass_osm"}	d827063cb4c958c8767168682a38f3b6a03247c8d3218b7f96b58ab8b553022e	approved	2026-09-30 09:14:51.059384+00
745	1	https://www.openstreetmap.org/way/1160817223	{"id": 1160817223, "tags": {"name": "Taman Pelangi Graha Cipadung", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.919897, "lon": 107.7195133}, "_source": "overpass_osm"}	51298a71b95de997c092738869d913410d8718a7d9f7e607e241cdc7f42b5658	approved	2026-09-30 09:14:51.059384+00
746	1	https://www.openstreetmap.org/way/1160817337	{"id": 1160817337, "tags": {"name": "Ruang Terbuka Masjid Manunggal", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9191751, "lon": 107.7201392}, "_source": "overpass_osm"}	c0ce1a54aab6d231b8ac771e0d9215195d486483f3db65ad2684adc050e02668	approved	2026-09-30 09:14:51.059384+00
747	1	https://www.openstreetmap.org/way/1160819004	{"id": 1160819004, "tags": {"name": "Area Rekreasi Komplek Manglayang Sari", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9148875, "lon": 107.7230816}, "_source": "overpass_osm"}	f86556490f4bf120fe4807e6761c5ec223d66c3d368377e8017ea2ef385c92a0	approved	2026-09-30 09:14:51.059384+00
748	1	https://www.openstreetmap.org/way/1160819041	{"id": 1160819041, "tags": {"name": "Taman Refleksi RW 13", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9144821, "lon": 107.7231413}, "_source": "overpass_osm"}	87e90b4f3f7fe058b106674224e1604e36c4ad257f27a1111ccb23a9a02291c3	approved	2026-09-30 09:14:51.059384+00
749	1	https://www.openstreetmap.org/way/1160950999	{"id": 1160950999, "tags": {"name": "Alun Alun Kiara Asri", "leisure": "garden", "natural": "grassland"}, "type": "way", "center": {"lat": -6.9297678, "lon": 107.6551218}, "_source": "overpass_osm"}	7180969093492b26da74b62be50e0ec61ccc2900993e3c68d8810122fa5a21c0	approved	2026-09-30 09:14:51.059384+00
787	1	https://www.openstreetmap.org/way/1282745289	{"id": 1282745289, "tags": {"name": "Lapangan Perumahan Al-Islam", "leisure": "park"}, "type": "way", "center": {"lat": -6.9496327, "lon": 107.6565906}, "_source": "overpass_osm"}	ba8dbb947560da4430f7fd7ae6f4d27cd44a4ae5b1e8d639d879e9dcb1696e95	approved	2026-09-30 09:14:51.059384+00
751	1	https://www.openstreetmap.org/way/1160955290	{"id": 1160955290, "tags": {"name": "Taman Kantor Kecamatan Kiaracondong", "source": "POI_WRI_Survey_2023", "leisure": "garden", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.9238832, "lon": 107.6544069}, "_source": "overpass_osm"}	3e48f0382f17c068cab3b34726adf5aaa0671adbdbb385a7d3969136f20c90c3	approved	2026-09-30 09:14:51.059384+00
752	1	https://www.openstreetmap.org/way/1161032426	{"id": 1161032426, "tags": {"name": "Taman RW 15 Babakan Surabaya", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9176361, "lon": 107.6522901}, "_source": "overpass_osm"}	19f047b4112b9a463e51a07e055be8f52bd3aceecbd6e5cf7fb5597078da0bb9	approved	2026-09-30 09:14:51.059384+00
753	1	https://www.openstreetmap.org/way/1161032956	{"id": 1161032956, "tags": {"name": "Taman Sempadan Sungai Babakan Surabaya", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9168526, "lon": 107.6470296}, "_source": "overpass_osm"}	d883698dc6a888815867fbfb90df11893c675f91b12f01a45fc20934fbfe4d2d	approved	2026-09-30 09:14:51.059384+00
754	1	https://www.openstreetmap.org/way/1161033656	{"id": 1161033656, "tags": {"name": "Taman Komplek Perum ITT", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9163697, "lon": 107.6455883}, "_source": "overpass_osm"}	661b67c204b0a5ef651bd6c2ea9084db29ae8ce40bcf715a267e2c2ff85e3711	approved	2026-09-30 09:14:51.059384+00
755	1	https://www.openstreetmap.org/way/1161034215	{"id": 1161034215, "tags": {"name": "Ruang Terbuka", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9155026, "lon": 107.6459061}, "_source": "overpass_osm"}	cca032de32ba7a1298a871e029c7f42e1b0c570490479869ff90e218be9f5caa	approved	2026-09-30 09:14:51.059384+00
756	1	https://www.openstreetmap.org/way/1161034727	{"id": 1161034727, "tags": {"name": "RTH Sempadan Sungai Babakan Surabaya", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9149394, "lon": 107.6457583}, "_source": "overpass_osm"}	360dfe2f5110be54fdeda2f46475337cacb28d2c7096b0c4b17f4672b5dcf0b6	approved	2026-09-30 09:14:51.059384+00
757	1	https://www.openstreetmap.org/way/1161035243	{"id": 1161035243, "tags": {"name": "Taman dan Rekreasi Kiara Artha Park", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "yes"}, "type": "way", "center": {"lat": -6.9159, "lon": 107.642083}, "_source": "overpass_osm"}	98497665c998aba5dc2b7313ad666a4a17bc14d268d7adb4a462a3ddb8337033	approved	2026-09-30 09:14:51.059384+00
758	1	https://www.openstreetmap.org/way/1161036306	{"id": 1161036306, "tags": {"name": "Taman Baksur", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.910948, "lon": 107.6440282}, "_source": "overpass_osm"}	c7f447df0716ed20b769745aeafb729f6f4425d184b8f31d00fa5557b96783a2	approved	2026-09-30 09:14:51.059384+00
759	1	https://www.openstreetmap.org/way/1161042005	{"id": 1161042005, "tags": {"name": "Area Rekreasi Anak Puri Tirta Kencana", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9048396, "lon": 107.6517007}, "_source": "overpass_osm"}	18984bec2010378aa635a8f760215621bb8cc8b13137d3b9892b66e23b2fd7ee	approved	2026-09-30 09:14:51.059384+00
760	1	https://www.openstreetmap.org/way/1161047265	{"id": 1161047265, "tags": {"name": "Taman Kurdi", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9435799, "lon": 107.6055707}, "_source": "overpass_osm"}	e665ef8988d2e6eb6ed1cc5d2cbb057d5cf3ff432814de624bf4ae53605f1294	approved	2026-09-30 09:14:51.059384+00
761	1	https://www.openstreetmap.org/way/1161048762	{"id": 1161048762, "tags": {"name": "Taman LPM WOMunity", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9374627, "lon": 107.6028855}, "_source": "overpass_osm"}	2fcf9f36be930eb137503b4d269eaba130ba36b70f4e9ab3a382c6cb4d82c71c	approved	2026-09-30 09:14:51.059384+00
762	1	https://www.openstreetmap.org/way/1161050177	{"id": 1161050177, "tags": {"name": "Taman Komplek Jati Permai", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9414326, "lon": 107.6018706}, "_source": "overpass_osm"}	052d403dcbb7566d56c527ab6a70633a223c7d2458e47579d70dff2ffa1bb504	approved	2026-09-30 09:14:51.059384+00
763	1	https://www.openstreetmap.org/way/1161051337	{"id": 1161051337, "tags": {"name": "Taman Terminal Tegalega", "source": "POI_WRI_Survey_2023", "leisure": "garden", "abandoned": "yes"}, "type": "way", "center": {"lat": -6.9339394, "lon": 107.6028905}, "_source": "overpass_osm"}	3a5e1d1822971ba8a9d62d8ce7885aafe5625516866da4a8d5f0846278ca671b	approved	2026-09-30 09:14:51.059384+00
764	1	https://www.openstreetmap.org/way/1161053823	{"id": 1161053823, "tags": {"name": "RTH Pertigaan Jalan Astana Anyar", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9301714, "lon": 107.6007637}, "_source": "overpass_osm"}	6272f75c06268152cbf692e54a28cef2d7a73d0d3fbff716033a04cf878229b4	approved	2026-09-30 09:14:51.059384+00
765	1	https://www.openstreetmap.org/way/1161055224	{"id": 1161055224, "tags": {"name": "RTH Jalan Pajagalan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9283053, "lon": 107.6005188}, "_source": "overpass_osm"}	c3a67c23f9d1aa779e753e72a336de1a77b0195b8310f69cd8de5f0c88c061dd	approved	2026-09-30 09:14:51.059384+00
766	1	https://www.openstreetmap.org/way/1161210836	{"id": 1161210836, "tags": {"name": "Taman RW", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9179143, "lon": 107.6148055}, "_source": "overpass_osm"}	fa2a00500801f54d46d4267d12377eb4f8e3f55be1df4443ee0b854d14db5afa	approved	2026-09-30 09:14:51.059384+00
767	1	https://www.openstreetmap.org/way/1161288754	{"id": 1161288754, "tags": {"name": "RTH Sempadan Jalan Taman Citarum", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9041983, "lon": 107.6209736}, "_source": "overpass_osm"}	0ba77bf909339cb6b7599d065d3cd2ab2cb8c2ac18e4c01719856f9641633319	approved	2026-09-30 09:14:51.059384+00
768	1	https://www.openstreetmap.org/way/1161288777	{"id": 1161288777, "tags": {"name": "RTH Sempadan Jalan Progo", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.9045262, "lon": 107.6202752}, "_source": "overpass_osm"}	bf2b6e79e3579ad8062fd9b8ddb9409fa12513b26b834747c9e83e19309ab95d	approved	2026-09-30 09:14:51.059384+00
769	1	https://www.openstreetmap.org/way/1161291496	{"id": 1161291496, "tags": {"name": "Taman Lansia", "source": "POI_WRI_Survey_2023", "leisure": "park", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.8975856, "lon": 107.6311992}, "_source": "overpass_osm"}	3fb9e4a255a85f698fd050481b962c2baeac60aeff39fdf78b249d47659b6798	approved	2026-09-30 09:14:51.059384+00
770	1	https://www.openstreetmap.org/way/1161292638	{"id": 1161292638, "tags": {"name": "RTH", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.8962795, "lon": 107.632889}, "_source": "overpass_osm"}	cc7fcc94b13a19f6e49ffd443c7d3eb2d6717cd68b3dfc022ab50e89e921e0d2	approved	2026-09-30 09:14:51.059384+00
771	1	https://www.openstreetmap.org/way/1161294195	{"id": 1161294195, "tags": {"name": "Taman Lingkungan", "source": "POI_WRI_Survey_2023", "leisure": "garden", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.8773852, "lon": 107.6005241}, "_source": "overpass_osm"}	be6ae9f1ec7b02e08ab23cf4359130df287c636d1feade28d3c4edc95085c126	approved	2026-09-30 09:14:51.059384+00
772	1	https://www.openstreetmap.org/way/1161294653	{"id": 1161294653, "tags": {"name": "Taman Cidadap", "source": "POI_WRI_Survey_2023", "leisure": "park", "tactile_paving": "yes"}, "type": "way", "center": {"lat": -6.8738582, "lon": 107.599521}, "_source": "overpass_osm"}	6c7f96652ec9dc002e6d0d48b7295488b68add662e0908b3e2837c83a6fac429	approved	2026-09-30 09:14:51.059384+00
773	1	https://www.openstreetmap.org/way/1161297086	{"id": 1161297086, "tags": {"name": "RTH Bunderan Ciumbuleuit", "source": "POI_WRI_Survey_2023", "leisure": "garden", "wheelchair": "no"}, "type": "way", "center": {"lat": -6.865855, "lon": 107.6060946}, "_source": "overpass_osm"}	7a0dae47a6e656b0fbdc3f807883b5603218f15fb85cc234014aa0a2da0e44f9	approved	2026-09-30 09:14:51.059384+00
774	1	https://www.openstreetmap.org/way/1193303182	{"id": 1193303182, "tags": {"name": "Tugu Sister City Bandung - Petaling Jaya", "historic": "memorial", "memorial": "obelisk"}, "type": "way", "center": {"lat": -6.9102444, "lon": 107.6087718}, "_source": "overpass_osm"}	828b099bcf3b41b3ebc9fa23c7bb06d825dc33f00b464d1db8e4acf95532a284	approved	2026-09-30 09:14:51.059384+00
775	1	https://www.openstreetmap.org/way/1197847831	{"id": 1197847831, "tags": {"name": "Bundaran Cibeureum", "leisure": "park"}, "type": "way", "center": {"lat": -6.9171947, "lon": 107.5743753}, "_source": "overpass_osm"}	a0550bd66bd11b383a61a70a824b31907e4a339041fe0767406cfe02faab6f05	approved	2026-09-30 09:14:51.059384+00
776	1	https://www.openstreetmap.org/way/1200653171	{"id": 1200653171, "tags": {"name": "Taman Sumringah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9548497, "lon": 107.6942549}, "_source": "overpass_osm"}	a2145c21743b47b7ad22a2cf2dc3b57d2308ba8f7f288dd6ba1127c9a21046e9	approved	2026-09-30 09:14:51.059384+00
796	1	https://www.openstreetmap.org/way/1303199215	{"id": 1303199215, "tags": {"name": "Taman Hukum", "leisure": "park"}, "type": "way", "center": {"lat": -6.8745836, "lon": 107.6054076}, "_source": "overpass_osm"}	5f907543ec2571e4e5b20884abf59773423d96ae85dc9dcdc8faea8b7329a949	approved	2026-09-30 09:14:51.059384+00
777	1	https://www.openstreetmap.org/way/1200663212	{"id": 1200663212, "tags": {"name": "Shakti Hotel", "layer": "1", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Soekarno-Hatta", "addr:postcode": "40292", "addr:housenumber": "735"}, "type": "way", "center": {"lat": -6.9373346, "lon": 107.697184}, "_source": "overpass_osm"}	d65fbb7f32f13971fe9f75909493044583d14c7221be4b09576f45779174214f	approved	2026-09-30 09:14:51.059384+00
778	1	https://www.openstreetmap.org/way/1206655963	{"id": 1206655963, "tags": {"name": "Grand Asrilia Hotel", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9364732, "lon": 107.6245656}, "_source": "overpass_osm"}	f9ca8c02a293046af46843e56c4b896f252188773016bf307deaa35f619bb164	approved	2026-09-30 09:14:51.059384+00
779	1	https://www.openstreetmap.org/way/1222527778	{"id": 1222527778, "tags": {"fee": "yes", "name": "Taman Tepi Kota", "landuse": "grass", "leisure": "park", "opening_hours": "Mo-Fr 11:00-20:00, Sa-Su 08:00-20:00"}, "type": "way", "center": {"lat": -6.910487, "lon": 107.6697666}, "_source": "overpass_osm"}	48cf0d5d762a279fa4936f18a09258a356e7a8c00f5e549f3dd45dc0843c2952	approved	2026-09-30 09:14:51.059384+00
780	1	https://www.openstreetmap.org/way/1230842025	{"id": 1230842025, "tags": {"name": "Taman Gantole", "landuse": "recreation_ground", "leisure": "park", "surface": "unpaved"}, "type": "way", "center": {"lat": -6.9241229, "lon": 107.6718024}, "_source": "overpass_osm"}	403caa6a004c48869113a7bec5c3fccdd5681b3212f6dc48c82d5472691aa2dd	approved	2026-09-30 09:14:51.059384+00
781	1	https://www.openstreetmap.org/way/1230970262	{"id": 1230970262, "tags": {"name": "Local Field", "leisure": "park"}, "type": "way", "center": {"lat": -6.8808468, "lon": 107.6129199}, "_source": "overpass_osm"}	13f87351e7aec35bab1de6aa65e0ae6bb3852cc21fe15a5b25ef4bb4d0c3d75f	approved	2026-09-30 09:14:51.059384+00
782	1	https://www.openstreetmap.org/way/1231033708	{"id": 1231033708, "tags": {"name": "Lapangan Segitiga", "leisure": "garden", "garden:type": "community"}, "type": "way", "center": {"lat": -6.8666288, "lon": 107.6097797}, "_source": "overpass_osm"}	6a5d324d25983277ef339b62f48bbf5e39def46bde57e317f23fc1385f5b4c70	approved	2026-09-30 09:14:51.059384+00
783	1	https://www.openstreetmap.org/way/1231034299	{"id": 1231034299, "tags": {"name": "Taman Al Qolam", "leisure": "park"}, "type": "way", "center": {"lat": -6.8671798, "lon": 107.604853}, "_source": "overpass_osm"}	4c24f25f66bc43ae3f9357e30527c29d2dea0eb368dae9bedc8281836a7f6d26	approved	2026-09-30 09:14:51.059384+00
784	1	https://www.openstreetmap.org/way/1231329820	{"id": 1231329820, "tags": {"name": "Kebun Seni Tani", "landuse": "education", "leisure": "garden", "farmland": "field"}, "type": "way", "center": {"lat": -6.9229973, "lon": 107.6736193}, "_source": "overpass_osm"}	39fca52db29c3e47ac75e492271d75fcfd323398471df370591c23dd81843f29	approved	2026-09-30 09:14:51.059384+00
785	1	https://www.openstreetmap.org/way/1234640088	{"id": 1234640088, "tags": {"name": "Hotel Tebu", "tourism": "hotel", "building": "yes", "check_date": "2026-05-04"}, "type": "way", "center": {"lat": -6.9062519, "lon": 107.6202158}, "_source": "overpass_osm"}	aa1e9f7fa921b533826129e32ffe4f25e96179e078f5163354f4421778a4c646	approved	2026-09-30 09:14:51.059384+00
786	1	https://www.openstreetmap.org/way/1243176756	{"id": 1243176756, "tags": {"name": "Taman Danau Tilu", "leisure": "park"}, "type": "way", "center": {"lat": -6.9586244, "lon": 107.6960166}, "_source": "overpass_osm"}	25fadb2a7ab927eb9e238571d6a17b9b49f3871b7756701e239bc42be96d1dfb	approved	2026-09-30 09:14:51.059384+00
788	1	https://www.openstreetmap.org/way/1282745294	{"id": 1282745294, "tags": {"name": "Taman Kalkun", "leisure": "park"}, "type": "way", "center": {"lat": -6.9467401, "lon": 107.6598125}, "_source": "overpass_osm"}	e5e998ae3b5bb32b194878e43679cb4d6935e399fa62cc22246f98a47278a818	approved	2026-09-30 09:14:51.059384+00
789	1	https://www.openstreetmap.org/way/1282745295	{"id": 1282745295, "tags": {"name": "Taman Galaxy", "leisure": "park"}, "type": "way", "center": {"lat": -6.9498564, "lon": 107.6571095}, "_source": "overpass_osm"}	1f92723583c79a6bcb5d59791065e75fb9933eaadfb480232aca813481039d0a	approved	2026-09-30 09:14:51.059384+00
790	1	https://www.openstreetmap.org/way/1284642671	{"id": 1284642671, "tags": {"name": "Taman Inklusi", "leisure": "park"}, "type": "way", "center": {"lat": -6.9088375, "lon": 107.6155682}, "_source": "overpass_osm"}	62c894849f951bb438d8fae2cad3acdbe1ee758e802e229b9e2d5b2ede0bc4dc	approved	2026-09-30 09:14:51.059384+00
791	1	https://www.openstreetmap.org/way/1286450090	{"id": 1286450090, "tags": {"name": "Holiday Inn Bandung Pasteur", "type": "building", "brand": "Holiday Inn", "stars": "4", "tourism": "hotel", "website": "https://www.ihg.com/holidayinn/hotels/us/en/bandung/bdopa/hoteldetail", "building": "hotel", "addr:street": "Jl. Dr. Djunjunan", "brand:wikidata": "Q2717882", "building:levels": "10", "addr:housenumber": "96"}, "type": "way", "center": {"lat": -6.8956757, "lon": 107.5910718}, "_source": "overpass_osm"}	d5b7db6c5216b2173b8c99ec85abdf74a1e92f22c04cdbb5cc6d489cbe586093	approved	2026-09-30 09:14:51.059384+00
792	1	https://www.openstreetmap.org/way/1299816104	{"id": 1299816104, "tags": {"name": "Taman Cisatu", "leisure": "park"}, "type": "way", "center": {"lat": -6.8732065, "lon": 107.603088}, "_source": "overpass_osm"}	4d5e035021b7032b0316d4595db759e5ccb78023c8b19a3c42d47b75fdb23f33	approved	2026-09-30 09:14:51.059384+00
793	1	https://www.openstreetmap.org/way/1301132302	{"id": 1301132302, "tags": {"name": "Plaza Pandang", "highway": "pedestrian", "leisure": "park"}, "type": "way", "center": {"lat": -6.9473087, "lon": 107.7018068}, "_source": "overpass_osm"}	43622e03cc1564f78aa1d6f3d1a52c28bc0f87b789558c687b074ec849d4aa8e	approved	2026-09-30 09:14:51.059384+00
794	1	https://www.openstreetmap.org/way/1303184245	{"id": 1303184245, "tags": {"name": "Ruang Terbuka Publik (RTP) Itenas", "leisure": "garden", "website": "https://www.medcom.id/pendidikan/news-pendidikan/yKXqm64N-walkot-bandung-dorong-perguruan-tinggi-ikut-jejak-itenas-bikin-ruang-terbuka-publik"}, "type": "way", "center": {"lat": -6.8981293, "lon": 107.63612}, "_source": "overpass_osm"}	90b14e2a1a63a18aa6c205e8448db88406add83d694ef3f26994083d921d7758	approved	2026-09-30 09:14:51.059384+00
795	1	https://www.openstreetmap.org/way/1303199211	{"id": 1303199211, "tags": {"name": "Taman Pohon FISIP", "leisure": "park"}, "type": "way", "center": {"lat": -6.8750223, "lon": 107.6057875}, "_source": "overpass_osm"}	41227d0259cfff25600e3c7af00721020b812bdbc9242f8e0d33930ebce33d02	approved	2026-09-30 09:14:51.059384+00
797	1	https://www.openstreetmap.org/way/1303199227	{"id": 1303199227, "tags": {"name": "Taman Rektorat", "leisure": "park"}, "type": "way", "center": {"lat": -6.8750922, "lon": 107.6046955}, "_source": "overpass_osm"}	0a9f1e084a83d4bd3caf8bcb34a11e1fe5a53f34673c3bb7e96e7ef6454ae879	approved	2026-09-30 09:14:51.059384+00
798	1	https://www.openstreetmap.org/way/1303199228	{"id": 1303199228, "tags": {"name": "Water Tower Oranye", "leisure": "park"}, "type": "way", "center": {"lat": -6.8754024, "lon": 107.60497}, "_source": "overpass_osm"}	c9a1f9edbfc6b9484da13753463538bae68b16f615a1387e2307f432f9a0f579	approved	2026-09-30 09:14:51.059384+00
799	1	https://www.openstreetmap.org/way/1317357915	{"id": 1317357915, "tags": {"name": "Tulip Park 1", "leisure": "park", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9666096, "lon": 107.7041586}, "_source": "overpass_osm"}	6efd9c9ae89ee7498d3c078adfcccd717a25cf34a636ed775f816981f75f7710	approved	2026-09-30 09:14:51.059384+00
800	1	https://www.openstreetmap.org/way/1317358129	{"id": 1317358129, "tags": {"name": "Tulip Park 2", "leisure": "park", "opening_hours": "24/7"}, "type": "way", "center": {"lat": -6.9667914, "lon": 107.7014494}, "_source": "overpass_osm"}	fcc3ce3fd71bfb8623dd9c090a7fb6e9de7ef02b5817e3714e02d9fb14a365bf	approved	2026-09-30 09:14:51.059384+00
801	1	https://www.openstreetmap.org/way/1349368391	{"id": 1349368391, "tags": {"name": "Pohon Hukum", "leisure": "park"}, "type": "way", "center": {"lat": -6.874296, "lon": 107.6052122}, "_source": "overpass_osm"}	409a23445f5017dbd0c11e92b60116b38d1f911790d2e07c7b831acf1842b8f5	approved	2026-09-30 09:14:51.059384+00
802	1	https://www.openstreetmap.org/way/1351095918	{"id": 1351095918, "tags": {"name": "Lapangan SD Sukaasih Atas", "leisure": "park"}, "type": "way", "center": {"lat": -6.9006743, "lon": 107.6856471}, "_source": "overpass_osm"}	972bbea20e855bb209257a229cf175a0bd380851992b12b75c936c247faa3b4e	approved	2026-09-30 09:14:51.059384+00
803	1	https://www.openstreetmap.org/way/1370426942	{"id": 1370426942, "tags": {"name": "Pia Hotel", "landuse": "tourism", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.94987, "lon": 107.6238053}, "_source": "overpass_osm"}	ff1b1dda7a1a5f7de13da73e52d890f221155c6d36d77a3ebb62ea9a660bca1e	approved	2026-09-30 09:14:51.059384+00
804	1	https://www.openstreetmap.org/way/1370426961	{"id": 1370426961, "tags": {"name": "Panghegar Waterboom", "leisure": "water_park"}, "type": "way", "center": {"lat": -6.9617568, "lon": 107.6223174}, "_source": "overpass_osm"}	16b78c60c18fa07180375a2efc40dbf748ad476e1dae64db9a09598f0146b954	approved	2026-09-30 09:14:51.059384+00
805	1	https://www.openstreetmap.org/way/1370429558	{"id": 1370429558, "tags": {"name": "Museum Sri Baduga", "phone": "+62 22 5210976", "museum": "history", "source": "local knowledge", "landuse": "tourism", "tourism": "museum", "operator": "Government", "wikidata": "Q3171723", "addr:city": "Kota Bandung", "wikipedia": "en:Sri Baduga Museum", "wheelchair": "no", "addr:street": "Jalan Peta", "description": "The museum features various items related with the province of┬áWest Java, such as┬áSundanese┬ácrafts, furnishings, geologic history, and natural diversity.", "addr:postcode": "40243", "opening_hours": "Mo-Su 08:00-15:00", "operator:type": "public/government", "payment:cards": "no", "tactile_paving": "no", "internet_access": "no", "addr:housenumber": "185", "air_conditioning": "yes", "wikimedia_commons": "Category:Sri Baduga Museum", "payment:debit_cards": "no", "payment:credit_cards": "no"}, "type": "way", "center": {"lat": -6.9377464, "lon": 107.6035642}, "_source": "overpass_osm"}	cfcc9316fdb9d4d83e2649039d3609eb257af96b5a1b6931537476a9b494141d	approved	2026-09-30 09:14:51.059384+00
806	1	https://www.openstreetmap.org/way/1370729232	{"id": 1370729232, "tags": {"name": "Hotel Lingga", "landuse": "commercial", "tourism": "hotel"}, "type": "way", "center": {"lat": -6.9501485, "lon": 107.6268367}, "_source": "overpass_osm"}	7913a2d3f0b4ae14a4e82a942d8203d1898eef7208d120c67556f9fd82a32b40	approved	2026-09-30 09:14:51.059384+00
807	1	https://www.openstreetmap.org/way/1381663440	{"id": 1381663440, "tags": {"name": "Kawasan Jalan Braga", "landuse": "retail", "tourism": "attraction"}, "type": "way", "center": {"lat": -6.9179393, "lon": 107.6093249}, "_source": "overpass_osm"}	0ce0d746652a317366fb62e389089174eda827b7797398d428a9fa5ab2a52b45	approved	2026-09-30 09:14:51.059384+00
808	1	https://www.openstreetmap.org/way/1395143854	{"id": 1395143854, "tags": {"name": "Hotel Astria Graha", "tourism": "hotel", "building": "yes"}, "type": "way", "center": {"lat": -6.9233477, "lon": 107.6104142}, "_source": "overpass_osm"}	86aa56e63540fce5b88d79a079c103442bb74a07be9cbece008c6f5ac0d8e702	approved	2026-09-30 09:14:51.059384+00
809	1	https://www.openstreetmap.org/way/1409981523	{"id": 1409981523, "tags": {"name": "├⌐L Hotel Bandung", "brand": "├⌐L Hotel Bandung", "email": "reservation.bdg@el-hotels.com", "rooms": "514", "stars": "4", "landuse": "commercial", "tourism": "hotel", "website": "https://bandung.el-hotels.com/", "operator": "├⌐L Hotel Group", "addr:city": "Bandung, Jawa Barat", "addr:unit": "411", "addr:street": "Jalan Merdeka", "addr:postcode": "40111", "internet_access": "wlan", "addr:housenumber": "2", "internet_access:fee": "yes"}, "type": "way", "center": {"lat": -6.9161047, "lon": 107.6106151}, "_source": "overpass_osm"}	f5ae8ee72f72b79a1a7437170dd905e8a47587ea55a490cd8575eed59bb06b08	approved	2026-09-30 09:14:51.059384+00
810	1	https://www.openstreetmap.org/way/1411443701	{"id": 1411443701, "tags": {"fee": "no", "name": "Banceuy Prison Museum", "museum": "history", "name:id": "Monumen Lembaga Permasyarakatan Banceuy", "tourism": "museum", "building": "prison", "operator": "Dinas Pariwisata Jawa Barat", "operator:type": "government"}, "type": "way", "center": {"lat": -6.9195986, "lon": 107.6069604}, "_source": "overpass_osm"}	b03ced2b51c489adc1e4e4031aff32633aaec6dcf077f0eec68ffa5350bf1f6b	approved	2026-09-30 09:14:51.059384+00
811	1	https://www.openstreetmap.org/way/1417983396	{"id": 1417983396, "tags": {"name": "The Luxton", "landuse": "commercial", "tourism": "hotel", "addr:city": "Bandung", "addr:street": "Jl. Ir. H.Djuanda", "addr:housenumber": "18"}, "type": "way", "center": {"lat": -6.9037761, "lon": 107.6113448}, "_source": "overpass_osm"}	60bfc1b2513b8ed1bddc39a890220b89f3d71fb5d92f4dc3d45d4cbdea06d7fd	approved	2026-09-30 09:14:51.059384+00
812	1	https://www.openstreetmap.org/way/1431411339	{"id": 1431411339, "tags": {"name": "Museum Srihadi Soedarsono", "tourism": "gallery", "website": "https://www.museumsrihadisoedarsono.com/", "building": "yes", "opening_hours": "Mo-Su 10:00-17:00"}, "type": "way", "center": {"lat": -6.8717203, "lon": 107.6050527}, "_source": "overpass_osm"}	7bc66ac9950f7b3039a4b652ac600df19b73494f3a7003ef46c1da0448fbcf64	approved	2026-09-30 09:14:51.059384+00
813	1	https://www.openstreetmap.org/way/1434554474	{"id": 1434554474, "tags": {"name": "Taman Emily Barat", "leisure": "park"}, "type": "way", "center": {"lat": -6.9629654, "lon": 107.6975246}, "_source": "overpass_osm"}	fb76f56ab2f16bc6773b31a87381b1afffd2db890fd6af84ed18ec3cb10e1526	approved	2026-09-30 09:14:51.059384+00
814	1	https://www.openstreetmap.org/way/1434554482	{"id": 1434554482, "tags": {"name": "Taman Emily Tengah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9634878, "lon": 107.6989535}, "_source": "overpass_osm"}	89db04ee8753a00b208592ebaef16ba2de5da043450b7d951fccced5f4a2a323	approved	2026-09-30 09:14:51.059384+00
815	1	https://www.openstreetmap.org/way/1434554492	{"id": 1434554492, "tags": {"name": "Taman Emily Timur", "leisure": "park"}, "type": "way", "center": {"lat": -6.9642665, "lon": 107.7006022}, "_source": "overpass_osm"}	958d175cc27319a50c83c7dc9af9c788f95fa1b72d32592384de27e692e8fdca	approved	2026-09-30 09:14:51.059384+00
816	1	https://www.openstreetmap.org/way/1434803982	{"id": 1434803982, "tags": {"name": "Saninten Inn", "tourism": "hotel", "building": "yes", "addr:city": "Bandung", "addr:street": "Jalan Saninten", "addr:postcode": "40114", "addr:province": "Jawa Barat", "addr:housenumber": "65"}, "type": "way", "center": {"lat": -6.9057001, "lon": 107.6272429}, "_source": "overpass_osm"}	01a2993e823d5beeea54c4f6294a3d680eb566972bc9e537a12f0ed4fe152005	approved	2026-09-30 09:14:51.059384+00
817	1	https://www.openstreetmap.org/way/1434820033	{"id": 1434820033, "tags": {"name": "Alun Alun Palem", "leisure": "park"}, "type": "way", "center": {"lat": -6.9665388, "lon": 107.6998853}, "_source": "overpass_osm"}	5f174936be18401c518bec13b0f3795f9240d9648cf5d77bdff47893c183f635	approved	2026-09-30 09:14:51.059384+00
818	1	https://www.openstreetmap.org/way/1436136153	{"id": 1436136153, "tags": {"name": "Taman Derwati", "leisure": "park"}, "type": "way", "center": {"lat": -6.9644576, "lon": 107.678711}, "_source": "overpass_osm"}	53a10f57f257242e9e528a860937411400ca34d10e8e793ea581bd00d3da7f52	approved	2026-09-30 09:14:51.059384+00
819	1	https://www.openstreetmap.org/way/1442741324	{"id": 1442741324, "tags": {"fee": "no", "name": "Taman Sub 07 Sektor 22 SCH", "access": "yes", "leisure": "garden", "garden:type": "community"}, "type": "way", "center": {"lat": -6.893769, "lon": 107.5875069}, "_source": "overpass_osm"}	7a258f162626ec065760ef96c24906f911673431b7a7600fb08c3872bdb8cc87	approved	2026-09-30 09:14:51.059384+00
820	1	https://www.openstreetmap.org/way/1443175089	{"id": 1443175089, "tags": {"name": "Playground Cynthia", "leisure": "park"}, "type": "way", "center": {"lat": -6.9615055, "lon": 107.6955998}, "_source": "overpass_osm"}	652495031378826cfbcf4013d05feff1141af517eafd6ecbed4537dc2c892862	approved	2026-09-30 09:14:51.059384+00
821	1	https://www.openstreetmap.org/way/1443187677	{"id": 1443187677, "tags": {"area": "yes", "name": "Sawarga Courtyard", "highway": "pedestrian", "tourism": "attraction"}, "type": "way", "center": {"lat": -6.9551659, "lon": 107.6978716}, "_source": "overpass_osm"}	ba6a1f846bada07d7428fdacfef0485024de08059d0b212ff90dea868fc0ff0d	approved	2026-09-30 09:14:51.059384+00
822	1	https://www.openstreetmap.org/way/1454960790	{"id": 1454960790, "tags": {"name": "Taman Tulip", "leisure": "park"}, "type": "way", "center": {"lat": -6.9672239, "lon": 107.7023281}, "_source": "overpass_osm"}	9522136c935aae95daed584081c1e30ec204494d4a20bbcab0fed0708f29e96e	approved	2026-09-30 09:14:51.059384+00
823	1	https://www.openstreetmap.org/way/1462081924	{"id": 1462081924, "tags": {"name": "Taman Sehati RW.09", "leisure": "park"}, "type": "way", "center": {"lat": -6.9451534, "lon": 107.7115654}, "_source": "overpass_osm"}	92c32b2911afa4cc32c67f11d8725fb94f6bbeee4fd341fb75cd821fa3361cd9	approved	2026-09-30 09:14:51.059384+00
824	1	https://www.openstreetmap.org/way/1467055121	{"id": 1467055121, "tags": {"name": "Taman Dirgantara", "leisure": "park"}, "type": "way", "center": {"lat": -6.9299064, "lon": 107.55126}, "_source": "overpass_osm"}	c65f9b8db0b4c961fbae923c2d583fe044f0ed25867c1fe1444cd686a05f2c00	approved	2026-09-30 09:14:51.059384+00
825	1	https://www.openstreetmap.org/way/1475160334	{"id": 1475160334, "tags": {"name": "Taman Braga", "leisure": "park", "tourism": "attraction"}, "type": "way", "center": {"lat": -6.9198965, "lon": 107.6101048}, "_source": "overpass_osm"}	1a7a09bbf00bf5eef7b5b8225195af3992d283ccc148667ce63f419e5cf5137b	approved	2026-09-30 09:14:51.059384+00
826	1	https://www.openstreetmap.org/way/1484267798	{"id": 1484267798, "tags": {"name": "Sukajadi Guest House", "tourism": "guest_house", "building": "yes"}, "type": "way", "center": {"lat": -6.8756062, "lon": 107.5949457}, "_source": "overpass_osm"}	59c605c48474aaf7ffc91c90ca851f098fad49ee4d71e6a1471029eaa11f8475	approved	2026-09-30 09:14:51.059384+00
827	1	https://www.openstreetmap.org/way/1489896474	{"id": 1489896474, "tags": {"name": "Plaza Timur", "leisure": "park"}, "type": "way", "center": {"lat": -6.9494343, "lon": 107.7056257}, "_source": "overpass_osm"}	67ec01b5535d43be271b060ea81f303d3fe65d16769bf946a0ae565a0c690ce6	approved	2026-09-30 09:14:51.059384+00
828	1	https://www.openstreetmap.org/way/1489929123	{"id": 1489929123, "tags": {"name": "Taman Tematik Nabi Adam", "leisure": "park"}, "type": "way", "center": {"lat": -6.9497306, "lon": 107.7045455}, "_source": "overpass_osm"}	eb1ebc423c832cb63f567917bb60928748f33c2eea55d572f9ae053a958ea579	approved	2026-09-30 09:14:51.059384+00
829	1	https://www.openstreetmap.org/way/1489929124	{"id": 1489929124, "tags": {"name": "Taman Tematik Nabi Yunus", "leisure": "park"}, "type": "way", "center": {"lat": -6.9497666, "lon": 107.7028202}, "_source": "overpass_osm"}	11bd41584261f36717d2ad41d7e7d9cb14b743c0f83f6617db2801c7585c93dd	approved	2026-09-30 09:14:51.059384+00
830	1	https://www.openstreetmap.org/way/1489929125	{"id": 1489929125, "tags": {"name": "Taman Tematik Nabi Ibrahim", "leisure": "park"}, "type": "way", "center": {"lat": -6.9498761, "lon": 107.7036717}, "_source": "overpass_osm"}	4c35d6adfd33d956a621579685726ac79a37566ba66a9a6b6295d249be4e74fb	approved	2026-09-30 09:14:51.059384+00
831	1	https://www.openstreetmap.org/way/1489929126	{"id": 1489929126, "tags": {"name": "Taman Tematik Nabi Nuh", "leisure": "park"}, "type": "way", "center": {"lat": -6.949337, "lon": 107.7017436}, "_source": "overpass_osm"}	c5d30e0e04fde48cc2483ba6bfaf5b969873c5683a78bb98af64566c1825d93d	approved	2026-09-30 09:14:51.059384+00
832	1	https://www.openstreetmap.org/way/1489929127	{"id": 1489929127, "tags": {"name": "Taman Islam", "leisure": "park"}, "type": "way", "center": {"lat": -6.9485628, "lon": 107.7013507}, "_source": "overpass_osm"}	4adf90f997beb27ca37ccea124305cc4db3d602540b9c52407fdb69f85c6b50a	approved	2026-09-30 09:14:51.059384+00
833	1	https://www.openstreetmap.org/way/1489929130	{"id": 1489929130, "tags": {"name": "Taman Tematik Nabi Isa", "leisure": "park"}, "type": "way", "center": {"lat": -6.9464769, "lon": 107.7016828}, "_source": "overpass_osm"}	2b5e980070ab8628457bb8e435365fe3f6fdc2d66a2dcfd470a502e6509434f5	approved	2026-09-30 09:14:51.059384+00
834	1	https://www.openstreetmap.org/way/1491374784	{"id": 1491374784, "tags": {"name": "Lapangan Tenis Kawaluyaan Indah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9344997, "lon": 107.6601597}, "_source": "overpass_osm"}	c92d911c7127f438ce4dd09fe0f7828d713875ffd6ff14c21de70c302175f1a9	approved	2026-09-30 09:14:51.059384+00
835	1	https://www.openstreetmap.org/way/1502723323	{"id": 1502723323, "tags": {"name": "Lapangan Sekolah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9218622, "lon": 107.714973}, "_source": "overpass_osm"}	0558288a52db54bc18913029093b49830d2fc2dc5d30e59d86878c670a0590da	approved	2026-09-30 09:14:51.059384+00
836	1	https://www.openstreetmap.org/way/1511658239	{"id": 1511658239, "tags": {"name": "JPL Jalan Braga", "building": "yes", "historic": "building"}, "type": "way", "center": {"lat": -6.915081, "lon": 107.6091304}, "_source": "overpass_osm"}	337601cb972b5a7f77afbbc2954ead27c3399cf359fef84ef66a744daa05930e	approved	2026-09-30 09:14:51.059384+00
837	1	https://www.openstreetmap.org/way/1513067561	{"id": 1513067561, "tags": {"name": "Taman Pandawa", "leisure": "park"}, "type": "way", "center": {"lat": -6.9221177, "lon": 107.6576487}, "_source": "overpass_osm"}	4eec480ebc2b9f7785ad620a99fa4649eda8de8b51e7ca695a58ade0a320fc8f	approved	2026-09-30 09:14:51.059384+00
838	1	https://www.openstreetmap.org/way/1515964637	{"id": 1515964637, "tags": {"name": "Alun Alun Griya Caraka", "leisure": "park"}, "type": "way", "center": {"lat": -6.9321721, "lon": 107.673489}, "_source": "overpass_osm"}	8bae52a10c273bdcd8a99066f88cbc0ce4d140dfe7d01ca204ae32d360aeb2f4	approved	2026-09-30 09:14:51.059384+00
839	1	https://www.openstreetmap.org/way/1558985258	{"id": 1558985258, "tags": {"name": "Taman Al Uhkuwah", "leisure": "park"}, "type": "way", "center": {"lat": -6.9459176, "lon": 107.7104343}, "_source": "overpass_osm"}	f06cea36274d58dd52df9f7d3422a778c478c4b4dd3307a5d2e307f3e9259a7c	approved	2026-09-30 09:14:51.059384+00
840	1	https://www.openstreetmap.org/way/1559886641	{"id": 1559886641, "tags": {"name": "Taman Sumber Sari", "leisure": "park"}, "type": "way", "center": {"lat": -6.9329221, "lon": 107.5752375}, "_source": "overpass_osm"}	f44fc99c0798e65d29a9ac17bcb850ea7067c645930039e00e173adc92e13a16	approved	2026-09-30 09:14:51.059384+00
\.


--
-- Data for Name: scrape_runs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.scrape_runs (id, source_id, query, started_at, finished_at, items_found) FROM stdin;
1	1	Kota Bandung places + accommodations	2026-09-30 09:14:51.059384+00	2026-09-30 09:14:51.059384+00	840
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: tags; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tags (id, name) FROM stdin;
\.


--
-- Data for Name: geocode_settings; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.geocode_settings (name, setting, unit, category, short_desc) FROM stdin;
\.


--
-- Data for Name: pagc_gaz; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_gaz (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_lex; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_lex (id, seq, word, stdword, token, is_custom) FROM stdin;
\.


--
-- Data for Name: pagc_rules; Type: TABLE DATA; Schema: tiger; Owner: postgres
--

COPY tiger.pagc_rules (id, rule, is_custom) FROM stdin;
\.


--
-- Data for Name: topology; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.topology (id, name, srid, "precision", hasz) FROM stdin;
\.


--
-- Data for Name: layer; Type: TABLE DATA; Schema: topology; Owner: postgres
--

COPY topology.layer (topology_id, layer_id, schema_name, table_name, feature_column, feature_type, level, child_id) FROM stdin;
\.


--
-- Name: accommodation_images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accommodation_images_id_seq', 1, false);


--
-- Name: accommodations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.accommodations_id_seq', 386, true);


--
-- Name: ai_extractions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ai_extractions_id_seq', 1, false);


--
-- Name: amenities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.amenities_id_seq', 10, true);


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_id_seq', 12, true);


--
-- Name: cities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cities_id_seq', 1, true);


--
-- Name: data_sources_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.data_sources_id_seq', 3, true);


--
-- Name: districts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.districts_id_seq', 30, true);


--
-- Name: place_images_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.place_images_id_seq', 1, false);


--
-- Name: places_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.places_id_seq', 436, true);


--
-- Name: provinces_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.provinces_id_seq', 1, true);


--
-- Name: raw_scraped_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.raw_scraped_items_id_seq', 840, true);


--
-- Name: scrape_runs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.scrape_runs_id_seq', 1, true);


--
-- Name: tags_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tags_id_seq', 1, false);


--
-- Name: topology_id_seq; Type: SEQUENCE SET; Schema: topology; Owner: postgres
--

SELECT pg_catalog.setval('topology.topology_id_seq', 1, false);


--
-- Name: accommodation_amenities accommodation_amenities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_amenities
    ADD CONSTRAINT accommodation_amenities_pkey PRIMARY KEY (accommodation_id, amenity_id);


--
-- Name: accommodation_images accommodation_images_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_images
    ADD CONSTRAINT accommodation_images_pkey PRIMARY KEY (id);


--
-- Name: accommodations accommodations_google_place_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_google_place_id_key UNIQUE (google_place_id);


--
-- Name: accommodations accommodations_osm_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_osm_ref_key UNIQUE (osm_ref);


--
-- Name: accommodations accommodations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_pkey PRIMARY KEY (id);


--
-- Name: accommodations accommodations_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_slug_key UNIQUE (slug);


--
-- Name: ai_extractions ai_extractions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_extractions
    ADD CONSTRAINT ai_extractions_pkey PRIMARY KEY (id);


--
-- Name: amenities amenities_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amenities
    ADD CONSTRAINT amenities_name_key UNIQUE (name);


--
-- Name: amenities amenities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.amenities
    ADD CONSTRAINT amenities_pkey PRIMARY KEY (id);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: cities cities_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_pkey PRIMARY KEY (id);


--
-- Name: cities cities_province_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_province_id_name_key UNIQUE (province_id, name);


--
-- Name: data_sources data_sources_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_name_key UNIQUE (name);


--
-- Name: data_sources data_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.data_sources
    ADD CONSTRAINT data_sources_pkey PRIMARY KEY (id);


--
-- Name: districts districts_city_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_city_id_name_key UNIQUE (city_id, name);


--
-- Name: districts districts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_pkey PRIMARY KEY (id);


--
-- Name: place_images place_images_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_images
    ADD CONSTRAINT place_images_pkey PRIMARY KEY (id);


--
-- Name: place_sources place_sources_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_sources
    ADD CONSTRAINT place_sources_pkey PRIMARY KEY (place_id, source_id);


--
-- Name: place_tags place_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_tags
    ADD CONSTRAINT place_tags_pkey PRIMARY KEY (place_id, tag_id);


--
-- Name: places places_google_place_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_google_place_id_key UNIQUE (google_place_id);


--
-- Name: places places_osm_ref_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_osm_ref_key UNIQUE (osm_ref);


--
-- Name: places places_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_pkey PRIMARY KEY (id);


--
-- Name: places places_slug_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_slug_key UNIQUE (slug);


--
-- Name: provinces provinces_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.provinces
    ADD CONSTRAINT provinces_name_key UNIQUE (name);


--
-- Name: provinces provinces_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.provinces
    ADD CONSTRAINT provinces_pkey PRIMARY KEY (id);


--
-- Name: raw_scraped_items raw_scraped_items_content_hash_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raw_scraped_items
    ADD CONSTRAINT raw_scraped_items_content_hash_key UNIQUE (content_hash);


--
-- Name: raw_scraped_items raw_scraped_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raw_scraped_items
    ADD CONSTRAINT raw_scraped_items_pkey PRIMARY KEY (id);


--
-- Name: scrape_runs scrape_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scrape_runs
    ADD CONSTRAINT scrape_runs_pkey PRIMARY KEY (id);


--
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: idx_accom_city; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accom_city ON public.accommodations USING btree (city_id);


--
-- Name: idx_accom_district; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accom_district ON public.accommodations USING btree (district_id);


--
-- Name: idx_accom_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accom_location ON public.accommodations USING gist (location);


--
-- Name: idx_accom_name_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accom_name_trgm ON public.accommodations USING gin (name public.gin_trgm_ops);


--
-- Name: idx_accom_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_accom_type ON public.accommodations USING btree (type);


--
-- Name: idx_cities_boundary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_cities_boundary ON public.cities USING gist (boundary);


--
-- Name: idx_districts_boundary; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_districts_boundary ON public.districts USING gist (boundary);


--
-- Name: idx_places_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_category ON public.places USING btree (category_id);


--
-- Name: idx_places_city; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_city ON public.places USING btree (city_id);


--
-- Name: idx_places_district; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_district ON public.places USING btree (district_id);


--
-- Name: idx_places_gem; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_gem ON public.places USING btree (hidden_gem_score DESC) WHERE is_hidden_gem;


--
-- Name: idx_places_location; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_location ON public.places USING gist (location);


--
-- Name: idx_places_name_trgm; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_places_name_trgm ON public.places USING gin (name public.gin_trgm_ops);


--
-- Name: idx_raw_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_raw_status ON public.raw_scraped_items USING btree (status);


--
-- Name: accommodations trg_accom_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_accom_updated BEFORE UPDATE ON public.accommodations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: places trg_places_updated; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_places_updated BEFORE UPDATE ON public.places FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: accommodation_amenities accommodation_amenities_accommodation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_amenities
    ADD CONSTRAINT accommodation_amenities_accommodation_id_fkey FOREIGN KEY (accommodation_id) REFERENCES public.accommodations(id) ON DELETE CASCADE;


--
-- Name: accommodation_amenities accommodation_amenities_amenity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_amenities
    ADD CONSTRAINT accommodation_amenities_amenity_id_fkey FOREIGN KEY (amenity_id) REFERENCES public.amenities(id) ON DELETE CASCADE;


--
-- Name: accommodation_images accommodation_images_accommodation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodation_images
    ADD CONSTRAINT accommodation_images_accommodation_id_fkey FOREIGN KEY (accommodation_id) REFERENCES public.accommodations(id) ON DELETE CASCADE;


--
-- Name: accommodations accommodations_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: accommodations accommodations_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.accommodations
    ADD CONSTRAINT accommodations_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.districts(id);


--
-- Name: ai_extractions ai_extractions_promoted_accommodation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_extractions
    ADD CONSTRAINT ai_extractions_promoted_accommodation_id_fkey FOREIGN KEY (promoted_accommodation_id) REFERENCES public.accommodations(id);


--
-- Name: ai_extractions ai_extractions_promoted_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_extractions
    ADD CONSTRAINT ai_extractions_promoted_place_id_fkey FOREIGN KEY (promoted_place_id) REFERENCES public.places(id);


--
-- Name: ai_extractions ai_extractions_raw_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ai_extractions
    ADD CONSTRAINT ai_extractions_raw_item_id_fkey FOREIGN KEY (raw_item_id) REFERENCES public.raw_scraped_items(id) ON DELETE CASCADE;


--
-- Name: cities cities_province_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.cities
    ADD CONSTRAINT cities_province_id_fkey FOREIGN KEY (province_id) REFERENCES public.provinces(id);


--
-- Name: districts districts_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.districts
    ADD CONSTRAINT districts_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: place_images place_images_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_images
    ADD CONSTRAINT place_images_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE CASCADE;


--
-- Name: place_sources place_sources_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_sources
    ADD CONSTRAINT place_sources_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE CASCADE;


--
-- Name: place_sources place_sources_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_sources
    ADD CONSTRAINT place_sources_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.data_sources(id);


--
-- Name: place_tags place_tags_place_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_tags
    ADD CONSTRAINT place_tags_place_id_fkey FOREIGN KEY (place_id) REFERENCES public.places(id) ON DELETE CASCADE;


--
-- Name: place_tags place_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.place_tags
    ADD CONSTRAINT place_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: places places_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: places places_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.cities(id);


--
-- Name: places places_district_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.places
    ADD CONSTRAINT places_district_id_fkey FOREIGN KEY (district_id) REFERENCES public.districts(id);


--
-- Name: raw_scraped_items raw_scraped_items_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.raw_scraped_items
    ADD CONSTRAINT raw_scraped_items_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.scrape_runs(id) ON DELETE CASCADE;


--
-- Name: scrape_runs scrape_runs_source_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.scrape_runs
    ADD CONSTRAINT scrape_runs_source_id_fkey FOREIGN KEY (source_id) REFERENCES public.data_sources(id);


--
-- PostgreSQL database dump complete
--

