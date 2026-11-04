# Sphir iOS Design Specification

> Source of truth for recreating the Sphir iOS app in Figma.  
> All measurements are in **points (pt)**. All colors are in **hex**.

---

## 1. Color Palette

| Token | Hex | Usage |
|---|---|---|
| `background` | `#F5F2EE` | App-wide page background |
| `cardBackground` | `#FFFFFF` | Card surfaces, form fields, nav bars |
| `cardBackgroundAlt` | `#FAF8F5` | Secondary surfaces, image placeholders, tab strip |
| `textPrimary` | `#2A2825` | Headings and primary body text |
| `taupe` | `#8B7B68` | Accent: buttons, icons, links, active states |
| `lightTaupe` | `#C9B89A` | Avatar fills, large icon overlays |
| `mutedText` | `#8A8279` | Labels, secondary text, placeholders |
| `border` | `#E8E3DC` | Strokes, dividers, separators |
| `success` | `#4CAF50` | Sync badge, checkmarks, positive states |

### Derived / contextual colors

| Usage | Value |
|---|---|
| Taupe button pressed | `#6F5E4E` (approx –15 L) |
| Sync badge background | `#4CAF50` at 12% opacity |
| Tag pill background | `#8B7B68` at 12% opacity |
| Thumbnail placeholder fill | `#8B7B68` at 12% opacity |
| Cover image placeholder | `#FAF8F5` |
| Sign-out button text | System Red (`#FF3B30`) |
| Session-expired notice bg | `#FDF8EC` |
| Session-expired notice border | `#F0D890` |
| Session-expired notice text | `#8A6A1C` |

---

## 2. Typography Scale

Sphir uses two font stacks:

| Stack | SwiftUI call | Figma equivalent |
|---|---|---|
| **Heading** (serif) | `.system(design: .serif)` | Playfair Display |
| **Body** (default) | `.system()` | SF Pro |

### Heading styles

| Name | Size | Weight | Color (default) |
|---|---|---|---|
| Screen Title Large | 24 pt | Bold | `textPrimary` |
| Screen Title Medium | 22 pt | Bold | `textPrimary` |
| Section Header | 20 pt | Bold | `textPrimary` |
| Logo / Avatar Monogram | 36 pt | Bold | White |
| About Heading | 18 pt | Bold | `textPrimary` |
| Settings Profile Monogram | 24 pt | Bold | White |

### Body styles

| Name | Size | Weight | Color (default) |
|---|---|---|---|
| Nav Bar Title | 17 pt | Semibold | `textPrimary` |
| Settings Name | 17 pt | Bold | `textPrimary` |
| Primary Body | 15 pt | Regular | `textPrimary` |
| Row Title | 15 pt | Semibold | `textPrimary` |
| Row Subtitle | 12 pt | Regular | `mutedText` |
| Sync Status Label | 12 pt | Semibold | Contextual |
| Field Label | 13 pt | Semibold | `mutedText` |
| Secondary Label | 13 pt | Regular | `mutedText` |
| Tag Pill Text | 13 pt | Medium | `taupe` |
| Button Primary (large) | 16 pt | Semibold | White |
| Button Ghost | 16 pt | Semibold | `taupe` |
| Header Button (+ Card) | 13 pt | Semibold | White |
| Header Button (+ Coll.) | 13 pt | Semibold | `taupe` |
| Greeting | 20 pt | Bold (serif) | `textPrimary` |
| Dashboard App Name | 22 pt | Bold (serif) | `textPrimary` |
| Version Label | 12 pt | Regular | `mutedText` |
| Detail URL Link | 13 pt | Regular | `taupe` (underlined) |

---

## 3. Spacing Scale

| Label | Value |
|---|---|
| XS | 4 pt |
| SM | 8 pt |
| MD | 12 pt |
| LG | 16 pt |
| XL | 20 pt |
| 2XL | 24 pt |
| 3XL | 32 pt |
| 4XL | 40 pt |

---

## 4. Corner Radius Scale

| Name | Value | Usage |
|---|---|---|
| Pill | 50 pt (full) | Capsule buttons, search bar, tab strip |
| Button | 22 pt | Primary action buttons (large) |
| Card | 12 pt | Collection cards, form fields, setting cards, row cells |
| Input | 12 pt | Form text fields and collection picker |
| Tag | Full capsule | Tag pills |
| Thumbnail | 8 pt | Card row thumbnail images |
| Image Card | 12 pt | Cover image on card detail |
| Logo Circle | Full circle | Auth logo, avatar circles |

---

## 5. Shadow

Used on `CollectionCardView` only:

| Property | Value |
|---|---|
| Color | `#000000` at 4% opacity |
| Radius | 6 pt |
| X offset | 0 |
| Y offset | 2 pt |

---

## 6. Shared Components

### 6.1 FlowModalHeader

Used at the top of every `.sheet` and `.fullScreenCover`.

```
ZStack (height: ~52 pt)
  Text — SphirFont.heading(18, .bold), textPrimary, centered
  HStack trailing:
    Button [xmark icon]
      SF Symbol: "xmark", size 15 pt, weight semibold, mutedText
Padding: horizontal 20 pt, top 20 pt, bottom 12 pt
```

### 6.2 DetailTopBar

Sticky top bar on detail screens (CollectionDetail, CardDetail).

```
ZStack (height: ~52 pt)
  Text (title) — SphirFont.body(17, .semibold), textPrimary, centered
  HStack leading:
    Button [chevron.left + "Back"]
      SF Symbol: "chevron.left", size 16 pt, weight semibold
      Text "Back" — SphirFont.body(16, .semibold)
      Color: taupe
Padding: horizontal 20 pt, vertical 14 pt
Background: cardBackground + 1 pt border bottom
```

### 6.3 CardOptionRow

Full-width selectable row in type/source pickers.

```
HStack (spacing 12, padding H 16, minHeight 64–72 pt)
  Text (emoji) — system 24 pt
  VStack (spacing 2)
    Text (title) — body 15 pt semibold, textPrimary
    Text (subtitle) — body 12 pt, mutedText
  Spacer
  Image "chevron.right" — 13 pt semibold, mutedText

Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

### 6.4 CollectionCardView

2-column grid card on the Dashboard.

```
VStack (alignment: leading, spacing 12)
  PrivacyBadge
  Circle (60×60 pt)
    fill: taupe
    overlay: "square.stack.fill" SF Symbol, 24 pt, white
  Text (name) — body 15 pt bold, textPrimary, lineLimit 1
  Text (count) — body 12 pt, mutedText

Padding: 16 pt all sides
Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
Shadow: black 4%, radius 6, x 0, y 2
```

### 6.5 CardRowView

List row used in CollectionDetail, Dashboard uncategorized section, and search results.

```
HStack (spacing 12, padding 14 all sides)
  Thumbnail (44×44 pt)
    If image: resizable, scaledToFill, clipShape RoundedRectangle(r 8)
    Else: Circle fill taupe 12%, overlay card-type SF Symbol 16 pt taupe
  VStack (spacing 3)
    Text (title) — body 15 pt semibold, textPrimary, lineLimit 1
    Text (description) — body 12 pt, mutedText, lineLimit 2
    OR HStack: source icon (10 pt) + source label + "·" + date — body 12 pt, mutedText
  Spacer
  Image "chevron.right" — 13 pt semibold, mutedText

Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

### 6.6 EmptyStateView

Centered placeholder when a list is empty.

```
VStack (spacing 12)
  Image (SF Symbol, size 40 pt) — lightTaupe
  Text (title) — body 16 pt semibold, textPrimary
  Text (message) — body 13 pt, mutedText, multilineTextAlignment center

Width: maxWidth .infinity
Padding: horizontal 24 pt, vertical 40 pt
```

### 6.7 PrivacyBadge

Small pill indicating privacy level (referenced but not shown in detail — pill-shaped capsule badge).

### 6.8 Primary Button (large, full-width)

```
Text — body 16 pt semibold, white
Width: maxWidth .infinity
Padding vertical: 16 pt
Background: RoundedRectangle(r 22) fill taupe
Disabled: opacity 0.5
```

### 6.9 Ghost / Outlined Button (large, full-width)

```
Text — body 16 pt semibold, taupe
Width: maxWidth .infinity
Padding vertical: 16 pt
Background: RoundedRectangle(r 22) fill cardBackground
Border: RoundedRectangle(r 22) stroke taupe, lineWidth 1
```

---

## 7. Screen Specifications

---

### Screen 1: AuthView

**Layout:** `NavigationStack` → `ZStack(background) → VStack(spacing 24) → ScrollView`

**Background:** `#F5F2EE`

**Outer padding:** horizontal 28 pt, top 64 pt, bottom 32 pt

#### 7.1 Logo

```
Circle (72×72 pt)
  fill: taupe (#8B7B68)
  overlay: Text "S"
    font: heading 36 pt bold
    color: white
```

#### 7.2 Title

```
Text — heading 24 pt bold, textPrimary
"Welcome back" (sign in) / "Create account" (sign up)
```

#### 7.3 Subtitle

```
Text — body 13 pt, mutedText
"Sign in to your Sphir account" / "Get started for free"
```

#### 7.4 Text Fields

Each field:
```
VStack (spacing 8, field-to-field spacing 12)
  Label — body 13 pt, mutedText
  TextField
    font: body 15 pt, textPrimary
    padding: horizontal 14 pt, vertical 14 pt
    background: cardBackground (white)
    border: RoundedRectangle(r 12) stroke border, lineWidth 1
    focus border: taupe
```

Sign-up mode adds a 2-column grid row for First Name + Last Name:
```
HStack (spacing 12): [First Name field] [Last Name field]
```

#### 7.5 Field error message

```
Text — body 12 pt, system red
display: block below field, margin-top 4 pt
```

#### 7.6 Submit Button

```
Primary Button (large, full-width, cornerRadius 22)
Text: "Sign In" or "Create Account"
Spinner: white, 18×18 pt, border 2 pt
```

#### 7.7 Forgot Password (sign-in mode only)

```
Button text — body 13 pt, taupe
Trailing alignment
Margin top: 4 pt
```

#### 7.8 Mode Toggle Row

```
HStack
  Text — body 13 pt, mutedText ("Don't have an account?")
  Button text — body 13 pt semibold, taupe ("Sign up")
Centered, margin top: 24 pt
```

#### 7.9 Guest Button (sign-in mode only)

```
Button text — body 14 pt, mutedText ("Continue as Guest")
Centered, margin top 16 pt
```

#### 7.10 Session-expired notice

```
VStack banner
  background: #FDF8EC
  border: 1 pt #F0D890, cornerRadius 8
  padding: 10×12 pt
  text: 13 pt color #8A6A1C
```

---

### Screen 2: DashboardView

**Navigation:** `NavigationStack`  
**Background:** `#F5F2EE`

#### 2.1 Sticky Header

```
HStack (spacing 12)
  Text "SPHIR" — heading 22 pt bold, textPrimary
  Spacer
  [+ Card button]
  [+ Collection button]
  [Bell button]
  [Avatar button]

Padding: horizontal 20 pt, vertical 12 pt
Background: #F5F2EE + 1 pt border (#E8E3DC) bottom edge
```

**+ Card button (filled capsule):**
```
Text "+ Card" — body 13 pt semibold, white
Padding: H 12 pt, V 7 pt
Background: Capsule fill taupe
```

**+ Collection button (outlined capsule):**
```
Text "+ Collection" — body 13 pt semibold, taupe
Padding: H 12 pt, V 7 pt
Background: Capsule fill cardBackground
Border: Capsule stroke taupe, lineWidth 1
```

**Bell icon:** SF Symbol `"bell"`, 18 pt, textPrimary

**Avatar:**
```
Circle (32×32 pt)
  fill: lightTaupe (#C9B89A)
  overlay: initials text, body 14 pt semibold, white
```

#### 2.2 Scroll Content padding

```
VStack (spacing 20)
Padding: horizontal 20 pt, top 16 pt, bottom 32 pt
```

#### 2.3 Greeting

```
Text "Good morning, [Name]"
font: heading 20 pt bold, textPrimary
```

#### 2.4 Search Bar

```
HStack (spacing 8)
  Image "magnifyingglass" — mutedText
  TextField "Search collections..."
    font: body 15 pt, textPrimary

Padding: horizontal 16 pt, vertical 12 pt
Background: RoundedRectangle(r 20) fill cardBackground
Border: RoundedRectangle(r 20) stroke border, lineWidth 1
```

#### 2.5 Tab Selector

```
HStack (spacing 4) [Collections | Groups]
  Each tab:
    Text — body 14 pt semibold
    Active: textPrimary, Capsule fill cardBackground
    Inactive: mutedText, clear
    Padding vertical: 8 pt, maxWidth .infinity

Outer padding: 4 pt all sides
Background: Capsule fill cardBackgroundAlt (#FAF8F5)
Border: Capsule stroke border, lineWidth 1
```

#### 2.6 Collections Grid

```
LazyVGrid
  2 columns, spacing 16 pt
  Each cell: CollectionCardView (see 6.4)
```

#### 2.7 Uncategorized Section

```
VStack (spacing 12)
  Text "Uncategorized" — body 14 pt semibold, mutedText
  ForEach: CardRowView (see 6.5)
```

#### 2.8 Search Results (when query active)

Tabs hidden. Two sections shown vertically:
- Collections section: filtered CollectionCardView grid
- "Cards" section header (body 14 pt semibold, mutedText) + CardRowView list

"No matching collections" empty state: `EmptyStateView(icon: "magnifyingglass", ...)`
"No matching cards": `Text "No matching cards"` — body 13 pt, mutedText

#### 2.9 Empty States (no collections, no search match)

```
EmptyStateView
  icon: "square.stack.3d.up" (SF Symbol, 40 pt, lightTaupe)
  title: "No collections yet" — body 16 pt semibold, textPrimary
  message: "Tap "+Collection" to create your first one." — body 13 pt, mutedText
  padding: H 24 pt, V 40 pt
```

---

### Screen 3: CollectionDetailView

**Background:** `#F5F2EE`  
**Top bar:** `DetailTopBar` (see 6.2)

#### 3.1 Header Block

```
VStack (spacing 10, padding bottom 4)
  Text (collection name) — heading 22 pt bold, textPrimary
  Text (description) — body 14 pt, mutedText  [if non-empty]
  HStack (spacing 10)
    PrivacyBadge
    Text "[n] items" — body 12 pt, mutedText
```

#### 3.2 Card List

```
VStack (spacing implicit from ForEach)
  ForEach: CardRowView (see 6.5)
  Long-press context menu: "Edit" (pencil icon), "Delete" (trash, destructive)
```

**Scroll content padding:** horizontal 20 pt, top 16 pt, bottom 32 pt

#### 3.3 Empty State

```
EmptyStateView
  icon: "tray" (SF Symbol)
  title: "No cards yet"
  message: "Add one with "+ Card", or share a link to Sphir."
```

---

### Screen 4: CardDetailView

**Background:** `#F5F2EE`  
**Top bar:** `DetailTopBar` with card type as title (see 6.2)

**Scroll content padding:** horizontal 20 pt, top 16 pt, bottom 32 pt  
**Content VStack spacing:** 20 pt

#### 4.1 Sync Badge

```
HStack (spacing 6)
  Image (SF Symbol from syncStatus.iconName, 11 pt bold)
  Text (syncStatus.label) — body 12 pt semibold

Foreground: syncStatus.color
Padding: H 10 pt, V 6 pt
Background: Capsule fill syncStatus.color 12% opacity
```

syncStatus colors:
- synced → success green `#4CAF50`
- syncing → taupe `#8B7B68`
- offline → mutedText `#8A8279`

#### 4.2 Card Title

```
Text — heading 24 pt bold, textPrimary
```

#### 4.3 Cover Image

If image data present:
```
Image — resizable, scaledToFit, maxWidth .infinity
clipShape: RoundedRectangle(r 12)
border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

If no image (placeholder):
```
RoundedRectangle(r 12)
  fill: cardBackgroundAlt (#FAF8F5)
  height: 180 pt
  overlay: "photo" SF Symbol, 32 pt, lightTaupe
  border: stroke border, lineWidth 1
```

#### 4.4 Open in Reader Button (when URL exists)

```
HStack (spacing 8)
  Image "safari"
  Text "Open in Reader"
  font: body 16 pt semibold, white
  width: maxWidth .infinity
  padding vertical: 16 pt
  background: RoundedRectangle(r 22) fill taupe
```

#### 4.5 URL Link (when URL exists)

```
Text (url string) — body 13 pt, taupe, underline
lineLimit 1, truncationMode .middle
```

#### 4.6 Description

```
Text — body 15 pt, mutedText
fixedSize(horizontal: false, vertical: true)
```

#### 4.7 Content (raw, when URL not present)

```
Text — body 15 pt, textPrimary
```

#### 4.8 Tag Cloud

```
VStack (spacing 8)
  Text "Tags" — body 13 pt semibold, mutedText
  HStack (spacing 8)
    ForEach tag:
      Text "#[tag]" — body 13 pt medium, taupe
      padding: H 10 pt, V 5 pt
      background: Capsule fill taupe 12% opacity
```

#### 4.9 Metadata Footer

```
VStack (spacing 8)
  Label (sourceApp.label, systemImage: sourceApp.iconName)
  Label (date string, systemImage: "calendar")
  font: body 13 pt, mutedText
```

---

### Screen 5: SettingsView

**Presentation:** `.sheet` (modal)  
**Top bar:** `FlowModalHeader("Settings", xmark)` (see 6.1)  
**Background:** `#F5F2EE`  
**Scroll content padding:** horizontal 20 pt, top 8 pt, bottom 32 pt  
**Section spacing:** 20 pt

#### 5.1 Profile Card

```
HStack (spacing 14, padding 16)
  Circle (56×56 pt)
    fill: lightTaupe (#C9B89A)
    overlay: initials, heading 24 pt bold, white
  VStack (spacing 3)
    Text (displayName) — body 17 pt bold, textPrimary
    Text (email) — body 13 pt, mutedText

Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

#### 5.2 Sync Status Card

```
HStack (spacing 10, padding 16)
  Circle (10×10 pt) fill success green
  VStack (spacing 2)
    Text "Synced" — body 15 pt semibold, textPrimary
    Text "All changes saved locally" — body 12 pt, mutedText
  Spacer
  Image "checkmark.icloud" — 18 pt, success green

Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

#### 5.3 About Card

```
VStack (spacing 8, padding 16)
  Text "About Sphir" — heading 18 pt bold, textPrimary
  Text (body copy) — body 14 pt, mutedText, fixedSize

Background: RoundedRectangle(r 12) fill cardBackground
Border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

#### 5.4 Sign Out Button

```
Text "Sign Out" — body 16 pt semibold, system red
width: maxWidth .infinity
padding vertical: 16 pt
background: RoundedRectangle(r 12) fill cardBackground
border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

#### 5.5 Version Label

```
Text "Version X.X (X)" — body 12 pt, mutedText
Centered, padding top 8 pt
```

---

### Screen 6: Card Flow — Step 1: SelectCardTypeView

**Presentation:** `.sheet`  
**Background:** `#F5F2EE`  
**Top bar:** `FlowModalHeader("Select Card Type", xmark)`

#### Card Types (5 options, each as CardOptionRow)

| Emoji | Title | Subtitle |
|---|---|---|
| Defined on CardType model | Text | Articles, Blog Posts, Documents… |
| | Media | Videos, Podcasts, Audio Files… |
| | Business | Companies, Organizations, Professionals… |
| | Product | Physical or digital Products, Apps, Books… |
| | Original Scribe | Your own unique content |

**List padding:** horizontal 20 pt, top 8 pt, bottom 24 pt  
**Row spacing:** 12 pt  
**Row:** `CardOptionRow` (see 6.3), minHeight 64 pt

---

### Screen 7: Card Flow — Step 2: SelectSourceView

**Presentation:** `.sheet` (presented from SelectCardTypeView)  
**Background:** `#F5F2EE`  
**Top bar:** `FlowModalHeader("Where are you adding from?", xmark)`

#### Sources (4 options)

| Emoji | Title | Subtitle |
|---|---|---|
| Defined on CardSource | Photos | Pick from your photo library |
| | Camera | Take a new photo |
| | URL | Paste a link |
| | Screenshots | Import screenshots from your library |

**List padding:** horizontal 20 pt, top 8 pt, bottom 24 pt  
**Row spacing:** 12 pt  
**Row:** `CardOptionRow` (see 6.3), minHeight 72 pt

---

### Screen 8: Card Flow — Step 3: CardFormView

**Presentation:** `.fullScreenCover`  
**Background:** `#F5F2EE`

#### 8.1 Navigation Bar

```
ZStack
  Text "New Card" — body 17 pt semibold, textPrimary, centered
  HStack
    Button [chevron.left] — SF Symbol 17 pt semibold, textPrimary
    Spacer
    Button "Done" — body 16 pt semibold
      Active: taupe
      Inactive: mutedText (disabled)

Padding: horizontal 20 pt, vertical 14 pt
Background: #F5F2EE + 1 pt border bottom
```

#### 8.2 Sync Strip

```
HStack (spacing 6)
  Image "checkmark" — 11 pt bold, success
  Text "Saved locally" — body 12 pt semibold, success

Padding: H 10 pt, V 6 pt
Background: Capsule fill success 12% opacity
```

#### 8.3 Form Fields

Each field:
```
VStack (spacing 8)
  Text (label) — body 13 pt semibold, mutedText
  TextField / content
    font: body 15 pt, textPrimary
    padding: H 14 pt, V 12 pt
    background: RoundedRectangle(r 12) fill cardBackground
    border: RoundedRectangle(r 12) stroke border, lineWidth 1
```

Fields (VStack spacing 20 pt):
- **Title** — TextField "Card title"
- **Description** — TextField multiline "Add description...", lineLimit 3...6
- **URL** (conditional, source = .url) — TextField "https://...", keyboardType .URL
- **Tags** — TextField "Add tags (comma separated)"
- **Collection** — Menu/Picker (chevron.up.chevron.down icon, 12 pt, mutedText)
- **Cover Image** — Dashed placeholder button

#### 8.4 Cover Image Placeholder

```
VStack (spacing 8)
  Label — body 13 pt semibold, mutedText
  Button area
    HStack: "photo" icon + "Add Image" text, body 15 pt medium, mutedText
    Width: maxWidth .infinity
    Padding vertical: 28 pt
    Background: RoundedRectangle(r 12) fill cardBackgroundAlt
    Border: RoundedRectangle(r 12) stroke border, lineWidth 1.5, dash [6, 4]
```

#### 8.5 Bottom Done Button

```
Primary Button (cornerRadius 22)
Text "Done" — body 16 pt semibold, white
Padding: H 20 pt, vertical 12 pt, bottom 12 pt
Background strip: cardBackground
Disabled: opacity 0.5
```

**Scroll content padding:** horizontal 20 pt, top 16 pt, bottom 24 pt

---

### Screen 9: Card Flow — Step 4: SuccessView

**Presentation:** Opacity overlay on `CardFormView` (`.overlay` + `.transition(.opacity)`)  
**Background:** `#F5F2EE` (full screen)  
**Auto-dismiss:** 3 seconds

```
VStack (spacing 16)
  Image "checkmark.circle.fill"
    80×80 pt
    foreground: success green (#4CAF50)

  Text "Card Saved!" — heading 24 pt bold, textPrimary

  Text "Added to your collection" — body 14 pt, mutedText

  VStack (spacing 12, padding top 24, H 40)
    [Add Another] — Primary Button (cornerRadius 22)
    [Back to Dashboard] — Ghost Button (cornerRadius 22)
```

---

## 8. Icon Reference (SF Symbols)

| Symbol | Usage |
|---|---|
| `magnifyingglass` | Search bar icon, search empty state |
| `bell` | Notifications button in header |
| `xmark` | Modal close button (FlowModalHeader) |
| `chevron.left` | Back button (DetailTopBar, CardFormView nav) |
| `chevron.right` | Row trailing indicator |
| `chevron.up.chevron.down` | Collection picker dropdown |
| `square.stack.3d.up` | No-collections empty state |
| `square.stack.fill` | Collection card icon |
| `tray` | No-cards empty state |
| `checkmark.circle.fill` | Success view checkmark |
| `checkmark` | Sync strip confirmed, collection menu checkmark |
| `checkmark.icloud` | Settings sync status |
| `safari` | Open in Reader button |
| `photo` | Cover image placeholder |
| `pencil` | Context menu Edit |
| `trash` | Context menu Delete |
| `calendar` | Card metadata date label |

Card type SF Symbols are defined on the `CardType` model (rawValue-driven), not hardcoded in views.

---

## 9. Layout Patterns

### Modal sheets

- All `.sheet` presentations use `SphirColor.background` as their root background.
- Header is always `FlowModalHeader` (ZStack, centered title, trailing xmark).
- Content in `ScrollView` with `VStack(spacing 12)` and padding H 20 pt.

### Detail screens

- Use `VStack(spacing: 0)` as root.
- `DetailTopBar` is sticky at top (not in ScrollView).
- `ScrollView` below with `VStack(alignment: .leading, spacing: 20)`.
- Toolbar hidden: `.toolbar(.hidden, for: .navigationBar)`.
- Back button hidden: `.navigationBarBackButtonHidden(true)`.

### Navigation

- Root: `NavigationStack(path: $router.path)` in `DashboardView`.
- Destinations registered with `.navigationDestination(for:)` for `Collection` and `Card`.
- Card flow uses nested `.sheet` → `.sheet` → `.fullScreenCover` chain.

### Pull to refresh

- Dashboard `ScrollView` has `.refreshable { await appStore.syncFromAPI() }`.

---

## 10. Animation

| Interaction | Animation |
|---|---|
| Tab switch (Collections ↔ Groups) | `.easeInOut(duration: 0.25)` + `.move(edge:)` + `.opacity` |
| Success overlay appear/disappear | `.easeInOut(duration: 0.2)` + `.opacity` |
| Search field focus | Standard iOS keyboard animation |
