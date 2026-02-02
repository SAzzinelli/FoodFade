import SwiftUI

/// Vista di caricamento "magica" con glow full screen
struct MagicLoadingView: View {
    @State private var glowRotation: Double = 0
    @State private var glowIntensity: Double = 0.3
    @State private var sparklePositions: [CGPoint] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background glow iridescente animato
                AngularGradient(
                    colors: iridescentColors,
                    center: .center,
                    angle: .degrees(glowRotation)
                )
                .opacity(glowIntensity)
                .ignoresSafeArea()
                .blur(radius: 50)
                
                // Glow radiale centrale
                RadialGradient(
                    colors: [
                        ThemeManager.shared.primaryColor.opacity(0.4),
                        ThemeManager.shared.primaryColor.opacity(0.2),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: geometry.size.width / 2
                )
                .ignoresSafeArea()
                
                // Sparkles animati
                ForEach(0..<20, id: \.self) { index in
                    if index < sparklePositions.count {
                        Image(systemName: "sparkle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                            .position(sparklePositions[index])
                            .blur(radius: 2)
                    }
                }
                
                // Contenuto centrale
                VStack(spacing: 24) {
                    // Icona principale con rotazione
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(glowRotation))
                        .shadow(color: ThemeManager.shared.primaryColor.opacity(0.8), radius: 20)
                    
                    Text("MAGIA IN CORSO...")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: ThemeManager.shared.primaryColor.opacity(0.8), radius: 10)
                    
                    Text("Sto creando la tua ricetta")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .onAppear {
                // Animazione glow rotante
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    glowRotation = 360
                }
                
                // Animazione pulsante intensità
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowIntensity = 0.6
                }
                
                // Genera posizioni sparkle random
                generateSparklePositions(geometry: geometry)
                
                // Animazione sparkle
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                    updateSparklePositions()
                }
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                // Rigenera posizioni se la dimensione cambia (es. rotazione dispositivo)
                generateSparklePositions(geometry: geometry)
            }
        }
    }
    
    private var iridescentColors: [Color] {
        [
            ThemeManager.shared.primaryColor.opacity(0.8),
            .purple.opacity(0.6),
            .blue.opacity(0.7),
            .cyan.opacity(0.6),
            ThemeManager.shared.primaryColor.opacity(0.8)
        ]
    }
    
    private func generateSparklePositions(geometry: GeometryProxy) {
        sparklePositions = (0..<20).map { _ in
            CGPoint(
                x: CGFloat.random(in: 0...geometry.size.width),
                y: CGFloat.random(in: 0...geometry.size.height)
            )
        }
    }
    
    private func updateSparklePositions() {
        sparklePositions = sparklePositions.map { point in
            CGPoint(
                x: point.x + CGFloat.random(in: -50...50),
                y: point.y + CGFloat.random(in: -50...50)
            )
        }
    }
}

#Preview {
    MagicLoadingView()
}
