# What executives need in a meeting, and what the app does about it

Everything here works with no network. The app has no network code at all.

## Content

| Need | How it is handled | Status |
|---|---|---|
| Decks, board books, reports (PDF) | Native PDFKit reader. Swipe, zoom, contents, search, flagged pages, resume | Built |
| PowerPoint, Word, Excel | Converted to PDF on the PC by `tools\Prep-Content.ps1` (uses the Office on that PC). Animations and embedded video do not survive; export those separately | Built (prep step) |
| Images: store photos, lookbooks, floor plans, charts, screenshots | Image viewer: swipe through a folder's images, pinch and double-tap zoom, large photos downsampled so memory stays safe | Built |
| Video: campaign films, store walkthroughs, training | Native player (H.264 or HEVC in MP4 / MOV / M4V), remembers where you stopped, no picture-in-picture | Built |
| Audio: recorded briefings | Same player (MP3 / M4A / WAV) | Built |
| Live dashboards, web pages, links | Cannot work offline. Capture as PDF or image before the meeting | By design |
| Interactive spreadsheets | Not editable. Export the view you need as PDF | By design |

## The meeting itself

| Need | How it is handled | Status |
|---|---|---|
| Group materials by meeting | A folder per meeting. Folder name is the meeting name | Built |
| Agenda with times and presenters | Optional `meeting.json` in the folder. Each agenda line can open its document with one tap. On the day, "NOW" and "NEXT" are highlighted from the iPad clock | Built |
| Upcoming meetings first | Folders sort by date: today and future first (soonest first), then past (newest first), then undated, then loose files | Built |
| Confidential marking | `"confidential": true` in `meeting.json` shows a CONFIDENTIAL tag | Built |
| Take notes | Typed notes per meeting, saved on the iPad as a text file, with an "Add time" button. Reachable from the library and from inside any document | Built |
| Find something fast | Search inside a PDF with results listed by page and a highlighted jump | Built |
| Find a figure when you do not know which document | **Search all documents** (magnifier on the library): text inside every PDF plus the names of photos and videos, grouped by document, opens on the page | Built |
| Mark pages to come back to | Flag button. Flagged pages are listed in Contents | Built |
| Handwrite notes on a page | Apple Pencil writing mode on PDFs: pens, highlighter, eraser, saved beside the document and cleared with the meeting | Built, needs a device test |
| Know the time and battery (status bar is hidden in kiosk mode) | Clock and battery % in every screen | Built |
| Dim for a dark room, brighten for daylight | Brightness control in every screen (Control Center is unavailable in kiosk mode) | Built |
| Pick up where you left off | Last page, video position, flags are remembered | Built |

## Getting content on and off the iPad, offline and non-technical

| Need | How it is handled | Status |
|---|---|---|
| Load the day before without IT | **Manage > Choose files or Choose a folder** from a USB drive or SD card; pick which meeting; see `docs/ASSISTANT-GUIDE.md` | Built, needs a device test |
| A prepared folder with its agenda | Choose the folder; its `meeting.json` comes with it | Built |
| Wipe between meetings in one step | **Clear everything for the next meeting**, with a confirmation; also removes notes, reading positions and cover pictures | Built |
| Remove one meeting, or all finished ones | **Remove**, **Remove finished meetings** | Built |
| Only the right person can add or wipe | Optional PIN on Manage | Built |
| Know there is room | **Free space** shown | Built |
| Over the air (AirDrop, cloud) | Blocked on purpose: no network and no AirDrop | By design |

## Presenting to a room

| Need | Notes | Status |
|---|---|---|
| Show on a TV or projector with a cable | USB-C or Lightning to HDMI adapter. iPadOS mirrors automatically. Works in kiosk mode | Works (system), verify with your adapter |
| Wireless (AirPlay) mirroring | Starting it needs Control Center, which kiosk mode blocks. Video playback can use the AirPlay button in the player. Full mirroring wirelessly would need a different lockdown choice | Limit, decide with IT |

## Not built yet (and why)

| Need | Why not yet |
|---|---|
| Speaker timer / countdown | The clock and NOW/NEXT cover most of it |
| Attendee bios and contacts | Put them in a PDF or image for now |
| Syncing new material without a cable | Needs MDM or a server, which breaks "no network". Today: Finder file sharing |

## Safety around all of the above

- Screenshots, AirDrop, and iCloud document sync are blocked by the profile.
- Notes are plain text files in the app's Documents folder, visible to IT through Finder file sharing.
  Wiping the iPad deletes them. Tell executives that notes are retrievable by IT.
- Set a passcode. Everything on the iPad is encrypted when it is locked, but only if a passcode exists.
