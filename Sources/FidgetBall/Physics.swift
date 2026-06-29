import AppKit

struct FidgetSettings {
    var gravity: CGFloat = 1500
    var ropeStiffness: CGFloat = 0.42
    var airDrag: CGFloat = 0.018
    var ballRadius: CGFloat = 34
    var ballWeight: CGFloat = 1.0
    var bounceDamping: CGFloat = 0.72
    var ropeLengthBase: CGFloat = 230
    var ropeDragStretch: CGFloat = 1.15
    var throwBoost: CGFloat = 1.0
    var floorFriction: CGFloat = 0.08
    var spinResponse: CGFloat = 1.0
    var ropeDamping: CGFloat = 0.24

    var ropeLength: CGFloat {
        ropeLengthBase + ballRadius * 0.7
    }
}

struct FidgetState {
    var anchor = CGPoint(x: 900, y: 760)
    var position = CGPoint(x: 930, y: 535)
    var velocity = CGVector(dx: 0, dy: 0)
    var attached = true
    var dragging = false
    var spin: CGFloat = 0
    var lastDragPoint = CGPoint.zero
    var lastDragTime = CACurrentMediaTime()
    var grabOffset = CGVector.zero
    var smoothedDragVelocity = CGVector.zero
    var dragStretchVelocity = CGVector.zero
}

struct PhysicsEvents {
    var bounced = false
    var detached = false
}

struct CollisionRegion {
    var rect: CGRect
    var blocksLeft = true
    var blocksRight = true
    var blocksBottom = true
    var blocksTop = true
}

final class FidgetPhysics {
    var settings = FidgetSettings()
    var state = FidgetState()

    func reset(in bounds: CGRect, anchor: CGPoint? = nil) {
        let fallbackAnchorY = max(bounds.maxY - 120, bounds.midY)
        state.anchor = anchor ?? CGPoint(x: bounds.midX + 190, y: fallbackAnchorY)
        state.position = CGPoint(x: state.anchor.x + 38, y: state.anchor.y - settings.ropeLength)
        state.velocity = .zero
        state.attached = true
        state.dragging = false
        state.spin = 0
        state.grabOffset = .zero
        state.smoothedDragVelocity = .zero
        state.dragStretchVelocity = .zero
    }

    func reattach(anchor: CGPoint? = nil) {
        if let anchor {
            state.anchor = anchor
        }
        state.attached = true
        state.dragging = false
        state.velocity.dx *= 0.4
        state.velocity.dy *= 0.4
    }

    func moveAnchor(to anchor: CGPoint) {
        let delta = CGVector(dx: anchor.x - state.anchor.x, dy: anchor.y - state.anchor.y)
        state.anchor = anchor
        guard state.attached && !state.dragging else { return }
        state.position.x += delta.dx
        state.position.y += delta.dy
    }

    func cutRope() {
        state.attached = false
        state.dragging = false
    }

    func beginDrag(at point: CGPoint) {
        state.dragging = true
        state.lastDragPoint = point
        state.lastDragTime = CACurrentMediaTime()
        state.grabOffset = .zero
        state.velocity = .zero
        state.smoothedDragVelocity = .zero
        state.dragStretchVelocity = .zero
    }

    @discardableResult
    func drag(to point: CGPoint) -> PhysicsEvents {
        let now = CACurrentMediaTime()
        let dt = max(0.001, now - state.lastDragTime)
        let rawTarget = CGPoint(x: point.x - state.grabOffset.dx, y: point.y - state.grabOffset.dy)
        let target = rawTarget
        let dx = target.x - state.position.x
        let dy = target.y - state.position.y
        let rawVelocity = CGVector(
            dx: dx / dt * settings.throwBoost,
            dy: dy / dt * settings.throwBoost
        )
        let smoothing: CGFloat = 0.36
        state.smoothedDragVelocity = CGVector(
            dx: rawVelocity.dx * smoothing + state.smoothedDragVelocity.dx * (1 - smoothing),
            dy: rawVelocity.dy * smoothing + state.smoothedDragVelocity.dy * (1 - smoothing)
        )
        state.velocity = state.smoothedDragVelocity
        state.position = target
        let rawDistance = hypot(rawTarget.x - state.anchor.x, rawTarget.y - state.anchor.y)
        state.dragStretchVelocity = stretchSnapVelocity(rawDistance: rawDistance, target: target)
        state.spin += dx / max(settings.ballRadius, 1) * settings.spinResponse
        state.lastDragPoint = point
        state.lastDragTime = now

        return PhysicsEvents()
    }

    func endDrag() {
        state.dragging = false
        state.velocity = CGVector(
            dx: state.smoothedDragVelocity.dx + state.dragStretchVelocity.dx,
            dy: state.smoothedDragVelocity.dy + state.dragStretchVelocity.dy
        )
    }

    func pop(from point: CGPoint) {
        let offset = (point.x - state.position.x) / max(settings.ballRadius, 1)
        let massScale = 1 / max(0.35, settings.ballWeight)
        state.dragging = false
        state.velocity.dx += max(-520, min(520, offset * 420)) * massScale * settings.throwBoost
        state.velocity.dy = max(state.velocity.dy, 980 * massScale * settings.throwBoost)
        state.spin += offset * 0.7 * settings.spinResponse
    }

    @discardableResult
    func step(dt rawDt: CGFloat, bounds: CGRect) -> PhysicsEvents {
        step(dt: rawDt, collisionRegion: CollisionRegion(rect: bounds))
    }

    @discardableResult
    func step(dt rawDt: CGFloat, collisionRegion: CollisionRegion) -> PhysicsEvents {
        let substeps = max(1, min(3, Int(ceil(rawDt / (1 / 120)))))
        let dt = min(rawDt / CGFloat(substeps), 1 / 120)
        var events = PhysicsEvents()

        if state.dragging {
            return events
        }

        for _ in 0..<substeps {
            integrate(dt: dt)

            if state.attached {
                limitExtremeRopeStretch()
            }

            if collide(with: collisionRegion, dt: dt) {
                events.bounced = true
            }
        }

        return events
    }

    var distanceFromAnchor: CGFloat {
        hypot(state.position.x - state.anchor.x, state.position.y - state.anchor.y)
    }

    private var mass: CGFloat {
        max(0.25, settings.ballWeight)
    }

    private func integrate(dt: CGFloat) {
        state.velocity.dy -= settings.gravity * dt
        if state.attached {
            applyElasticRope(dt: dt)
        }
        applyAirDrag(dt: dt)
        capVelocity()
        state.position.x += state.velocity.dx * dt
        state.position.y += state.velocity.dy * dt
        state.spin += state.velocity.dx * dt / max(settings.ballRadius, 1) * settings.spinResponse
    }

    private func applyAirDrag(dt: CGFloat) {
        let drag = max(0, 1 - settings.airDrag * dt / mass)
        guard state.attached && distanceFromAnchor > settings.ropeLength * 0.98 else {
            state.velocity.dx *= drag
            state.velocity.dy *= drag
            return
        }

        let dx = state.position.x - state.anchor.x
        let dy = state.position.y - state.anchor.y
        let distance = max(1, hypot(dx, dy))
        let nx = dx / distance
        let ny = dy / distance
        let radial = state.velocity.dx * nx + state.velocity.dy * ny
        let radialVelocity = CGVector(dx: nx * radial, dy: ny * radial)
        let tangentVelocity = CGVector(
            dx: (state.velocity.dx - radialVelocity.dx) * drag,
            dy: (state.velocity.dy - radialVelocity.dy) * drag
        )
        state.velocity = CGVector(
            dx: radialVelocity.dx + tangentVelocity.dx,
            dy: radialVelocity.dy + tangentVelocity.dy
        )
    }

    private func applyElasticRope(dt: CGFloat) {
        let dx = state.position.x - state.anchor.x
        let dy = state.position.y - state.anchor.y
        let distance = max(1, hypot(dx, dy))
        guard distance > settings.ropeLength else { return }

        let nx = dx / distance
        let ny = dy / distance
        let stretch = distance - settings.ropeLength
        let radialVelocity = state.velocity.dx * nx + state.velocity.dy * ny
        let spring = stretch * 18 * settings.ropeStiffness / mass
        let damping = radialVelocity * 6.5 * settings.ropeDamping / mass
        let pull = max(-900, spring + damping)
        state.velocity.dx -= nx * pull * dt
        state.velocity.dy -= ny * pull * dt
    }

    private func limitExtremeRopeStretch() {
        let dx = state.position.x - state.anchor.x
        let dy = state.position.y - state.anchor.y
        let distance = max(1, hypot(dx, dy))
        let maxLength = settings.ropeLength * (1 + settings.ropeDragStretch * 1.2)
        guard distance > maxLength else { return }

        let nx = dx / distance
        let ny = dy / distance
        state.position = CGPoint(
            x: state.anchor.x + nx * maxLength,
            y: state.anchor.y + ny * maxLength
        )

        let outwardVelocity = state.velocity.dx * nx + state.velocity.dy * ny
        if outwardVelocity > 0 {
            state.velocity.dx -= nx * outwardVelocity * 0.65
            state.velocity.dy -= ny * outwardVelocity * 0.65
        }
    }

    private func stretchSnapVelocity(rawDistance: CGFloat, target: CGPoint) -> CGVector {
        guard state.attached else { return .zero }

        let dx = target.x - state.anchor.x
        let dy = target.y - state.anchor.y
        let distance = max(1, hypot(dx, dy))
        let stretch = max(0, rawDistance - settings.ropeLength)
        guard stretch > 0 else { return .zero }

        let snap = min(1500, stretch * 4.2 * settings.ropeStiffness)
        return CGVector(dx: -dx / distance * snap, dy: -dy / distance * snap)
    }

    private func collide(with region: CollisionRegion, dt: CGFloat) -> Bool {
        let bounds = region.rect
        let radius = settings.ballRadius
        let restitution = max(0.05, min(settings.bounceDamping, 0.98))
        let friction = max(0, min(settings.floorFriction, 0.6))
        let restSpeed: CGFloat = 55
        var bounced = false

        if region.blocksLeft && state.position.x - radius < bounds.minX {
            state.position.x = bounds.minX + radius
            if state.velocity.dx < 0 {
                state.velocity.dx = abs(state.velocity.dx) * restitution
                state.velocity.dy *= 1 - friction * 0.45
                bounced = true
            }
        } else if region.blocksRight && state.position.x + radius > bounds.maxX {
            state.position.x = bounds.maxX - radius
            if state.velocity.dx > 0 {
                state.velocity.dx = -abs(state.velocity.dx) * restitution
                state.velocity.dy *= 1 - friction * 0.45
                bounced = true
            }
        }

        if region.blocksBottom && state.position.y - radius < bounds.minY {
            state.position.y = bounds.minY + radius
            if state.velocity.dy < 0 {
                let impactSpeed = abs(state.velocity.dy)
                if impactSpeed < restSpeed {
                    state.velocity.dy = 0
                } else {
                    state.velocity.dy = impactSpeed * restitution
                    bounced = true
                }
                state.velocity.dx *= max(0, 1 - friction * 9 * dt)
                state.spin += state.velocity.dx / max(radius, 1) * 0.025 * settings.spinResponse
            }

            if abs(state.velocity.dy) < restSpeed {
                state.velocity.dy = 0
                state.velocity.dx *= max(0, 1 - friction * 12 * dt)
                if abs(state.velocity.dx) < 4 {
                    state.velocity.dx = 0
                }
            }
        } else if region.blocksTop && state.position.y + radius > bounds.maxY {
            state.position.y = bounds.maxY - radius
            if state.velocity.dy > 0 {
                state.velocity.dy = -abs(state.velocity.dy) * restitution
                state.velocity.dx *= max(0, 1 - friction * 3 * dt)
                bounced = true
            }
        }

        return bounced
    }

    private func capVelocity() {
        let maxSpeed: CGFloat = 4200
        let speed = hypot(state.velocity.dx, state.velocity.dy)
        guard speed > maxSpeed else { return }
        let scale = maxSpeed / speed
        state.velocity.dx *= scale
        state.velocity.dy *= scale
    }
}
