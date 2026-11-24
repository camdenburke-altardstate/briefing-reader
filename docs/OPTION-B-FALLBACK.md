# Fallback: if the custom app is not ready in time

The original plan (`Ipad Deck Solution - Save Paper.md`) says: if the turnaround is under 24 hours, use an
off-the-shelf reader locked with Single App Mode. This is that fallback, so it exists before it is needed.
It needs the same Mac and Apple Configurator, but **no Xcode build and no developer account**.

## What you give up

| Custom Briefing Reader | Fallback |
|---|---|
| Altar'd State library, agendas, NOW and NEXT, confidential tag | A plain list of files |
| Books and Kindle feel, two-page spreads | The reader's own screens, with its menus |
| Photos, video, notes, search across all documents, Pencil markup | Whatever the chosen app offers |
| Load and clear from a USB drive, with no technical knowledge | Files are copied from the Mac with Finder or Apple Configurator |

## Pick one (all work offline)

| App | Notes |
|---|---|
| **Apple Books** | Already on the iPad. Fastest. PDFs open well. The menu buttons (bookmarks, search, back) cannot be hidden. |
| **Files** (the Files app) | Also built in. Shows the iOS file browser sidebar. |
| **PDF Expert or Adobe Acrobat** | Better reading and annotation. They need to be installed, which may need an Apple ID or Apple Business Manager. |
| **Kiosk Pro Lite** | Made for locked displays. Hides more of the interface. Check it is still on the App Store and what it costs. |

Test the one you choose on a spare iPad before any executive sees it: open the biggest deck, and check that
you can leave the app only through the lock you set up.

## Steps (about an hour for four iPads)

1. **Wipe and supervise** each iPad, exactly as in `docs/DEPLOYMENT.md` section 4.
2. **Install the app** if it is not built in: Apple Configurator, Add > Apps.
3. **Load the PDFs.** Finder > the iPad > Files tab, drag the PDFs onto the app. (Apple Books: drag them
   into Books on the Mac and sync, or use AirDrop before supervising.)
4. **Lock to the one app.** Create a profile with the **Single App Mode** (also called App Lock) setting for
   that app's bundle id, in Apple Configurator: File > New Profile, then Add > Profiles on each iPad.
   - Apple Books is `com.apple.iBooks`. Files is `com.apple.DocumentsApp`. For third-party apps, find the bundle
     id in Apple Configurator's app list.
   - The wording and layout of that payload differ between Apple Configurator versions, so check it in your
     version. It only works on supervised iPads.
5. **Apply the same restrictions** as the custom app, by copying the restrictions block from
   `Profiles/BriefingReader-Kiosk.mobileconfig` into the same profile: no AirDrop, no screenshots, no app
   removal, no erase from the iPad.
6. **Run the lock checks** from `docs/DEPLOYMENT.md` section 8 (Home gesture, Control Center, notifications,
   App Switcher).
7. **Passcode and Find My**, as in section 6.

## Moving to the custom app later

Nothing here blocks it. When the custom app is ready, install it with Apple Configurator and replace the
profile. The PDFs can stay on the iPad until then, and the Manage screen loads everything again anyway.
