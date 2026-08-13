public enum GestureClassifier {
    public static func classify(_ input: GestureInput) -> GestureDecision {
        guard input.isDockApplication else {
            return .passThrough
        }

        let modifiers = input.modifiers.intersection(.meaningful)

        switch input.button {
        case .left:
            guard modifiers.isEmpty, input.isTargetFrontmost else {
                return .passThrough
            }
            return .perform(.hide)

        case .right:
            guard modifiers.contains(.command),
                  !modifiers.contains(.control),
                  !modifiers.contains(.shift) else {
                return .passThrough
            }

            if modifiers.contains(.option) {
                return .perform(.forceTerminate)
            }
            return .perform(.terminate)
        }
    }

    public static func mayHandle(button: MouseButton, modifiers: GestureModifiers) -> Bool {
        let modifiers = modifiers.intersection(.meaningful)

        switch button {
        case .left:
            return modifiers.isEmpty
        case .right:
            return modifiers.contains(.command)
                && !modifiers.contains(.control)
                && !modifiers.contains(.shift)
        }
    }
}
