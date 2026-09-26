# Pathsnap

**Pathsnap** is an interactive travel planning and route optimization application designed to help travelers discover destinations, create customized itineraries, and visualize routes on an interactive map.

---

## 🚀 Features

* **Interactive Trip Planner:** Build custom trip routes with real-time map visualization and itinerary management.
* **Destination Discovery:** Explore curated destinations with filtering options based on preferences, activities, and regions.
* **Detailed Destination Guides:** View comprehensive information, highlight points of interest, and reviews for featured spots.
* **Responsive Layout:** Modern, mobile-friendly UI built with Tailwind CSS.

---

## 🛠 Tech Stack & Architecture

* **Framework / Library:** React, TypeScript
* **Build Tool:** Vite
* **Styling:** Tailwind CSS, PostCSS
* **Code Quality:** ESLint

---

## 📂 Repository Structure

```text
Pathsnap/
├── src/
│   ├── components/
│   │   ├── destinations/   # Filter bars, cards, and list views
│   │   ├── home/           # Hero sections, featured spots, and testimonials
│   │   ├── layout/         # Header, Footer, and navigation wrappers
│   │   ├── planner/        # Interactive MapView and RouteSidebar components
│   │   └── ui/             # Reusable UI elements (Buttons, Cards, Modals)
│   ├── data/               # Mock data sources and static assets
│   ├── pages/              # Application pages (Home, PlanTrip, Destinations, Contact)
│   ├── types/              # TypeScript definitions and interfaces
│   └── utils/              # Helper functions and utilities
├── eslint.config.js        # ESLint configuration
├── index.html              # HTML entry point
├── package.json            # Project dependencies and scripts
├── tailwind.config.js      # Tailwind CSS configuration
├── tsconfig.json           # TypeScript setup
└── vite.config.ts          # Vite build configuration
