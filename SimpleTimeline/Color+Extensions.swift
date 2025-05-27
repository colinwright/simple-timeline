import SwiftUI // Or import UIKit if this were for iOS and using UIColor

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

    func darker(by percentage: CGFloat = 0.2) -> Color {
        // This is a simplified darkening function.
        // For more accurate HSB/RGB manipulation, you might need to bridge to NSColor/UIColor.
        // However, for many standard SwiftUI colors, this approach can work.
        // It might not work as expected for all color types (e.g., system adaptive colors without direct RGB).
        
        // Attempt to get RGB components (this part is tricky with pure SwiftUI Color)
        // A more robust way involves NSColor on macOS.
        let nsColor: NSColor
        if #available(macOS 11.0, *) {
            nsColor = NSColor(self)
        } else {
            // Fallback for older macOS if needed, though less reliable for all Color types
            guard let cgColor = self.cgColor else { return self }
            nsColor = NSColor(cgColor: cgColor) ?? NSColor.black // Default if cgColor conversion fails
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
}
