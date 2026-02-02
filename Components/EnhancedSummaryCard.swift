import SwiftUI

/// Card di riepilogo migliorata con gradazioni e design accattivante
struct EnhancedSummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let gradient: LinearGradient
    let iconColor: Color
    var isLarge: Bool = false
    let action: () -> Void
    
    @State private var animatedCount: Int = 0
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
                action()
            }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                // Icona con sfondo gradiente
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [iconColor, iconColor.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    Spacer()
                }
                
                // Titolo
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                // Numero grande
                Text("\(animatedCount)")
                    .font(.system(size: isLarge ? 48 : 40, weight: .bold, design: .rounded))
                    .foregroundStyle(gradient)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: isLarge ? 160 : 140)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: AppTheme.cardShadow, radius: isPressed ? 4 : 12, x: 0, y: isPressed ? 2 : 6)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedCount = count
            }
        }
        .onChange(of: count) { oldValue, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedCount = newValue
            }
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        EnhancedSummaryCard(
            title: "Scadono Oggi",
            count: 3,
            icon: "exclamationmark.triangle.fill",
            gradient: AppTheme.gradient(for: .today),
            iconColor: AppTheme.accentOrange
        ) {}
        
        EnhancedSummaryCard(
            title: "Prossimi",
            count: 5,
            icon: "clock.fill",
            gradient: AppTheme.gradient(for: .soon),
            iconColor: AppTheme.accentYellow
        ) {}
    }
    .padding()
    .background(AppTheme.backgroundGradient)
}

