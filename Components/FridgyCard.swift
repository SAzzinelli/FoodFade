import SwiftUI

/// Card UI agnostica per Fridgy
/// Interpreta il contesto per decidere icona e colore
struct FridgyCard: View {
    let context: FridgyContext
    let message: String
    
    @State private var glowIntensity: Double = 0.6
    
    /// Periodo rotazione gradiente (secondi)
    private let rotationPeriod: TimeInterval = 5.0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let rotation = (now.truncatingRemainder(dividingBy: rotationPeriod)) / rotationPeriod * 360
            
            fridgyContent(glowRotation: rotation)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
        }
    }
    
    private func fridgyContent(glowRotation: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 12) {
                Image("FridgySettingsHeader")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                
                Text("FRIDGY CONSIGLIA:")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
            }
            
            Text(message)
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        AngularGradient(
                            colors: iridescentBackgroundColors,
                            center: .center,
                            angle: .degrees(glowRotation)
                        )
                    )
                    .opacity(0.2)
                
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(glowIntensity * 0.25),
                                color.opacity(glowIntensity * 0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    AngularGradient(
                        colors: iridescentColors,
                        center: .center,
                        angle: .degrees(glowRotation)
                    ),
                    lineWidth: 2
                )
                .shadow(color: color.opacity(glowIntensity * 0.5), radius: 8, x: 0, y: 0)
                .shadow(color: color.opacity(glowIntensity * 0.3), radius: 12, x: 0, y: 0)
        )
    }
    
    // MARK: - Stili basati sul contesto
    
    private var color: Color {
        switch context {
        case .tip:
            return .blue
        case .warning:
            return .orange
        case .reminder:
            return .blue
        }
    }
    
    private var icon: String {
        switch context {
        case .tip:
            return "sparkles"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .reminder:
            return "bell.fill"
        }
    }
    
    // Colori iridescenti per il bordo glow (simile ad Apple Intelligence)
    // Gradiente lungo per transizione fluida senza salti
    private var iridescentColors: [Color] {
        let baseColors: [Color]
        switch context {
        case .tip:
            baseColors = [
                .blue.opacity(0.8),
                .cyan.opacity(0.7),
                Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.8),
                .blue.opacity(0.8)
            ]
        case .warning:
            baseColors = [
                .orange.opacity(0.8),
                .yellow.opacity(0.6),
                .red.opacity(0.7),
                .orange.opacity(0.8)
            ]
        case .reminder:
            baseColors = [
                .blue.opacity(0.8),
                .purple.opacity(0.6),
                .cyan.opacity(0.7),
                .blue.opacity(0.8)
            ]
        }
        // Ripeti i colori 3 volte per un gradiente più lungo e fluido
        return baseColors + baseColors + baseColors
    }
    
    // Colori iridescenti per il background glow
    private var iridescentBackgroundColors: [Color] {
        let baseColors: [Color]
        switch context {
        case .tip:
            baseColors = [
                .blue.opacity(0.3),
                .cyan.opacity(0.25),
                Color(red: 0.4, green: 0.7, blue: 1.0).opacity(0.25),
                .blue.opacity(0.3)
            ]
        case .warning:
            baseColors = [
                .orange.opacity(0.3),
                .yellow.opacity(0.2),
                .red.opacity(0.25),
                .orange.opacity(0.3)
            ]
        case .reminder:
            baseColors = [
                .blue.opacity(0.3),
                .purple.opacity(0.2),
                .cyan.opacity(0.25),
                .blue.opacity(0.3)
            ]
        }
        // Ripeti i colori 3 volte per un gradiente più lungo e fluido
        return baseColors + baseColors + baseColors
    }
}

#Preview {
    VStack(spacing: 16) {
        FridgyCard(
            context: .tip,
            message: "Prodotto fresco — conservalo in frigorifero e consumalo entro 3 giorni"
        )
        
        FridgyCard(
            context: .warning,
            message: "Aperto da poco — consumalo entro 2 giorni per evitare sprechi"
        )
        
        FridgyCard(
            context: .reminder,
            message: "Prodotto aperto — ricorda che la durata si riduce dopo l'apertura"
        )
    }
    .padding()
}
