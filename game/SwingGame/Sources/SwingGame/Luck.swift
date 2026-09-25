import Foundation

/// Deterministic "randomness". Same seed and index, same number, every time,
/// on every machine — so a replayed fixture produces the same match and a test
/// can assert on the fourth ball of the second over.
///
/// SplitMix64. Not cryptographic and not meant to be.
struct Luck: Hashable, Sendable {
    var seed: UInt64

    init(seed: UInt64) { self.seed = seed }

    /// A value in 0..<1 for the `index`th draw.
    func draw(_ index: Int) -> Double {
        var z = seed &+ UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9_7F4A_7C15
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }

    /// A second, independent stream for the same index.
    func draw(_ index: Int, stream: Int) -> Double {
        Luck(seed: seed ^ (UInt64(stream) &* 0xD1B5_4A32_D192_ED03)).draw(index)
    }
}
