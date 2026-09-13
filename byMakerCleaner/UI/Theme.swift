import SwiftUI

enum Theme {
    // MARK: - Colors
    
    /// Pure black background for the ultimate terminal feel.
    static let background = Color.black
    
    /// Very dark gray for surface/card backgrounds.
    static let surface = Color(red: 0.05, green: 0.05, blue: 0.05)
    
    /// Accent color (Neon Orange/Amber)
    static let accent = Color(red: 1.0, green: 0.55, blue: 0.0) // #FF8C00
    
    /// Warning color (Neon Yellow/Amber)
    static let warning = Color(red: 1.0, green: 0.8, blue: 0.0) // #FFCC00
    
    /// Destructive color (Neon Red)
    static let destructive = Color(red: 1.0, green: 0.2, blue: 0.2) // #FF3333
    
    /// Success color (Neon Green)
    static let success = Color(red: 0.0, green: 1.0, blue: 0.4) // #00FF66
    
    /// Primary text color (Light gray/white)
    static let textPrimary = Color(white: 0.9)
    
    /// Secondary/Muted text color
    static let textMuted = Color(white: 0.4)
    
    /// Border color for inactive elements
    static let border = Color(white: 0.2)
    
    // MARK: - Typography
    
    /// Standard monospaced font modifier
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.system(size: size, weight: weight, design: .monospaced)
    }
}

// Extension to easily apply neon glow effects
extension View {
    func neonGlow(color: Color, radius: CGFloat = 4.0, opacity: Double = 0.5) -> some View {
        self.shadow(color: color.opacity(opacity), radius: radius, x: 0, y: 0)
    }
}
