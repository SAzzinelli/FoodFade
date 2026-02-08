import SwiftUI

/// Anello di progresso: colore unico, parte non riempita stesso colore a opacità bassa, centro per numero + stato.
struct AnimatedProgressRing<CenterContent: View>: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let ringColor: Color
    let unfilledOpacity: Double
    let animationsEnabled: Bool
    let centerContent: CenterContent
    
    @State private var animatedProgress: Double = 0
    
    init(
        progress: Double,
        size: CGFloat = 140,
        lineWidth: CGFloat = 20,
        ringColor: Color = AppTheme.primaryGreen,
        unfilledOpacity: Double = 0.15,
        animationsEnabled: Bool = true,
        @ViewBuilder centerContent: () -> CenterContent
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.ringColor = ringColor
        self.unfilledOpacity = unfilledOpacity
        self.animationsEnabled = animationsEnabled
        self.centerContent = centerContent()
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(unfilledOpacity), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            centerContent
        }
        .onAppear {
            if animationsEnabled {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
                    animatedProgress = progress
                }
            } else {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            if animationsEnabled {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    animatedProgress = newValue
                }
            } else {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    AnimatedProgressRing(progress: 0.5, ringColor: .orange) {
        VStack(spacing: 4) {
            Text("50%").font(.system(size: 36, weight: .bold)).foregroundColor(.primary)
            Text("Quasi tutto ok").font(.system(size: 14, weight: .medium)).foregroundColor(.secondary)
        }
    }
    .padding()
}
