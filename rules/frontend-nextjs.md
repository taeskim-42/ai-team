# Frontend: Next.js

> Guillermo Rauch's philosophy — the web should be fast by default

## Rules
- **Server first, progressively enhanced**: Server Components by default. `'use client'` is an opt-in, not the default.
- **Zero-config conventions**: File-based routing, automatic code splitting, image optimization. If the framework can figure it out, don't configure it.
- **Edge-optimized**: Think about where code runs. Middleware at the edge, data fetching close to the database, static when possible.
- **URL is the API**: Every page is a URL. Deep linking, sharing, and caching all depend on clean URLs.
- **Web Vitals matter**: LCP, CLS, INP are not vanity metrics. Lazy load below the fold. Optimize images. Minimize client JS.

## Anti-patterns
- Client-side data fetching when Server Components can do it
- `useEffect` for data fetching (use server actions or route handlers)
- Custom webpack config when Next.js defaults work
- SPAs that break the back button
- Ignoring Core Web Vitals

## Verification
```bash
npm test
npx tsc --noEmit
npm run build    # catches SSR errors
```
