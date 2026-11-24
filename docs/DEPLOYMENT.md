# Deployment runbook

Do steps 1 to 3 once. Steps 4 to 8 are repeated for each of the 4 iPads.

## 1. Build the app (Mac)

1. Copy the `iPadReader` folder (or the zip) to the Mac.
2. Install XcodeGen once: `brew install xcodegen`
3. In the folder: `xcodegen generate`, then open `BriefingReader.xcodeproj`.
   (No XcodeGen? Create a new iOS App project named BriefingReader in Xcode, interface SwiftUI,
   iPad only, then drag the three folders under `BriefingReader/` in and copy the Info.plist keys
   from `project.yml`.)
4. Target > Signing & Capabilities: choose your paid team. If `com.altardstate.briefingreader` is
   taken or you want a different id, change it in `project.yml` AND in the profile's
   `BundleIdentifier` (they must match exactly).
5. The app icon is a placeholder made from the real wordmark (see Branding in the README). If
   Marketing has an official app icon, replace `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
   with a 1024x1024 PNG (no transparency).
6. Run it in an iPad simulator first (press Run in Xcode once so the app installs), then in the project
   folder run `bash tools/load-samples-simulator.sh` to put the four sample decks in the app.
   Check the grid, covers, page flipping, zoom, slider, link taps, and that the Contents button
   shows for the board book and the Store Performance deck but NOT for the Holiday Plan deck.
   Also open the one page brief (no slider) and, if you ran `make_sample_decks.py --stress 60`, the
   stress deck (swipe smoothly through 60 big pages).

## 2. Register the iPads and export an Ad Hoc build

1. Get each iPad's UDID (Finder: click the device, click the serial number line until UDID shows).
2. developer.apple.com > Certificates, Identifiers & Profiles: register the 4 devices, then create an
   **Ad Hoc** provisioning profile for the app id including all 4.
3. Xcode: Product > Archive, then Distribute App > Ad Hoc > export. You get `BriefingReader.ipa`.

Ad Hoc builds last a year. Put the renewal date on a calendar.

## 3. Prepare the content (Windows, offline)

1. Put the material in a folder. Files directly in it are the loose "Library". Each sub-folder is a
   meeting, and the folder name is the meeting name.
2. Run `tools\Prep-Content.ps1 -Source "<that folder>" -Destination "<ready folder>" -MeetingTemplates`.
   It copies PDFs, photos, MP4/MOV/M4V video and MP3/M4A/WAV audio after checking them (password
   protected or fake PDFs, video the iPad cannot play), converts PowerPoint, Word and Excel to PDF
   using the Office on that PC, lists anything it could not use with how to convert it, and writes a
   starter `meeting.json` in each meeting folder. Nothing in the source folder is changed.
   - PowerPoint conversion drops animations and embedded video. Send videos as separate MP4 files.
   - iPads play H.264 or HEVC video in MP4, MOV or M4V. For MKV, AVI, WMV or WEBM the tool prints the
     ffmpeg command to convert.
3. Open each `meeting.json` and fill in the date (`yyyy-MM-dd`), start times, presenters, and delete
   the agenda lines you do not want. Every field is optional; see the README for the format.
4. Name each file the way the executive should see it: the file name is the title shown in the grid.
5. 100MB+ PDFs and large photos are fine. Videos take space: the tool prints the total size, and each
   iPad needs that much free.
6. `tools\Check-Decks.ps1` is a lighter check for PDFs only.

## 4. Wipe and supervise each iPad (Apple Configurator, Mac)

1. Connect the iPad by USB. Select it, then Actions > Prepare.
2. Manual configuration. Tick **Supervise devices**. Do not enroll in MDM (unless Infosys already
   has the iPads in one, in which case stop and talk to them first, because MDM and this profile
   would both manage the device).
3. Set an organization name. Skip all the Setup Assistant panes.
4. Let it erase and restart. Supervision is what allows the lockdown to work.

## 5. Install the app and the profile

1. With the iPad selected: Add > Apps > Choose from my Mac > `BriefingReader.ipa`.
2. Add > Profiles > `Profiles/BriefingReader-Kiosk.mobileconfig`.
   Because the profile blocks app installs and profile changes, anything you still need to do
   (steps 6 and 7) is easier done first. If you want to keep the option to change things later,
   remove `allowAppInstallation` and `allowUIConfigurationProfileInstallation` from the profile for
   now, and add them back once the iPads are final.

## 6. iPad settings no profile covers

Do these by hand on each iPad before handing over:

- Update to the latest iPadOS now (the profile defers updates for 90 days afterwards).
- Wi-Fi: leave on if decks will be updated over the network, otherwise turn Wi-Fi and Bluetooth off.
- Display & Brightness: set Auto-Lock (suggest 15 minutes) and a comfortable brightness.
- Remove widgets and extra pages from the Home Screen (they are unreachable once locked anyway).
- Decide on a passcode. A passcode means a lost iPad does not leak board material. No passcode means
  nothing to type when the iPad wakes. Recommended: a passcode, held by IT.
- Turn on Find My iPad (needs an Apple ID that IT controls; do not use a personal one).

## 7. Load the content

There are two ways. Day to day, the first is the one to use.

**A. In the app, from a USB drive or SD card (no Mac, no technical knowledge).** Follow
`docs/ASSISTANT-GUIDE.md`: plug in the drive, tap **Manage**, **Choose a folder** or **Choose files**. Hand
that guide to whoever prepares the iPads. Afterwards, **Manage > Clear everything for the next meeting**
empties the iPad. Set a PIN in Manage if you want only that person to be able to do this.

**B. From a Mac with Finder (IT).** Select the iPad > **Files** tab, expand **Briefings**, and drag the contents
of the ready folder in (meeting folders and loose files). To update later, drag new files in and delete the old
ones. The library refreshes within 15 seconds. Do not name a meeting folder "Notes" or "Inbox": those are ignored.

Meeting notes the executives type are saved on the iPad in the **Notes** folder (one text file per meeting).
IT can copy them off through Finder. **Clearing everything deletes them too**, so copy off any that are needed
first. Tell executives that notes are retrievable and that clearing removes them.

## 8. Lock and verify

Open the app. On first launch it requests Single App Mode. Then run this checklist:

| Check | Expected |
|---|---|
| Swipe up from the bottom / press Home | Nothing happens, app stays |
| Swipe down from top right | No Control Center |
| Swipe down from top left | No Notification Center, no banners |
| Try the App Switcher gesture | Nothing happens |
| Press the power button, wake again | Back in the app (passcode if set) |
| Long-press and double-tap-drag text on a page | No Copy / Look Up / Share menu |
| Take a screenshot (power + volume) | Blocked |
| Open the biggest deck | First page in a few seconds, swipe is smooth |
| Open any deck | Goes straight to the page, no bar showing. Footer reads "Page N of M" with the clock and battery |
| Tap the right edge, then the left edge | Next page, then previous page |
| Swipe left and right | Pages slide |
| Tap the middle | Bar appears (back, contents, search, bookmark, notes, sun). Turn a page: bar hides |
| Zoom in with a pinch, then tap near the edge | Does NOT turn the page; it just shows the bar |
| Tap a table-of-contents link inside a page | Jumps to the page |
| Contents button (decks with bookmarks only) | List appears, tapping a row jumps there. Absent for decks with no bookmarks |
| Bookmark button on a page, turn away, open Contents | Ribbon shows on that page, and it is listed under Bookmarks |
| Search a word that appears in the deck | Results list pages with a snippet; tapping one jumps there and highlights it |
| Pencil button, write on a page with the Pencil, tap Done writing | Ink appears where drawn, the bar does not pop up while writing; a finger still turns pages and zooms; a resting palm does nothing |
| Write, then rotate the iPad right away | Nothing written is lost |
| iPad in Dark Mode | Black ink is still black on the page |
| Zoom in after writing, then back out | The handwriting stays glued to the same spot on the page |
| Turn away and back, then close and reopen the document | Handwriting is still there, and only on its own page |
| Write in the landscape two-page spread | Both pages accept writing; it survives rotating to portrait |
| Remove the meeting, then add it again | The handwriting is gone (no ghost ink on the new copy) |
| Library magnifier: search a word that is in two different documents | Results appear grouped by document as the search runs; tapping one opens that document on that page |
| Drag the scrubber | A picture of the page and its chapter appear above it; the page jumps on release |
| Sun button: brightness, then White / Warm / Night | Screen dims; page tone changes; Night inverts the page |
| Open a photo, swipe, pinch, double-tap | Moves between the meeting's photos, zooms, zooms out |
| Open a large photo (20+ megapixels) | Appears quickly, no memory crash |
| Play a video; leave and reopen | Plays with sound, no picture-in-picture; resumes near where it stopped |
| Open Notes, type, tap Add time, Done; reopen | Text and time stamp are there; file appears in Finder under Notes |
| Meeting dated today with times | NOW and NEXT follow the iPad clock; tapping a line opens its file |
| Meeting marked confidential | CONFIDENTIAL tag shows on the meeting |
| Library after reading | Continue row shows the last thing opened with a progress bar |
| Quit and reopen from the library | Library shows "Page N", reopens at that page |
| Rotate the iPad | Page refits, zoom still works |
| Long report: drag the slider end to end | Caption shows "Page N, section name"; page stays put until release, then jumps once |
| Long report: Contents, tap "Section 8.6.3" | Lands on page 297 |
| Long report: go to page 250, tap Library, reopen | Opens on page 250, library says "Page 250" |
| Long report: go to page 250, press the power button to sleep, wake | Still on page 250 |
| Long report: force-quit is not possible in kiosk mode, so instead leave it on page 250, restart the iPad | Reopens on page 250 (position survived) |
| Long report: swipe quickly through 30 pages | No stall, no blank pages, no crash |
| Stress deck (`make_sample_decks.py --stress 60`): swipe, zoom 4x, scrub | No memory crash, pages draw within about a second |
| Library with a 100MB+ deck: close and reopen the app | Library appears quickly (page counts are remembered) |
| Add a new PDF in Finder with the app open | Appears within 15 seconds |
| Manage > Choose files, with a USB drive plugged in | The drive appears in the chooser; pick files; it asks which meeting; they are added and open |
| Manage > Choose a folder (a prepared meeting folder with meeting.json) | Appears as a meeting with its agenda; the USB drive's own files are unchanged |
| Add a PowerPoint file | Declined with "save as PDF first"; nothing broken is added |
| Unplug the drive in the middle of copying a big video | Says "could not be copied"; the library is not left with a broken item |
| Manage > Remove one meeting | Asks "Are you sure?", then it and its notes are gone |
| Manage > Clear everything for the next meeting | Asks "Are you sure?", then the iPad is empty; the Notes folder, reading positions and covers are gone too |
| Set a PIN, close Manage, open it again | Asks for the PIN; a wrong PIN is refused |
| Landscape, open a portrait-page report | Two-page spread with a spine shadow, cover alone, footer "Pages x-y of N"; swipe moves a whole spread |
| Rotate to portrait and back while reading | One page, then the spread again, on the same page |
| Landscape library with a meeting that has an agenda | Agenda on the left, materials beside it; portrait stacks them |
| Leave the battery test running (screen on, flipping) for 1 hour | Note the drop for the hand-off notes |

If Single App Mode does not engage, the usual causes are: iPad not supervised, profile not
installed, or the bundle id in the profile does not match the app exactly.

## Getting out (IT only)

To service an iPad: connect it to the Mac with Apple Configurator, remove the profile
(Profiles tab), or re-run Prepare. Keep this paragraph with IT, not with the executives.

## Known limits and things I could not verify

- File sharing is on (`UIFileSharingEnabled`) so IT can load and retrieve files with Finder. That makes the app's
  whole Documents folder, including typed notes and Pencil handwriting, readable by anyone who can unlock the
  iPad and trust a Mac. Set a passcode, and turn on the Data Protection capability (Complete) in Xcode so files
  are unreadable while the iPad is locked. See `docs/ACTION-PLAN.md`. No formal security review has been run.

- Pencil handwriting is the most device-dependent feature. It relies on PDFKit's page overlay views scaling
  with the page when zooming, working with the page-turning controller and the two-page spread. If it
  misbehaves, set `Features.pencilMarkup` to `false` in `Branding.swift` to remove it cleanly.

- The in-app file chooser, reading a USB drive in Single App Mode, and the wipe have not been run on a real
  iPad. The chooser is part of iPadOS, not this app: it can show other locations and its own menus. It is only
  reachable through Manage, so set a PIN if executives could wander into it.
- The two-page spread relies on PDFKit's paging in `twoUp` mode. If it misbehaves, set `ReaderLayout.useSpreads`
  to `false` in `Branding.swift` (one page everywhere).

- Long document behavior (scrubbing, resume at a deep page, memory on 100MB+ files) is designed
  and reviewed, and checked in a browser mockup, but not on an iPad. The resume-at-a-deep-page fix in
  particular depends on how PDFKit behaves at first layout, so test it on a real device.

- The code has not been compiled. Expect small fixes on first build.
- Hiding the text-selection menu relies on PDFKit's internal views, and may change with iPadOS
  versions. Check the long-press row of the checklist after every iPadOS update.
- Restriction keys in the profile are supervised-only and are checked by the iPad, not by this
  project. If Configurator rejects one, delete it. Apple Configurator's own Restrictions editor lists
  the same settings with descriptions.
- Single App Mode keeps the app up but does not stop someone with physical access wiping the iPad
  through recovery mode. That is a separate, physical-security concern.

## Ideas for later

- Bookmarks and a "Recently added" marker
- Branding: logo on the library screen and app icon
- MDM-based installs and updates instead of USB, if the iPads multiply
