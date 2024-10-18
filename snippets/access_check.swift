#!/usr/bin/swift

import ApplicationServices
import Foundation

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

// Main script execution
print("Accessibility Check Tool")
print("=======================")

// Call the function to check accessibility and get the result
let (accessibilityEnabled, accessibilityMessage) = checkAccessibilityAndGetInfoV1()

// Print the message
print(accessibilityMessage)

// Demonstrate use of the boolean value
if accessibilityEnabled {
	print(
		"\nAccessibility is enabled. You can proceed with tasks that require accessibility permissions."
	)
	// Your code that requires accessibility permissions would go here
} else {
	print(
		"\nAccessibility is not enabled. Please grant the necessary permissions before proceeding.")
	// Handle the case where accessibility is not enabled
}

// Example of how you might use this in a larger script
func performAccessibilityRequiringTask() {
	print("Performing a task that requires accessibility permissions...")
	// Your actual task code would go here
}

print("\nAttempting to perform a task that requires accessibility:")
if accessibilityEnabled {
	performAccessibilityRequiringTask()
} else {
	print("Cannot perform the task. Accessibility permissions are required.")
}

print("\nScript execution complete.")
