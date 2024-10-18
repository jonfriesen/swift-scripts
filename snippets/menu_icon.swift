import Cocoa

/// Sets the menu icon for a given NSStatusItem using either a base64-encoded image or a fallback emoji.
///
/// - Parameters:
///   - statusItem: The NSStatusItem for which to set the icon.
///   - iconData: A base64-encoded string representing the icon image.
///   - fallbackEmoji: A string containing an emoji to use if the image fails to load.
///
/// - Note: The function attempts to load the image from the provided base64 string.
///         If successful, it sets the image as the button's icon and adjusts its size to 18x18 pixels.
///         If the image fails to load or set, it falls back to using the provided emoji as the button's title.
///
/// - Important: Ensure that the `iconData` is a valid base64-encoded string representing an image.
///              The fallback emoji should be a single character string containing a valid emoji.
///
/// To convert a PNG file to a base64-encoded string, use the following command in the terminal:
/// ```
/// base64 -i 'icon.png' | tr -d '\n'
/// ```
/// This command will output the base64-encoded string without line breaks, ready to be used as `iconData`.

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
