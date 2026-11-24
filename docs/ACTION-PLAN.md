# Action plan and status

The table from the original plan (`Ipad Deck Solution - Save Paper.md`), with what is actually done.
Fill in the owner and the date. "Blocked on" says what stops the next step.

| Task phase | Deliverable | Status | Blocked on | Owner | Target date |
|---|---|---|---|---|---|
| **1. Provisioning** | Wipe 4 iPads and enable Supervised Mode | Runbook written (`DEPLOYMENT.md` section 4). Not started. | A Mac with Apple Configurator, and the 4 iPads in hand | | |
| **2. App build** | Compile the custom reader | All source written and reviewed three times. Never compiled. | A Mac with Xcode and a paid Apple Developer account | | |
| **3. Content pre-load** | Ingest the executive decks | Done in the app (Manage screen) and Windows prep tool. Needs the real decks. | The final PDF and media files | | |
| **4. Lockdown and QA** | Single App Mode, test battery and rendering | Profile and QA table written. Untested on a device. | Phases 1 and 2 | | |
| **5. Executive hand-off** | Deliver configured iPads to leadership | Quick guide written (`EXECUTIVE-QUICKSTART.md`). | Phase 4, a named IT contact for the guide | | |

## The plan's "next steps and approvals"

| Item | State |
|---|---|
| Confirm custom app vs off-the-shelf reader | **Open.** The custom app is built; `OPTION-B-FALLBACK.md` is the plan if it is not ready in time. |
| Provide the final PDF decks | **Open.** Only made-up sample content exists. |
| Collect the 4 physical iPads | **Open.** Also record each one's model, iPadOS version and UDID in `ipad-register.csv`. |

## Things that must be decided or found out

1. **Which iPad models and iPadOS versions?** The app needs iPadOS 16 or newer. An older iPad may not run it.
2. **Do the iPads have Apple Pencils?** Handwriting needs one, and only certain iPads support a Pencil.
3. **Are the iPads already managed by IT's MDM?** If so, supervising by cable would conflict with it (see the
   warning in `DEPLOYMENT.md` section 4).
4. **Who holds the Apple Developer account?** Ad Hoc builds last a year and the renewal needs an owner.
5. **Marketing sign-off** on the logo, the colors and the placeholder app icon.
6. **Who loads the iPads day to day** (the assistant), and who is the IT contact printed on the quick guide?
7. **Is a passcode wanted?** Recommended: yes, held by IT.
8. **Data protection.** The app stores files, notes and handwriting in its own Documents folder, which is also
   visible to Finder file sharing for IT retrieval. For board material, turn on the **Data Protection**
   capability in Xcode (Signing and Capabilities) and choose **Complete**, so files are unreadable while the
   iPad is locked. A formal security review of the app has not been run.
