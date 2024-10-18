#!/usr/bin/swift

/// Key Binds Manager: A macOS utility for custom keyboard shortcuts
///
/// This script creates a menu bar application that allows users to define and use custom
/// key bindings, effectively remapping certain key combinations to trigger different actions.
///
/// Author: Jon Friesen <jon@jonfriesen.com>
///
/// Usage:
///   $ chmod +x key-binds.swift
///   $ ./key-binds.swift
///
/// Features:
///   - Custom key bindings for system-wide shortcuts
///   - Menu bar interface for easy access and control
///   - Accessibility permissions check and guidance
///   - Toggle to enable/disable key bindings
///
/// Note: This script requires accessibility permissions to function properly.
/// Development time: Approximately 1 hours for initial implementation.
///
/// Dependencies:
///   - macOS 15.0 or later
///   - Swift 6.0 or later

import Cocoa

enum Keycode {
	static let printScreen: UInt16 = 0x69  // F13 on most Mac keyboards
	static let four: UInt16 = 0x15
	static let f14: UInt16 = 0x6B
	static let f: UInt16 = 0x03
}

// Static keybind configuration
enum KeybindConfig {
	static let bindings:
		[(
			trigger: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags),
			action: (keyCode: UInt16, modifiers: NSEvent.ModifierFlags),
			description: String
		)] = [
			// Print Screen (F13) + Command + Shift -> Command + Shift + 4
			(
				(keyCode: Keycode.printScreen, modifiers: [.command, .shift]),
				(keyCode: Keycode.four, modifiers: [.command, .shift]),
				"Print Screen"
			),

			// Print Screen (F13) + Control + Command + Shift -> Control + Command + Shift + 4
			(
				(keyCode: Keycode.printScreen, modifiers: [.control, .command, .shift]),
				(keyCode: Keycode.four, modifiers: [.control, .command, .shift]),
				"Print Screen (with Control)"
			),

			// Example: F14 + Command -> Control + Command + F
			(
				(keyCode: Keycode.f14, modifiers: [.command]),
				(keyCode: Keycode.f, modifiers: [.control, .command]),
				"F14 Command"
			),
		]
}

class KeybindManagerApp: NSObject, NSApplicationDelegate {
	var statusItem: NSStatusItem!
	var enabled = true
	static var shared: KeybindManagerApp?

	let embeddedImageData = """
		iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAAJdJREFUWEftVkEOgCAMKz/Tl6kvw5+pSyAZhCiJzB7cLhwka9cWswByBTI+nIAroBWYACwA5LSsHcB24chZhDB+AJ4HE/C5JnCkr9a5KHA0mBOoFVhTKEcEUkIn/aS6LaATGDF5q0e3AnQCdAvoBOgW0AlkC/Qb7rGldf/Vf4BGgG7B/wjQFxL6Smbl+W1f6/XrcSgn4AqcNWw+IWZP0dIAAAAASUVORK5CYII=
		"""

	override init() {
		super.init()
		KeybindManagerApp.shared = self

		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		setMenuIconV1(for: statusItem, iconData: embeddedImageData, fallbackEmoji: "⌨️")

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
			setupKeyBinds()
		}
	}

	func setupKeyBinds() {
		print("Setting up keybinds...")
		NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard let self = self, self.enabled else { return }

			let modifiers = event.modifierFlags

			for binding in KeybindConfig.bindings {
				if event.keyCode == binding.trigger.keyCode
					&& modifiers.contains(binding.trigger.modifiers)
				{
					print("DEBUG: Keybind triggered - \(binding.description)")
					self.simulateKeyPress(
						keyCode: binding.action.keyCode, modifierFlags: binding.action.modifiers
					)
					break
				}
			}
		}
		print("Keybind setup complete")
	}

	func simulateKeyPress(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
		let keyDownEvent = CGEvent(
			keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true
		)
		keyDownEvent?.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
		keyDownEvent?.post(tap: .cghidEventTap)

		let keyUpEvent = CGEvent(
			keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false
		)
		keyUpEvent?.flags = CGEventFlags(rawValue: UInt64(modifierFlags.rawValue))
		keyUpEvent?.post(tap: .cghidEventTap)
	}

	@objc func toggleEnabled() {
		enabled = !enabled
		statusItem.menu?.item(at: 0)?.state = enabled ? .on : .off
		print("DEBUG: Keybind manager \(enabled ? "enabled" : "disabled")")
	}

	@objc func quit() {
		print("DEBUG: Keybind manager quitting")
		NSApplication.shared.terminate(self)
	}
}

// Set up signal handling for Ctrl-C
func handleInterrupt(signal _: Int32) {
	print("DEBUG: Interrupt signal received, quitting...")
	if let app = KeybindManagerApp.shared {
		app.quit()
	}
}

signal(SIGINT, handleInterrupt)

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

let app = NSApplication.shared
let delegate = KeybindManagerApp()
app.delegate = delegate
app.run()

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
