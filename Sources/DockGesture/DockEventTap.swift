import AppKit
import CoreGraphics
import DockGestureCore

private func dockGestureEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<DockEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    return eventTap.handle(type: type, event: event)
}

final class DockEventTap: @unchecked Sendable {
    var onAction: ((ApplicationAction, ResolvedDockApplication) -> Void)?
    var onWindowMoveShortcut: (() -> Void)?
    var onFailure: ((String) -> Void)?

    private let resolver: DockItemResolver
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var suppressor = MouseUpSuppressor()
    private var windowMoveShortcutClassifier = WindowMoveShortcutClassifier()

    init(resolver: DockItemResolver) {
        self.resolver = resolver
    }

    var isRunning: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func start() -> Bool {
        if isRunning {
            return true
        }
        stop()

        let eventTypes: [CGEventType] = [
            .leftMouseDown,
            .leftMouseUp,
            .rightMouseDown,
            .rightMouseUp,
            .keyDown,
            .keyUp
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) {
            $0 | (CGEventMask(1) << $1.rawValue)
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: dockGestureEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            onFailure?("无法创建输入事件监听")
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        tap = newTap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    func stop() {
        suppressor.reset()
        windowMoveShortcutClassifier.reset()
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            windowMoveShortcutClassifier.reset()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown || type == .keyUp {
            return handleKeyboard(type: type, event: event)
        }

        guard let button = mouseButton(for: type) else {
            return Unmanaged.passUnretained(event)
        }

        if type == .leftMouseUp || type == .rightMouseUp {
            if suppressor.consumeMouseUp(for: button) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        // A mouse-up can be lost if a device disconnects or the tap is
        // temporarily disabled. Never let stale suppression affect a later
        // physical click.
        _ = suppressor.consumeMouseUp(for: button)

        let modifiers = gestureModifiers(from: event.flags)
        guard GestureClassifier.mayHandle(button: button, modifiers: modifiers) else {
            return Unmanaged.passUnretained(event)
        }

        let frontmost = NSWorkspace.shared.frontmostApplication
        guard let resolved = resolver.resolve(at: event.location, frontmost: frontmost) else {
            return Unmanaged.passUnretained(event)
        }

        let isFrontmost = frontmost?.processIdentifier == resolved.application.processIdentifier
        let decision = GestureClassifier.classify(.init(
            button: button,
            modifiers: modifiers,
            isDockApplication: true,
            isTargetFrontmost: isFrontmost
        ))

        guard case .perform(let action) = decision else {
            return Unmanaged.passUnretained(event)
        }

        suppressor.beginSuppressing(button)
        DispatchQueue.main.async { [weak self] in
            self?.onAction?(action, resolved)
        }
        return nil
    }

    private func mouseButton(for type: CGEventType) -> MouseButton? {
        switch type {
        case .leftMouseDown, .leftMouseUp:
            return .left
        case .rightMouseDown, .rightMouseUp:
            return .right
        default:
            return nil
        }
    }

    private func gestureModifiers(from flags: CGEventFlags) -> GestureModifiers {
        var result: GestureModifiers = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }

    private func handleKeyboard(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        let input = WindowMoveShortcutInput(
            eventType: type == .keyDown ? .keyDown : .keyUp,
            keyCode: UInt16(truncatingIfNeeded: event.getIntegerValueField(
                .keyboardEventKeycode
            )),
            modifiers: windowMoveModifiers(from: event.flags),
            isAutoRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )

        switch windowMoveShortcutClassifier.classify(input) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .suppress:
            return nil
        case .triggerAndSuppress:
            DispatchQueue.main.async { [weak self] in
                self?.onWindowMoveShortcut?()
            }
            return nil
        }
    }

    private func windowMoveModifiers(
        from flags: CGEventFlags
    ) -> WindowMoveShortcutModifiers {
        var result: WindowMoveShortcutModifiers = []
        if flags.contains(.maskSecondaryFn) { result.insert(.function) }
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskAlternate) { result.insert(.option) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        if flags.contains(.maskAlphaShift) { result.insert(.capsLock) }
        if flags.contains(.maskNumericPad) { result.insert(.numericPad) }
        return result
    }
}
