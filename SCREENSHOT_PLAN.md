# App Store screenshot plan — Sphir

## Required sizes (App Store Connect)
Uploading these two covers every current iPhone; App Store scales them down.
- **6.5"** — iPhone 14 Pro Max / 15 Plus (also accepts 6.7"). 1284 × 2778 px.
- **5.5"** — iPhone 8 Plus. 1242 × 2208 px.

Capture the **same 5 screens at both sizes** (5 is the sweet spot; min 3).
Use the same content on both so the set stays consistent.

## How to capture
- Run on the matching simulator (iPhone 15 Plus for 6.5", iPhone 8 Plus for
  5.5") with the app **not** in UITEST mode so real seeded data shows.
- Cmd+S in the simulator saves a correctly-sized PNG.
- For the share-extension shot, trigger the share sheet from Safari on the
  same simulator.
- Add caption text as an overlay band (top or bottom) in your design tool —
  Apple screenshots are typically framed with a caption; the captions below
  are written for that band, not baked into the app UI.

## The 5 screenshots (in listing order)

1. **Onboarding — "Welcome to Sphir"**
   - Screen: `OnboardingView` (launch with `SHOW_ONBOARDING`, or fresh install).
   - Caption: **"Your calm space to capture what matters."**

2. **Dashboard — collections grid**
   - Screen: `DashboardView`, Collections tab with the seeded collections.
   - Caption: **"Organize everything into tidy collections."**

3. **+Card flow — Paste URL with preview**
   - Screen: `URLCardView` after fetching a link (title + description +
     thumbnail populated).
   - Caption: **"Save any link — previews fill in automatically."**

4. **Card detail — image, text, tags**
   - Screen: `CardDetailView` for a card with an image and extracted text.
   - Caption: **"Turn screenshots into searchable text, on device."**

5. **Share Extension in action**
   - Screen: Safari share sheet → "Save to Sphir" sheet with the URL preview
     and collection picker (the `ShareView`).
   - Caption: **"Save from Safari, Mail, or Messages in one tap."**

## Caption style tips (App Store compliant)
- Keep each caption to one short line; describe a real feature (don't imply
  functionality the build doesn't have — e.g. avoid "share with friends"
  since Groups is not yet functional).
- No pricing, no "#1 / best", no Apple product photos or logos.
- Status bar should look clean (full battery, no debug clutter) — the
  simulator status bar is fine.

## Optional
- **App preview video** (15–30s) is optional; skip for the first TestFlight/
  submission and add later if desired.
- iPad screenshots are only required if you ship an iPad build; Sphir targets
  iPhone for launch, so they're not needed unless you enable iPad.
