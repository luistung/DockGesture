import AppKit
import ApplicationServices

final class ResolvedDockApplication: @unchecked Sendable {
    let application: NSRunningApplication
    let name: String

    init(application: NSRunningApplication) {
        self.application = application
        self.name = application.localizedName ?? application.bundleIdentifier ?? "未知应用"
    }
}

final class DockItemResolver {
    private let systemWideElement = AXUIElementCreateSystemWide()
    private let dockBundleIdentifier = "com.apple.dock"

    func resolve(at point: CGPoint, frontmost: NSRunningApplication?) -> ResolvedDockApplication? {
        guard let dockPID = NSRunningApplication
            .runningApplications(withBundleIdentifier: dockBundleIdentifier)
            .first?
            .processIdentifier else {
            return nil
        }

        var hitElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWideElement,
            Float(point.x),
            Float(point.y),
            &hitElement
        )
        guard error == .success, var current = hitElement else {
            return nil
        }

        for _ in 0..<7 {
            guard processIdentifier(of: current) == dockPID else {
                return nil
            }

            if stringAttribute(kAXSubroleAttribute as CFString, of: current)
                == (kAXApplicationDockItemSubrole as String) {
                return resolveApplication(from: current, frontmost: frontmost)
            }

            guard let parent = elementAttribute(kAXParentAttribute as CFString, of: current) else {
                return nil
            }
            current = parent
        }

        return nil
    }

    private func resolveApplication(
        from element: AXUIElement,
        frontmost: NSRunningApplication?
    ) -> ResolvedDockApplication? {
        let itemURL = urlAttribute(kAXURLAttribute as CFString, of: element)
        let itemBundleIdentifier = itemURL.flatMap { Bundle(url: $0)?.bundleIdentifier }

        let candidates: [NSRunningApplication]
        if let itemBundleIdentifier {
            candidates = NSRunningApplication.runningApplications(
                withBundleIdentifier: itemBundleIdentifier
            )
        } else {
            let title = stringAttribute(kAXTitleAttribute as CFString, of: element)
            guard let title else { return nil }
            candidates = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular && $0.localizedName == title
            }
            guard candidates.count == 1 else { return nil }
        }

        guard !candidates.isEmpty else { return nil }

        if let frontmost,
           let match = candidates.first(where: { $0.processIdentifier == frontmost.processIdentifier }) {
            return ResolvedDockApplication(application: match)
        }

        if let itemURL {
            let itemPath = itemURL.standardizedFileURL.path
            if let exactMatch = candidates.first(where: {
                $0.bundleURL?.standardizedFileURL.path == itemPath
            }) {
                return ResolvedDockApplication(application: exactMatch)
            }
        }

        guard let regular = candidates.first(where: { $0.activationPolicy == .regular }) else {
            return nil
        }
        return ResolvedDockApplication(application: regular)
    }

    private func processIdentifier(of element: AXUIElement) -> pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else {
            return nil
        }
        return pid
    }

    private func copyAttribute(_ attribute: CFString, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        copyAttribute(attribute, of: element) as? String
    }

    private func urlAttribute(_ attribute: CFString, of element: AXUIElement) -> URL? {
        guard let value = copyAttribute(attribute, of: element) else {
            return nil
        }
        if CFGetTypeID(value) == CFURLGetTypeID() {
            return value as? URL
        }
        if let string = value as? String {
            return URL(string: string)
        }
        return nil
    }

    private func elementAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> AXUIElement? {
        guard let value = copyAttribute(attribute, of: element),
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXUIElement.self)
    }
}
