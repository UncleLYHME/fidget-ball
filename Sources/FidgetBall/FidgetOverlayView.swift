import AppKit

final class PassthroughWindow: NSPanel {
    weak var fidgetView: FidgetOverlayView?

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        guard let fidgetView else {
            super.mouseDown(with: event)
            return
        }
        let point = fidgetView.convert(event.locationInWindow, from: nil)
        if fidgetView.isInteractive(point) {
            super.mouseDown(with: event)
        } else {
            ignoresMouseEvents = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.ignoresMouseEvents = false
            }
        }
    }
}

final class FidgetOverlayView: NSView {
    let physics = FidgetPhysics()
    var onDetach: (() -> Void)?
    private let physicsBounds: CGRect
    private let playableScreens: [CGRect]
    private var menuBarAnchor: CGPoint
    private var appSettings: AppSettings
    private var timer: Timer?
    private var lastTick = CACurrentMediaTime()
    private var timeAccumulator: CGFloat = 0
    private var mouseDownPoint = CGPoint.zero
    private var didDragPastClickThreshold = false
    private var ropeCutArmed = true
    private var ropeCutAnimation: RopeCutAnimation?
    private var mouseMoveMonitor: Any?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    init(frame frameRect: NSRect, physicsBounds: CGRect, playableScreens: [CGRect], menuBarAnchor: CGPoint, settings: AppSettings) {
        self.physicsBounds = physicsBounds
        self.playableScreens = playableScreens
        self.menuBarAnchor = menuBarAnchor
        self.appSettings = settings
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        apply(settings)
        start()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        physics.reset(in: physicsBounds, anchor: menuBarAnchor)
        lastTick = CACurrentMediaTime()
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 120, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        mouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged]) { [weak self] _ in
            Task { @MainActor in
                self?.updateMousePassthrough()
            }
        }
    }

    isolated deinit {
        timer?.invalidate()
        if let mouseMoveMonitor {
            NSEvent.removeMonitor(mouseMoveMonitor)
        }
    }

    func resetBall() {
        physics.reset(in: physicsBounds, anchor: menuBarAnchor)
        ropeCutArmed = true
        needsDisplay = true
    }

    func updateSettings(_ settings: AppSettings) {
        appSettings = settings
        apply(settings)
        needsDisplay = true
    }

    func reattachRope() {
        physics.reattach(anchor: menuBarAnchor)
        ropeCutArmed = true
        needsDisplay = true
    }

    func moveHome(to anchor: CGPoint) {
        menuBarAnchor = anchor
        physics.reset(in: physicsBounds, anchor: anchor)
        ropeCutAnimation = nil
        ropeCutArmed = true
        needsDisplay = true
    }

    func moveAnchor(to anchor: CGPoint) {
        menuBarAnchor = anchor
        physics.moveAnchor(to: anchor)
        needsDisplay = true
    }

    func cutRope() {
        beginRopeCut(at: ropeMidpoint)
        ropeCutArmed = false
    }

    func isInteractive(_ point: CGPoint) -> Bool {
        let ballDistance = hypot(point.x - physics.state.position.x, point.y - physics.state.position.y)
        if ballDistance <= physics.settings.ballRadius + appSettings.hitPadding {
            return true
        }

        return false
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        isInteractive(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            reattachRope()
            needsDisplay = true
            return
        }
        mouseDownPoint = point
        didDragPastClickThreshold = false
        physics.beginDrag(at: point)
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) > 5 {
            didDragPastClickThreshold = true
        }
        let events = physics.drag(to: point)
        if events.detached {
            onDetach?()
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        physics.endDrag()
        if !didDragPastClickThreshold {
            physics.pop(from: point)
        }
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawRope(in: context)
        drawCutRope(in: context)
        drawBall(in: context)
    }

    private func tick() {
        updateMousePassthrough()

        let now = CACurrentMediaTime()
        let dt = CGFloat(now - lastTick)
        lastTick = now
        timeAccumulator = min(timeAccumulator + dt, 1 / 12)

        let fixedStep: CGFloat = 1 / 120
        var detached = false
        while timeAccumulator >= fixedStep {
            let events = physics.step(dt: fixedStep, collisionRegion: collisionRegion())
            detached = detached || events.detached
            timeAccumulator -= fixedStep
        }

        if detached {
            onDetach?()
        }
        needsDisplay = true
    }

    private func collisionRegion() -> CollisionRegion {
        let radius = physics.settings.ballRadius
        let screenBounds = activeScreenBounds(for: physics.state.position)
        return CollisionRegion(
            rect: screenBounds.insetBy(dx: 6, dy: 6),
            blocksLeft: !hasNeighbor(across: .left, from: screenBounds, radius: radius),
            blocksRight: !hasNeighbor(across: .right, from: screenBounds, radius: radius),
            blocksBottom: !hasNeighbor(across: .bottom, from: screenBounds, radius: radius),
            blocksTop: !hasNeighbor(across: .top, from: screenBounds, radius: radius)
        )
    }

    private func activeScreenBounds(for point: CGPoint) -> CGRect {
        if let containing = playableScreens.first(where: { $0.contains(point) }) {
            return containing
        }

        return playableScreens.min { left, right in
            squaredDistance(from: point, to: left) < squaredDistance(from: point, to: right)
        } ?? physicsBounds
    }

    private enum CollisionEdge {
        case left
        case right
        case bottom
        case top
    }

    private func hasNeighbor(across edge: CollisionEdge, from rect: CGRect, radius: CGFloat) -> Bool {
        let tolerance: CGFloat = 2
        let position = physics.state.position
        return playableScreens.contains { other in
            switch edge {
            case .left:
                return abs(other.maxX - rect.minX) <= tolerance
                    && position.y >= other.minY - radius
                    && position.y <= other.maxY + radius
            case .right:
                return abs(other.minX - rect.maxX) <= tolerance
                    && position.y >= other.minY - radius
                    && position.y <= other.maxY + radius
            case .bottom:
                return abs(other.maxY - rect.minY) <= tolerance
                    && position.x >= other.minX - radius
                    && position.x <= other.maxX + radius
            case .top:
                return abs(other.minY - rect.maxY) <= tolerance
                    && position.x >= other.minX - radius
                    && position.x <= other.maxX + radius
            }
        }
    }

    private func squaredDistance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return dx * dx + dy * dy
    }

    private func updateMousePassthrough() {
        guard let window else { return }
        if physics.state.dragging {
            window.ignoresMouseEvents = false
            return
        }

        let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let viewPoint = convert(windowPoint, from: nil)
        cutRopeIfPointerTouches(viewPoint)
        window.ignoresMouseEvents = !isInteractive(viewPoint)
    }

    private func cutRopeIfPointerTouches(_ point: CGPoint) {
        guard physics.state.attached, ropeCutArmed else { return }
        let ballDistance = hypot(point.x - physics.state.position.x, point.y - physics.state.position.y)
        guard ballDistance > physics.settings.ballRadius + 6 else { return }

        if distance(point, toSegmentFrom: physics.state.anchor, to: physics.state.position) < 9 {
            beginRopeCut(at: point)
            ropeCutArmed = false
        }
    }

    private var ropeMidpoint: CGPoint {
        CGPoint(
            x: (physics.state.anchor.x + physics.state.position.x) / 2,
            y: (physics.state.anchor.y + physics.state.position.y) / 2
        )
    }

    private func beginRopeCut(at point: CGPoint) {
        guard physics.state.attached else { return }
        let cut = nearestPoint(point, onSegmentFrom: physics.state.anchor, to: physics.state.position)
        ropeCutAnimation = RopeCutAnimation(
            anchor: physics.state.anchor,
            ball: physics.state.position,
            cut: cut,
            startTime: CACurrentMediaTime()
        )
        physics.cutRope()
        onDetach?()
        needsDisplay = true
    }

    private func apply(_ settings: AppSettings) {
        physics.settings = settings.physicsSettings
    }

    private func drawRope(in context: CGContext) {
        guard physics.state.attached else { return }
        let anchor = physics.state.anchor
        let ball = physics.state.position
        let tension = min(1, physics.distanceFromAnchor / max(physics.settings.ropeLength * 1.4, 1))

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(3 + tension * 2)
        context.setStrokeColor(appSettings.ropeColor.withAlphaComponent(0.78).cgColor)
        context.move(to: anchor)
        context.addQuadCurve(to: ball, control: ropeControlPoint(anchor: anchor, ball: ball))
        context.strokePath()

        context.setFillColor(appSettings.ropeColor.withAlphaComponent(0.95).cgColor)
        context.fillEllipse(in: CGRect(x: anchor.x - 5, y: anchor.y - 5, width: 10, height: 10))
        context.restoreGState()
    }

    private func ropeControlPoint(anchor: CGPoint, ball: CGPoint) -> CGPoint {
        let dx = ball.x - anchor.x
        let dy = ball.y - anchor.y
        let length = max(1, hypot(dx, dy))
        let midpoint = CGPoint(x: (anchor.x + ball.x) / 2, y: (anchor.y + ball.y) / 2)

        let stretchRatio = min(1, length / max(physics.settings.ropeLength, 1))
        let slack = max(0, physics.settings.ropeLength - length)
        let tangentSpeed = abs((-dy / length) * physics.state.velocity.dx + (dx / length) * physics.state.velocity.dy)
        let visualTension = max(stretchRatio, min(1, tangentSpeed / 1600))

        let gravitySag = min(70, slack * 0.35) * (1 - visualTension)
        let pullStraightening = physics.state.dragging ? 0.18 : 1.0
        let swingOffset = max(-48, min(48, physics.state.velocity.dx * 0.018)) * (1 - visualTension * 0.65)

        return CGPoint(
            x: midpoint.x - dy / length * swingOffset,
            y: midpoint.y + gravitySag * pullStraightening + dx / length * swingOffset
        )
    }

    private func drawCutRope(in context: CGContext) {
        guard let animation = ropeCutAnimation else { return }
        let age = CACurrentMediaTime() - animation.startTime
        let duration: CGFloat = 0.42
        let progress = min(1, CGFloat(age) / duration)
        if progress >= 1 {
            ropeCutAnimation = nil
            return
        }

        let alpha = 0.8 * (1 - progress)
        let recoil = 34 * progress
        let anchorEnd = animation.cut.pointMoved(toward: animation.anchor, by: recoil)
        let ballEnd = animation.cut.pointMoved(toward: animation.ball, by: recoil)
        let flutter = sin(progress * .pi) * 18

        context.saveGState()
        context.setLineCap(.round)
        context.setLineWidth(4)
        context.setStrokeColor(NSColor(calibratedRed: 0.87, green: 0.72, blue: 0.35, alpha: alpha).cgColor)

        context.move(to: animation.anchor)
        context.addQuadCurve(
            to: anchorEnd,
            control: CGPoint(
                x: (animation.anchor.x + anchorEnd.x) / 2 - flutter,
                y: (animation.anchor.y + anchorEnd.y) / 2 + flutter
            )
        )
        context.strokePath()

        context.move(to: animation.ball)
        context.addQuadCurve(
            to: ballEnd,
            control: CGPoint(
                x: (animation.ball.x + ballEnd.x) / 2 + flutter,
                y: (animation.ball.y + ballEnd.y) / 2 - flutter
            )
        )
        context.strokePath()
        context.restoreGState()
    }

    private func drawBall(in context: CGContext) {
        let center = physics.state.position
        let radius = physics.settings.ballRadius
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.35).cgColor)
        context.addEllipse(in: rect)
        context.clip()
        drawSkin(appSettings.ballSkin, in: context, rect: rect, center: center, radius: radius)
        context.restoreGState()
    }

    private func distance(_ point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let projection = nearestPoint(point, onSegmentFrom: start, to: end)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func nearestPoint(_ point: CGPoint, onSegmentFrom start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared == 0 {
            return start
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    }
}

private struct RopeCutAnimation {
    let anchor: CGPoint
    let ball: CGPoint
    let cut: CGPoint
    let startTime: CFTimeInterval
}

private extension CGPoint {
    func pointMoved(toward target: CGPoint, by distance: CGFloat) -> CGPoint {
        let dx = target.x - x
        let dy = target.y - y
        let length = max(1, hypot(dx, dy))
        return CGPoint(x: x + dx / length * distance, y: y + dy / length * distance)
    }
}
