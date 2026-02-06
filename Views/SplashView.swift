import SwiftUI
import SwiftData

/// Schermata di intro animata con logo
struct SplashView: View {
    @Binding var showWelcome: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Query private var userProfiles: [UserProfile]
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
                
                // Logo animato
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    leafColor.opacity(0.2),
                                    leafColorDark.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: 20)
                    
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 120))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [leafColor, leafColorDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(color: leafColor.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                
                // Testo di benvenuto su due righe
                VStack(alignment: .center, spacing: 4) {
                    Text(welcomeGreeting)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                    
                    Text("splash.appname".localized)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(leafColor)
                        .opacity(textOpacity)
                        .offset(y: textOffset)
                }
                
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
    
    private var welcomeGreeting: String {
        // Usa GenderHelper per ottenere la variante corretta del saluto
        let gender = GenderHelper.getGender(from: userProfiles.first)
        return GenderHelper.localizedString("splash.welcome", gender: gender)
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

