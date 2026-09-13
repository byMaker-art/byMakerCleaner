import SwiftUI

struct HealthGaugeView: View {
    let score: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Health:")
                .font(.subheadline)
                .bold()
            
            Text("[\(barString)] \(score)%")
                .font(.body)
                .monospaced()
                .foregroundColor(colorForScore)
        }
    }
    
    private var barString: String {
        let totalBlocks = 10
        let filledBlocks = max(0, min(10, Int(round(Double(score) / 10.0))))
        let emptyBlocks = totalBlocks - filledBlocks
        
        return String(repeating: "█", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
    }
    
    private var colorForScore: Color {
        if score >= 80 {
            return .green
        } else if score >= 40 {
            return .yellow
        } else {
            return .red
        }
    }
}
