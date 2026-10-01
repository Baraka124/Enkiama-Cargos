# Enkiama Cargos V9 — Vercel deployment

This is the complete cumulative V9 project. Desktop, laptop, tablet and mobile layouts are in the same responsive Vue application; there is no separate mobile build.

## Vercel

- Framework preset: Vite
- Build command: `npm run build`
- Output directory: `dist`
- Install command: `npm install` (Vercel default is also fine)

## Environment variables

Add these in Vercel → Project Settings → Environment Variables:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Use the values from your Supabase project. Do not commit a private service-role key to this frontend project.

## SPA routing

`vercel.json` is already included and rewrites application routes to `index.html`, so Vue Router routes work after refresh/direct navigation.

## Included cumulative experience

- Market / Discovery
- Product Experience
- Property & Land Experience
- Movement / Tracking
- Business / Storefront Identity
- Shared Motion & View Transitions
- Checkout & Conversion
- Mobile Excellence
- Original operational views and Supabase project files

## Local check

```bash
npm install
npm run dev
```

Production check:

```bash
npm run build
npm run preview
```
