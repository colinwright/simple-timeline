import SwiftUI
import AppKit // For NSColor, ensure this is imported for macOS

// Helper extension to initialize Color from Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0 // Default alpha

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 { // With alpha for future use if needed
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil // Invalid hex length
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
    
    func toHex(includeAlpha: Bool = false) -> String? {
        let nsColor = NSColor(self) // Directly use NSColor(self) for macOS 11+
        
        // Attempt to convert to sRGB color space for component extraction
        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else {
            // Fallback for colors that cannot be converted (e.g. pattern colors)
            // This might not be perfect for all color types, but a reasonable fallback.
            if self == .clear { return includeAlpha ? "#00000000" : "#000000" } // Handle clear explicitly
            print("Warning: Could not convert color to sRGB for hex conversion. Color: \(self)")
            return nil
        }

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        if r < 0 || r > 1 || g < 0 || g > 1 || b < 0 || b > 1 || a < 0 || a > 1 {
            // This can happen if getRed fails to populate for some system colors
            // print("Warning: Invalid color components for hex conversion. R:\(r) G:\(g) B:\(b)")
            // Attempt a more direct, though potentially less accurate, component access for common cases
            // This part is tricky because Color doesn't directly expose RGB easily for ALL cases.
            // For now, we'll rely on the sRGB conversion. If it fails, we return nil.
            // The check above handles the common case where conversion might fail.
             return nil
        }

        if includeAlpha {
            return String(format: "#%02X%02X%02X%02X",
                          Int(max(0,min(r,1)) * 255.0),
                          Int(max(0,min(g,1)) * 255.0),
                          Int(max(0,min(b,1)) * 255.0),
                          Int(max(0,min(a,1)) * 255.0))
        } else {
            return String(format: "#%02X%02X%02X",
                          Int(max(0,min(r,1)) * 255.0),
                          Int(max(0,min(g,1)) * 255.0),
                          Int(max(0,min(b,1)) * 255.0))
        }
    }

    func darker(by percentage: CGFloat = 0.2) -> Color {
        // This is a simplified darkening function.
        // For more accurate HSB/RGB manipulation, you might need to bridge to NSColor.
        // However, for many standard SwiftUI colors, this approach can work.
        // It might not work as expected for all color types (e.g., system adaptive colors without direct RGB).
        
        let nsColor: NSColor
        // The #available check is good practice for macOS compatibility.
        // For Color(self) to NSColor, macOS 11+ is generally assumed for direct conversion.
        // If your target is older, cgColor might be needed, but can be less reliable for all Color types.
        if #available(macOS 11.0, *) {
             nsColor = NSColor(self)
        } else {
            guard let cgColor = self.cgColor else { return self }
            nsColor = NSColor(cgColor: cgColor) ?? NSColor.black
        }


        guard let srgbColor = nsColor.usingColorSpace(.sRGB) else { return self }
        
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        srgbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let newBrightness = max(0, brightness - percentage) // Ensure brightness doesn't go below 0
        
        return Color(hue: hue, saturation: saturation, brightness: newBrightness, opacity: alpha)
    }

    // --- NEW METHOD TO ADD ---
    /// Determines if the color is perceived as light or dark based on its luminance.
    /// - Parameter threshold: The luminance threshold to distinguish light from dark. Defaults to 0.5.
    /// - Returns: `true` if the color is considered light, `false` otherwise.
    func isLight(threshold: Double = 0.5) -> Bool {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0 // Alpha component, not used in luminance calculation

        // Convert SwiftUI Color to NSColor to reliably get RGB components on macOS
        let nsColorRepresentation = NSColor(self)
        
        // Try to get components in sRGB color space for consistency
        if let srgbColor = nsColorRepresentation.usingColorSpace(.sRGB) {
            srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        } else {
            // Fallback if sRGB conversion fails (e.g., for pattern colors or some system colors)
            // This might not be perfectly accurate for all color types.
            nsColorRepresentation.getRed(&r, green: &g, blue: &b, alpha: &a)
        }

        // Standard formula for luminance (perceived brightness)
        // These coefficients are for sRGB.
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

        return luminance > threshold
    }
}
