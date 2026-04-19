import SwiftUI
import AVKit

struct PlayerView: View {
    @Environment(AppState.self) var app
    let channel: Channel
    var onClose: () -> Void = {}
    var onSwitchChannel: (Int) -> Void = { _ in }

    @State private var player: AVPlayer?
    @State private var showOverlay = true
    @State private var volume: Float = 1.0
    @State private var showVolume = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            if let player = player {
                #if os(tvOS)
                // Use bare AVPlayer layer on tvOS so remote events pass through
                AVPlayerLayerView(player: player)
                    .ignoresSafeArea()
                #else
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                #endif
            } else {
                ProgressView().scaleEffect(2)
            }

            if showOverlay {
                VStack {
                    overlay
                    Spacer()
                }
                .transition(.opacity)
            }

            // Volume indicator
            if showVolume {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 20))
                        ProgressView(value: Double(volume), total: 1.0)
                            .frame(width: 120)
                            .tint(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(10)
                    .padding(.bottom, 40)
                }
                .transition(.opacity)
            }

            // Close button (iOS/macOS only)
            #if !os(tvOS)
            VStack {
                HStack {
                    Spacer()
                    Button { close() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white, .black.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .padding(24)
                }
                Spacer()
            }
            #endif
        }
        .focusable()
        .onAppear {
            loadStream()
        }
        .onDisappear {
            player?.pause()
        }
        #if os(tvOS)
        .onExitCommand { close() }
        .onMoveCommand { direction in
            switch direction {
            case .left:  switchChannel(-1)
            case .right: switchChannel(1)
            case .up:    adjustVolume(0.1)
            case .down:  adjustVolume(-0.1)
            @unknown default: break
            }
        }
        .onPlayPauseCommand {
            if let player = player {
                if player.timeControlStatus == .playing {
                    player.pause()
                } else {
                    player.play()
                }
            }
        }
        #endif
        #if os(macOS)
        .onKeyPress(.escape) {
            close()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            switchChannel(-1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            switchChannel(1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            adjustVolume(0.1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            adjustVolume(-0.1)
            return .handled
        }
        #endif
    }

    private func loadStream() {
        let url: URL?
        if let directURL = channel.streamURL {
            url = directURL
        } else if case .xtream(let creds) = app.connectionConfig {
            let api = XtreamAPI(credentials: creds)
            url = api.streamURL(for: channel)
        } else {
            url = nil
        }
        if let url {
            player = AVPlayer(url: url)
            player?.volume = volume
            player?.play()
        }
        scheduleHideOverlay()
    }

    private func close() {
        player?.pause()
        player = nil
        onClose()
    }

    private func switchChannel(_ direction: Int) {
        player?.pause()
        player = nil
        withAnimation { showOverlay = true }
        onSwitchChannel(direction)
    }

    private func adjustVolume(_ delta: Float) {
        volume = max(0, min(1, volume + delta))
        player?.volume = volume
        withAnimation { showVolume = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { showVolume = false }
        }
    }

    private var overlay: some View {
        VStack(alignment: .leading, spacing: Platform.dim(8)) {
            Text(channel.name)
                .font(Platform.font(42, weight: .bold))
            if let current = app.currentProgram(for: channel) {
                HStack(spacing: 10) {
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                    Text("Now: \(current.title)")
                        .font(Platform.font(26))
                }
                Text(timeRange(current))
                    .font(Platform.font(20))
                    .foregroundColor(.secondary)
            }
            if let next = app.nextProgram(for: channel) {
                Text("Next: \(next.title)")
                    .font(Platform.font(22))
                    .foregroundColor(.secondary)
            }
        }
        .padding(Platform.dim(30))
        .background(Color.black.opacity(0.75))
        .cornerRadius(16)
        .padding(Platform.dim(60))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduleHideOverlay() {
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation { showOverlay = false }
        }
    }

    private func timeRange(_ p: EPGProgram) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: p.start)) - \(f.string(from: p.stop))"
    }
}

// Bare AVPlayer layer without transport controls (for tvOS)
#if os(tvOS) || os(iOS)
struct AVPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? PlayerUIView {
            view.playerLayer.player = player
        }
    }

    private class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#endif
