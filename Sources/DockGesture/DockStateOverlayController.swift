import AppKit
import CoreGraphics

@MainActor
final class DockStateOverlayController {
    @MainActor
    private final class Overlay {
        let panel: NSPanel
        let indicatorView: DockStateIndicatorView

        init(screen: NSScreen) {
            indicatorView = DockStateIndicatorView(frame: .zero)
            panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            panel.contentView = indicatorView
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.level = NSWindow.Level(
                rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1
            )
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .stationary,
                .fullScreenAuxiliary,
                .ignoresCycle
            ]
        }

        func update(
            screen: NSScreen,
            indicators: [DockStateIndicatorPresentation]
        ) {
            guard let first = indicators.first else {
                panel.orderOut(nil)
                return
            }
            let indicatorBounds = indicators.dropFirst().reduce(first.frame) {
                $0.union($1.frame)
            }
            let panelFrame = indicatorBounds
                .insetBy(dx: -8, dy: -8)
                .intersection(screen.frame)
            guard !panelFrame.isNull, !panelFrame.isEmpty else {
                panel.orderOut(nil)
                return
            }

            panel.setFrame(panelFrame, display: false)
            indicatorView.frame = CGRect(origin: .zero, size: panelFrame.size)
            indicatorView.indicators = indicators.map {
                DockStateIndicatorPresentation(
                    state: $0.state,
                    frame: $0.frame.offsetBy(dx: -panelFrame.minX, dy: -panelFrame.minY)
                )
            }
            panel.orderFrontRegardless()
        }
    }

    private struct ScreenIndicators {
        let screen: NSScreen
        var indicators: [DockStateIndicatorPresentation]
    }

    private var overlays: [CGDirectDisplayID: Overlay] = [:]

    func update(indicators: [DockStateIndicatorPresentation]) {
        var grouped: [CGDirectDisplayID: ScreenIndicators] = [:]
        for indicator in indicators {
            guard let screen = screen(containing: indicator.frame),
                  let identifier = displayIdentifier(for: screen) else {
                continue
            }
            if grouped[identifier] == nil {
                grouped[identifier] = ScreenIndicators(screen: screen, indicators: [])
            }
            grouped[identifier]?.indicators.append(indicator)
        }

        for (identifier, group) in grouped {
            let overlay = overlays[identifier] ?? Overlay(screen: group.screen)
            overlays[identifier] = overlay
            overlay.update(screen: group.screen, indicators: group.indicators)
        }

        for identifier in overlays.keys where grouped[identifier] == nil {
            overlays[identifier]?.panel.orderOut(nil)
        }
    }

    func clear() {
        for overlay in overlays.values {
            overlay.panel.orderOut(nil)
        }
        overlays.removeAll()
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.intersects(frame) })
    }

    private func displayIdentifier(for screen: NSScreen) -> CGDirectDisplayID? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value
    }
}
