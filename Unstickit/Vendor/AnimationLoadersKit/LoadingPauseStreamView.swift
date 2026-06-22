import SwiftUI

public enum LoadingStreamAxis: String, CaseIterable, Identifiable {
    case horizontal
    case vertical

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .horizontal:
            return "Horizontal"
        case .vertical:
            return "Vertical"
        }
    }
}

public struct LoadingPauseStreamView: View {
    let seed: Int
    let dotCount: Int
    let axis: LoadingStreamAxis
    let dotColor: Color
    let backgroundColor: Color

    private let cycleDuration: TimeInterval = 5.4
    private let packetSpawnSpreadProgress: CGFloat = 0.24
    private let packetTravelDuration: CGFloat = 0.68
    private let packetFadeInDuration: CGFloat = 0.1
    private let packetFadeOutDuration: CGFloat = 0.12
    private let approachHoldStartProgress: CGFloat = 0.42
    private let holdEndProgress: CGFloat = 0.76
    private let holdCenterStartX: CGFloat = 0.495
    private let holdCenterEndX: CGFloat = 0.505
    private let releaseAccelerationExponent: CGFloat = 2.2
    private let plugDotCount: Int = 20
    private let plugLoopWidth: CGFloat = 9
    private let plugLoopHeight: CGFloat = 36
    private let plugLoopSpeed: TimeInterval = 2.8
    private let plugFadeDuration: CGFloat = 0.08
    private let plugExplosionDuration: CGFloat = 0.16

    private let nodes: [PauseStreamNode]
    private let generator = PauseStreamFieldGenerator()

    public init(seed: Int = 41,
                dotCount: Int = 220,
                axis: LoadingStreamAxis = .horizontal,
                dotColor: Color = .primary,
                backgroundColor: Color = .clear) {
        self.seed = seed
        self.dotCount = dotCount
        self.axis = axis
        self.dotColor = dotColor
        self.backgroundColor = backgroundColor
        self.nodes = generator.generate(seed: seed, dotCount: dotCount)
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let cycleProgress = fract(CGFloat(time / cycleDuration))

                drawPlug(in: &context, size: size, time: time, cycleProgress: cycleProgress)

                for node in nodes {
                    let grain = grain(for: node, time: time, in: size)
                    let circle = Path(ellipseIn: CGRect(x: grain.position.x - grain.radius,
                                                        y: grain.position.y - grain.radius,
                                                        width: grain.radius * 2,
                                                        height: grain.radius * 2))
                    context.fill(circle, with: .color(dotColor.opacity(grain.opacity)))
                }
            }
            .background(backgroundColor)
        }
    }

    private func drawPlug(in context: inout GraphicsContext,
                          size: CGSize,
                          time: TimeInterval,
                          cycleProgress: CGFloat) {
        let plugScale = compactPlugScale(for: size)
        let width = plugLoopWidth * plugScale
        let height = plugLoopHeight * plugScale
        let radiusScale = lerp(0.72, 1, plugScale)
        let releaseCycleProgress = holdEndProgress * packetTravelDuration
        let fadeStart = max(0, releaseCycleProgress - plugFadeDuration)
        let center = axisPosition(for: holdCenterEndX,
                                  laneOffset: 0,
                                  in: size,
                                  axialJitter: 0,
                                  noise: (axial: 0, lane: 0))
        let cycleIndex = floor(time / cycleDuration)
        let releaseTime = (cycleIndex + Double(releaseCycleProgress)) * cycleDuration
        let loopWidth = axis == .horizontal ? width : height
        let loopHeight = axis == .horizontal ? height : width

        if cycleProgress < releaseCycleProgress {
            let visibility: CGFloat
            if cycleProgress < fadeStart {
                visibility = 1
            } else {
                visibility = smoothstep((releaseCycleProgress - cycleProgress) / (releaseCycleProgress - fadeStart))
            }

            for index in 0..<plugDotCount {
                let point = plugPoint(for: index,
                                      time: time,
                                      center: center,
                                      width: loopWidth,
                                      height: loopHeight)
                let radius = (1.2 + (0.45 * CGFloat(0.5 + 0.5 * sin((time * 9.5) + Double(index))))) * radiusScale
                let opacity = 0.26 + (0.46 * visibility)
                let circle = Path(ellipseIn: CGRect(x: point.x - radius,
                                                    y: point.y - radius,
                                                    width: radius * 2,
                                                    height: radius * 2))
                context.fill(circle, with: .color(dotColor.opacity(opacity)))
            }
            return
        }

        let explosionEnd = min(1, releaseCycleProgress + plugExplosionDuration)
        guard cycleProgress < explosionEnd else { return }

        let explosionLocal = (cycleProgress - releaseCycleProgress) / (explosionEnd - releaseCycleProgress)
        let fade = 1 - smoothstep(explosionLocal)

        for index in 0..<plugDotCount {
            let basePoint = plugPoint(for: index,
                                      time: releaseTime,
                                      center: center,
                                      width: loopWidth,
                                      height: loopHeight)
            let direction = explosionDirection(for: index, basePoint: basePoint, center: center)
            let distance = (4 + (42 * pow(explosionLocal, 0.72))) * plugScale
            let point = CGPoint(x: basePoint.x + (direction.dx * distance),
                                y: basePoint.y + (direction.dy * distance))
            let radius = (1.15 + (0.35 * (1 - explosionLocal))) * radiusScale
            let circle = Path(ellipseIn: CGRect(x: point.x - radius,
                                                y: point.y - radius,
                                                width: radius * 2,
                                                height: radius * 2))
            context.fill(circle, with: .color(dotColor.opacity(0.72 * fade)))
        }
    }

    private func grain(for node: PauseStreamNode,
                       time: TimeInterval,
                       in size: CGSize) -> GrainState {
        let cycleProgress = fract(CGFloat(time / cycleDuration))
        let startDelay = node.packetOffset * packetSpawnSpreadProgress
        let localProgress = (cycleProgress - startDelay) / packetTravelDuration

        guard (0...1).contains(localProgress) else {
            return GrainState(position: .zero, radius: 0, opacity: 0)
        }

        let shapedProgress = shapedProgress(for: localProgress)
        let minDimension = min(size.width, size.height)
        let axialNoise = minDimension * 0.0018 * smoothNoise(time: time, seed: node.noiseSeed, period: 2.4)
        let laneNoise = minDimension * 0.006 * smoothNoise(time: time, seed: node.noiseSeed &+ 137, period: 3.6)
        let position = axisPosition(for: shapedProgress,
                                    laneOffset: node.laneOffset,
                                    in: size,
                                    axialJitter: node.axialJitter,
                                    noise: (axial: axialNoise, lane: laneNoise))

        let holdFocus = gaussian(shapedProgress, center: 0.5, spread: 0.08)
        let packetVisibility = packetOpacity(for: localProgress)
        let opacityBoost = 0.08 * holdFocus

        return GrainState(position: position,
                          radius: node.radius,
                          opacity: min(1, (node.opacity + opacityBoost) * packetVisibility))
    }

    private func shapedProgress(for progress: CGFloat) -> CGFloat {
        if progress < approachHoldStartProgress {
            // One continuous ease-out so the stream reads as a single slowdown into the hold.
            let local = progress / approachHoldStartProgress
            let decelerated = 1 - pow(1 - local, 2.35)
            return lerp(0, holdCenterStartX, decelerated)
        }

        if progress < holdEndProgress {
            let local = (progress - approachHoldStartProgress) / (holdEndProgress - approachHoldStartProgress)
            return lerp(holdCenterStartX, holdCenterEndX, local)
        }

        // Phase 3: one continuous accelerating release to the trailing edge.
        let local = (progress - holdEndProgress) / (1 - holdEndProgress)
        let accelerated = pow(local, releaseAccelerationExponent)
        return lerp(holdCenterEndX, 1, accelerated)
    }

    private func axisPosition(for progress: CGFloat,
                              laneOffset: CGFloat,
                              in size: CGSize,
                              axialJitter: CGFloat,
                              noise: (axial: CGFloat, lane: CGFloat)) -> CGPoint {
        let minDimension = min(size.width, size.height)
        let crossTravel = minDimension * 0.045
        let cross = (laneOffset * crossTravel) + noise.lane

        switch axis {
        case .horizontal:
            let margin = size.width * 0.08
            let travel = size.width + (margin * 2)
            let x = (progress * travel) - margin + (axialJitter * minDimension * 0.004) + noise.axial
            let y = (size.height * 0.5) + cross
            return CGPoint(x: x, y: y)
        case .vertical:
            let margin = size.height * 0.08
            let travel = size.height + (margin * 2)
            let x = (size.width * 0.5) + cross
            let y = (progress * travel) - margin + (axialJitter * minDimension * 0.004) + noise.axial
            return CGPoint(x: x, y: y)
        }
    }

    private func plugPoint(for index: Int,
                           time: TimeInterval,
                           center: CGPoint,
                           width: CGFloat,
                           height: CGFloat) -> CGPoint {
        let phase = CGFloat(index) / CGFloat(plugDotCount)
        let loopProgress = fract(CGFloat(time / plugLoopSpeed) + phase)
        let point = rectangleLoopPoint(progress: loopProgress, width: width, height: height)
        return CGPoint(x: center.x + point.x, y: center.y + point.y)
    }

    private func rectangleLoopPoint(progress: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
        let halfWidth = width * 0.5
        let halfHeight = height * 0.5

        switch progress {
        case 0..<0.25:
            let local = progress / 0.25
            return CGPoint(x: lerp(-halfWidth, halfWidth, local), y: -halfHeight)
        case 0.25..<0.5:
            let local = (progress - 0.25) / 0.25
            return CGPoint(x: halfWidth, y: lerp(-halfHeight, halfHeight, local))
        case 0.5..<0.75:
            let local = (progress - 0.5) / 0.25
            return CGPoint(x: lerp(halfWidth, -halfWidth, local), y: halfHeight)
        default:
            let local = (progress - 0.75) / 0.25
            return CGPoint(x: -halfWidth, y: lerp(halfHeight, -halfHeight, local))
        }
    }

    private func explosionDirection(for index: Int, basePoint: CGPoint, center: CGPoint) -> CGVector {
        let dx = basePoint.x - center.x
        let dy = basePoint.y - center.y
        let jitter = CGFloat(index - (plugDotCount / 2)) * 0.06
        let length = max(0.001, sqrt((dx * dx) + (dy * dy)))
        return CGVector(dx: (dx / length) + jitter, dy: (dy / length) - jitter * 0.25).normalized
    }

    private func compactPlugScale(for size: CGSize) -> CGFloat {
        let minDimension = min(size.width, size.height)
        let normalized = minDimension / 180
        return max(0.28, min(1, normalized))
    }

    private func packetOpacity(for progress: CGFloat) -> CGFloat {
        if progress < packetFadeInDuration {
            return smoothstep(progress / packetFadeInDuration)
        }

        if progress > (1 - packetFadeOutDuration) {
            return smoothstep((1 - progress) / packetFadeOutDuration)
        }

        return 1
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        let remainder = value - floor(value)
        return remainder >= 0 ? remainder : remainder + 1
    }

    private func lerp(_ start: CGFloat, _ end: CGFloat, _ amount: CGFloat) -> CGFloat {
        start + ((end - start) * amount)
    }

    private func gaussian(_ value: CGFloat, center: CGFloat, spread: CGFloat) -> CGFloat {
        let delta = (value - center) / spread
        return exp(-(delta * delta))
    }

    private func smoothstep(_ value: CGFloat) -> CGFloat {
        let clamped = max(0, min(1, value))
        return clamped * clamped * (3 - (2 * clamped))
    }

    private func smoothNoise(time: TimeInterval, seed: Int, period: TimeInterval) -> CGFloat {
        let t = time / period
        let t0 = floor(t)
        let t1 = t0 + 1
        let fraction = CGFloat(t - t0)
        let blend = smoothstep(fraction)
        let v0 = randomUnit(seed: seed, index: Int(t0))
        let v1 = randomUnit(seed: seed, index: Int(t1))
        return v0 * (1 - blend) + v1 * blend
    }

    private func randomUnit(seed: Int, index: Int) -> CGFloat {
        var value = UInt64(bitPattern: Int64(seed &* 64123091 ^ index &* 16095857))
        value ^= value >> 33
        value = value &* 0xff51afd7ed558ccd
        value ^= value >> 33
        value = value &* 0xc4ceb9fe1a85ec53
        value ^= value >> 33
        let normalized = Double(value & 0xFFFFFFFFFFFF) / Double(0xFFFFFFFFFFFF)
        return CGFloat((normalized * 2) - 1)
    }
}

private struct GrainState {
    let position: CGPoint
    let radius: CGFloat
    let opacity: CGFloat
}

private extension CGVector {
    var normalized: CGVector {
        let length = max(0.001, sqrt((dx * dx) + (dy * dy)))
        return CGVector(dx: dx / length, dy: dy / length)
    }
}
