import SwiftUI
import CoreText

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#endif

public struct SandTextView: View {
    let text: String
    let seed: Int
    let dotCount: Int
    let dotColor: Color
    let backgroundColor: Color

    private let nodes: [SandShapeStreamNode]
    private let generator = SandShapeStreamFieldGenerator()

    public init(text: String,
                seed: Int = 23,
                dotCount: Int = 220,
                dotColor: Color = .primary,
                backgroundColor: Color = .clear) {
        self.text = text
        self.seed = seed
        self.dotCount = dotCount
        self.dotColor = dotColor
        self.backgroundColor = backgroundColor
        self.nodes = generator.generate(seed: seed, dotCount: dotCount)
    }

    public var body: some View {
        GeometryReader { proxy in
            let layout = SandTextLayout.make(text: text, in: proxy.size)

            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    guard layout.totalLength > 0 else { return }
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    for node in nodes {
                        let grain = grain(for: node, time: time, layout: layout, size: size)
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
    }

    private func grain(for node: SandShapeStreamNode,
                       time: TimeInterval,
                       layout: SandTextLayout,
                       size: CGSize) -> SandTextGrainRenderState {
        let progress = fract(node.phaseOffset + CGFloat(time) * node.speed * 1.12 + (CGFloat(node.streamIndex) * 0.18))
        let contour = layout.contour(for: node.noiseSeed)
        let sample = contour.sample(progress: progress)
        let tangent = normalized(sample.tangent)
        let normal = CGVector(dx: -tangent.dy, dy: tangent.dx)
        let minDimension = min(size.width, size.height)

        let tangentialOffset = node.tangentialBias * minDimension * 0.0026
        let radialNoise = smoothNoise(time: time, seed: node.noiseSeed, period: 2.6)
        let radialOffset = (node.radialBias * minDimension * 0.0044) + (radialNoise * minDimension * 0.0018)
        let opacityPulse = 0.1 * (0.5 + (0.5 * sin((Double(progress) * .pi * 2) + time * 2.8)))
        let presence = loopPresence(for: progress)

        let x = sample.point.x + (tangent.dx * tangentialOffset) + (normal.dx * radialOffset)
        let y = sample.point.y + (tangent.dy * tangentialOffset) + (normal.dy * radialOffset)

        return SandTextGrainRenderState(position: CGPoint(x: x, y: y),
                                        radius: node.radius * 0.9,
                                        opacity: min(1, node.opacity * (0.5 + (presence * 0.5)) + opacityPulse))
    }

    private func loopPresence(for progress: CGFloat) -> CGFloat {
        let fade: CGFloat = 0.12
        switch progress {
        case 0..<fade:
            return smoothstep(progress / fade)
        case (1 - fade)...1:
            return smoothstep((1 - progress) / fade)
        default:
            return 1
        }
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = sqrt((vector.dx * vector.dx) + (vector.dy * vector.dy))
        guard length > 0.0001 else {
            return CGVector(dx: 1, dy: 0)
        }

        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private func fract(_ value: CGFloat) -> CGFloat {
        let remainder = value - floor(value)
        return remainder >= 0 ? remainder : remainder + 1
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
        var value = UInt64(bitPattern: Int64(seed &* 83492791 ^ index &* 29765729))
        value ^= value >> 33
        value = value &* 0xff51afd7ed558ccd
        value ^= value >> 33
        value = value &* 0xc4ceb9fe1a85ec53
        value ^= value >> 33
        let normalized = Double(value & 0xFFFFFFFFFFFF) / Double(0xFFFFFFFFFFFF)
        return CGFloat((normalized * 2) - 1)
    }
}

@available(*, deprecated, renamed: "SandTextView")
public typealias LoadingSandTextStreamView = SandTextView

private struct SandTextLayout {
    let contours: [SandTextContour]
    let totalLength: CGFloat
    let contourThresholds: [CGFloat]

    func contour(for seed: Int) -> SandTextContour {
        guard let contour = contour(for: CGFloat(abs(seed) % 10_000) / 10_000) else {
            return contours[0]
        }

        return contour
    }

    private func contour(for selector: CGFloat) -> SandTextContour? {
        guard !contours.isEmpty else { return nil }
        guard totalLength > 0 else { return contours.first }

        let target = selector * totalLength
        for (index, threshold) in contourThresholds.enumerated() where target <= threshold {
            return contours[index]
        }

        return contours.last
    }

    static func make(text: String, in size: CGSize) -> SandTextLayout {
        guard size.width > 0, size.height > 0 else {
            return SandTextLayout(contours: [], totalLength: 0, contourThresholds: [])
        }

        let baseSize = max(80, min(size.width * 0.28, size.height * 0.42))
        let font = PlatformFont.systemFont(ofSize: baseSize, weight: .bold)
        let ctFont = CTFontCreateWithName(font.fontName as CFString, baseSize, nil)
        let attributed = NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): ctFont
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        let runs = CTLineGetGlyphRuns(line) as NSArray
        var contours: [[CGPoint]] = []

        for runObject in runs {
            let run = runObject as! CTRun
            let glyphCount = CTRunGetGlyphCount(run)
            guard glyphCount > 0 else { continue }

            var glyphs = Array(repeating: CGGlyph(), count: glyphCount)
            var positions = Array(repeating: CGPoint.zero, count: glyphCount)
            CTRunGetGlyphs(run, CFRangeMake(0, 0), &glyphs)
            CTRunGetPositions(run, CFRangeMake(0, 0), &positions)

            for index in 0..<glyphCount {
                guard let glyphPath = CTFontCreatePathForGlyph(ctFont, glyphs[index], nil) else { continue }
                var transform = CGAffineTransform(translationX: positions[index].x, y: positions[index].y)
                let translated = glyphPath.copy(using: &transform) ?? glyphPath
                contours.append(contentsOf: flatten(path: translated))
            }
        }

        let allPoints = contours.flatMap { $0 }
        guard let bounds = bounds(for: allPoints) else {
            return SandTextLayout(contours: [], totalLength: 0, contourThresholds: [])
        }

        let usableWidth = size.width * 0.84
        let usableHeight = size.height * 0.34
        let scale = min(usableWidth / max(bounds.width, 1), usableHeight / max(bounds.height, 1))
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let transformedContours = contours.compactMap { contour -> SandTextContour? in
            guard contour.count > 1 else { return nil }

            let transformed = contour.map { point in
                CGPoint(x: size.width * 0.5 + ((point.x - center.x) * scale),
                        y: size.height * 0.5 - ((point.y - center.y) * scale))
            }

            return SandTextContour(points: transformed)
        }

        let thresholds = transformedContours.reduce(into: [CGFloat]()) { partial, contour in
            let next = (partial.last ?? 0) + contour.length
            partial.append(next)
        }

        return SandTextLayout(contours: transformedContours,
                              totalLength: thresholds.last ?? 0,
                              contourThresholds: thresholds)
    }

    private static func flatten(path: CGPath) -> [[CGPoint]] {
        var contours: [[CGPoint]] = []
        var current: [CGPoint] = []
        var startPoint = CGPoint.zero
        var currentPoint = CGPoint.zero

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            let points = element.points

            switch element.type {
            case .moveToPoint:
                if current.count > 1 {
                    contours.append(current)
                }
                startPoint = points[0]
                currentPoint = startPoint
                current = [startPoint]
            case .addLineToPoint:
                let point = points[0]
                current.append(point)
                currentPoint = point
            case .addQuadCurveToPoint:
                let control = points[0]
                let end = points[1]
                current.append(contentsOf: sampledQuadratic(from: currentPoint, control: control, to: end))
                currentPoint = end
            case .addCurveToPoint:
                let control1 = points[0]
                let control2 = points[1]
                let end = points[2]
                current.append(contentsOf: sampledCubic(from: currentPoint, control1: control1, control2: control2, to: end))
                currentPoint = end
            case .closeSubpath:
                if current.last != startPoint {
                    current.append(startPoint)
                }
                if current.count > 1 {
                    contours.append(current)
                }
                current = []
                currentPoint = startPoint
            @unknown default:
                break
            }
        }

        if current.count > 1 {
            contours.append(current)
        }

        return contours
    }

    private static func sampledQuadratic(from start: CGPoint,
                                         control: CGPoint,
                                         to end: CGPoint,
                                         steps: Int = 18) -> [CGPoint] {
        guard steps > 0 else { return [end] }
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let mt = 1 - t
            let x = (mt * mt * start.x) + (2 * mt * t * control.x) + (t * t * end.x)
            let y = (mt * mt * start.y) + (2 * mt * t * control.y) + (t * t * end.y)
            return CGPoint(x: x, y: y)
        }
    }

    private static func sampledCubic(from start: CGPoint,
                                     control1: CGPoint,
                                     control2: CGPoint,
                                     to end: CGPoint,
                                     steps: Int = 22) -> [CGPoint] {
        guard steps > 0 else { return [end] }
        return (1...steps).map { step in
            let t = CGFloat(step) / CGFloat(steps)
            let mt = 1 - t
            let x = (mt * mt * mt * start.x)
                + (3 * mt * mt * t * control1.x)
                + (3 * mt * t * t * control2.x)
                + (t * t * t * end.x)
            let y = (mt * mt * mt * start.y)
                + (3 * mt * mt * t * control1.y)
                + (3 * mt * t * t * control2.y)
                + (t * t * t * end.y)
            return CGPoint(x: x, y: y)
        }
    }

    private static func bounds(for points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var minY = first.y
        var maxX = first.x
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private struct SandTextContour {
    let points: [CGPoint]
    let segmentLengths: [CGFloat]
    let length: CGFloat

    init(points: [CGPoint]) {
        self.points = points

        var total: CGFloat = 0
        var segments: [CGFloat] = []
        for index in 1..<points.count {
            let dx = points[index].x - points[index - 1].x
            let dy = points[index].y - points[index - 1].y
            total += sqrt((dx * dx) + (dy * dy))
            segments.append(total)
        }

        self.segmentLengths = segments
        self.length = total
    }

    func sample(progress: CGFloat) -> (point: CGPoint, tangent: CGVector) {
        guard points.count > 1, length > 0 else {
            return (points.first ?? .zero, CGVector(dx: 1, dy: 0))
        }

        let target = max(0, min(1, progress)) * length
        var segmentIndex = segmentLengths.firstIndex(where: { target <= $0 }) ?? (segmentLengths.count - 1)
        segmentIndex = max(0, min(segmentIndex, points.count - 2))

        let previousLength = segmentIndex == 0 ? 0 : segmentLengths[segmentIndex - 1]
        let segmentLength = max(segmentLengths[segmentIndex] - previousLength, 0.0001)
        let local = (target - previousLength) / segmentLength
        let start = points[segmentIndex]
        let end = points[segmentIndex + 1]
        let point = CGPoint(x: start.x + ((end.x - start.x) * local),
                            y: start.y + ((end.y - start.y) * local))
        let tangent = CGVector(dx: end.x - start.x, dy: end.y - start.y)

        return (point, tangent)
    }
}

private struct SandTextGrainRenderState {
    let position: CGPoint
    let radius: CGFloat
    let opacity: CGFloat
}
