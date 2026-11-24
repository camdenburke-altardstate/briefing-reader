import SwiftUI
import UIKit

/// Battery level for the clock/battery readout. The iPad's status bar is hidden in kiosk mode,
/// so the time and battery have to be shown by the app.
final class BatteryModel: ObservableObject {
    static let shared = BatteryModel()

    @Published private(set) var percent: Int?
    @Published private(set) var charging = false
    private var tokens: [NSObjectProtocol] = []

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        update()
        let center = NotificationCenter.default
        for name in [UIDevice.batteryLevelDidChangeNotification, UIDevice.batteryStateDidChangeNotification] {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.update()
            })
        }
    }

    private func update() {
        let level = UIDevice.current.batteryLevel
        percent = level < 0 ? nil : Int((level * 100).rounded())
        let state = UIDevice.current.batteryState
        charging = state == .charging || state == .full
    }
}

/// "3:42 PM   battery 82%"
struct StatusCluster: View {
    var tint: Color = Brand.inkSecondary
    @ObservedObject private var battery = BatteryModel.shared

    var body: some View {
        HStack(spacing: 14) {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
            }
            if let percent = battery.percent {
                HStack(spacing: 4) {
                    Image(systemName: battery.charging ? "battery.100.bolt" : symbol(for: percent))
                    Text("\(percent)%")
                }
            }
        }
        .font(Brand.font(.book, 14, .footnote))
        .monospacedDigit()
        .foregroundStyle(tint)
    }

    private func symbol(for percent: Int) -> String {
        if percent > 75 { return "battery.100" }
        if percent > 50 { return "battery.75" }
        if percent > 25 { return "battery.50" }
        return "battery.25"
    }
}

/// The sun button: brightness (Control Center is unavailable in kiosk mode) and, for PDFs, paper tone.
struct DisplayButton: View {
    var showsTone = false
    var tint: Color = Brand.ink

    @AppStorage("readingTone") private var toneRaw = ReadingTone.standard.rawValue
    @State private var showing = false
    @State private var brightness = Double(UIScreen.main.brightness)

    var body: some View {
        Button {
            brightness = Double(UIScreen.main.brightness)
            showing = true
        } label: {
            Image(systemName: "sun.max")
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .foregroundStyle(tint)
        }
        .accessibilityLabel("Display")
        .popover(isPresented: $showing) { panel }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                Slider(value: $brightness, in: 0.05...1).tint(Brand.ink)
                Image(systemName: "sun.max")
            }
            .foregroundStyle(Brand.ink)
            .onChange(of: brightness) { newValue in
                UIScreen.main.brightness = CGFloat(newValue)
            }

            if showsTone {
                Picker("Paper", selection: $toneRaw) {
                    ForEach(ReadingTone.allCases) { tone in
                        Text(tone.label).tag(tone.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}
