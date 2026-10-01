# Phase 18 — Governed Media System

Phase 18 turns imagery into a shared product system instead of letting each page render media differently.

## What changed

### 1. One public media renderer
`src/components/MediaFrame.vue` now governs flagship public media across Market, Product, Business and Property.

It provides:
- stable media boxes to reduce layout shift
- eager/high-priority loading for primary hero media
- lazy loading for collection/detail media
- async image decoding
- consistent cover/contain behavior
- world-aware fallbacks for missing and failed imagery
- loading skeletons that respect reduced-motion preferences
- optional View Transition naming so the same object/place can carry into its detail page

### 2. Shared media URL helpers
`src/lib/media.js` centralizes safe media URL validation, image-list normalization and first-image selection.

### 3. Media roles are now explicit
The visual system defines separate media roles rather than one universal crop:
- Product / object lead: square to 4:5, object clarity first
- Business cover: wide editorial crop, approximately 16:9 or 3:2
- Business logo: crisp square identity mark
- Property lead: landscape context, approximately 3:2 or 4:3
- Thumbnails / ledgers: cropped derivatives of those same source images

The system does not create fake stock photography when content is missing.

### 4. Seller-side quality guidance
Existing client-side image analysis remains advisory rather than blocking, but guidance is now purpose-aware.

Product guidance emphasizes:
- 800px+ source resolution
- sharp focus and usable light
- square / 4:5-friendly lead imagery
- detail/context images after the lead image

Property guidance emphasizes:
- 1200×700px+ landscape imagery
- understanding the surrounding place before close details
- avoiding portrait lead images and extreme panoramas

Business identity guidance emphasizes:
- 1600px+ wide cover imagery with safe edge composition
- 512×512px+ square logos

### 5. Public surfaces migrated
The flagship public media paths now use the same governed renderer:
- Market hero, product collections and product ledgers
- Product main stage, thumbnails, related objects, checkout summary and lightbox
- Business hero, floating object, story imagery, collection leads and product ledgers
- Property featured place, listing collection, seller listing thumbnails, detail gallery and lightbox

## Data / backend scope

No media schema, Supabase bucket, RPC, RLS, auth, order, property, tracking or storefront data contract was changed.

Uploads continue to use the existing storage flow. Phase 18 changes how media is judged, presented and recovered from failure—not where the application stores it.
