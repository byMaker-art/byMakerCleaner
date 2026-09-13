import SwiftUI

// MARK: - Terminal Card

/// A container that looks like a terminal window or blueprint section.
struct TerminalCard<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background
            Theme.surface
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                if let title = title {
                    // Spacer for title
                    Text(" ")
                        .font(Theme.font(size: 14))
                        .padding(.top, 4)
                }
                
                content
            }
            .padding(16)
            
            // Border
            Rectangle()
                .stroke(Theme.border, lineWidth: 1)
            
            // Attached Title (if any)
            if let title = title {
                Text("[ \(title.uppercased()) ]")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, 4)
                    .background(Theme.background)
                    .offset(x: 12, y: -8)
            }
        }
        .padding(.top, title != nil ? 8 : 0)
    }
}

// MARK: - Terminal Button

/// A GPU-safe button (using onTapGesture) that looks like a terminal command.
struct TerminalButton: View {
    let title: String
    let icon: String?
    let isDestructive: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    init(_ title: String, icon: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        let color = isDestructive ? Theme.destructive : Theme.accent
        
        HStack {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(isHovered ? "[ \(title.uppercased()) ]" : "  \(title.uppercased())  ")
        }
        .font(Theme.font(size: 14, weight: .bold))
        .foregroundColor(isHovered ? Theme.background : color)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? color : Color.clear)
        .border(color, width: 1)
        .contentShape(Rectangle()) // Make entire area clickable
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            action()
        }
        // GPU safe: We avoid complex shadows if possible, but a tiny neon glow on hover is okay.
        .neonGlow(color: isHovered ? color : .clear, radius: 2, opacity: 0.5)
    }
}

// MARK: - Terminal Toggle

/// A GPU-safe toggle switch displaying as [X] ENABLED or [ ] DISABLED.
struct TerminalToggle: View {
    let title: String
    @Binding var isOn: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(isOn ? "[X]" : "[ ]")
                .foregroundColor(isOn ? Theme.accent : Theme.textMuted)
            
            Text(title.uppercased())
                .foregroundColor(isOn ? Theme.textPrimary : Theme.textMuted)
            
            Spacer()
        }
        .font(Theme.font(size: 14))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            isOn.toggle()
        }
        .background(isHovered ? Theme.surface.opacity(0.5) : Color.clear)
    }
}

// MARK: - Terminal Progress

/// ASCII-style progress bar. Example: [██████░░░░] 60%
struct TerminalProgress: View {
    let value: Double // 0.0 to 1.0
    let totalLength: Int
    let color: Color
    
    init(value: Double, totalLength: Int = 20, color: Color = Theme.accent) {
        self.value = max(0, min(1, value))
        self.totalLength = totalLength
        self.color = color
    }
    
    var body: some View {
        let filledCount = Int(round(value * Double(totalLength)))
        let emptyCount = totalLength - filledCount
        
        let filledStr = String(repeating: "█", count: filledCount)
        let emptyStr = String(repeating: "░", count: emptyCount)
        
        HStack(spacing: 8) {
            Text("[\(filledStr)\(emptyStr)]")
                .foregroundColor(color)
            
            Text(String(format: "%3.0f%%", value * 100))
                .foregroundColor(Theme.textPrimary)
        }
        .font(Theme.font(size: 14))
    }
}

// MARK: - Terminal Bar Chart

struct BarChartItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

/// A simplified bar chart using text or basic rectangles to show data distributions.
struct TerminalBarChart: View {
    let items: [BarChartItem]
    let maxValue: Double
    let height: CGFloat
    
    init(items: [BarChartItem], height: CGFloat = 100) {
        self.items = items
        self.maxValue = items.map { $0.value }.max() ?? 1.0
        self.height = height
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(items) { item in
                VStack {
                    // Value Label
                    Text(formatValue(item.value))
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textMuted)
                    
                    // Bar
                    GeometryReader { geo in
                        let normalizedHeight = maxValue > 0 ? CGFloat(item.value / maxValue) * geo.size.height : 0
                        
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(item.color)
                                .frame(height: max(1, normalizedHeight)) // At least 1px visible
                        }
                    }
                    .frame(width: 30)
                    
                    // Category Label
                    Text(item.label.uppercased())
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .frame(width: 40)
                }
            }
        }
        .frame(height: height)
        .padding()
        .background(Theme.surface)
        .border(Theme.border, width: 1)
    }
    
    private func formatValue(_ val: Double) -> String {
        if val >= 1024 * 1024 * 1024 {
            return String(format: "%.1fG", val / (1024 * 1024 * 1024))
        } else if val >= 1024 * 1024 {
            return String(format: "%.1fM", val / (1024 * 1024))
        } else {
            return String(format: "%.0fK", val / 1024)
        }
    }
}
