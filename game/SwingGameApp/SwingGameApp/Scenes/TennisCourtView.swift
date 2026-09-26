import SwiftUI
import SwingGame

/// The court from above. You at the bottom, them at the top. An incoming
/// ball crosses toward the side it is coming to as the count plays; your
/// shot lands on the far side where the game says it did.
struct TennisCourtView: View {
    let session: TennisSession

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                // Court geometry, metres → points. Doubles width for the
                // surround, singles lines drawn inside.
                let courtLength = 23.77, doublesWidth = 10.97, singlesWidth = 8.23
                let margin: CGFloat = 26
                let scale = min((size.height - margin * 2) / CGFloat(courtLength), (size.width - margin * 2) / CGFloat(doublesWidth))
                let cx = size.width / 2, cy = size.height / 2
                let L = CGFloat(courtLength) * scale, W = CGFloat(doublesWidth) * scale, S = CGFloat(singlesWidth) * scale
                let court = CGRect(x: cx - W / 2, y: cy - L / 2, width: W, height: L)
                let mirror: CGFloat = session.handedness == .right ? 1 : -1

                // Surround and surface.
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.10, green: 0.30, blue: 0.22)))
                ctx.fill(Path(court), with: .color(Color(red: 0.17, green: 0.42, blue: 0.68)))

                // Lines.
                func line(_ a: CGPoint, _ b: CGPoint, width: CGFloat = 2) {
                    var p = Path()
                    p.move(to: a); p.addLine(to: b)
                    ctx.stroke(p, with: .color(.white), lineWidth: width)
                }
                ctx.stroke(Path(court), with: .color(.white), lineWidth: 2)
                line(CGPoint(x: cx - S / 2, y: court.minY), CGPoint(x: cx - S / 2, y: court.maxY))
                line(CGPoint(x: cx + S / 2, y: court.minY), CGPoint(x: cx + S / 2, y: court.maxY))
                let serviceOffset = CGFloat(6.4) * scale
                line(CGPoint(x: cx - S / 2, y: cy - serviceOffset), CGPoint(x: cx + S / 2, y: cy - serviceOffset))
                line(CGPoint(x: cx - S / 2, y: cy + serviceOffset), CGPoint(x: cx + S / 2, y: cy + serviceOffset))
                line(CGPoint(x: cx, y: cy - serviceOffset), CGPoint(x: cx, y: cy + serviceOffset))
                // Centre marks.
                line(CGPoint(x: cx, y: court.minY), CGPoint(x: cx, y: court.minY + 6))
                line(CGPoint(x: cx, y: court.maxY), CGPoint(x: cx, y: court.maxY - 6))
                // Net.
                var net = Path()
                net.move(to: CGPoint(x: court.minX - 10, y: cy))
                net.addLine(to: CGPoint(x: court.maxX + 10, y: cy))
                ctx.stroke(net, with: .color(.white.opacity(0.9)), lineWidth: 4)
                ctx.stroke(net, with: .color(.black.opacity(0.35)), style: StrokeStyle(lineWidth: 4, dash: [2, 3]))

                // Players.
                let you = CGPoint(x: cx, y: court.maxY + 10)
                let them = CGPoint(x: cx, y: court.minY - 10)
                ctx.fill(Path(ellipseIn: CGRect(x: them.x - 6, y: them.y - 6, width: 12, height: 12)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: you.x - 7, y: you.y - 7, width: 14, height: 14)), with: .color(.yellow))
                ctx.stroke(Path(ellipseIn: CGRect(x: you.x - 7, y: you.y - 7, width: 14, height: 14)), with: .color(.black.opacity(0.5)), lineWidth: 1)

                // Incoming ball during the count: crosses from them to the
                // side it is coming to, arriving at contact.
                if let ball = session.incoming, let active = session.activeScript {
                    let sideX = (ball.side == .forehand ? 1.0 : -1.0) * mirror
                    let target = CGPoint(x: cx + sideX * S * 0.32, y: court.maxY - 6)
                    let total = active.contactTime - active.start
                    let p = ((now - active.start) / max(total, 0.1)).clamped(to: 0...1)
                    // Landing region glow on your side.
                    let glow = 0.35 + 0.25 * sin(now * 6)
                    let zone = CGRect(x: sideX > 0 ? cx : cx - S / 2, y: cy + serviceOffset, width: S / 2, height: court.maxY - cy - serviceOffset)
                    ctx.fill(Path(zone), with: .color(.yellow.opacity(0.18 * glow)))
                    let pos = CGPoint(x: them.x + (target.x - them.x) * CGFloat(p), y: them.y + (target.y - them.y) * CGFloat(p))
                    let height = CGFloat(sin(p * .pi)) * 22
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 3, y: pos.y - 2, width: 6, height: 4)), with: .color(.black.opacity(0.3)))
                    ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 5, y: pos.y - 5 - height, width: 10, height: 10)), with: .color(Color(red: 0.85, green: 0.95, blue: 0.2)))
                    let word = Text(ball.side == .forehand ? "FOREHAND" : "BACKHAND").font(.system(size: 11, weight: .heavy)).foregroundStyle(.yellow)
                    ctx.draw(word, at: CGPoint(x: zone.midX, y: zone.midY))
                }

                // Your last shot, flying to where it landed.
                if let step = session.lastStep, session.stage == .result || session.stage == .stance {
                    let age = now - session.lastResultAt
                    let p = CGFloat(min(age / 0.9, 1))
                    let end: CGPoint
                    let colour: Color
                    switch step.stroke.outcome {
                    case .inPlay(let placement):
                        end = CGPoint(x: cx + CGFloat(placement.lateral) * scale * mirror, y: cy - CGFloat(placement.depth) * L / 2)
                        colour = placement.quality > 0.7 ? .green : (placement.quality > 0.4 ? .yellow : .orange)
                    case .outLong:
                        end = CGPoint(x: cx, y: court.minY - 14)
                        colour = .red
                    case .outWide:
                        end = CGPoint(x: court.maxX + 14, y: cy - L / 4)
                        colour = .red
                    case .net:
                        end = CGPoint(x: cx, y: cy + 3)
                        colour = .red
                    case .miss:
                        end = you
                        colour = .clear
                    }
                    if step.stroke.outcome != .miss {
                        let pos = CGPoint(x: you.x + (end.x - you.x) * p, y: you.y + (end.y - you.y) * p)
                        var trail = Path()
                        trail.move(to: you); trail.addLine(to: pos)
                        ctx.stroke(trail, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        let height = CGFloat(sin(Double(p) * .pi)) * 20
                        ctx.fill(Path(ellipseIn: CGRect(x: pos.x - 5, y: pos.y - 5 - height, width: 10, height: 10)), with: .color(Color(red: 0.85, green: 0.95, blue: 0.2)))
                        if p >= 1 {
                            ctx.stroke(Path(ellipseIn: CGRect(x: end.x - 9, y: end.y - 9, width: 18, height: 18)), with: .color(colour), lineWidth: 2.5)
                        }
                    }
                }

                // Stance hint.
                if session.stage == .stance {
                    let pulse = 0.5 + 0.5 * sin(now * 4)
                    let r = 12 + CGFloat(pulse) * 8
                    ctx.stroke(Path(ellipseIn: CGRect(x: you.x - r, y: you.y - r, width: r * 2, height: r * 2)), with: .color(.yellow.opacity(0.9 - 0.5 * pulse)), lineWidth: 2)
                }
            }
        }
        .background(Color(red: 0.08, green: 0.22, blue: 0.16))
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
