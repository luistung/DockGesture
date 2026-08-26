import AppKit
import DockGestureCore

struct DockStateIndicatorPresentation {
    let state: DockApplicationIndicatorState
    let frame: CGRect
}

@MainActor
final class DockStateIndicatorView: NSView {
    var indicators: [DockStateIndicatorPresentation] = [] {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        for indicator in indicators where indicator.frame.intersects(dirtyRect) {
            draw(indicator)
        }
    }

    private func draw(_ indicator: DockStateIndicatorPresentation) {
        switch indicator.state {
        case .none:
            return
        case .frontmost:
            drawFrontmost(in: indicator.frame)
        case .hidden:
            drawHidden(in: indicator.frame)
        }
    }

    private func drawFrontmost(in frame: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 0.22, green: 0.66, blue: 1, alpha: 0.85)
        shadow.shadowBlurRadius = max(2, frame.width * 0.28)
        shadow.shadowOffset = .zero
        shadow.set()

        let circle = NSBezierPath(ovalIn: frame.insetBy(dx: 1, dy: 1))
        NSColor(calibratedRed: 0.22, green: 0.66, blue: 1, alpha: 1).setFill()
        circle.fill()
        NSGraphicsContext.restoreGraphicsState()

        stroke(circle, lineWidth: max(1, frame.width * 0.1))
    }

    private func drawHidden(in frame: CGRect) {
        let circle = NSBezierPath(ovalIn: frame.insetBy(dx: 1, dy: 1))
        NSColor(calibratedRed: 0.41, green: 0.44, blue: 0.49, alpha: 1).setFill()
        circle.fill()
        stroke(circle, lineWidth: max(1, frame.width * 0.1))

        let minus = NSBezierPath()
        minus.move(to: CGPoint(x: frame.minX + frame.width * 0.27, y: frame.midY))
        minus.line(to: CGPoint(x: frame.maxX - frame.width * 0.27, y: frame.midY))
        minus.lineCapStyle = .round
        minus.lineWidth = max(1.5, frame.width * 0.13)
        NSColor.white.setStroke()
        minus.stroke()
    }

    private func stroke(_ path: NSBezierPath, lineWidth: CGFloat) {
        path.lineWidth = lineWidth
        NSColor(calibratedWhite: 0.08, alpha: 0.9).setStroke()
        path.stroke()
    }
}
