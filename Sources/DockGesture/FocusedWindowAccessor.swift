import AppKit
import ApplicationServices

enum FocusedWindowAccessFailure: Error {
    case noFrontmostApplication
    case noFocusedWindow
    case invalidPosition
    case invalidSize
}

@MainActor
struct FocusedWindowSnapshot {
    let element: AXUIElement
    let title: String?
    let frame: CGRect
    let positionIsSettable: Bool
    let sizeIsSettable: Bool
}

@MainActor
final class FocusedWindowAccessor {
    func readFocusedWindow() -> Result<FocusedWindowSnapshot, FocusedWindowAccessFailure> {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return .failure(.noFrontmostApplication)
        }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        AXUIElementSetMessagingTimeout(applicationElement, 1)
        guard let window = elementAttribute(
            kAXFocusedWindowAttribute as CFString,
            of: applicationElement
        ) else {
            return .failure(.noFocusedWindow)
        }
        guard let position = pointAttribute(kAXPositionAttribute as CFString, of: window) else {
            return .failure(.invalidPosition)
        }
        guard let size = sizeAttribute(kAXSizeAttribute as CFString, of: window),
              size.width > 0,
              size.height > 0 else {
            return .failure(.invalidSize)
        }

        return .success(FocusedWindowSnapshot(
            element: window,
            title: stringAttribute(kAXTitleAttribute as CFString, of: window),
            frame: CGRect(origin: position, size: size),
            positionIsSettable: isAttributeSettable(
                kAXPositionAttribute as CFString,
                of: window
            ),
            sizeIsSettable: isAttributeSettable(
                kAXSizeAttribute as CFString,
                of: window
            )
        ))
    }

    func setPosition(_ position: CGPoint, of window: AXUIElement) -> AXError {
        var position = position
        guard let value = AXValueCreate(.cgPoint, &position) else {
            return .illegalArgument
        }
        return AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            value
        )
    }

    func setSize(_ size: CGSize, of window: AXUIElement) -> AXError {
        var size = size
        guard let value = AXValueCreate(.cgSize, &size) else {
            return .illegalArgument
        }
        return AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            value
        )
    }

    private func copyAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        return value
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

    private func stringAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> String? {
        copyAttribute(attribute, of: element) as? String
    }

    private func pointAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> CGPoint? {
        guard let value = axValueAttribute(attribute, of: element),
              AXValueGetType(value) == .cgPoint else {
            return nil
        }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func sizeAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> CGSize? {
        guard let value = axValueAttribute(attribute, of: element),
              AXValueGetType(value) == .cgSize else {
            return nil
        }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func axValueAttribute(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> AXValue? {
        guard let value = copyAttribute(attribute, of: element),
              CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return unsafeDowncast(value, to: AXValue.self)
    }

    private func isAttributeSettable(
        _ attribute: CFString,
        of element: AXUIElement
    ) -> Bool {
        var settable = DarwinBoolean(false)
        return AXUIElementIsAttributeSettable(element, attribute, &settable) == .success
            && settable.boolValue
    }
}
