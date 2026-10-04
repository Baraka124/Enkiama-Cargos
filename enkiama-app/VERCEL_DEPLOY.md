# Enkiama Cargos V23 — Existing Vercel project update

This is the cumulative V23 project. Desktop, laptop, tablet and mobile are one Vue/Vite application.

## Existing deployment

If this repository is already connected to Vercel, do **not** create a new project. Copy/update the `enkiama-app` contents, commit, and push to the same branch. Vercel will redeploy the existing project automatically.

Existing Vercel environment variables remain in place; only add them again if Vercel reports that they are missing:

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`

Never expose a Supabase service-role key in this frontend.

## Build settings

- Framework: Vite
- Install: `npm install` / Vercel default
- Build: `npm run build`
- Output: `dist`

`vercel.json` retains the SPA fallback. The application currently uses Vue hash history, so public application states also remain refresh-safe behind the static host.

## Local release check

```bash
npm install
npm run build
npm run preview
```

## Suggested Git update

```bash
git status
git add enkiama-app
git commit -m "Update Enkiama Market to V23"
git push origin main
```


## Deployment retry

V23 deployment retriggered from the connected ChatGPT GitHub workflow after repository write access was enabled.
