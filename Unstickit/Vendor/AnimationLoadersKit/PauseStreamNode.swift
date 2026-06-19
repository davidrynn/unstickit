import Foundation
import CoreGraphics

struct PauseStreamNode: Identifiable {
    let id: Int
    let packetOffset: CGFloat
    let laneOffset: CGFloat
    let axialJitter: CGFloat
    let noiseSeed: Int
    let radius: CGFloat
    let opacity: CGFloat
}
