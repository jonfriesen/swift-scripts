#!/usr/bin/swift

/// Scroll Reverser: A customizable scroll direction manager for macOS
///
/// This script creates a menu bar application that allows users to reverse
/// scroll direction independently for mouse and trackpad, with separate
/// controls for vertical and horizontal scrolling.
///
/// Author: Jon Friesen <jon@jonfriesen.com>
///
/// Usage:
///   $ chmod +x scroll-reverser.swift
///   $ ./scroll-reverser.swift
///
/// Features:
///   - Separate controls for mouse and trackpad scrolling
///   - Independent vertical and horizontal scroll reversal
///   - Menu bar icon for easy access to settings
///   - Persists user preferences across app restarts
///
/// Development time: Approximately 1.5 hours
///
/// Dependencies:
///   - macOS 15.0 or later
///   - Swift 6.0 or later

import Cocoa

class ScrollReverserApp: NSObject, NSApplicationDelegate {
	let domain = "ca.jonfriesen.scrollreverser"
	var statusItem: NSStatusItem!
	var eventTap: CFMachPort?
	var runLoopSource: CFRunLoopSource?
	var lastSource: ScrollEventSource = .mouse
	var menuItems: [String: NSMenuItem] = [:]

	let embeddedImageData = """
		iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAAAXNSR0IArs4c6QAAATtJREFUWEftlwEOwiAMRbuTqSdTT6aeTPcXmlQs7Z9kEqMkhsRB/2tX4TvJ4DEN1pc1AHsRwWdXZo/9KiK3+cGJTYwFQMAjG7SsOzMgDIAVR4YIjBnjXmaNo1VS2BQiA7DiByOsxagB9Hu7L4TIAFSgFaQFABBU41KIPPjlUQSgWUQZRACIDwCANGNEALq5Se/0QN2nWgX0DOK8jAggKy8aDQIYdXNaobBK7wJodaxQK8tNAOqgkcj3A0QHoL5CzZJZ+7SG6QEm6KYAHuRv9YBXgeE/QxxAQw+iNdZgk3PgD/CRCjDXcQbSdR2rIWne5Zn6/Dw1NdFRTFmqAML6wqZO5glpc1mBWPguU4q4NQReidpyz4LZA6rblns2m3j1y5JUPHPFnhCqwfw1i6pE+wE20651WRN2BWc2PwA88Wch3B/HAQAAAABJRU5ErkJggg==
		"""

	enum ScrollEventSource {
		case mouse, trackpad
	}

	override init() {
		super.init()
		registerDefaults()
		setupStatusItem()
		startEventTap()
	}

	func setupStatusItem() {
		statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
		updateStatusItemTitle()

		let menu = NSMenu()

		addMenuItem(
			to: menu, title: "Enable Scroll Reverser", action: #selector(toggleEnabled),
			key: "enabled"
		)
		menu.addItem(NSMenuItem.separator())

		let mouseMenu = NSMenu()
		addMenuItem(
			to: mouseMenu, title: "Reverse Vertical", action: #selector(toggleMouseVertical),
			key: "mouse.vertical"
		)
		addMenuItem(
			to: mouseMenu, title: "Reverse Horizontal", action: #selector(toggleMouseHorizontal),
			key: "mouse.horizontal"
		)
		let mouseItem = NSMenuItem(title: "Mouse", action: nil, keyEquivalent: "")
		mouseItem.submenu = mouseMenu
		menu.addItem(mouseItem)

		let trackpadMenu = NSMenu()
		addMenuItem(
			to: trackpadMenu, title: "Reverse Vertical", action: #selector(toggleTrackpadVertical),
			key: "trackpad.vertical"
		)
		addMenuItem(
			to: trackpadMenu, title: "Reverse Horizontal",
			action: #selector(toggleTrackpadHorizontal), key: "trackpad.horizontal"
		)
		let trackpadItem = NSMenuItem(title: "Trackpad", action: nil, keyEquivalent: "")
		trackpadItem.submenu = trackpadMenu
		menu.addItem(trackpadItem)

		menu.addItem(NSMenuItem.separator())
		menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

		statusItem.menu = menu
	}

	func addMenuItem(to menu: NSMenu, title: String, action: Selector, key: String) {
		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.state = UserDefaults.standard.bool(forKey: "\(domain).\(key)") ? .on : .off
		menu.addItem(item)
		menuItems[key] = item
	}

	func registerDefaults() {
		let defaults: [String: Any] = [
			"\(domain).enabled": true,
			"\(domain).mouse.vertical": true,
			"\(domain).mouse.horizontal": true,
			"\(domain).trackpad.vertical": true,
			"\(domain).trackpad.horizontal": true,
		]
		UserDefaults.standard.register(defaults: defaults)
	}

	@objc func toggleEnabled() { toggleSetting(forKey: "enabled") }
	@objc func toggleMouseVertical() { toggleSetting(forKey: "mouse.vertical") }
	@objc func toggleMouseHorizontal() { toggleSetting(forKey: "mouse.horizontal") }
	@objc func toggleTrackpadVertical() { toggleSetting(forKey: "trackpad.vertical") }
	@objc func toggleTrackpadHorizontal() { toggleSetting(forKey: "trackpad.horizontal") }

	func toggleSetting(forKey key: String) {
		let fullKey = "\(domain).\(key)"
		let newValue = !UserDefaults.standard.bool(forKey: fullKey)
		UserDefaults.standard.set(newValue, forKey: fullKey)

		if let item = menuItems[key] {
			item.state = newValue ? .on : .off
		}

		if key == "enabled" {
			updateStatusItemTitle()
		}

		// Debug logging
		print("Setting changed: \(key) is now \(newValue)")
		printCurrentSettings()
	}

	func updateStatusItemTitle() {
		setMenuIconV1(for: statusItem, iconData: embeddedImageData, fallbackEmoji: "🖱️")
	}

	func printCurrentSettings() {
		print("Current settings:")
		print("  Enabled: \(UserDefaults.standard.bool(forKey: "\(domain).enabled"))")
		print("  Mouse Vertical: \(UserDefaults.standard.bool(forKey: "\(domain).mouse.vertical"))")
		print(
			"  Mouse Horizontal: \(UserDefaults.standard.bool(forKey: "\(domain).mouse.horizontal"))"
		)
		print(
			"  Trackpad Vertical: \(UserDefaults.standard.bool(forKey: "\(domain).trackpad.vertical"))"
		)
		print(
			"  Trackpad Horizontal: \(UserDefaults.standard.bool(forKey: "\(domain).trackpad.horizontal"))"
		)
	}

	@objc func quit() {
		NSApplication.shared.terminate(self)
	}

	func startEventTap() {
		let eventMask = (1 << CGEventType.scrollWheel.rawValue)
		guard
			let tap = CGEvent.tapCreate(
				tap: .cghidEventTap,
				place: .headInsertEventTap,
				options: .defaultTap,
				eventsOfInterest: CGEventMask(eventMask),
				callback: { _, type, event, userInfo in
					let reverser = Unmanaged<ScrollReverserApp>.fromOpaque(userInfo!)
						.takeUnretainedValue()
					return reverser.handleEvent(type: type, event: event)
				},
				userInfo: Unmanaged.passUnretained(self).toOpaque()
			)
		else {
			print("Failed to create event tap")
			return
		}

		eventTap = tap
		runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
		CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
		CGEvent.tapEnable(tap: tap, enable: true)
		print("Scroll Reverser started")
		printCurrentSettings()
	}

	func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent> {
		if type == .scrollWheel {
			return handleScrollEvent(event: event)
		}
		return Unmanaged.passUnretained(event)
	}

	func handleScrollEvent(event: CGEvent) -> Unmanaged<CGEvent> {
		let enabled = UserDefaults.standard.bool(forKey: "\(domain).enabled")
		guard enabled
		else {
			return Unmanaged.passUnretained(event)
		}

		let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
		let source = determineScrollSource(continuous: continuous)

		let deltaY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
		let deltaX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
		let pointDeltaY = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
		let pointDeltaX = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
		let fixedPtDeltaY = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
		let fixedPtDeltaX = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)

		let reverseVertical: Bool
		let reverseHorizontal: Bool

		switch source
		{
		case .mouse:
			reverseVertical = UserDefaults.standard.bool(forKey: "\(domain).mouse.vertical")
			reverseHorizontal = UserDefaults.standard.bool(forKey: "\(domain).mouse.horizontal")
		case .trackpad:
			reverseVertical = UserDefaults.standard.bool(forKey: "\(domain).trackpad.vertical")
			reverseHorizontal = UserDefaults.standard.bool(forKey: "\(domain).trackpad.horizontal")
		}

		if reverseVertical {
			event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -deltaY)
			event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pointDeltaY)
			event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedPtDeltaY)
		}
		if reverseHorizontal {
			event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -deltaX)
			event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -pointDeltaX)
			event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixedPtDeltaX)
		}

		return Unmanaged.passRetained(event)
	}

	func determineScrollSource(continuous: Bool) -> ScrollEventSource {
		return continuous ? .trackpad : .mouse
	}
}

// Set up signal handling for Ctrl-C
func handleInterrupt(signal _: Int32) {
	print("Interrupted, exiting...")
	exit(0)
}

signal(SIGINT, handleInterrupt)

let app = NSApplication.shared
let delegate = ScrollReverserApp()
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
