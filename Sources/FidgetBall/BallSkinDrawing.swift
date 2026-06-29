import AppKit

extension FidgetOverlayView {
    func drawSkin(_ skin: BallSkin, in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat) {
        if let image = BallSkinImageCache.shared.image(for: skin) {
            drawImageSkin(image, in: context, rect: rect, center: center, radius: radius)
            return
        }

        switch skin {
        case .smiley:
            drawGradient(in: context, rect: rect, colors: [
                NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.28, alpha: 1),
                NSColor(calibratedRed: 0.82, green: 0.57, blue: 0.06, alpha: 1)
            ])
            drawFace(in: context, center: center, radius: radius)
        case .marble:
            drawGradient(in: context, rect: rect, colors: [
                NSColor(calibratedWhite: 0.98, alpha: 1),
                NSColor(calibratedWhite: 0.62, alpha: 1)
            ])
            drawMarbleLines(in: context, center: center, radius: radius)
        case .basketball:
            drawGradient(in: context, rect: rect, colors: [
                NSColor(calibratedRed: 0.96, green: 0.47, blue: 0.12, alpha: 1),
                NSColor(calibratedRed: 0.55, green: 0.19, blue: 0.04, alpha: 1)
            ])
            drawSportsSeams(in: context, center: center, radius: radius, color: .black, football: false)
        case .tennis:
            drawGradient(in: context, rect: rect, colors: [
                NSColor(calibratedRed: 0.84, green: 0.95, blue: 0.21, alpha: 1),
                NSColor(calibratedRed: 0.34, green: 0.62, blue: 0.08, alpha: 1)
            ])
            drawTennisSeams(in: context, center: center, radius: radius)
        case .football:
            drawGradient(in: context, rect: rect, colors: [
                NSColor(calibratedRed: 0.46, green: 0.24, blue: 0.08, alpha: 1),
                NSColor(calibratedRed: 0.18, green: 0.09, blue: 0.03, alpha: 1)
            ])
            drawSportsSeams(in: context, center: center, radius: radius, color: .white, football: true)
        case .disco:
            drawDiscoTiles(in: context, rect: rect, center: center, radius: radius)
        }
    }

    private func drawImageSkin(_ image: NSImage, in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        let rotatedRect = CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: rotatedRect, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
        drawImageHighlight(in: context, rect: rect)
    }

    private func drawImageHighlight(in context: CGContext, rect: CGRect) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                NSColor.white.withAlphaComponent(0.22).cgColor,
                NSColor.clear.cgColor
            ] as CFArray,
            locations: [0, 1]
        )
        context.drawRadialGradient(
            gradient!,
            startCenter: CGPoint(x: rect.minX + rect.width * 0.32, y: rect.maxY - rect.height * 0.28),
            startRadius: 0,
            endCenter: CGPoint(x: rect.midX, y: rect.midY),
            endRadius: rect.width * 0.8,
            options: []
        )
    }

    private func drawGradient(in context: CGContext, rect: CGRect, colors: [NSColor]) {
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map(\.cgColor) as CFArray,
            locations: [0, 1]
        )
        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }

    private func drawMarbleLines(in context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.22).cgColor)
        context.setLineWidth(max(2, radius * 0.055))
        for offset in stride(from: -radius * 0.7, through: radius * 0.7, by: radius * 0.35) {
            context.move(to: CGPoint(x: -radius, y: offset))
            context.addCurve(
                to: CGPoint(x: radius, y: offset + radius * 0.18),
                control1: CGPoint(x: -radius * 0.45, y: offset + radius * 0.28),
                control2: CGPoint(x: radius * 0.38, y: offset - radius * 0.22)
            )
            context.strokePath()
        }
        context.restoreGState()
    }

    private func drawSportsSeams(in context: CGContext, center: CGPoint, radius: CGFloat, color: NSColor, football: Bool) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        context.setStrokeColor(color.withAlphaComponent(football ? 0.72 : 0.55).cgColor)
        context.setLineWidth(max(2, radius * 0.065))
        context.strokeEllipse(in: CGRect(x: -radius * 0.82, y: -radius * 0.82, width: radius * 1.64, height: radius * 1.64))
        context.move(to: CGPoint(x: 0, y: -radius))
        context.addLine(to: CGPoint(x: 0, y: radius))
        context.strokePath()
        context.move(to: CGPoint(x: -radius, y: 0))
        context.addLine(to: CGPoint(x: radius, y: 0))
        context.strokePath()
        if football {
            context.setLineWidth(max(2, radius * 0.05))
            for y in stride(from: -radius * 0.18, through: radius * 0.18, by: radius * 0.12) {
                context.move(to: CGPoint(x: -radius * 0.16, y: y))
                context.addLine(to: CGPoint(x: radius * 0.16, y: y))
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    private func drawTennisSeams(in context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.78).cgColor)
        context.setLineWidth(max(3, radius * 0.08))
        context.addArc(center: CGPoint(x: -radius * 0.35, y: 0), radius: radius * 0.7, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        context.strokePath()
        context.addArc(center: CGPoint(x: radius * 0.35, y: 0), radius: radius * 0.7, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: false)
        context.strokePath()
        context.restoreGState()
    }

    private func drawDiscoTiles(in context: CGContext, rect: CGRect, center: CGPoint, radius: CGFloat) {
        drawGradient(in: context, rect: rect, colors: [
            NSColor(calibratedRed: 0.86, green: 0.92, blue: 1, alpha: 1),
            NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.5, alpha: 1)
        ])
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        let tile = max(7, radius * 0.18)
        for x in stride(from: -radius, through: radius, by: tile) {
            for y in stride(from: -radius, through: radius, by: tile) where hypot(x, y) < radius {
                let alpha = 0.15 + CGFloat((Int(abs(x + y)) % 5)) * 0.1
                context.setStrokeColor(NSColor.white.withAlphaComponent(alpha).cgColor)
                context.stroke(CGRect(x: x, y: y, width: tile, height: tile), width: 1)
            }
        }
        context.restoreGState()
    }

    private func drawFace(in context: CGContext, center: CGPoint, radius: CGFloat) {
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: physics.state.spin * 0.08)
        context.setFillColor(NSColor.black.withAlphaComponent(0.78).cgColor)
        let eye = radius * 0.16
        context.fillEllipse(in: CGRect(x: -radius * 0.42, y: radius * 0.12, width: eye, height: eye * 1.55))
        context.fillEllipse(in: CGRect(x: radius * 0.22, y: radius * 0.12, width: eye, height: eye * 1.55))
        context.setLineWidth(max(3, radius * 0.08))
        context.setLineCap(.round)
        context.setStrokeColor(NSColor.black.withAlphaComponent(0.76).cgColor)
        context.move(to: CGPoint(x: -radius * 0.32, y: -radius * 0.16))
        context.addQuadCurve(to: CGPoint(x: radius * 0.34, y: -radius * 0.16), control: CGPoint(x: 0, y: -radius * 0.42))
        context.strokePath()
        context.restoreGState()
    }
}

@MainActor
private final class BallSkinImageCache {
    static let shared = BallSkinImageCache()
    private var images: [BallSkin: NSImage] = [:]

    func image(for skin: BallSkin) -> NSImage? {
        if let image = images[skin] {
            return image
        }
        guard let url = Bundle.module.url(forResource: skin.assetName, withExtension: "png", subdirectory: "BallSkins"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        images[skin] = image
        return image
    }
}
