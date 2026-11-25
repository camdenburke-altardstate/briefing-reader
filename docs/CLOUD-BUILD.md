# Compile the app in the cloud (no Mac needed)

The Swift in this project has never been compiled. GitHub can do that for you on a Mac in its data center,
for free on a private repository within the monthly free minutes (macOS minutes count more than Linux ones,
roughly ten times, so a 10 to 15 minute run is cheap but not unlimited).

The workflow file is `.github/workflows/build.yml`. On every push it does this:

1. Installs XcodeGen and generates the Xcode project from `project.yml`.
2. Builds the app and the unit tests for an iPad simulator, with signing switched off.
3. Runs the unit tests.
4. Writes the compiler errors, warnings and test results onto the run's summary page, and keeps the full logs
   for 14 days as a download.

A second, fast job runs on Linux and checks that the kiosk profile is valid XML, the Python tools have no
syntax errors, `project.yml` parses, and the documents contain no em dashes.

## Screenshots

After the unit tests, the same run starts the real app in an iPad simulator, loads the sample decks, and a UI test
(`BriefingReaderUITests/ScreenshotTests.swift`) opens the main screens in landscape and portrait: the library, a
two-page board book, a 320-page report, a slide deck, a photo, a video, Manage and Search. It saves 19 pictures.
Find them on the run's page under **Artifacts > screenshots** (a zip, about 7 MB). Sample content is moved to
today's date first (`tools/prepare_screenshot_content.py`) so the NOW and NEXT agenda tags show.

How it gets the sample decks in: debug builds only read a `-seedFrom` folder at launch (`BriefingReader/App/DebugSeed.swift`).
That file is compiled out of Release builds, so the iPad version has no such hook. A problem in this step never fails
the build; you just get fewer pictures. The run takes about 16 minutes.

## Videos and the overview PDF

- `tools/make_slideshow_video.py` builds the captioned walkthrough video from the run's screenshots
  (`Demo/Briefing-Reader-Walkthrough.mp4`). This is the reliable way to get a video.
- A live screen recording is also wired in (`WalkthroughTests`, `tools/make_walkthrough_video.py`), but it only runs when you
  press **Run workflow** by hand. On the cloud runner it came out choppy (about 6 frames a second), sideways, and the test
  stalled, so it is not used. For true motion, screen-record the simulator on a Mac or a real iPad.
- `tools/make_overview_pdf.py` builds `docs/Briefing-Reader-Overview.pdf` from the screenshots in `docs/screens`.

## What it proves, and what it does not

| It proves | It does not prove |
|---|---|
| The Swift compiles with a current Xcode | Anything that needs a real Pencil, USB drive or kiosk profile |
| The logic tests pass (agenda times, naming, PIN) | Pencil ink stays glued to the page when zoomed |
| The project file is generated correctly | The kiosk lock, USB loading, battery, or video |
| | An installable app. That needs your Apple signing |

So this removes the "never compiled" risk. The checks that need a real iPad in `FIRST-BUILD-CHECKLIST.md`
(sections 5 and 6) still need a Mac and an iPad later.

## One-time setup (about 10 minutes, done by someone with a GitHub account)

1. On github.com create a **new private repository**, for example `briefing-reader`. Leave it empty (no README,
   no .gitignore). Keep it private: it contains company branding and sample board content.
2. In a terminal in the project folder, set who you are for commits (once per PC):

   ```
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
3. Send the project up:

   ```
   git init -b main
   git add .
   git commit -m "Briefing Reader: first import"
   git remote add origin https://github.com/YOUR-ACCOUNT/briefing-reader.git
   git push -u origin main
   ```

   Git will ask you to sign in to GitHub the first time (a browser window opens).
4. On GitHub open the repository, then **Actions**. The first run starts by itself. You can also press
   **Run workflow** on the "Build and test the iPad app" workflow at any time.

## Reading the result

- A **green tick** means it compiled and the tests passed.
- A **red cross**: open the run, then the **Summary** page. The first list is the exact compiler errors, with
  file and line. Copy that list into the chat and the fixes can be applied and a new zip made.
- The full logs are on the same page under **Artifacts** (`build-and-test-logs`).

## Notes

- The workflow uses `macos-15-intel`. `macos-14` was tried first and GitHub no longer offered it. `macos-latest`
  (Apple Silicon) then sat queued for 15 minutes and failed with "not acquired by Runner" because of capacity limits,
  so the Intel pool is used. Compiling and unit tests work the same on Intel. If this label is retired, pick a
  current `macos-` name from GitHub's runner list. If the
  step "Pick an iPad simulator" finds none, the Xcode on that image has no iPad runtime; the "Show the
  toolchain" step prints what is available.
- Nothing in the workflow uses secrets, and it has read-only access to the repository.
- Because the build is unsigned, no Apple Developer account is needed for this step. The account is still
  needed to make the Ad Hoc build that goes on the four iPads (`FIRST-BUILD-CHECKLIST.md` section 7).
- Do not put real board material in this repository. `SampleDecks/` is made-up content only.
