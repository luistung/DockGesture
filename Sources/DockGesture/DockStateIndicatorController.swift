import AppKit
import CoreGraphics
import DockGestureCore

@MainActor
final class DockStateIndicatorController {
    private let resolver: DockItemResolver
    private let stateMonitor = DockApplicationStateMonitor()
    private let scheduler = DockStateRefreshScheduler()
    private let overlayController = DockStateOverlayController()

    private var isRunning = false

    init(resolver: DockItemResolver) {
        self.resolver = resolver

        stateMonitor.onChange = { [weak scheduler] in
            scheduler?.requestImmediateRefresh()
        }
        scheduler.onRefresh = { [weak self] in
            self?.refresh() ?? .slow
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        stateMonitor.start()
        scheduler.start()
    }

    func stop() {
        guard isRunning else {
            overlayController.clear()
            return
        }
        isRunning = false
        stateMonitor.stop()
        scheduler.stop()
        overlayController.clear()
    }

    private func refresh() -> DockStateRefreshScheduler.Pace {
        guard isRunning else {
            overlayController.clear()
            return .slow
        }

        let mainDisplayHeight = Double(CGDisplayBounds(CGMainDisplayID()).height)
        var appKitIconFrames: [CGRect] = []
        var indicators: [DockStateIndicatorPresentation] = []

        let snapshots = resolver.applicationSnapshots()
        for snapshot in snapshots {
            let accessibilityRect = DockIndicatorRect(
                x: Double(snapshot.accessibilityFrame.origin.x),
                y: Double(snapshot.accessibilityFrame.origin.y),
                width: Double(snapshot.accessibilityFrame.size.width),
                height: Double(snapshot.accessibilityFrame.size.height)
            )
            let converted = DockAccessibilityCoordinateConverter.appKitRect(
                from: accessibilityRect,
                mainDisplayHeight: mainDisplayHeight
            )
            let iconFrame = CGRect(
                x: converted.x,
                y: converted.y,
                width: converted.width,
                height: converted.height
            )
            appKitIconFrames.append(iconFrame)

            let state = DockApplicationIndicatorState.resolve(
                instances: snapshot.applications.map {
                    DockRunningApplicationState(
                        isActive: $0.isActive,
                        isHidden: $0.isHidden
                    )
                }
            )
            guard state != .none else { continue }

            let layoutFrame = DockStateIndicatorLayout.frame(for: converted)
            indicators.append(DockStateIndicatorPresentation(
                state: state,
                frame: CGRect(
                    x: layoutFrame.x,
                    y: layoutFrame.y,
                    width: layoutFrame.width,
                    height: layoutFrame.height
                )
            ))
        }

        overlayController.update(indicators: indicators)

        let mouseLocation = NSEvent.mouseLocation
        let pointerNearDock = appKitIconFrames.contains {
            $0.insetBy(dx: -80, dy: -80).contains(mouseLocation)
        }
        return pointerNearDock ? .fast : .slow
    }
}
