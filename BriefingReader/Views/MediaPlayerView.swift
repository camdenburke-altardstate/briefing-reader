import SwiftUI
import AVFoundation
import AVKit

/// Plays a video or an audio recording from the iPad's own storage. It remembers where you
/// stopped. Picture-in-picture is off so playback cannot float out of the locked app.
struct MediaPlayerView: View {
    let item: ContentItem
    let collection: ContentCollection

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var timeToken: Any?

    var body: some View {
        ZStack {
            Brand.media.ignoresSafeArea()

            if let player {
                PlayerController(player: player)
                    .ignoresSafeArea()
            }

            if item.kind == .audio {
                VStack(spacing: 14) {
                    Image(systemName: "waveform").font(.system(size: 64))
                    Text(item.title).font(Brand.font(.medium, 22, .title3))
                }
                .foregroundStyle(.white.opacity(0.8))
            }

            VStack {
                HStack(spacing: 4) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 20)).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Library")
                    Spacer()
                    StatusCluster(tint: Color.white.opacity(0.7))
                    NotesButton(collection: collection, tint: .white)
                    DisplayButton(tint: .white)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.45))
                Spacer()
            }
        }
        .statusBarHidden(true)
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private func start() {
        // Play through the speaker even if the silent switch is on, like a media app.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        let avPlayer = AVPlayer(url: item.url)
        let resume = store.savedSeconds(for: item)
        // Pick up where it left off, unless it was nearly finished.
        if resume > 3 && resume < item.measure - 5 {
            avPlayer.seek(to: CMTime(seconds: Double(resume), preferredTimescale: 600))
        }
        timeToken = avPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 2, preferredTimescale: 1),
            queue: .main
        ) { time in
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            Task { @MainActor in store.savePage(Int(seconds), for: item) }
        }
        store.markOpened(item)
        player = avPlayer
        avPlayer.play()
    }

    private func stop() {
        if let player {
            player.pause()
            if let timeToken { player.removeTimeObserver(timeToken) }
            let seconds = CMTimeGetSeconds(player.currentTime())
            if seconds.isFinite { store.savePage(Int(seconds), for: item) }
        }
        timeToken = nil
        player = nil
        store.commitProgress()
    }
}

struct PlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.updatesNowPlayingInfoCenter = false
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}
}
