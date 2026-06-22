import Foundation
import CoreGraphics

struct SandShapeStreamFieldGenerator {
    func generate(seed: Int, dotCount: Int) -> [SandShapeStreamNode] {
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        var nodes: [SandShapeStreamNode] = []

        for id in 0..<dotCount {
            let streamIndex = id.isMultiple(of: 2) ? 0 : 1
            let phaseOffset = CGFloat(Double.random(in: 0...1, using: &rng))
            let speed = CGFloat(Double.random(in: 0.16...0.28, using: &rng))
            let radialBias = CGFloat(Double.random(in: -1...1, using: &rng))
            let tangentialBias = CGFloat(Double.random(in: -1...1, using: &rng))
            let noiseSeed = Int(Double.random(in: 1...10_000, using: &rng))
            let radius = CGFloat(Double.random(in: 0.75...1.6, using: &rng))
            let opacity = CGFloat(Double.random(in: 0.5...0.98, using: &rng))

            nodes.append(SandShapeStreamNode(id: id,
                                             streamIndex: streamIndex,
                                             phaseOffset: phaseOffset,
                                             speed: speed,
                                             radialBias: radialBias,
                                             tangentialBias: tangentialBias,
                                             noiseSeed: noiseSeed,
                                             radius: radius,
                                             opacity: opacity))
        }

        return nodes
    }
}
