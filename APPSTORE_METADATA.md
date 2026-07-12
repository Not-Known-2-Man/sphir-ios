# App Store Connect metadata — Sphir 1.0

## App name
Sphir

## Subtitle (≤30)
Capture, collect, organize  (26)

## Primary category
Productivity  (suggested secondary: Utilities)

## Keywords (≤100, comma-separated)
save,read later,bookmarks,collections,links,screenshots,OCR,notes,capture,organizer,share,clip
(94 chars)

## Promotional text (≤170, optional, editable anytime)
Save links, screenshots, and photos into calm, private collections — right from the share sheet. Everything stays on your device.

## Description (≤4000)
Sphir is a calm space to capture and collect the things that matter to you — articles, links, screenshots, and photos — organized into tidy collections you actually revisit.

Save from anywhere. Tap Share in Safari, Mail, or Messages and send a page, link, or note straight to Sphir. Or add cards right inside the app.

Rich link previews. Paste a URL and Sphir automatically pulls in the page title, description, and thumbnail — no copy-and-paste busywork.

Turn screenshots into text. Import a screenshot or photo and Sphir uses on-device text recognition to pull out the words, so your captures are searchable and editable.

Everything in its place. Group your cards into collections, browse them in a clean grid, open any card for the full picture, and edit or delete with a long-press.

Find it fast. Search across your collections and cards by title, content, and tags in real time.

Private by design. Sphir stores everything on your device. There are no accounts, no sign-in, and no servers — your library is yours.

FEATURES
• Save to Sphir from the iOS share sheet (Safari, Mail, Messages)
• Automatic link previews (title, description, image)
• On-device OCR for screenshots and photos (English and Spanish)
• Capture from Photos, the camera, a pasted URL, or by hand
• Collections with privacy labels and live item counts
• Card detail views with image, text, tags, and source
• Fast search across collections and cards
• Edit and delete with a long-press
• Onboarding, empty states, and full VoiceOver support
• Works offline — your data never leaves your device

Sphir keeps capture simple and your collection calm.

## What's New (1.0)
First release. Capture links, screenshots, and photos into private collections; save from the share sheet; automatic link previews and on-device text recognition.

## Support / Marketing URLs
- Support URL: https://sphir.io/support
- Marketing URL (optional): https://sphir.io
- Privacy Policy URL (required): https://sphir.io/privacy

---

# Privacy — App Privacy questionnaire

Summary: **Data Not Collected.** Sphir has no accounts and no backend; all
content is stored on-device (CoreData in the app's App Group container).

- "Do you or your third-party partners collect data from this app?" → **No**
  → App Store shows **"Data Not Collected."**

Notes / justification (for your reference, not entered verbatim):
- **Camera / Photos:** used only to create cards. Photos are picked via the
  out-of-process system picker (PHPickerViewController) and captures stay on
  device. Not transmitted to us or any third party.
- **Network:** when a user pastes/shares a URL, the app requests that page
  (LinkPresentation + a metadata fetch) to build a preview. This contacts the
  destination website only; no user data is sent to a Sphir server (there
  isn't one) or to analytics.
- No tracking, no ads, no analytics SDKs, no IDFA → **App Tracking
  Transparency not required.**

Usage-description strings shipped in the app:
- Camera: "Sphir uses the camera to capture photos for your cards."
- (Photos: none needed — PHPicker requires no photo-library permission.)

---

# Age Rating questionnaire → 4+

Answer **None / No** to every content question:
- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Prolonged Graphic or Sadistic Realistic Violence: None
- Profanity or Crude Humor: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None
- Medical/Treatment Information: None
- Alcohol, Tobacco, or Drug Use or References: None
- Simulated Gambling: None
- Sexual Content or Nudity: None
- Graphic Sexual Content and Nudity: None
- Contests: None
- Unrestricted Web Access: **No** (the app has no built-in browser; it only
  fetches metadata for links the user provides)
- Gambling and Contests: No

Result: **4+**

---

# Other App Store Connect fields
- Bundle ID: com.Sphir
- SKU: sphir-ios-1
- Version: 1.0
- Copyright: © 2026 (your name / company)
- Sign-in required to review? **No** (no account needed)
- Export compliance: uses only standard HTTPS/system encryption → typically
  "does not use non-exempt encryption" = **No** custom encryption.
