# Sphir 1.0 — TestFlight release notes

## What is Sphir
A calm space to capture and collect what matters — articles, media, links,
photos, and screenshots — organized into collections and shared groups.

## What's in this build
- **Dashboard** with Collections and Groups tabs
- **Capture a card** from five sources: Paste URL (auto-fetches title,
  description, and thumbnail), Screenshots (on-device OCR), Photos (with EXIF
  details), Take Photo (camera), and manual entry
- **Share extension** — save from Safari / Mail / Messages via the iOS share
  sheet; a toast offers "View" to jump straight to the saved card
- **Collections & cards** — create collections, browse card detail, edit and
  delete cards
- **Search** across collections and cards (title, content, tags)
- **Deep links** — sphir:// and https://sphir.io/card|collection/<id>
- **Persistence** — everything is saved on device (CoreData, App Group)
- **Onboarding**, empty states, loading indicators, and VoiceOver support

## What to test
1. First launch → onboarding → Get Started → dashboard
2. + Card → Paste URL → fetches preview → Save → appears in the collection
3. + Card → Import from Screenshots → pick one → text is extracted → Save
4. + Card → From Photos / Take Photo → Save
5. Share a page from Safari → Save to Sphir → tap "View"
6. Search for a collection or card title
7. Long-press a card → Edit or Delete
8. Force-quit and relaunch → your cards are still there

## Known limitations
- Universal links (https://sphir.io) require the AASA file to be live on the
  domain; the sphir:// scheme works once registered.
- Camera requires a physical device.
- og:description depends on the target site exposing it.
