# Shipping Sphir to TestFlight

Archiving and uploading must be done from Xcode with your Apple Developer
account signed in — it can't be automated from this environment (no signing
identity or App Store Connect credentials here).

## 0. Prerequisites (one-time)
- Apple Developer Program membership.
- In App Store Connect: create the app record with bundle id **com.Sphir**
  (and the app group / extension id **com.Sphir.SphirShare**).
- In Xcode → both targets → Signing & Capabilities: select your **Team**,
  enable **Automatically manage signing**.
- Confirm the capabilities are present: App Groups (`group.com.sphir.shared`)
  on both targets; Associated Domains (`applinks:sphir.io`) if using universal
  links; the `sphir` URL type; and the Camera usage description.

## 1. Version & build number
- Marketing version is already **1.0** (`MARKETING_VERSION`).
- Set/confirm the **build number** (`CURRENT_PROJECT_VERSION`). It must be
  unique and increasing for every upload (start at 1, bump to 2, 3, … on each
  new TestFlight build). Set it on all targets to the same value.

## 2. Archive
1. Select the **Sphir** scheme and destination **Any iOS Device (arm64)**
   (not a simulator).
2. **Product ▸ Archive**. Wait for the build.
3. The Organizer opens with the archive.

## 3. Upload to App Store Connect
1. In Organizer, select the archive → **Distribute App**.
2. **App Store Connect** → **Upload** → keep the defaults (automatic signing,
   include symbols) → **Upload**.
3. Wait for processing in App Store Connect (a few minutes).

## 4. TestFlight
1. App Store Connect → your app → **TestFlight**.
2. When the build finishes processing, add **What to Test** (paste from
   `RELEASE_NOTES.md`) and complete the export-compliance question
   (Sphir uses only standard HTTPS → typically "No" to custom encryption).
3. Add **David** as an internal (or external) tester and enable the build.
4. David installs **TestFlight** on his device and accepts the invite.

## Tips
- If upload is rejected for signing, re-check Team selection on **all three**
  targets (app, extension, tests) and that the app group/identifiers exist in
  your account.
- Bump the build number before each re-upload.
