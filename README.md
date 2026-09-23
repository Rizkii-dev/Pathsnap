# Pathsnap

## Local setup

Install dependencies and start the app:

```bash
npm install
npm run dev
```

The optional AI trip assistant on the planner page uses Groq. Copy `.env.example` to `.env.local` and add your Groq API key as `VITE_GROQ_API_KEY` before starting the dev server. The key is read only from the environment and is not committed to the repository.

Because this is currently a Vite frontend, the key is exposed to the browser at runtime. Use a server-side proxy or backend endpoint before deploying this integration publicly.