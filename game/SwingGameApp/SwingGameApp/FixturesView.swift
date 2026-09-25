import SwiftUI
import SwingCore
import SwingGame

/// What has been recorded on this phone. Share to a Mac, or plug in and open
/// the Files app: `Swing/fixtures/`.
struct FixturesView: View {
    @State private var store = FixtureStore.shared

    var body: some View {
        List {
            if store.fixtures.isEmpty {
                ContentUnavailableView(
                    "No swings yet",
                    systemImage: "figure.cricket",
                    description: Text("Play a few balls. Every swing the phone reads is saved here with its full trace.")
                )
            }
            ForEach(Array(zip(store.fixtures, store.urls)), id: \.1) { fixture, url in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fixture.id).font(.headline)
                    Text(fixture.note).font(.subheadline).foregroundStyle(.secondary)
                    if let s = fixture.expected {
                        Text(String(format: "%.1f m/s · %d samples · %@", s.releaseSpeed, fixture.samples.count, s.kind.rawValue))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { store.delete(url) }
                    ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
                }
            }
        }
        .navigationTitle("Recorded swings")
        .toolbar {
            if !store.urls.isEmpty {
                ShareLink(items: store.urls) { Label("Share all", systemImage: "square.and.arrow.up") }
            }
        }
        .onAppear { store.reload() }
    }
}
