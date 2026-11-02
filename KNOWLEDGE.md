# Craft

**Ship these. They are what made the real apps feel finished.**

- Home **is** the mechanic (canvas, rings, tower, wheel, matrix, dial, board, console). A tab plus a list of records is a clone. Mini-references are mechanics and density only — never type names, layouts, WebView, OneSignal, or betting chrome.
- A TabView with exactly three tabs is the factory stamp — use two or four-to-five destinations, or a different chrome. Family screen lists and `-ReviewScreen today|log|goals` are destinations / launch keys, not a tab bar.
- Guideline 4.2 (Minimum Functionality): the App Store product is a native SwiftUI app with a persisted verb on device. A WebView, Safari sheet, site wrapper, or content catalog you could browse on the web is a reject. Push notifications, Core Location, and sharing do **not** make a browser into a product.
- One persisted verb on home. Unit-test that verb. A decorative Game / Aura / Circuit / Nest / Sweep tab is filler — do not ship one.
- Every primary list has an empty state: generated art, one headline, one line, one CTA as a **full page** (`frame(maxHeight: .infinity)`). A crumb in a `Spacer` fails.
- Generated art that sits on UI is a **cutout** (real PNG alpha, transparent corners, solid subject in the center). An opaque square plate inside a circle or pentagon fails. A hollow glass box or wire frame with a transparent center fails. AppIcon / Splash / CardBackdrop fill the canvas.
- Screens fill the device. Unused flat field, a narrow text column, or a header-plus-void overlay is a fail. Edge-to-edge rows; the writing surface / list / hero uses remaining height. iPad uses the width. Simulator seed shows a **used** product (several cards, several lines of ink), not one stub row. Sibling cards never paint over each other. A title or amount cut in half is a fail: display type keeps its height (`fixedSize` vertically or a scroll), and a flexible sibling does not compress it. `.clipped()` is for a framed image cell only, never for text. Grid / HStack media is framed and `.clipped()` so `scaledToFill` cannot cover the neighbor.
- The root has no back button. `.navigationTitle` is never the product name — a back control that reads the app name looks like leaving and returning to the same app. Sheets dismiss with Close on their own stack.
- Hit the whole chrome, not the glyph. Chrome lives **inside** the `Button` label with `.contentShape`. Min ~44pt. Rows, chips, cards, tab columns: one target.
- Onboarding Next / Continue / START is bottom, full width — not a 36pt control in the corner.
- Simulator seed only, once, behind a versioned key. Never seed on a device. Skip onboarding on Simulator after seed so home is not empty. Seeded home: primary verb enabled. Blocked twist is a test fixture, not the first frame.
- Background fills the safe area (no white strips). Tab bar sits on the home indicator; lists use `contentMargins(.bottom)`.
- Contact URL on Settings (or Goals). App Review looks for it.
- Health or product advice in the binary needs citations (tappable source links, easy to find). A "not medical advice" line without sources fails App Store 1.4.1. Catalog credit is a tappable source link, not a static OpenFoodFacts label.
- Camera scan (when used): include `.qr`; extract 8–14 digit runs from QR/URL; UPC-A pad; Simulator chips + manual; stop the session on disappear/background.
- Offline: if the product needs a catalog, a local shelf must catch empty/fail search. A spinner forever fails.
- Denied camera (when used) explains the state and routes to Settings. Silent no-op fails.
- Guideline 5.1.1 (when camera is used): the button before `requestAccess` is Continue or Next. "Allow camera" / "Enable camera" / "Grant camera" / bare Allow or Enable on that button is a reject. The system alert is the only Allow.
- Numbers go through a `FormatStyle` (`Text(value, format: .number.precision(.fractionLength(0...1)))`), never `NumberFormatter` or `String(format:)`. Day edges use `Calendar.current.startOfDay`.
- One haptic on a successful commit, none on navigation.
- VoiceOver labels on every icon-only control. Colour is never the only signal.

**Anti-slop (taste kit). Defects, not suggestions.**

- No three identical equal-weight cards. One hero, then variance.
- No everything-centered. Asymmetry or a real grid.
- No em-dash or en-dash in UI copy. Period or comma.
- No elevate / unlock / seamless / effortless / supercharge / empower.
- No SECTION 01, FEATURE, Lorem, Your headline here.
- No emoji anywhere in the binary (labels, comments, assets copy).
- No 3-4pt tinted left-border on cards or alerts.
- No #000 on #FFF. Use the section 7.1 tokens.
- Neutrals carry the screen; accent is spice, one hit.
- Display type is short and wide (max ~4 lines, usually 1-2). Body ~17pt.
- Outer padding > card padding > inner gaps. Never invert.
- Adjacent home blocks do not share the same column structure.
- Sibling cards never paint over each other. A title cut in half is a fail.
- One radius language and one elevation language (section 7.4). No second kit.

**SwiftUI craft (from the kit adapter).**

- Colours, type, space, radius: one accessor each. No raw hex / magic pt in views.
- Primary Button uses a `ButtonStyle` with default, pressed, disabled, loading.
  Destructive actions use a destructive variant, not `action.primary` in red.
- Interactive views that apply: default, pressed, focused, disabled, loading,
  error, selected. Hover is press on iPhone.
- `@Environment(\.accessibilityReduceMotion)` gates travel. Fade stays.
- Dynamic Type: no clipped headlines at AX5. `@ScaledMetric` for custom sizes.
- Grid / HStack image: frame the cell, `.clipped()`. `scaledToFill` without
  clip paints over the neighbor. Titles stay readable.
- Native `Button` / `Toggle` / `TextField`. A tappable `onTapGesture` card fails.
- Hit the whole chrome, `.contentShape`, min 44pt. Focus ring contrast 3:1.
- Token by intent: the live verb wears accent; delete does not.
- SF Symbols for chrome. Generated art is the brand, not a symbol-as-logo.

**UX writing.**

- Buttons frontload the verb: Save, Log, Scan. Not Submit or Click here.
- Empty: value, then action. Not 'No data'.
- Error: what, why if needed, how. A path forward or it is a dead end.
- Destructive confirm names the thing and the consequence.
- Voice is this app's DNA voice. Tone shifts (warm empty, plain error) but
  the voice does not.

Full taste doctrine is design-taste.md in the added ux-ui/taste directory. The factory list above wins on conflict.

**Design DNA — `notion` / warm / All-in-one workspace. Warm minimalism, serif headings, soft surfaces.**
- Layout family: `asymmetric-split` — Uneven columns (7/5 or 8/4), not a clean 50/50.
- Density: airy. Warm soft: friendly radii, comfortable pad, one playful moment.
- Motion `snap`: Press scale 0.97, 140-180ms ease-out. Sheets scale 0.96 to 1 plus fade. Reduce Motion: opacity only.
- Voice `tactical`: Status-first. Noun plus state. 'Scan failed. Try again.'
- Type: One display size, then caption. No third weight on home. Reference type feel: warm.
- Execute: Warm soft: friendly radii, comfortable pad, one playful moment. Layout `asymmetric-split`, density airy. Kit 16/2, material, soft card. Palette recipe `high-contrast`. Press scale 0.97, 140-180ms ease-out. Sheets scale 0.96 to 1 plus fade. Reduce Motion: opacity only. Reduce Motion: fade only. Do not invent a second radius or a second accent.
- Feel like the named system. The DESIGN.md in added directories is the source for palette, density, and component language. Use this app's tokens and radii. Do not copy web chrome, type names, or product logic.

**Review screenshots (21AUG App02–09)**

The running app, not `ImageRenderer`. One launch argument, at least six keys
and at most ten:

- `-ReviewScreen today` — home after onboarding (often a no-op)
- `-ReviewScreen log` — log / statement / planner
- `-ReviewScreen goals` — goals / targets / profile
- Extra slugs from this app's own screens (settings, history, kiln, …) until
  there are six to ten frames. Each extra key opens a different screen.

These keys are launch arguments, not TabView items. A Home / Log / Settings
tab bar is the factory stamp — do not map the three keys onto three tabs.

Read `ProcessInfo.processInfo.arguments` **once**, **after** onboarding is done.
If onboarding is still showing, the hook never fires. today/log/goals must open
three **different** screens — same frame on those keys is a miss. Extra keys
that fall through to home are dropped, not a pass.

Companion (Simulator only):

- Seed one demo day behind a versioned key (`{prefix}.demo.v1`).
- Mark onboarding complete in the same seed so the hook is reachable.
- `#if targetEnvironment(simulator)`. Never seed on a device.
- Seed fills the primary surface (four slot posts from the local shelf).
- Seed the happy path: home primary verb enabled. Blocked twist is a test fixture.

Driver (outside the app): build → install on iPhone and iPad → launch with the
argument → wait until the UI settles → `xcrun simctl io <udid> screenshot`.
Name files `{App}-{today|log|goals}.png`. Pick any available simulator UDID.

**The frame is the product. Rebuild a wrong screen. Do not patch pixels over it.**

- A stranger names the job and the next tap from home. A riddle headline fails.
- Title slot is words, not an image or glyph mush. Seeded values are not unknown or dots.
- Seeded home: primary CTA enabled. Fake tappable cards and axis values as titles fail.
- Type sits on a plate, not a busy raster. Tiny values that dissolve on the crop fail.
- Home **is** the mechanic, not a list of records. An empty or one-color frame fails.
- Overlapping cards / clipped titles fail. An amount or headline cut by the bar above it fails. Grid media stays inside its cell. The root has no back button titled with the product name.
- Exactly three TabView tabs is the factory stamp. Two or four-to-five, or other chrome.
- Guideline 4.2: native verb on device. A WebView / Safari / browse-only catalog fails. Push, location, and share do not count.
- Hit the whole chrome, not the glyph. Min ~44pt. `contentShape` on the fill.
- Unused canvas / narrow column — fill with this app's mechanic, not Spacer.
- Empty and onboarding are full pages, CTA at the bottom full width.
- Seed only Simulator + versioned key. Skip onboarding on Simulator after seed.
- Background fills the safe area. Contact URL on Settings.
- Home follows section 7.6 DNA. Three equal cards, em-dash copy, or emoji fail.

**Family `food_symptom`**
- Home: Day board or 24h dial. Meals and pulses on one surface.
- Invariant (unit-test this): Lookback 0…6h. Split meal on comma/newline. score = matched/totalSymptoms; drop if matched<2. Not calories.
- Empty: The board is empty. Log a meal or a symptom.
- Fake that fails: A calorie tracker, or a black-box 'AI trigger'.
- Never: No GutGarden mini-game. No medical claims without in-app source links (1.4.1).

**From the shelf**
Marked ugly by the operator — do not produce anything that looks like these (the same look, mood or visual recipe is a reject even under another name):
- Chalkthread — design=coinbase · gallery-wall · branded — typography=Helvetica — art=Claymation claymorphism 3D · documentary — navigation=Plan-locked chrome (the pitch plan with its two peg rails and the End rim never leaves; Matches, Insights, Squad and Settings arrive as sheets over the plan; bell and export fuse onto the board)
- Pendilia — design=Soft card daylight · take artquiz4 — typography=SF Pro — art=3D glass render glassmorphism · take artquiz8 — navigation=Pendant-locked chrome (the lead hanging never leaves; Explore, Saved and Settings arrive as sheets; tack and mate fuse on Quiz)

SwiftUI craft lives in the added frameworks directory (swiftui.md and animation-gestures.md). Follow it for tokens, Reduce Motion, and native controls.
