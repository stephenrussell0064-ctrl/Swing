import SwiftUI
import SwingGame

/// The catalogue. Pick a sport, then stand up.
struct ContentView: View {
    @State private var handedness: Handedness = .right

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Sport.allCases) { sport in
                        if sport.isPlayable {
                            NavigationLink(value: sport) {
                                row(sport)
                            }
                        } else {
                            row(sport).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Golf arrives with the motion half of the app. Bowling and darts are next.")
                }

                Section("You") {
                    Picker("Hand", selection: $handedness) {
                        Text("Right-handed").tag(Handedness.right)
                        Text("Left-handed").tag(Handedness.left)
                    }
                }

                Section {
                    NavigationLink("Recorded swings") {
                        FixturesView()
                    }
                } footer: {
                    Text("Every swing the phone reads is saved as a fixture. Plug the phone into a Mac and they are in the Files app, ready for the repository.")
                }
            }
            .navigationTitle("Swing")
            .navigationDestination(for: Sport.self) { sport in
                PlayView(sport: sport, handedness: handedness)
            }
        }
    }

    private func row(_ sport: Sport) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(sport.title).font(.title3.weight(.semibold))
            Text(sport.blurb).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
