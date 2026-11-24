# Briefing Reader

A locked-down, offline reading and meeting app for the four executive iPads: board books, decks,
photos, video and meeting agendas, in a Books/Kindle style. Built from the plan in
`Ipad Deck Solution - Save Paper.md` (Option A: custom SwiftUI app on native PDFKit and AVKit).

## What the app does

- **Library screen:** the Altar'd State wordmark, a Continue row, then your meetings (each folder
  is a meeting, with its agenda) and loose files, as a grid of covers with title, length and progress.
- **Reader:** see "Reads like Books or Kindle" below.
- **Photos and video:** swipe through photos with zoom; play video and audio from the iPad itself.
- **Search everything:** the magnifier on the library searches inside every PDF (and the names of photos
  and videos) at once, grouped by document, and opens a result on its page. Offline. Searching a very large
  library takes a moment, so it shows what it has found as it goes and stops at 200 matches.
- **Remembers where you were** in every document and video. A replaced file starts over.
- **No exits:** no settings screen, no share or copy menu, no address bar. The kiosk profile locks
  the iPad to the app (no Home gesture, App Switcher, Control Center or notifications).
- **Big files:** covers are rendered one at a time and cached to disk; pages are rendered by PDFKit
  on demand, so 100MB+ board books are not loaded into memory whole; photos are decoded at screen size.
- **Loading and clearing, no technical knowledge:** a **Manage** screen lets an assistant pick files or a
  folder from a USB drive or SD card, say which meeting they belong to, and later clear everything in one
  step. See `docs/ASSISTANT-GUIDE.md`. IT can still drag files in with Finder; the app notices within 15 seconds.
- **Offline:** the app has no network code.

No third-party packages. The three open-source wrappers listed in the plan's Research section add
nothing that PDFKit does not already do, and each one is a dependency to vet on a device that holds
board material.

## Branding

Open `Brand/ui-preview.html` in a browser to see the screens (a static mockup, sample titles only).

- **Logo:** the real Altar'd State wordmark, copied from the asset hub's brand folder
  (`logo-charcoal.png` for the library header and launch screen). Originals are in `Brand/`.
- **Color:** charcoal `#363636` (the wordmark color) on white, warm gray backdrop behind pages,
  hairline borders. The app is forced to light mode. The burgundy on altardstate.com is a seasonal
  banner, so it is not used.
- **Type:** Avenir (light, book, medium), the face altardstate.com lists in its font stack. It ships
  with iPadOS, so nothing is bundled. The site's headline font (Trenda) is licensed and not used.
  The section label echoes the wordmark's wide letter-spacing.
- **One file to restyle:** `BriefingReader/App/Branding.swift` (colors, fonts, titles).
- **App icon is a placeholder:** the wordmark split into two lines, white on charcoal. It is built from
  the real logo, but it is not an official icon. If Marketing has one, drop it in as described in the
  runbook (step 1.5). Have Marketing confirm the logo use and colors before the iPads go to leadership.
- Not verified: the preview is a browser mockup, so Avenir spacing, the real launch screen and the
  icon's rounded-corner crop will only be confirmed on an iPad.

## Reads like Books or Kindle

The PDF reader is built to feel like an e-reader, not a file viewer:

- Opens straight onto the page. No toolbars until you ask.
- **Tap the left or right edge** to turn the page (the outer fifth of the screen), **swipe** to turn,
  **tap the middle** for the bar. When zoomed in, taps just show the bar. Turning a page hides the bar again.
- A quiet footer outside the page: "Page 12 of 96 · 12%", with the clock and battery.
- A **bookmark ribbon** in the corner of any bookmarked page; bookmarks are listed with the contents.
- **Contents**, **search** (results by page with a highlighted jump) and a **scrubber that previews the
  page** under your finger and names the chapter.
- **Paper tones** like the reading themes in Books: White, Warm, Night (from the sun button, which also
  sets brightness, since Control Center is unavailable in kiosk mode).
- The library has a **Continue** row, progress bars under covers, and NEW tags.
- Page changes slide. A page-curl animation is not included: PDFKit's own paging does not offer it.

## Writing with Apple Pencil

The pencil button in the reader bar starts **writing mode**: the bar goes away, the Pencil's tool palette
(pens, highlighter, eraser, undo) appears, and Pencil strokes land on the page. A finger still turns pages
and zooms. **Done writing** (top right) saves it.

- Handwriting is kept **beside** the PDF, never inside it: the PDF is not changed. One drawing per page,
  stored on the iPad in `Annotations/<meeting>/`.
- If a deck is replaced with a newer version, the old handwriting is not shown on the new content.
- **Removing a meeting, or clearing the iPad, deletes its handwriting too.**
- Needs an Apple Pencil: only the Pencil writes, so a finger keeps turning pages and zooming while you write.
- One switch, `Features.pencilMarkup` in `Branding.swift`, hides the button and turns the whole feature off.
- IT can copy the handwriting files off through Finder, but they are PencilKit data, not an annotated PDF.
  An "annotated copy" export is not built.
- **Not verified on a device.** The risky parts are whether the strokes stay aligned with the page when you
  zoom, and how the layers behave in the two-page spread. See the QA table in `docs/DEPLOYMENT.md`.

## Looks by orientation

The layout follows how the iPad is held, borrowing from Books (Apple) and Kindle:

| | Landscape | Portrait |
|---|---|---|
| **PDF with portrait-shaped pages** (reports, board books) | **Two-page spread** like an open book, soft shadow down the spine, cover alone on the right, footer "Pages 8-9 of 31". Turning moves a whole spread (Books) | **One page** filling the width, footer "Page 8 of 31" (Kindle) |
| **Slide decks** (wide pages) | One slide filling the screen (Kindle) | One slide, centered, with the page tone around it |
| **Reader bar** | Icons with the title in the middle | Icons only, no title, so it never feels crowded (Kindle) |
| **Library** | Each meeting's **agenda on the left, materials beside it**, four columns for plain shelves | Agenda above, materials in three columns, smaller wordmark |
| **Photos and video** | Full screen, dark | Full screen, dark |

Rotating the iPad while reading keeps the same page. If PDFKit's two-page paging misbehaves on a device,
set `ReaderLayout.useSpreads = false` in `Branding.swift` for one page everywhere.

## Everything for a meeting, offline

See `docs/MEETING-NEEDS.md` for the full needs map. In short: PDFs, **photos** (swipe, pinch, double-tap
zoom), **video and audio** (remembers where you stopped), a **folder per meeting** with an optional
`meeting.json` agenda (tap an agenda line to open its file, NOW and NEXT follow the clock, a CONFIDENTIAL
tag), **typed notes per meeting**, and a clock, battery and brightness control on every screen.

Meeting folder example (drag the whole folder into Finder > iPad > Files > Briefings):

```
Board Meeting Dec 8/
  meeting.json              (optional agenda, see below)
  Q4 Board Book.pdf
  Flagship Floor Plan.jpg
  Store Walkthrough.mp4
```

```json
{ "title": "Board Meeting", "date": "2026-12-08", "time": "9:00 AM", "location": "Boardroom",
  "confidential": true, "note": "Read the board book first",
  "agenda": [ { "time": "9:15 AM", "title": "Q4 results", "presenter": "Finance", "file": "Q4 Board Book.pdf" } ] }
```

Every field is optional. `tools\Prep-Content.ps1` converts PowerPoint, Word and Excel to PDF on this PC,
checks videos and images, and writes a starter `meeting.json` for you to fill in.

## Loading and clearing content (Manage)

Built so a non-technical person can do it, offline:

- **Manage** (top right of the library): **Choose files** or **Choose a folder**, using the iPad's own file
  chooser, which shows a USB flash drive, an SD card reader, or the iPad. Files are copied onto the iPad;
  the original on the drive is never moved or changed.
- After choosing files it asks **which meeting**: a new one (name, optional date, confidential), one already
  there, or none. Choosing a prepared folder brings its `meeting.json` agenda with it.
- Unsupported files (PowerPoint, Word) are declined with a plain explanation: save them as PDF first.
- **Remove** a single meeting, **Remove finished meetings** (dated before today), or **Clear everything for
  the next meeting**. Each asks "Are you sure?". Clearing also removes the typed notes, the saved reading
  positions and the cover pictures, so nothing is left behind.
- Optional **PIN** on the Manage screen so only the person preparing the iPads can add or wipe content.
- **Free space** is shown, and a progress box appears while copying big videos.
- AirDrop is blocked by the profile, so a USB drive or SD card is the offline way in.

Nothing here is verified on a real iPad yet: the file chooser, reading a USB drive and the wipe all need a
device test (see the QA table in `docs/DEPLOYMENT.md`).

## Long documents (hundreds of pages)

Built for this, and checked against the 320 page sample:

- **Scrubbing:** dragging the page slider only names where the finger is ("Page 213 · Chapter 35"). The page
  jumps once, on release, so dragging across 300 pages renders one page, not dozens. (Mockup: 80 slider
  ticks caused 0 renders, release caused 1.)
- **Contents list:** every bookmark level, indented, read off the main thread so a big table of
  contents does not freeze the screen.
- **Resume:** the saved page is applied on the reader's first layout, because PDFKit ignores a jump
  made before the view has a size. Position is saved when the reader closes and when the app goes to
  the background, with writes batched so fast page turning does not hammer storage or redraw screens.
- **Library start-up:** page counts are remembered, so a folder of 100MB+ files is not reopened on every
  refresh.
- **Password-protected files** are skipped, not shown as broken. `tools\Check-Decks.ps1` warns about them.

Verified only in the browser mockup (pdf.js, not PDFKit) plus a read-through of the Swift. On an iPad,
confirm with the QA rows for the long report and the stress deck in `docs/DEPLOYMENT.md`.

## Sample decks and the iPad mockup

- `SampleDecks/` is made up, and labeled "Sample content, not real data" on every page and picture.
  It is rebuilt from scratch by `python tools/make_sample_decks.py` (do not keep your own files there):
  - `Weekly Leadership Sync/`: dated **today**, so the agenda shows NOW and NEXT following the clock.
    A deck with no bookmarks (the Contents button must NOT appear), a one page brief (no scrubber), an image.
  - `Board Meeting - <date>/`: dated 19 days out, CONFIDENTIAL, an agenda that opens its files, a 31 page
    board book with a clickable contents page, a 16 slide landscape deck, three pictures.
  - Loose in the library: a **320 page annual report** (155 bookmarks in three levels).
  - Video: a 12 second H.264 test clip (in the board meeting, linked from its agenda). It needs ffmpeg to
    generate: `pip install imageio-ffmpeg` (already installed on this PC) or `winget install ffmpeg`.
    Add `--stress 60` for a heavy 60 page, 80MB test deck.
- **Mockup:** double-click `tools\ipad-sim\start-mockup.cmd` to see the screens at iPad size
  (rotate button included) opening those real files: tap zones, bar, scrubber preview, bookmarks, search,
  paper tones, agenda, photos, video, notes. Drop any PDF, photo or video onto the iPad to add it; it stays
  in your browser. It imitates the app's layout and behavior. It is NOT the Swift app running, so it says
  nothing about compiling, PDFKit, AVKit or Single App Mode. Pinch zoom and battery are not in it.
- **Load them on a real iPad:** Finder > iPad > Files > Briefings, drag the whole `SampleDecks` contents in.
- **Load them in the Xcode simulator (Mac):** run the app once, then `bash tools/load-samples-simulator.sh`.
- Delete the samples before handing an iPad over.

## Demo video

`Demo/Briefing-Reader-Demo.mp4` (about 97 seconds, no sound) walks through the screens: both orientations, the
two-page spread, the scrubber, search, Pencil writing, night tone, photos, video, and loading and clearing
content. **It is filmed from the browser mockup with sample content, not from the Swift app on an iPad**, and
the closing card says so. Rebuild it with `python tools/make_demo_video.py` (needs Edge, the mockup server
running, `pip install pillow imageio-ffmpeg`). The scenes live in `tools/ipad-sim/index.html` (`?demo=<name>`).

## Layout

```
project.yml                           XcodeGen definition (generates the Xcode project on a Mac)
BriefingReader/App/                   App entry, kiosk request, Branding.swift (colors, fonts, titles)
BriefingReader/Assets.xcassets/       App icon, wordmark, launch color
Brand/                                Logo originals, placeholder icon, ui-preview.html
BriefingReader/Model/                 Content types, agenda logic, folder scanning, progress, covers, ContentManager (add/remove/wipe/PIN)
BriefingReader/Views/                 Library, PDF reader, photo gallery, media player, notes, Manage screen, clock/battery/display
Profiles/BriefingReader-Kiosk.mobileconfig   Single App Mode + restrictions
tools/Prep-Content.ps1                Windows: Office to PDF, media checks, starter meeting.json (+ office-to-pdf.ps1)
tools/Check-Decks.ps1                 Windows pre-flight check for PDFs only (password, size, names)
tools/make_sample_decks.py            Generates SampleDecks/ (and an optional heavy stress deck)
tools/ipad-sim/                       Browser mockup of the screens at iPad size (start-mockup.cmd)
tools/make_demo_video.py              Films the mockup scenes and builds Demo/Briefing-Reader-Demo.mp4
Demo/                                 The demo video (frames/ holds the captured scenes)
tools/load-samples-simulator.sh       Mac: copies SampleDecks into the booted iPad simulator
SampleDecks/                          Made-up meeting folders, photos and PDFs for testing
docs/DEPLOYMENT.md                    Step by step: build, supervise, install, load content, QA
docs/MEETING-NEEDS.md                 What executives need in a meeting and what is built, not built, and why
docs/ASSISTANT-GUIDE.md               Plain steps for loading a meeting from a USB drive and clearing it afterwards
docs/FIRST-BUILD-CHECKLIST.md          The Mac build and device test, in order, with fallbacks and what to send back
docs/CLOUD-BUILD.md                    Compile and test the Swift on a cloud Mac (GitHub Actions), no Mac of your own
docs/ACTION-PLAN.md                   The original plan's table with real status, plus decisions still open
docs/EXECUTIVE-QUICKSTART.md          One-page guide for the executives (fill in the IT contact)
docs/OPTION-B-FALLBACK.md             Off-the-shelf reader plus Single App Mode, if the app is not ready in time
docs/ipad-register.csv                Blank register: model, iPadOS, serial, UDID, Pencil, profile, expiry
BriefingReaderTests/                  Unit tests for the agenda, naming, meeting.json and PIN logic (Cmd U on a Mac)
Demo/stills/                          Nine cropped screenshots of the mockup, for slides and emails
```

## Status

All source is written but **has not been compiled or run**: this is a Windows PC with no Swift
toolchain, and the kiosk lockdown can only be proven on a real supervised iPad. Expect a small round
of compiler fixes on the first build, then work through the QA checklist in `docs/DEPLOYMENT.md`.

## You need

- A Mac with Xcode 15 or newer (building) and Apple Configurator (supervising and installing).
  Apple Configurator does not exist for Windows.
- A paid Apple Developer Program membership. A free account's builds expire after 7 days, which is
  no good for a kiosk. With the paid program you register the 4 iPads' UDIDs and distribute Ad Hoc.
- The 4 iPads and the final PDF decks.

Start with `docs/FIRST-BUILD-CHECKLIST.md`, then `docs/DEPLOYMENT.md`.
