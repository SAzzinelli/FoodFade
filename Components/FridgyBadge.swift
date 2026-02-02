import SwiftUI

/// Badge "Fridgy" con glow iridescente stile Apple Intelligence
struct FridgyBadge: View {
    let suggestion: String
    let onTap: (() -> Void)?
    
    @State private var glowIntensity: Double = 0.5
    @State private var rotation: Double = 0
    
    init(suggestion: String, onTap: (() -> Void)? = nil) {
        self.suggestion = suggestion
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: {
            onTap?()
        }) {
            HStack(spacing: 10) {
                // Icona Fridgy con glow
                ZStack {
                    // Glow iridescente animato
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [
                                    Color.blue.opacity(0.6),
                                    Color.purple.opacity(0.6),
                                    Color.pink.opacity(0.6),
                                    Color.blue.opacity(0.6)
                                ],
                                center: .center,
                                angle: .degrees(rotation)
                            )
                        )
                        .frame(width: 32, height: 32)
                        .blur(radius: 8)
                        .opacity(glowIntensity)
                    
                    // Icona principale
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.8),
                                    Color.purple.opacity(0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.3),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                }
                
                // Testo suggerimento
                Text(suggestion)
                    .font(.system(size: 14, weight: .regular, design: .default))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                Spacer()
                
                // Indicatore "Fridgy"
                Text("Fridgy")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray5))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3 * glowIntensity),
                                        Color.purple.opacity(0.3 * glowIntensity)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: Color.blue.opacity(0.2 * glowIntensity),
                radius: 8,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .onAppear {
            // Animazione glow continua
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
            
            // Rotazione gradiente
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        FridgyBadge(suggestion: "💡 Idea: potresti consumare Pizza e Pasta oggi per evitare sprechi")
        FridgyBadge(suggestion: "💡 Suggerimento: Yogurt sta per scadere — potresti abbinarlo a qualcosa che hai già aperto")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
