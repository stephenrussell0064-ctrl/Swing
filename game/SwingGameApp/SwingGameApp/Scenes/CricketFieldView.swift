import SwiftUI
import SwingGame

/// The ground from above. Batter in the middle, bowler's end at the top, the
/// standard field around them, the rope at the edge. After a shot the ball
/// runs out along its line; when bowling, the ball's line and length show on
/// the pitch.
struct CricketFieldView: View {
    let session: CricketSession

    private let boundaryMetres = 65.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2 + 4)
                let radius = min(size.width, size.height) / 2 - 14
                let scale = radius / boundaryMetres
                let mirror: CGFloat = session.handedness == .right ? 1 : -1

                func point(angleDegrees: Double, metres: Double) -> CGPoint {
                    let a = angleDegrees * .pi / 180
                    return CGPoint(
                        x: centre.x + CGFloat(sin(a) * metres) * scale * mirror,
                        y: centre.y - CGFloat(cos(a) * metres) * scale
                    )
                }

                // Outfield.
                let ground = Path(ellipseIn: CGRect(x: centre.x - radius * 1.08, y: centre.y - radius * 1.04, width: radius * 2.16, height: radius * 2.08))
                ctx.fill(ground, with: .radialGradient(
                    Gradient(colors: [Color(red: 0.22, green: 0.55, blue: 0.22), Color(red: 0.12, green: 0.38, blue: 0.14)]),
                    center: centre, startRadius: 0, endRadius: radius * 1.1
                ))
                // Mown stripes.
                for i in stride(from: -radius, through: radius, by: radius / 6) {
                    var stripe = Path()
                    stripe.addRect(CGRect(x: centre.x + i, y: centre.y - radius * 1.04, width: radius / 12, height: radius * 2.08))
                    ctx.clip(to: ground, options: [])
                    ctx.fill(stripe, with: .color(.white.opacity(0.04)))
                }
                // The rope.
                let rope = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
                ctx.stroke(rope, with: .color(.white.opacity(0.85)), lineWidth: 2.5)
                // Thirty-yard circle.
                let inner = Path(ellipseIn: CGRect(x: centre.x - 27 * scale, y: centre.y - 27 * scale, width: 54 * scale, height: 54 * scale))
                ctx.stroke(inner, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [3, 5]))

                // The pitch, batter's end at the centre, bowler's end up.
                let pitchLength = 20.12 * scale
                let pitchWidth = 3.05 * scale
                let pitch = CGRect(x: centre.x - pitchWidth / 2, y: centre.y - pitchLength, width: pitchWidth, height: pitchLength)
                ctx.fill(Path(roundedRect: pitch, cornerRadius: 2), with: .color(Color(red: 0.82, green: 0.72, blue: 0.5)))
                // Creases.
                for y in [pitch.minY + 1.22 * scale, pitch.maxY - 1.22 * scale] {
                    var crease = Path()
                    crease.move(to: CGPoint(x: pitch.minX - 2, y: y))
                    crease.addLine(to: CGPoint(x: pitch.maxX + 2, y: y))
                    ctx.stroke(crease, with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
                // Stumps.
                for y in [pitch.minY, pitch.maxY] {
                    for dx in [-0.11, 0, 0.11] {
                        let s = Path(roundedRect: CGRect(x: centre.x + CGFloat(dx) * scale * 6 - 1, y: y - 3, width: 2, height: 6), cornerRadius: 1)
                        ctx.fill(s, with: .color(.white))
                    }
                }

                // Fielders.
                for f in Field.standard.fielders where f.name != "the bowler" {
                    let p = point(angleDegrees: f.angle, metres: f.distance)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(Color(red: 0.95, green: 0.95, blue: 1)))
                    ctx.stroke(Path(ellipseIn: CGRect(x: p.x - 5, y: p.y - 5, width: 10, height: 10)), with: .color(.black.opacity(0.4)), lineWidth: 1)
                    let label = Text(f.name).font(.system(size: 8, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                    ctx.draw(label, at: CGPoint(x: p.x, y: p.y + 11))
                }
                // Bowler and batter.
                let bowler = CGPoint(x: centre.x, y: pitch.minY - 4 * scale)
                ctx.fill(Path(ellipseIn: CGRect(x: bowler.x - 5, y: bowler.y - 5, width: 10, height: 10)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12)), with: .color(.yellow))
                ctx.stroke(Path(ellipseIn: CGRect(x: centre.x - 6, y: centre.y - 6, width: 12, height: 12)), with: .color(.black.opacity(0.5)), lineWidth: 1)

                // The ball, after a bat.
                if session.match.phase == .batting || session.stage == .result, let flight = session.lastBatting?.flight {
                    let age = now - session.lastResultAt
                    let duration = 1.4
                    let p = min(age / duration, 1)
                    let eased = 1 - pow(1 - p, 2)
                    let end = point(angleDegrees: flight.angle, metres: min(flight.total, boundaryMetres + 3))
                    let landing = point(angleDegrees: flight.angle, metres: min(flight.carry, boundaryMetres + 3))
                    let pos = CGPoint(x: centre.x + (end.x - centre.x) * eased, y: centre.y + (end.y - centre.y) * eased)
                    var trail = Path()
                    trail.move(to: centre)
                    trail.addLine(to: pos)
                    ctx.stroke(trail, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    if flight.lofted {
                        // Shadow on the ground, ball in the air until it lands.
                        let carryFrac = min(flight.carry / max(flight.total, 0.1), 1)
                        let airP = min(eased / max(carryFrac, 0.01), 1)
                        let height = CGFloat(sin(airP * .pi)) * radius * 0.25
                        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 3, y: pos.y - 2, width: 6, height: 4)), with: .color(.black.opacity(0.35)))
                        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 5, y: pos.y - 5 - height, width: 10, height: 10)), with: .color(.red))
                        ctx.stroke(Path(ellipseIn: CGRect(x: landing.x - 6, y: landing.y - 6, width: 12, height: 12)), with: .color(.white.opacity(0.6)), lineWidth: 1)
                    } else {
                        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 4.5, y: pos.y - 4.5, width: 9, height: 9)), with: .color(.red))
                    }
                }

                // The ball, after a bowl: where it pitched and its line.
                if session.match.phase == .bowling || session.lastBowling != nil, session.match.phase != .batting, let ball = session.lastBowling?.ball {
                    let age = now - session.lastResultAt
                    let p = min(age / 0.9, 1)
                    let x = centre.x - CGFloat(ball.line) * scale * 4 * mirror
                    let bounceMetres: Double
                    switch ball.length {
                    case .short: bounceMetres = 9
                    case .good: bounceMetres = 6
                    case .full: bounceMetres = 3
                    case .yorker: bounceMetres = 0.8
                    case .fullToss: bounceMetres = 0
                    }
                    let start = bowler
                    let end = CGPoint(x: x, y: pitch.maxY)
                    let pos = CGPoint(x: start.x + (end.x - start.x) * p, y: start.y + (end.y - start.y) * p)
                    var trail = Path()
                    trail.move(to: start)
                    trail.addLine(to: pos)
                    ctx.stroke(trail, with: .color(.red.opacity(0.6)), lineWidth: 1.5)
                    if bounceMetres > 0 {
                        let by = pitch.maxY - CGFloat(bounceMetres) * scale
                        ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: by - 4, width: 8, height: 8)), with: .color(.white.opacity(0.9)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 4.5, y: pos.y - 4.5, width: 9, height: 9)), with: .color(.red))
                }

                // Stance hint: a ring on the batter while we wait.
                if session.stage == .stance {
                    let pulse = 0.5 + 0.5 * sin(now * 4)
                    let r = 12 + CGFloat(pulse) * 8
                    ctx.stroke(Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2)), with: .color(.yellow.opacity(0.9 - 0.5 * pulse)), lineWidth: 2)
                }
            }
        }
        .background(Color(red: 0.06, green: 0.16, blue: 0.08))
    }
}
