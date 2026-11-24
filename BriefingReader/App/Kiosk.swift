import UIKit

/// Autonomous Single App Mode (ASAM).
///
/// The app asks iPadOS to lock the device to itself. iPadOS only grants this when the
/// device is supervised AND a configuration profile with a `com.apple.asam` payload
/// whitelists this app's bundle id (see Profiles/BriefingReader-Kiosk.mobileconfig).
/// On an unsupervised iPad, or in the simulator, the request simply fails and the app
/// behaves like a normal app, which is what you want while developing.
enum Kiosk {
    static func lock() {
        guard !UIAccessibility.isGuidedAccessEnabled else { return }
        UIAccessibility.requestGuidedAccessSession(enabled: true) { success in
            #if DEBUG
            print("ASAM lock requested, success: \(success)")
            #endif
        }
    }
}
