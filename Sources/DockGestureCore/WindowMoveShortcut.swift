public enum WindowMoveShortcutKey {
    public static let returnKeyCode: UInt16 = 0x24
    public static let keypadEnterKeyCode: UInt16 = 0x4C
}

public enum WindowMoveShortcutEventType: Sendable {
    case keyDown
    case keyUp
}

public struct WindowMoveShortcutModifiers: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let function = WindowMoveShortcutModifiers(rawValue: 1 << 0)
    public static let command = WindowMoveShortcutModifiers(rawValue: 1 << 1)
    public static let option = WindowMoveShortcutModifiers(rawValue: 1 << 2)
    public static let control = WindowMoveShortcutModifiers(rawValue: 1 << 3)
    public static let shift = WindowMoveShortcutModifiers(rawValue: 1 << 4)
    public static let capsLock = WindowMoveShortcutModifiers(rawValue: 1 << 5)
    public static let numericPad = WindowMoveShortcutModifiers(rawValue: 1 << 6)

    public static let conflicting: WindowMoveShortcutModifiers = [
        .command,
        .option,
        .control,
        .shift
    ]
}

public struct WindowMoveShortcutInput: Sendable {
    public let eventType: WindowMoveShortcutEventType
    public let keyCode: UInt16
    public let modifiers: WindowMoveShortcutModifiers
    public let isAutoRepeat: Bool

    public init(
        eventType: WindowMoveShortcutEventType,
        keyCode: UInt16,
        modifiers: WindowMoveShortcutModifiers,
        isAutoRepeat: Bool
    ) {
        self.eventType = eventType
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.isAutoRepeat = isAutoRepeat
    }
}

public enum WindowMoveShortcutDecision: Equatable, Sendable {
    case passThrough
    case suppress
    case triggerAndSuppress
}

public struct WindowMoveShortcutClassifier: Sendable {
    private var suppressedKeyCodes: Set<UInt16> = []

    public init() {}

    public mutating func classify(
        _ input: WindowMoveShortcutInput
    ) -> WindowMoveShortcutDecision {
        switch input.eventType {
        case .keyUp:
            return suppressedKeyCodes.remove(input.keyCode) == nil
                ? .passThrough
                : .suppress

        case .keyDown:
            if suppressedKeyCodes.contains(input.keyCode) {
                return .suppress
            }
            guard isEnterKey(input.keyCode),
                  input.modifiers.contains(.function),
                  input.modifiers.intersection(.conflicting).isEmpty else {
                return .passThrough
            }

            suppressedKeyCodes.insert(input.keyCode)
            if input.isAutoRepeat {
                return .suppress
            }
            return .triggerAndSuppress
        }
    }

    public mutating func reset() {
        suppressedKeyCodes.removeAll()
    }

    private func isEnterKey(_ keyCode: UInt16) -> Bool {
        keyCode == WindowMoveShortcutKey.returnKeyCode
            || keyCode == WindowMoveShortcutKey.keypadEnterKeyCode
    }
}
