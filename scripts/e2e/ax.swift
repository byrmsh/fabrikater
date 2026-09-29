// Reads and presses elements in the app's front window for scripts/e2e/lib.sh. It walks the accessibility tree in one
// process, where System Events needs one Apple Event per element and attribute and took seconds per check
// (docs/decisions/0014). scripts/e2e.sh compiles it to build/e2e-ax.
//   e2e-ax check                    fails unless this process may use the Accessibility API
//   e2e-ax PID text [ATTRIBUTE...]  every text attribute in the front window, one per line, elements in tree order
//   e2e-ax PID dump                 every element with its role, child count and attributes
//   e2e-ax PID press TEXT           presses the first element whose title, description or help tag is TEXT
//   e2e-ax PID focus TEXT           focuses the first element whose placeholder contains TEXT
//   e2e-ax PID disclose TEXT        presses the first disclosure triangle with a child whose value is TEXT
//   e2e-ax PID focused-value        prints the value of the app's focused element
//   e2e-ax PID focused-placeholder  prints the placeholder of the app's focused element
// Exits 1 when the window or element is missing, 2 on a usage or access error.

import ApplicationServices
import Foundation

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("e2e-ax: \(message)\n".utf8))
    exit(status)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

/// An attribute value as System Events' `as text` gives it: strings and numbers, never empty.
func text(_ value: CFTypeRef?) -> String? {
    guard let value else { return nil }
    if CFGetTypeID(value) == CFStringGetTypeID() {
        let string = value as! String
        return string.isEmpty ? nil : string
    }
    if CFGetTypeID(value) == CFNumberGetTypeID() || CFGetTypeID(value) == CFBooleanGetTypeID() {
        return (value as! NSNumber).stringValue
    }
    return nil
}

func texts(_ element: AXUIElement, _ names: [String]) -> [String?] {
    var values: CFArray?
    guard
        AXUIElementCopyMultipleAttributeValues(element, names as CFArray, AXCopyMultipleAttributeOptions(), &values)
            == .success, let values = values as? [AnyObject], values.count == names.count
    else { return names.map { _ in nil } }
    return values.map { text($0) }
}

func children(_ element: AXUIElement) -> [AXUIElement] {
    (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
}

/// Every element under `root`, depth first in tree order, as System Events' `entire contents` lists them.
func descendants(_ root: AXUIElement) -> [AXUIElement] {
    var found: [AXUIElement] = []
    func visit(_ element: AXUIElement) {
        for child in children(element) {
            found.append(child)
            visit(child)
        }
    }
    visit(root)
    return found
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard AXIsProcessTrusted() else {
    fail("this process may not use the Accessibility API; grant it in Privacy & Security › Accessibility", status: 2)
}
if arguments == ["check"] {
    exit(0)
}
guard arguments.count >= 2, let pid = pid_t(arguments[0]) else {
    fail("usage: e2e-ax PID text|dump|press|focus|disclose|focused-value|focused-placeholder [ARGUMENT...]", status: 2)
}
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 5)
let command = arguments[1]
let operand = arguments.count > 2 ? arguments[2] : ""

if command == "focused-value" || command == "focused-placeholder" {
    let name = command == "focused-value" ? kAXValueAttribute : "AXPlaceholderValue"
    guard let focused = attribute(app, kAXFocusedUIElementAttribute),
        let value = text(attribute(focused as! AXUIElement, name))
    else { exit(1) }
    print(value)
    exit(0)
}

guard let window = (attribute(app, kAXWindowsAttribute) as? [AXUIElement])?.first else {
    fail("process \(pid) has no window", status: 1)
}
let elements = descendants(window)

switch command {
case "text":
    let names = arguments.count > 2 ? Array(arguments[2...]) : ["AXTitle", "AXValue", "AXDescription", "AXHelp"]
    var lines: [String] = []
    for element in elements {
        lines += texts(element, names).compactMap { $0 }
    }
    print(lines.joined(separator: "\n"))
case "dump":
    for element in elements {
        var line = text(attribute(element, kAXRoleAttribute)) ?? ""
        let count = children(element).count
        if count > 0 { line += " children=\(count)" }
        var names: CFArray?
        if AXUIElementCopyAttributeNames(element, &names) == .success, let names = names as? [String] {
            for name in names {
                guard let value = attribute(element, name) else { continue }
                if let string = text(value) {
                    line += " \(name)=\(string)"
                } else {
                    line += " \(name)(\(CFCopyTypeIDDescription(CFGetTypeID(value)) as String))"
                }
            }
        }
        print(line)
    }
case "press":
    guard
        let target = elements.first(where: {
            texts($0, ["AXTitle", "AXDescription", "AXHelp"]).contains(operand)
        })
    else { exit(1) }
    guard AXUIElementPerformAction(target, kAXPressAction as CFString) == .success else { exit(1) }
case "focus":
    guard
        let target = elements.first(where: {
            text(attribute($0, "AXPlaceholderValue"))?.contains(operand) == true
        })
    else { exit(1) }
    guard AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success
    else { exit(1) }
case "disclose":
    guard
        let target = elements.first(where: { element in
            text(attribute(element, kAXRoleAttribute)) == "AXDisclosureTriangle"
                && children(element).contains { text(attribute($0, kAXValueAttribute)) == operand }
        })
    else { exit(1) }
    guard AXUIElementPerformAction(target, kAXPressAction as CFString) == .success else { exit(1) }
default:
    fail("unknown command \(command)", status: 2)
}
