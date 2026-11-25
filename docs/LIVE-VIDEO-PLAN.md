# Plan: a live-motion video of the app

The current video (`Demo/Briefing-Reader-Walkthrough.mp4`) is built from screenshots, so it shows each screen but no
movement. A live video shows page turns, the rotation, pinch zoom, search typing and loading, at real speed. The cloud
runner cannot record this well (about 6 frames a second, sideways, stalls), so record it on real graphics hardware.

## Pick a route

| Route | Needs | Quality | Effort |
|---|---|---|---|
| **A. Mac and the iPad simulator** | Any Mac with Xcode 15 or newer (no Apple Developer account) | Smooth, real speed. No real Pencil or USB | About 1 hour, including setup |
| **B. A real iPad** | The signed .ipa (needs the Apple Developer account) and one spare iPad | Best: real touch, real Pencil, real speed | About 30 minutes once installed |
| **C. The cloud runner again** | Nothing new | Poor, not recommended | n/a |

Recommendation: **A now** (it does not wait on the Apple account), **B later** for a final version that includes
handwriting and loading from a USB drive.

## Route A: Mac and the simulator

1. On the Mac, unzip `iPadReader.zip` (or clone the private GitHub repository).
2. `brew install xcodegen`, then in the project folder: `xcodegen generate` and `open BriefingReader.xcodeproj`.
3. Choose an **iPad Pro 11-inch** simulator, press Run (Cmd R) once so the app is installed.
4. Refresh the sample content so the weekly meeting is dated today: on any PC run `python tools/make_sample_decks.py`,
   copy `SampleDecks` to the Mac, then `bash tools/load-samples-simulator.sh`.
5. Start the recording, in a Terminal: `xcrun simctl io booted recordVideo --codec=h264 walkthrough.mp4`
   (stop with Ctrl C). Or use QuickTime Player, File, New Screen Recording, and select the simulator window.
6. Either drive it by hand with the shot list below, or let the scripted pass do it:
   `xcodebuild test -project BriefingReader.xcodeproj -scheme BriefingReaderUI -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' -only-testing:BriefingReaderUITests/WalkthroughTests`
   (start the recording first). On a Mac with a real graphics chip the test runs at normal speed. The scripted pass
   already writes its step times to `/tmp/BriefingWalk/markers.txt` for captioning.
7. Rotate the simulator with Cmd Left Arrow and Cmd Right Arrow.

## Route B: a real iPad

1. Install the signed build (see `docs/DEPLOYMENT.md` section 7). Use a spare iPad, **not** a locked-down one: Single App
   Mode blocks Control Center, which is how you start a screen recording.
2. Load the sample decks with the Manage screen from a USB drive. That load is a good scene in itself.
3. Record with Control Center's Screen Recording button, or plug the iPad into a Mac and use QuickTime Player,
   File, New Movie Recording, pick the iPad (cleaner, and no recording indicator in the picture).
4. Use a real Apple Pencil for the handwriting scene.

## Shot list (about 90 seconds)

| # | Seconds | What to do | What it proves |
|---|---|---|---|
| 1 | 8 | Library in landscape. Slowly scroll to the Board Meeting | Agenda with NOW and NEXT, confidential tag |
| 2 | 6 | Tap the Q4 Board Book | Opens like a book, no clutter |
| 3 | 12 | Turn four spreads by tapping the right edge, then swipe once | Two facing pages, quick turns |
| 4 | 8 | Tap the middle, drag the slider, tap Contents, jump to a section | Tools on demand, long-document navigation |
| 5 | 8 | Rotate to portrait, turn a page, rotate back | Same page after rotation |
| 6 | 8 | Pinch to zoom on a chart, pan, pinch out | Zoom, a swipe never turns the page while zoomed |
| 7 | 10 | Open the 320-page report, drag the slider to page 213, reopen it later | Long documents, resumes where you stopped (route B or A) |
| 8 | 8 | Open the photo, pinch; open the video and play a few seconds | Media |
| 9 | 8 | (Route B) Pencil: pen button, write a note on a page, Done writing | Handwriting stays with the page |
| 10 | 10 | Search for a word, tap a result, land on the right page | Search across every document |
| 11 | 10 | Manage: Choose a folder from the USB drive, watch the progress; then Clear everything | The assistant's whole job |

Tips: turn on Do Not Disturb, charge the iPad, use the sample decks only (no real company content on screen), and
keep each action slow and clear, with a one-second pause after each, so captions can sit on top.

## Finishing

- Trim and caption in iMovie, or in any editor. For a consistent look with the existing video, reuse the caption text in
  `tools/make_walkthrough_video.py` (the STEPS table) and the same wordmark and colors.
- A hand recording has no `markers.txt`. A small change to `tools/make_walkthrough_video.py` can take a plain list of
  step start times instead; ask for it when the recording exists.
- Export 1280 by 720 H.264. Expect about 10 MB for 90 seconds.

## What I need from you

1. Which route, and who has the Mac (IT, or a borrowed one)? Route A needs about an hour of someone's time at the Mac.
2. For route B: the Apple Developer account decision and a spare iPad.
3. Whether the video is internal only. If it will be shared outside, Marketing should approve the logo use first.
