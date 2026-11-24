import SwiftUI

@main
struct BriefingReaderApp: App {
    @StateObject private var store = LibraryStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(store)
                .tint(Brand.ink)
                .preferredColorScheme(.light)
                .statusBarHidden(true)
                .task {
                    #if DEBUG
                    DebugSeed.run()          // automated screenshot runs only; compiled out of Release
                    store.refresh(force: true)
                    #endif
                    Kiosk.lock()             // scenePhase may not report the very first .active
                }
                .persistentSystemOverlays(.hidden)
                .onChange(of: scenePhase) { phase in
                    if phase == .active {
                        Kiosk.lock()
                        store.refresh()
                    } else if phase == .background {
                        store.commitProgress()   // save the reading position before iPadOS can end the app
                    }
                }
        }
    }
}
