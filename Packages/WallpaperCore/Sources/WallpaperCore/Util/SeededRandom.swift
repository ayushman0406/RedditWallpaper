import Foundation

/// Deterministic random numbers from a text seed (FNV-1a hash feeding
/// SplitMix64), so "random" feeds page consistently and tests can pin them.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: String) {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        state = hash
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension Array {
    public func seededShuffle(seed: String) -> [Element] {
        var generator = SeededGenerator(seed: seed)
        return shuffled(using: &generator)
    }
}
