public protocol ApplicationActionTarget: AnyObject {
    @discardableResult func hide() -> Bool
    @discardableResult func terminate() -> Bool
    @discardableResult func forceTerminate() -> Bool
}

public enum ApplicationActionExecutor {
    @discardableResult
    public static func perform(
        _ action: ApplicationAction,
        on target: ApplicationActionTarget
    ) -> Bool {
        switch action {
        case .hide:
            return target.hide()
        case .terminate:
            return target.terminate()
        case .forceTerminate:
            return target.forceTerminate()
        }
    }
}
