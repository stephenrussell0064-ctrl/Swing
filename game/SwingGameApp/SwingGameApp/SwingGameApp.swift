import SwiftUI

/// The game half of Swing, on a phone, before the motion half has landed.
///
/// This target exists so tennis and cricket can be *felt* — the haptic
/// rhythm of a ball coming, the moment after a swing — rather than only
/// unit-tested. It reads a `Shot` from whatever `ShotSource` is plugged in.
/// Today that is the stand-in detector in `StandIn/`, which is scaffolding
/// and is deleted the day `motion/` arrives; see `game/README.md`.
@main
struct SwingGameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
