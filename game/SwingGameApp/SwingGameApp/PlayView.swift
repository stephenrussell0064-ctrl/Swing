import SwiftUI
import SwingCore
import SwingGame

/// The one screen you see while playing, and mostly you do not see it: you
/// glance at it between balls. So: one big line, one small line, big buttons.
struct PlayView: View {
    let sport: Sport
    let handedness: Handedness

    @State private var model: PlayModel?

    var body: some View {
        Group {
            if let model {
                PlayScreen(model: model)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(sport.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if model == nil {
                model = PlayModel(sport: sport, handedness: handedness)
            }
        }
        .onDisappear {
            model?.tearDown()
        }
    }
}

/// Owns the source, the players and whichever session the sport needs.
@MainActor
@Observable
final class PlayModel {
    let sport: Sport
    let handedness: Handedness
    let haptics = HapticPlayer()
    let announcer = Announcer()
    let detector: StandInDetector
    let tap = TapShotSource()
    /// Simulator has no motion sensors; a button stands in for the hand.
    var useTap: Bool
    var cricket: CricketSession?
    var tennis: TennisSession?
    var calibrating = false

    var source: any ShotSource { useTap ? tap : detector }

    init(sport: Sport, handedness: Handedness) {
        self.sport = sport
        self.handedness = handedness
        self.detector = StandInDetector()
        #if targetEnvironment(simulator)
        useTap = true
        #else
        useTap = false
        #endif
        detector.start()
    }

    var headline: String {
        cricket?.headline ?? tennis?.headline ?? (source.isCalibrated ? "Ready" : sport.calibrationPrompt)
    }

    var detail: String {
        cricket?.detail ?? tennis?.detail ?? source.status
    }

    var isRunning: Bool { cricket?.isRunning ?? tennis?.isRunning ?? false }

    func calibrate() async {
        calibrating = true
        announcer.sayNow(sport.calibrationPrompt)
        let ok = await source.calibrate()
        calibrating = false
        haptics.play(ok ? HapticVocabulary.cleanStrike : HapticVocabulary.miss)
        announcer.say(ok ? "Ready." : "Try again, and hold still.")
    }

    func play() {
        guard source.isCalibrated else { return }
        switch sport {
        case .cricket:
            if cricket == nil {
                cricket = CricketSession(source: source, haptics: haptics, announcer: announcer, handedness: handedness)
            }
            cricket?.start()
        case .tennis:
            if tennis == nil {
                tennis = TennisSession(source: source, haptics: haptics, announcer: announcer, handedness: handedness)
            }
            tennis?.start()
        default:
            break
        }
    }

    func stop() {
        cricket?.stop()
        tennis?.stop()
    }

    func restart() {
        cricket?.restart()
        tennis?.restart()
    }

    func tearDown() {
        stop()
        detector.stop()
        announcer.stop()
    }
}

private struct PlayScreen: View {
    @Bindable var model: PlayModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(model.headline)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: model.headline)

            Text(model.detail)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            scoreboard

            Spacer()

            if model.useTap {
                tapControls
            } else {
                Gauge(value: min(model.detector.liveRotation, 20), in: 0...20) {
                    Text("rotation")
                } currentValueLabel: {
                    Text(String(format: "%.0f", model.detector.liveRotation))
                }
                .gaugeStyle(.accessoryLinear)
                .padding(.horizontal, 40)
            }

            controls
        }
        .padding(.bottom, 24)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Tap instead of swing", isOn: $model.useTap)
                    Toggle("Mute voice", isOn: Binding(
                        get: { model.announcer.isMuted },
                        set: { model.announcer.isMuted = $0 }
                    ))
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    @ViewBuilder
    private var scoreboard: some View {
        if let c = model.cricket {
            HStack(spacing: 32) {
                score("You", "\(c.match.yours.runs)/\(c.match.yours.wickets)", c.match.yours.overs)
                score("Them", c.match.phase == .batting ? "—" : "\(c.match.theirs.runs)/\(c.match.theirs.wickets)", c.match.phase == .batting ? "" : c.match.theirs.overs)
            }
        } else if let t = model.tennis {
            HStack(spacing: 32) {
                score("You", "\(t.match.score.games[.you] ?? 0)", "")
                score("Them", "\(t.match.score.games[.opponent] ?? 0)", "")
            }
        }
    }

    private func score(_ who: String, _ big: String, _ small: String) -> some View {
        VStack {
            Text(who).font(.caption).foregroundStyle(.secondary)
            Text(big).font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
            Text(small).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private var tapControls: some View {
        TapControls(tap: model.tap, enabled: model.isRunning)
    }

    private struct TapControls: View {
        @Bindable var tap: TapShotSource
        let enabled: Bool

        var body: some View {
            VStack(spacing: 8) {
                Button {
                    tap.swingNow()
                } label: {
                    Text("Swing now")
                        .font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!enabled)

                HStack {
                    Text("Speed \(Int(tap.speed))").frame(width: 90, alignment: .leading)
                    Slider(value: $tap.speed, in: 3...25)
                }
                HStack {
                    Text("Up \(Int(tap.elevation))°").frame(width: 90, alignment: .leading)
                    Slider(value: $tap.elevation, in: -30...60)
                }
                HStack {
                    Text("Aim \(Int(tap.yaw))°").frame(width: 90, alignment: .leading)
                    Slider(value: $tap.yaw, in: -60...60)
                }
            }
            .font(.footnote.monospacedDigit())
            .padding(.horizontal, 24)
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                Task { await model.calibrate() }
            } label: {
                Label(model.source.isCalibrated ? "Re-aim" : "Aim", systemImage: "scope")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .disabled(model.calibrating || model.isRunning)

            if model.isRunning {
                Button(role: .destructive) {
                    model.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            } else if model.cricket != nil || model.tennis != nil {
                Button {
                    model.restart()
                } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    model.play()
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.source.isCalibrated)
            }
        }
        .padding(.horizontal, 24)
    }
}
