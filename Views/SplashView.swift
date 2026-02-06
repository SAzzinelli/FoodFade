import SwiftUI

/// Schermata di intro animata con logo
struct SplashView: View {
    @Binding var showWelcome: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var logoScale: CGFloat = 0.5
    
    private var leafColor: Color { colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor }
    private var leafColorDark: Color { colorScheme == .dark ? ThemeManager.naturalHomeLogoColor.opacity(0.8) : ThemeManager.shared.primaryColorDark }
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var textOffset: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Sfondo gradiente
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    leafColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Logo animato: icona arancione (tinta fissa per non diventare bianca col tema)
                Image("AppIconLogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [ThemeManager.naturalHomeLogoColor, ThemeManager.naturalHomeLogoColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .shadow(color: ThemeManager.naturalHomeLogoColor.opacity(0.3), radius: 20, x: 0, y: 10)
                
                // Solo nome app in arancione
                Text("splash.appname".localized)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(ThemeManager.naturalHomeLogoColor)
                    .opacity(textOpacity)
                    .offset(y: textOffset)
                
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // Permetti di passare avanti toccando lo schermo
            skipToNext()
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Prima animazione: logo
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Seconda animazione: testo (dopo un breve delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.6)) {
                textOpacity = 1.0
                textOffset = 0
            }
        }
        
        // Dopo 2.5 secondi, passa automaticamente alla schermata di benvenuto
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            skipToNext()
        }
    }
    
    private func skipToNext() {
        withAnimation(.easeInOut(duration: 0.5)) {
            showWelcome = true // true = mostra welcome, nascondi splash
        }
    }
}

#Preview {
    SplashView(showWelcome: .constant(false))
}

