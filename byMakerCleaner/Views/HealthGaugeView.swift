import SwiftUI

struct HealthGaugeView: View {
    let score: Int
    
    var body: some View {
        HStack(spacing: 4) {
            Text("HEALTH:")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            
            Text("[\(barString)]")
                .font(Theme.font(size: 10))
                .foregroundColor(colorForScore)
            
            Text("\(score)%")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(colorForScore)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8) // Ensure it scales down if needed
    }
    
    private var barString: String {
        let totalBlocks = 10
        let filledBlocks = max(0, min(10, Int(round(Double(score) / 10.0))))
        let emptyBlocks = totalBlocks - filledBlocks
        
        return String(repeating: "█", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
    }
    
    private var colorForScore: Color {
        if score >= 80 {
            return Theme.success
        } else if score >= 40 {
            return Theme.warning
        } else {
            return Theme.destructive
        }
    }
}
