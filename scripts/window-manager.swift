#!/usr/bin/swift

/// Window Manager: A macOS window management utility
///
/// This script provides hotkey-based window management functionality for macOS,
/// allowing users to quickly resize and position windows using keyboard shortcuts.
///
/// Author: Jon Friesen <jon@jonfriesen.com>
///
/// Usage:
///   $ chmod +x window-manager.swift
///   $ ./window-manager.swift
///
/// Features:
///   - Resize windows to quarters, halves, or full screen
///   - Cycle through different window sizes for left and right sides
///   - Set windows to a reasonable default size
///   - System tray icon for easy access and control
///   - Accessibility permission handling
///
/// This script was developed to enhance productivity by providing quick and easy
/// window management capabilities without the need for a full-fledged window manager.
///
/// Dependencies:
///   - macOS 15.0 or later
///   - Swift 6.0 or later
///   - Accessibility permissions must be granted for the script to function properly

import Cocoa

enum Keycode {
    // numbers
    static let one: UInt16 = 0x12
    static let two: UInt16 = 0x13
    static let three: UInt16 = 0x14
    static let four: UInt16 = 0x15

    // arrow keys
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
}

class WindowManagerApp: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var enabled = true
    static var shared: WindowManagerApp?

    let embeddedImageData = """
        iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAJtJREFUWEftlkEOgDAIBLc/05epL9OfqTQ2MfSAplB6gAuXtixDEzbBOZJzfYSA4QmsABbFf3IA2ABQziER0BZANan4/FWAYvP5qZM3LhHoLmB6Zk5ZI/jMRQL7PSOt4qWB98xFAdWBRgz8vRAQBIJAEAgC7gTIX1CUXBkS611QrRbuB9wFWK9jkYC1IREFNK7//9d7e8IgMB6BC41fOyEyh0mdAAAAAElFTkSuQmCC
        """

    override init() {
        super.init()
        WindowManagerApp.shared = self

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setMenuIconV1(for: statusItem, iconData: embeddedImageData, fallbackEmoji: "🪟")

        let menu = NSMenu()

        let (accessibilityEnabled, accessibilityMessage) = checkAccessibilityAndGetInfoV1()

        if !accessibilityEnabled {
            print(accessibilityMessage)

            let errorMenuItem = NSMenuItem(title: "Disabled", action: nil, keyEquivalent: "")
            errorMenuItem.attributedTitle = NSAttributedString(
                string: "⚠️ Permission Error, check logs for details.",
                attributes: [.foregroundColor: NSColor.red]
            )
            menu.addItem(errorMenuItem)
        } else {
            // Enabled menu item
            let enabledMenuItem = NSMenuItem(
                title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: ""
            )
            enabledMenuItem.state = enabled ? .on : .off
            menu.addItem(enabledMenuItem)
        }

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        // Set the menu to the status item
        statusItem.menu = menu

        if accessibilityEnabled {
            setupHotKeys()
        }
    }

    func setupHotKeys() {
        print("Setting up hotkeys...")
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self
            else {
                print("Self is nil, exiting hotkey handler")
                return
            }

            if !self.enabled {
                print("Window manager is disabled, ignoring hotkey")
                return
            }

            let modifiers: NSEvent.ModifierFlags = [.control, .command]
            if !event.modifierFlags.contains(modifiers) {
                // print("Modifiers don't match, ignoring keypress")
                return
            }

            print("Detected hotkey press. Key code: \(event.keyCode)")

            printFocusedWindow()
            print("---")

            switch event.keyCode
            {
            case Keycode.one:
                print("Activating top left quarter")
                self.topLeftQuarter()
            case Keycode.two:
                print("Activating top right quarter")
                self.topRightQuarter()
            case Keycode.three:
                print("Activating bottom left quarter")
                self.bottomLeftQuarter()
            case Keycode.four:
                print("Activating bottom right quarter")
                self.bottomRightQuarter()
            case Keycode.leftArrow:
                print("Activating left side")
                self.leftSide()
            case Keycode.rightArrow:
                print("Activating right side")
                self.rightSide()
            case Keycode.upArrow:
                print("Activating full screen")
                self.fullScreen()
            case Keycode.downArrow:
                print("Setting to reasonable size")
                self.setToReasonableSize()
            default:
                print("Unrecognized key code: \(event.keyCode)")
            }
        }
        print("Hotkey setup complete")
    }

    @objc func toggleEnabled() {
        enabled = !enabled
        statusItem.menu?.item(at: 0)?.state = enabled ? .on : .off
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }

    // Window management functions
    func topLeftQuarter() { setWindowFrame(CGRect(x: 0, y: 0, width: 0.5, height: 0.5)) }
    func topRightQuarter() { setWindowFrame(CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)) }
    func bottomLeftQuarter() { setWindowFrame(CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)) }
    func bottomRightQuarter() { setWindowFrame(CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)) }

    var leftSideState = 0
    func leftSide() {
        switch leftSideState
        {
        case 0: setWindowFrame(CGRect(x: 0, y: 0, width: 0.5, height: 1))
        case 1: setWindowFrame(CGRect(x: 0, y: 0, width: 2.0 / 3.0, height: 1))
        case 2: setWindowFrame(CGRect(x: 0, y: 0, width: 1.0 / 3.0, height: 1))
        default: break
        }
        leftSideState = (leftSideState + 1) % 3
    }

    var rightSideState = 0
    func rightSide() {
        switch rightSideState
        {
        case 0: setWindowFrame(CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        case 1: setWindowFrame(CGRect(x: 1.0 / 3.0, y: 0, width: 2.0 / 3.0, height: 1))
        case 2: setWindowFrame(CGRect(x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1))
        default: break
        }
        rightSideState = (rightSideState + 1) % 3
    }

    var fullScreenState = 0
    func fullScreen() {
        switch fullScreenState
        {
        case 0: setWindowFrame(CGRect(x: 0.125, y: 0, width: 0.75, height: 1))
        case 1: setWindowFrame(CGRect(x: 0, y: 0, width: 1, height: 1))
        default: break
        }
        fullScreenState = (fullScreenState + 1) % 2
    }

    func setToReasonableSize() {
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let aspectRatio: CGFloat = 1024.0 / 768.0

            // Calculate 60% of the screen size
            let maxWidth = screenFrame.width * 0.6
            let maxHeight = screenFrame.height * 0.6

            // Determine the window size while maintaining aspect ratio
            var windowWidth: CGFloat
            var windowHeight: CGFloat

            if maxWidth / aspectRatio <= maxHeight {
                windowWidth = maxWidth
                windowHeight = windowWidth / aspectRatio
            } else {
                windowHeight = maxHeight
                windowWidth = windowHeight * aspectRatio
            }

            // Ensure the size is at least 1024x768
            windowWidth = max(windowWidth, 1024)
            windowHeight = max(windowHeight, 768)

            // Calculate the position to center the window
            let x = (screenFrame.width - windowWidth) / 2
            let y = (screenFrame.height - windowHeight) / 2

            setWindowFrame(
                CGRect(x: x, y: y, width: windowWidth, height: windowHeight), absolute: true
            )
        }
    }

    func setWindowFrame(_ rect: CGRect, absolute: Bool = false) {
        print("setWindowFrame called with rect: \(rect), absolute: \(absolute)")

        if let (_, window) = getFocusedWindow() {
            print("Found window: \(window)")

            guard let screen = NSScreen.main
            else {
                print("Error: Unable to get main screen")
                return
            }

            var newFrame: CGRect
            // let screenFrame = window.screen?.frame ?? NSScreen.main!.frame
            let screenFrame = screen.frame

            print(
                "Debug: screenFrame = x: \(screenFrame.origin.x), y: \(screenFrame.origin.y), width: \(screenFrame.width), height: \(screenFrame.height)"
            )

            if absolute {
                newFrame = rect
                print("Using absolute positioning")
            } else {
                newFrame = CGRect(
                    x: screenFrame.origin.x + rect.origin.x * screenFrame.width,
                    y: screenFrame.origin.y + rect.origin.y * screenFrame.height,
                    width: rect.width * screenFrame.width,
                    height: rect.height * screenFrame.height
                )
                print("Calculated relative positioning")
            }

            print(
                "Debug: newFrame = x: \(newFrame.origin.x), y: \(newFrame.origin.y), width: \(newFrame.width), height: \(newFrame.height)"
            )

            resizeWindow(element: window, to: newFrame)
        } else {
            print("No window found")
        }
    }

    func resizeWindow(element: AXUIElement, to frame: CGRect) {
        var point = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var newSize = CGSize(width: frame.width, height: frame.height)

        print("Debug: point = x: \(point.x), y: \(point.y)")
        print("Debug: newSize = width: \(newSize.width), height: \(newSize.height)")

        AXUIElementSetAttributeValue(
            element, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &point)!
        )
        AXUIElementSetAttributeValue(
            element, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &newSize)!
        )
    }

    func printFocusedWindow() {
        if let (app, window) = getFocusedWindow() {
            var appName: AnyObject?
            AXUIElementCopyAttributeValue(app, kAXTitleAttribute as CFString, &appName)

            var windowTitle: AnyObject?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &windowTitle)

            print("Focused App: \(appName as? String ?? "Unknown")")
            print("Focused Window: \(windowTitle as? String ?? "Unknown")")
        } else {
            print("Unable to get focused window")
        }
    }

    func getFocusedWindow() -> (AXUIElement, AXUIElement)? {
        print("Attempting to get focused window...")
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp
        )

        if appResult != .success {
            print("Error getting focused application: \(appResult)")
            return getFocusedWindowFallback()
        }

        guard let app = focusedApp, CFGetTypeID(app) == AXUIElementGetTypeID()
        else {
            print("Invalid focused application")
            return getFocusedWindowFallback()
        }

        var focusedWindow: AnyObject?
        let windowResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow
        )

        if windowResult != .success {
            print("Error getting focused window: \(windowResult)")
            return getFocusedWindowFallback()
        }

        guard let window = focusedWindow, CFGetTypeID(window) == AXUIElementGetTypeID()
        else {
            print("Invalid focused window")
            return getFocusedWindowFallback()
        }

        print("Successfully got focused window using Accessibility API")
        return (app as! AXUIElement, window as! AXUIElement)
    }

    func getFocusedWindowFallback() -> (AXUIElement, AXUIElement)? {
        print("Attempting to get focused window using CGWindowList fallback...")
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        let windowList =
            CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []

        let focusedWindows = windowList.filter { ($0[kCGWindowLayer as String] as? Int ?? 0) == 0 }

        guard let frontmostWindow = focusedWindows.first,
            // let windowNumber = frontmostWindow[kCGWindowNumber as String] as? Int,
            let ownerPID = frontmostWindow[kCGWindowOwnerPID as String] as? pid_t
        else {
            print("No frontmost window found")
            return nil
        }

        let app = AXUIElementCreateApplication(ownerPID)
        var window: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &window)

        guard result == .success,
            let windowList = window as? [AXUIElement],
            let firstWindow = windowList.first
        else {
            print("Error getting window from application: \(result)")
            return nil
        }

        print("Successfully got focused window using CGWindowList fallback")
        return (app, firstWindow)
    }
}

// Set up signal handling for Ctrl-C
func handleInterrupt(signal _: Int32) {
    if let app = WindowManagerApp.shared {
        app.quit()
    }
}

signal(SIGINT, handleInterrupt)

let app = NSApplication.shared
let delegate = WindowManagerApp()
app.delegate = delegate
app.run()

// Tools

func checkAccessibilityAndGetInfoV1() -> (isEnabled: Bool, message: String) {
    func getParentProcessName() -> String {
        let parentPID = getppid()
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-p", String(parentPID), "-o", "comm="]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return "Unknown"
    }

    let parentApp = getParentProcessName()
    var message = "Checking accessibility permissions...\n"

    let isAccessibilityEnabled = AXIsProcessTrusted()

    if isAccessibilityEnabled {
        message += "Accessibility permissions are granted.\n"
        message += "The script is running under: \(parentApp)"
    } else {
        message += "🚨 Accessibility permissions are not granted.\n"
        message += "The script is running under: \(parentApp)\n"
        message += "\nPlease follow these steps to grant permissions:\n"
        message += "1. Open System Preferences\n"
        message += "2. Go to Security & Privacy > Privacy > Accessibility\n"
        message += "3. Click the lock icon to make changes\n"
        message += "4. Find and check the box next to \(parentApp)\n"
        message += "5. If \(parentApp) is not in the list, click the '+' button and add it\n"
        message += "6. You may need to restart \(parentApp) after granting permissions\n"
        message +=
            "\nNote: If \(parentApp) is not the application you're using to run this script,\n"
        message += "please grant permissions to the actual application you're using."
    }

    return (isAccessibilityEnabled, message)
}
func setMenuIconV1(for statusItem: NSStatusItem, iconData: String, fallbackEmoji: String) {
    if let button = statusItem.button {
        if let imageData = Data(base64Encoded: iconData),
            let image = NSImage(data: imageData)
        {
            button.image = image
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            print("Successfully loaded and set embedded icon image")
        } else {
            print("Failed to load icon image")
        }

        if button.image == nil {
            print("Image not set. Falling back to emoji.")
            button.title = fallbackEmoji
        }
    } else {
        print("Failed to get button from statusItem")
    }
}
