import Foundation
import CoreGraphics

struct PauseStreamFieldGenerator {
    func generate(seed: Int, dotCount: Int) -> [PauseStreamNode] {
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        var nodes: [PauseStreamNode] = []

        for id in 0..<dotCount {
            let orderedOffset = dotCount > 1 ? CGFloat(id) / CGFloat(dotCount - 1) : 0
            let packetOffset = orderedOffset + CGFloat(Double.random(in: -0.04...0.04, using: &rng))
            let laneOffset = CGFloat(Double.random(in: -1...1, using: &rng))
            let axialJitter = CGFloat(Double.random(in: -1...1, using: &rng))
            let noiseSeed = Int(Double.random(in: 1...10_000, using: &rng))
            let radius = CGFloat(Double.random(in: 0.65...1.2, using: &rng))
            let opacity = CGFloat(Double.random(in: 0.52...0.92, using: &rng))

            nodes.append(PauseStreamNode(id: id,
                                         packetOffset: max(0, min(1, packetOffset)),
                                         laneOffset: laneOffset,
                                         axialJitter: axialJitter,
                                         noiseSeed: noiseSeed,
                                         radius: radius,
                                         opacity: opacity))
        }

        return nodes
    }
}
