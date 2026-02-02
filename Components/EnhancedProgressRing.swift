import SwiftUI

/// Anello di progresso migliorato con gradazioni e design accattivante
struct EnhancedProgressRing: View {
    let progress: Double // 0.0 - 1.0
    let lineWidth: CGFloat
    let size: CGFloat
    
    @State private var animatedProgress: Double = 0
    
    init(progress: Double, lineWidth: CGFloat = 16, size: CGFloat = 160) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Sfondo con gradiente sottile
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryGreen.opacity(0.1),
                            AppTheme.primaryGreen.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size + 20, height: size + 20)
            
            // Background ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.systemGray5),
                            Color(.systemGray5).opacity(0.5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: lineWidth
                )
                .frame(width: size, height: size)
            
            // Progress ring con gradiente
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppTheme.primaryGreen,
                            AppTheme.primaryGreenLight,
                            AppTheme.primaryGreen
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppTheme.primaryGreen.opacity(0.3), radius: 8, x: 0, y: 4)
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animatedProgress)
            
            // Contenuto centrale
            VStack(spacing: 8) {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Sicuri")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

#Preview {
    EnhancedProgressRing(progress: 0.75)
        .padding()
        .background(AppTheme.backgroundGradient)
}

