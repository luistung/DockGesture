import AppKit
import DockGestureCore

final class AppActionController {
    var onResult: ((String) -> Void)?

    func perform(_ action: ApplicationAction, on resolved: ResolvedDockApplication) {
        let target = RunningApplicationTarget(application: resolved.application)
        let accepted = ApplicationActionExecutor.perform(action, on: target)
        let verb: String

        switch action {
        case .hide:
            verb = "隐藏"
        case .terminate:
            verb = "退出"
        case .forceTerminate:
            verb = "强制退出"
        }

        let result = accepted ? "请求已接受" : "请求失败"
        onResult?("\(verb) \(resolved.name)：\(result)")
    }
}

private final class RunningApplicationTarget: ApplicationActionTarget {
    private let application: NSRunningApplication

    init(application: NSRunningApplication) {
        self.application = application
    }

    func hide() -> Bool {
        application.hide()
    }

    func terminate() -> Bool {
        application.terminate()
    }

    func forceTerminate() -> Bool {
        application.forceTerminate()
    }
}
