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

struct DockApplicationItemSnapshot {
    let accessibilityFrame: CGRect
    let applications: [NSRunningApplication]
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

    func applicationSnapshots() -> [DockApplicationItemSnapshot] {
        guard let dockPID = dockProcessIdentifier() else {
            return []
        }

        let dockElement = AXUIElementCreateApplication(dockPID)
        return applicationDockItems(in: dockElement, dockPID: dockPID, depth: 0).compactMap {
            guard let frame = rect(of: $0) else {
                return nil
            }
            let applications = runningApplications(for: $0)
            guard !applications.isEmpty else {
                return nil
            }
            return DockApplicationItemSnapshot(
                accessibilityFrame: frame,
                applications: applications
            )
        }
    }

    private func resolveApplication(
        from element: AXUIElement,
        frontmost: NSRunningApplication?
    ) -> ResolvedDockApplication? {
        let candidates = runningApplications(for: element)

        guard !candidates.isEmpty else { return nil }

        if let frontmost,
           let match = candidates.first(where: { $0.processIdentifier == frontmost.processIdentifier }) {
            return ResolvedDockApplication(application: match)
        }

        guard let regular = candidates.first(where: { $0.activationPolicy == .regular }) else {
            return nil
        }
        return ResolvedDockApplication(application: regular)
    }

    private func dockProcessIdentifier() -> pid_t? {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: dockBundleIdentifier)
            .first?
            .processIdentifier
    }

    private func applicationDockItems(
        in element: AXUIElement,
        dockPID: pid_t,
        depth: Int
    ) -> [AXUIElement] {
        guard depth <= 8, processIdentifier(of: element) == dockPID else {
            return []
        }
        if stringAttribute(kAXSubroleAttribute as CFString, of: element)
            == (kAXApplicationDockItemSubrole as String) {
            return [element]
        }

        return elementsAttribute(kAXChildrenAttribute as CFString, of: element).flatMap {
            applicationDockItems(in: $0, dockPID: dockPID, depth: depth + 1)
        }
    }

    private func runningApplications(ofBundleIdentifier bundleIdentifier: String) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).filter {
            $0.activationPolicy == .regular
        }
    }

    private func runningApplications(for element: AXUIElement) -> [NSRunningApplication] {
        let itemURL = urlAttribute(kAXURLAttribute as CFString, of: element)
        if let itemURL,
           let bundleIdentifier = Bundle(url: itemURL)?.bundleIdentifier {
            let candidates = runningApplications(ofBundleIdentifier: bundleIdentifier)
            let itemPath = itemURL.standardizedFileURL.path
            let exactMatches = candidates.filter {
                $0.bundleURL?.standardizedFileURL.path == itemPath
            }
            return exactMatches.isEmpty ? candidates : exactMatches
        }

        guard let title = stringAttribute(kAXTitleAttribute as CFString, of: element) else {
            return []
        }
        let candidates = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.localizedName == title
        }
        return candidates.count == 1 ? candidates : []
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

    private func elementsAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> [AXUIElement] {
        copyAttribute(attribute, of: element) as? [AXUIElement] ?? []
    }

    private func rect(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(kAXPositionAttribute as CFString, of: element),
              let size = sizeAttribute(kAXSizeAttribute as CFString, of: element),
              size.width > 0,
              size.height > 0 else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func pointAttribute(_ attribute: CFString, of element: AXUIElement) -> CGPoint? {
        guard let value = axValueAttribute(attribute, of: element),
              AXValueGetType(value) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(_ attribute: CFString, of element: AXUIElement) -> CGSize? {
        guard let value = axValueAttribute(attribute, of: element),
              AXValueGetType(value) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValueAttribute(_ attribute: CFString, of element: AXUIElement) -> AXValue? {
        guard let value = copyAttribute(attribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
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
