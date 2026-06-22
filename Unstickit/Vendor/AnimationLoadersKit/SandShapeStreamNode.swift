import Foundation
import CoreGraphics

struct SandShapeStreamNode: Identifiable {
    let id: Int
    let streamIndex: Int
    let phaseOffset: CGFloat
    let speed: CGFloat
    let radialBias: CGFloat
    let tangentialBias: CGFloat
    let noiseSeed: Int
    let radius: CGFloat
    let opacity: CGFloat
}
