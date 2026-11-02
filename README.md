# Suspectround

Suspectround is an elimination-round diary for someone testing one food at a time. You pick a single suspect, then mark each day clean or flare. A week of clean days clears that suspect. A flare busts the round and the food can rotate off the list. It is for people who want a deliberate hunt, not a calorie log, a meal planner, or an automatic blame chart.

## Architecture

The round is a small state machine folded over day keys: Idle, Hunting, Cleared, or Busted. An empty chart writes Blank instead of pretending a hunt is underway. Pick writes one SuspectMark and moves Idle or Cleared into Hunting. A second pick during Hunting is refused. Clean marks accumulate on that hunt and, at seven in a row with no flare between them, write ClearedMark. A flare writes FlareMark and BustMark and moves the round to Busted. Rotate then clears the live suspect and returns the round to Idle. The next pick will not repeat the food that just busted until some later round is cleared.

That fold matches the product. The person is not collecting a timeline of meals and symptoms to correlate later. They are running one suspect to a verdict. Day keys (YYYYMMDD from the start of the day) are the only clock the fold needs, so the phase is replayable from the marks.

ChartStore is the only seam that saves. It keeps one Chart in memory (islands, books, sessions, runs, rhumbs) and projects it to an atomic JSON file plus the single UserDefaults key `spr.chart.v1`. The screen layer, when it arrives, will talk to RoundBoard and will not read the file itself.

## Unique feature

Suspect-then-bust is the reason to use this app. One active suspect, a day grid, and two marks: clean or flare. Seven cleans clear the round. One flare busts it. Marking a day while the round is idle or already busted does nothing until you pick or rotate. The clean streak is the live number on the board. The rotation ledger remembers what left the list.

## Art

Style: 16 bit pixel art, illustration. Assets are named and filled in a later pass. The prompts reserved for them:

- `spr_Onboarding1`: 16-bit pixel illustration of one grocery parcel standing in for a single suspect food, solid opaque subject centered, no text.
- `spr_Onboarding2`: 16-bit pixel illustration of a hand marking a day cell, mid gesture, solid opaque subject centered, no text.
- `spr_Onboarding3`: 16-bit pixel illustration of a week strip with a finished parcel set aside, solid opaque subject centered, no text.
- `spr_EmptyHome`: 16-bit pixel illustration of a closed lunch tin waiting unopened, solid ceramic or metal, fully opaque, not glass, centered, no text.
- `spr_TwistHero`: 16-bit pixel illustration of a seven-cell week with one food parcel in the middle cell, solid opaque emblem, centered, no text.
- `spr_HuntSprite`: 16-bit pixel illustration of a person running while holding one small food parcel, solid opaque figure centered, no text.
- `spr_BustToken`: 16-bit pixel illustration of a cracked seal lying flat, solid opaque object centered, no text, no letters.

Shared base: 16-bit pixel illustration, hard-edged sprites, limited dither, a solid centered subject with a readable silhouette, no letters, no interface chrome, no frame, no glass, and no hollow outline.

## How this differs

Other food and symptom apps pair meals and symptoms on a timeline or rank likely triggers for you. Suspectround keeps one suspect in play, ends the round as cleared or busted, and stores that verdict on the device. There is no macro math and no catalog to browse as the product.

## Build

From this directory:

```bash
xcodegen generate
xcodebuild build-for-testing -scheme Suspectround -destination 'platform=iOS Simulator,name=iPhone 16' -jobs 4
```

Signing flags and a derived-data path belong on the command line, not in `project.yml`. The unit target is `SuspectroundTests`.
