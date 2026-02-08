import SwiftUI

/// Tre anelli concentrici in stile Apple Fitness: Prodotti OK, In scadenza, Scaduti
struct ActivityRingsView: View {
    let okCount: Int
    let inScadenzaCount: Int
    let expiredCount: Int
    let size: CGFloat
    let lineWidth: CGFloat
    let animationsEnabled: Bool
    
    private var total: Int { okCount + inScadenzaCount + expiredCount }
    private var okProgress: Double { total > 0 ? Double(okCount) / Double(total) : 0 }
    private var inScadenzaProgress: Double { total > 0 ? Double(inScadenzaCount) / Double(total) : 0 }
    private var expiredProgress: Double { total > 0 ? Double(expiredCount) / Double(total) : 0 }
    
    @State private var animatedOk: Double = 0
    @State private var animatedInScadenza: Double = 0
    @State private var animatedExpired: Double = 0
    
    init(
        okCount: Int,
        inScadenzaCount: Int,
        expiredCount: Int,
        size: CGFloat = 120,
        lineWidth: CGFloat = 10,
        animationsEnabled: Bool = true
    ) {
        self.okCount = okCount
        self.inScadenzaCount = inScadenzaCount
        self.expiredCount = expiredCount
        self.size = size
        self.lineWidth = lineWidth
        self.animationsEnabled = animationsEnabled
    }
    
    private let okColor = Color.green
    private let inScadenzaColor = Color.orange
    private let expiredColor = Color.red
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                // Anello esterno: Prodotti OK (verde)
                ring(progress: animatedOk, color: okColor, diameter: size)
                // Anello medio: In scadenza (arancione)
                ring(progress: animatedInScadenza, color: inScadenzaColor, diameter: size - (lineWidth + 4) * 2)
                // Anello interno: Scaduti (rosso)
                ring(progress: animatedExpired, color: expiredColor, diameter: size - (lineWidth + 4) * 4)
            }
            .frame(width: size, height: size)
            
            VStack(alignment: .leading, spacing: 12) {
                ringRow(label: "home.rings.ok".localized, value: okCount, color: okColor)
                ringRow(label: "home.rings.inscadenza".localized, value: inScadenzaCount, color: inScadenzaColor)
                ringRow(label: "home.rings.scaduti".localized, value: expiredCount, color: expiredColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            applyProgress()
        }
        .onChange(of: okCount) { _, _ in applyProgress() }
        .onChange(of: inScadenzaCount) { _, _ in applyProgress() }
        .onChange(of: expiredCount) { _, _ in applyProgress() }
    }
    
    private func ring(progress: Double, color: Color, diameter: CGFloat) -> some View {
        Circle()
            .stroke(Color(.systemGray5), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .frame(width: diameter, height: diameter)
            .overlay(
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: diameter, height: diameter)
            )
    }
    
    private func ringRow(label: String, value: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private func applyProgress() {
        if animationsEnabled {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.15)) {
                animatedOk = okProgress
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.25)) {
                animatedInScadenza = inScadenzaProgress
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.35)) {
                animatedExpired = expiredProgress
            }
        } else {
            animatedOk = okProgress
            animatedInScadenza = inScadenzaProgress
            animatedExpired = expiredProgress
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ActivityRingsView(okCount: 8, inScadenzaCount: 2, expiredCount: 1, animationsEnabled: true)
        ActivityRingsView(okCount: 5, inScadenzaCount: 0, expiredCount: 0, size: 100, animationsEnabled: false)
    }
    .padding()
}
