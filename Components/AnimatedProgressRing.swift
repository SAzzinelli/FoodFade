import SwiftUI

/// Anello di progresso animato con glow e animazioni fluide
struct AnimatedProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let primaryColor: Color
    let primaryColorDark: Color
    let animationsEnabled: Bool
    
    @State private var animatedProgress: Double = 0
    @State private var glowIntensity: Double = 0.5
    @State private var rotation: Double = 0
    
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
            // Glow esterno (solo se animazioni abilitate)
            if animationsEnabled {
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        primaryColor.opacity(glowIntensity * 0.3),
                        style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90 + rotation))
                    .frame(width: size, height: size)
                    .blur(radius: 8)
            }
            
            // Background ring
            Circle()
                .stroke(
                    Color(.systemGray5),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
            
            // Progress ring con gradiente
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
                .shadow(
                    color: primaryColor.opacity(animationsEnabled ? 0.4 : 0.2),
                    radius: animationsEnabled ? 12 : 6,
                    x: 0,
                    y: 0
                )
            
            // Glow interno (solo se animazioni abilitate)
            if animationsEnabled {
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        primaryColor.opacity(glowIntensity * 0.2),
                        style: StrokeStyle(lineWidth: lineWidth - 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size, height: size)
                    .blur(radius: 4)
            }
        }
        .onAppear {
            if animationsEnabled {
                // Animazione iniziale del progresso
                withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
                    animatedProgress = progress
                }
                
                // Animazione continua del glow
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 1.0
                }
                
                // Rotazione sottile (opzionale)
                withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                    rotation = 360
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

