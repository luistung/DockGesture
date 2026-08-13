public struct MouseUpSuppressor: Sendable {
    private var suppressedButtons: Set<MouseButton> = []

    public init() {}

    public mutating func beginSuppressing(_ button: MouseButton) {
        suppressedButtons.insert(button)
    }

    public mutating func consumeMouseUp(for button: MouseButton) -> Bool {
        suppressedButtons.remove(button) != nil
    }

    public mutating func reset() {
        suppressedButtons.removeAll()
    }
}
