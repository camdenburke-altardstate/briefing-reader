# First build on a Mac: checklist

The Swift in this project has been written and reviewed three times but **never compiled or run**. This is the
order to find out, cheapest checks first. Tick as you go. If something fails, the "If it fails" column says what
to try, and the last section says exactly what to send back.

**No Mac yet?** `docs/CLOUD-BUILD.md` compiles the app and runs the unit tests on a cloud Mac, which covers
steps 1 and 2 below. Steps 3 onward still need a Mac and an iPad.

## 0. Before you start (10 minutes)

- [ ] A Mac on macOS 13 or newer with **Xcode 15 or newer** installed and opened once (accept the license).
- [ ] **XcodeGen**: `brew install xcodegen` (or build the project by hand, see step 2).
- [ ] The **project folder** on the Mac: unzip `iPadReader.zip`.
- [ ] One **iPad** (a spare, not an executive's) and its USB cable.
- [ ] A **paid Apple Developer Program** account. A free account is fine for steps 1 to 5 only, because its builds
      expire after 7 days. You need the paid one for the Ad Hoc builds in step 7.
- [ ] A USB flash drive with some PDFs, and a photo or two on it, for step 6.
- [ ] Refresh the sample content so the "today" meeting is dated today: on any PC, run
      `python tools/make_sample_decks.py`, then recopy `SampleDecks/`.

## 1. Generate and open the project (5 minutes)

```
cd iPadReader
xcodegen generate
open BriefingReader.xcodeproj
```

- [ ] Xcode opens it with a single target, **BriefingReader**, iPad only, iOS 16.0.
- [ ] Target > Signing & Capabilities: pick your team. The bundle id is `com.altardstate.briefingreader`. If you
      change it, change `BundleIdentifier` in `Profiles/BriefingReader-Kiosk.mobileconfig` to match.

| If it fails | Try |
|---|---|
| `xcodegen` not found | `brew install xcodegen`, or in Xcode create a new iOS App (SwiftUI, iPad only) named BriefingReader and drag the three folders under `BriefingReader/` in. Copy the Info.plist keys from `project.yml`. |
| "No such module" for a framework | The project uses only Apple frameworks (SwiftUI, PDFKit, PencilKit, AVKit, AVFoundation, ImageIO, CryptoKit, UniformTypeIdentifiers). Make sure the deployment target is iOS 16 and Xcode is 15 or newer. |
| The asset catalog warns about the app icon | Normal if the icon is missing. The placeholder is in `Assets.xcassets/AppIcon.appiconset`. |

## 2. Make it compile (the main event)

Press **Product > Build** (Cmd B) with an iPad simulator selected.

- [ ] **Zero errors.** Warnings are expected (see below).
- [ ] **Run the unit tests** (Cmd U). They check the agenda times, NOW and NEXT, meeting order, file naming, meeting.json
      and the PIN. If they all pass, that logic is right before any device testing. A failing test names the rule that broke.

Expect a handful of fixes at most. These are the places most likely to need one, from the reviews:

| Symptom | Likely cause and fix |
|---|---|
| "Call to main actor-isolated ... in a synchronous nonisolated context" in `ReaderView.swift` | Add `@MainActor` in front of `final class Coordinator` (inside `PDFKitView`). |
| "'nonisolated' ... can not be applied" or similar in `LibraryStore.swift` | The file-scope `ignoredMeetingFolders` and the `private nonisolated static func` helpers are the suspects. Move the helpers to a small `enum` with plain `static` functions. |
| "Unable to type-check this expression in reasonable time" | Break the expression into two lines. |
| A PencilKit or PDFKit method "has no member" | Check the exact signature in Xcode's autocomplete and adjust; PDFKit's page overlay provider is iOS 16 only. |
| "Reference to property in closure requires explicit use of 'self'" | Add `self.` or `[self] in`. |

Deprecation warnings (`UIScreen.main`, `AVAsset.duration`, `copyCGImage`) are known and safe to ignore.

- [ ] **Run in the simulator** (Cmd R). The library appears with the Altar'd State wordmark and an empty-state "Add files" button.

## 3. Load the samples in the simulator (5 minutes)

```
bash tools/load-samples-simulator.sh
```

(Run the app once first so it is installed.) Within 15 seconds the library should show the sample meetings.

- [ ] Weekly Leadership Sync with an agenda; NOW and NEXT highlighted.
- [ ] Board Meeting with a CONFIDENTIAL tag; the Annual Report in the loose library.
- [ ] Covers appear for PDFs, photos and the video.

## 4. The reading checks, in the simulator (20 minutes)

Rotate with Cmd Left or Right Arrow.

- [ ] Open the **Q4 Board Book** in landscape: a **two-page spread** with the cover alone first. Footer reads
      "Pages x-y of 31".
- [ ] Rotate to portrait: one page, same page number. Rotate back.
- [ ] Tap the right and left **edges**: pages turn. Tap the **middle**: the bar appears. Turn a page: it hides.
- [ ] **Contents**, **search**, **bookmark** (ribbon appears), **scrubber** (preview and chapter name).
- [ ] Open the **Annual Report** (320 pages), scrub to page 213, release. It lands on 213, and reopening resumes there.
- [ ] A slide deck stays one page in landscape.
- [ ] Open a photo (swipe, pinch, double-tap), the video (plays, resumes), notes (type, Add time).
- [ ] The library magnifier searches every document.
- [ ] Manage > Choose files works with files from the simulator's Files app. (A USB drive cannot be tested here.)

| If it fails | Fallback |
|---|---|
| The two-page spread looks wrong, or paging is odd | Set `ReaderLayout.useSpreads = false` in `Branding.swift`. One page everywhere. |
| Page turns by tap do nothing | In `ReaderView.swift`, `LockedPDFView.handleTap`: log whether `canGoToNextPage` is true. |
| A deep page does not resume | The jump happens in `LockedPDFView.layoutSubviews`; check `initialPage` is set. |

## 5. On the real iPad (the checks the simulator cannot do)

Plug the iPad in, choose it as the run destination, run. Trust the developer profile on the iPad if asked
(Settings > General > VPN & Device Management).

- [ ] **Pencil writing** (needs an Apple Pencil): pencil button in the bar, write, **Done writing**.
  - [ ] Ink appears under the Pencil. A finger still turns pages.
  - [ ] **Zoom in and out: the ink stays glued to the page.** This is the biggest unknown.
  - [ ] Turn away and back, close and reopen: the ink is still there.
  - [ ] Try it in the landscape spread.
  - [ ] In Xcode's console, in a debug build, you should see "markup layer requested for page N". If it never
        prints, PDFKit is not asking for overlays in page-turning mode.
- [ ] **USB drive:** plug in the flash drive, Manage > Choose files. The drive appears and the files copy.
- [ ] **Wipe:** Manage > Clear everything. The library is empty, and a quick look at the Files app (not available
      later in kiosk mode) shows no leftovers.
- [ ] **Battery:** leave a deck open, screen on, for an hour; note the drop.

| If it fails | Fallback |
|---|---|
| Pencil layers never appear, or ink drifts when zoomed | In `Branding.swift` set `Features.pencilMarkup = false`. If you still want it, try dropping `usePageViewController(true)` in `ReaderView.swift` and let the tap zones do the paging. |
| The palette does not show | Focus handling is in `Coordinator.focus`; check it runs after the layer is on screen. |
| The USB drive is not in the chooser | Try a different drive or adapter; format as exFAT or FAT32. |

## 6. Kiosk lock (needs a supervised iPad, which wipes it)

Only do this once steps 1 to 5 pass. It erases the iPad.

- [ ] Apple Configurator: **Prepare > Manual > Supervise**, no MDM.
- [ ] Install the app (step 7 gives the Ad Hoc file), then add `Profiles/BriefingReader-Kiosk.mobileconfig`.
- [ ] Open the app: it locks itself. Run the kiosk table in `docs/DEPLOYMENT.md` section 8 (no Home gesture, no
      Control Center, screenshots blocked, and so on).
- [ ] Check Manage > Choose files still works inside the lock (it is system UI), and that the PIN gate holds.

| If it fails | Try |
|---|---|
| The lock never engages | The iPad is not supervised, the profile is not installed, or the bundle id in the profile does not match the app exactly. |
| You cannot get out for servicing | Apple Configurator: remove the profile, or Prepare again. |

## 7. Ad Hoc build for all four iPads

- [ ] Register the four iPads' UDIDs in the developer portal and make an **Ad Hoc** provisioning profile.
- [ ] Product > Archive > Distribute App > Ad Hoc. You get `BriefingReader.ipa`.
- [ ] Apple Configurator: Add > Apps for each iPad. Put the renewal date (one year) on a calendar.

## 8. Before handing over

- [ ] Delete the sample content from every iPad (Manage > Clear everything).
- [ ] Load the real first meeting from a USB drive using `docs/ASSISTANT-GUIDE.md`, and open every document once.
- [ ] Set the PIN in Manage and write it down for IT.
- [ ] Replace the placeholder app icon if Marketing supplies one, and have them confirm the logo and colors.

## What to send back if something fails

So it can be fixed quickly, send:

1. The **exact text of each Xcode error** (Issue navigator, copy the messages, with the file and line).
2. For a runtime problem: what you tapped, what you expected, what happened, and the **console output**.
3. For a device-only problem: the iPad model and iPadOS version.
4. A phone photo of the screen if the layout looks wrong.

Paste them into the chat, and fixes can be applied to the project and a new zip made.
