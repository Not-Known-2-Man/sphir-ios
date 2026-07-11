# Sphir Universal Links hosting

Host `apple-app-site-association` (AASA) so `https://sphir.io/...` links open the app.

## Requirements
- Serve the file at **both**:
  - `https://sphir.io/.well-known/apple-app-site-association`
  - `https://sphir.io/apple-app-site-association`
- Content-Type: `application/json`
- **No** `.json` extension, served over HTTPS, no redirects.

## Before shipping
- Replace `TEAMID` in the AASA with your real Apple Developer Team ID
  (Membership page). Final `appID` looks like `A1B2C3D4E5.com.Sphir`.
- In Xcode, add the **Associated Domains** capability to the `Sphir` target
  with `applinks:sphir.io`.

## Matched paths
- `/card/<uuid>`       → opens that card
- `/collection/<uuid>` → opens that collection
