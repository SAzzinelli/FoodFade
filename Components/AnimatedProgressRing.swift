import SwiftUI

/// Anello di progresso animato (senza glow)
struct AnimatedProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let primaryColor: Color
    let primaryColorDark: Color
    let animationsEnabled: Bool
    
    @State private var animatedProgress: Double = 0
    init(
        progress: Double,
        size: CGFloat = 140,
        lineWidth: CGFloat = 14,
        primaryColor: Color = AppTheme.primaryGreen,
        primaryColorDark: Color = AppTheme.primaryGreenDark,
        animationsEnabled: Bool = true
    ) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.primaryColor = primaryColor
        self.primaryColorDark = primaryColorDark
        self.animationsEnabled = animationsEnabled
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color(.systemGray5),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
            
            // Progress ring con gradiente (senza glow/shadow)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [primaryColor, primaryColorDark, primaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
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
    VStack(spacing: 30) {
        AnimatedProgressRing(progress: 0.75, animationsEnabled: true)
        AnimatedProgressRing(progress: 0.45, animationsEnabled: false)
    }
    .padding()
}

