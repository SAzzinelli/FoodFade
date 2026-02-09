import SwiftUI
import SwiftData
import UIKit

/// Vista delle impostazioni di aspetto (sottovista)
struct AppearanceSettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var themeManager = ThemeManager.shared
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        List {
                // Modalità aspetto (Dark/Light/System) - Opzioni separate
                Section {
                    AppearanceModeOption(
                        mode: .system,
                        icon: "gearshape.fill",
                        title: "Sistema",
                        isSelected: viewModel.appearanceMode == .system
                    ) {
                        viewModel.appearanceMode = .system
                        viewModel.saveSettings()
                    }
                    
                    AppearanceModeOption(
                        mode: .light,
                        icon: "sun.max.fill",
                        title: "Chiaro",
                        isSelected: viewModel.appearanceMode == .light
                    ) {
                        viewModel.appearanceMode = .light
                        viewModel.saveSettings()
                    }
                    
                    AppearanceModeOption(
                        mode: .dark,
                        icon: "moon.fill",
                        title: "Scuro",
                        isSelected: viewModel.appearanceMode == .dark
                    ) {
                        viewModel.appearanceMode = .dark
                        viewModel.saveSettings()
                    }
                } header: {
                    Text("Aspetto")
                }
                
                // Animazioni
                Section {
                    Toggle(isOn: $viewModel.animationsEnabled) {
                        Label("Animazioni", systemImage: "sparkles")
                    }
                    .onChange(of: viewModel.animationsEnabled) { oldValue, newValue in
                        viewModel.saveSettings()
                    }
                } header: {
                    Text("Animazioni")
                } footer: {
                    Text("Abilita o disabilita le animazioni e gli effetti visivi")
                }
                
                // Colore principale d'accento - Opzioni separate
                Section {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        AccentColorOption(
                            color: color,
                            isSelected: viewModel.accentColor == color
                        ) {
                            viewModel.accentColor = color
                            viewModel.saveSettings()
                        }
                    }
                } header: {
                    Text("Colore Principale")
                } footer: {
                    Text("Naturale: icone a colori (mela rossa, bio verde…) e testi neri. Gli altri stili usano un unico colore accent.")
                }
                
                // Icona app – apre sotto-view con lista icone
                if UIApplication.shared.supportsAlternateIcons {
                    Section {
                        NavigationLink {
                            AppIconPickerView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "app.badge.fill")
                                    .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsAppearance))
                                Text("settings.app_icon.section".localized)
                            }
                        }
                    } footer: {
                        Text("settings.app_icon.footer".localized)
                    }
                }
            }
            .tint(colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor)
            .navigationTitle("Aspetto")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
    }
    
    private func colorForAccent(_ accent: AccentColor) -> Color {
        switch accent {
        case .natural:
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        case .green:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .blue:
            return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .purple:
            return Color(red: 0.7, green: 0.4, blue: 1.0)
        case .orange:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .pink:
            return Color(red: 1.0, green: 0.4, blue: 0.6)
        case .teal:
            return Color(red: 0.2, green: 0.7, blue: 0.8)
        }
    }
}

// MARK: - Appearance Mode Option
private struct AppearanceModeOption: View {
    let mode: AppearanceMode
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? ThemeManager.shared.primaryColor : .secondary)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(ThemeManager.shared.primaryColor)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - Accent Color Option
private struct AccentColorOption: View {
    let color: AccentColor
    let isSelected: Bool
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack {
                if color == .natural {
                    Image(systemName: "paintpalette.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red.opacity(0.8), .orange, .green],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(colorForAccent(color))
                        .frame(width: 24, height: 24)
                }
                
                Text(color.displayName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeManager.primaryColor)
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
    }
    
    private func colorForAccent(_ accent: AccentColor) -> Color {
        switch accent {
        case .natural:
            return Color(red: 0.5, green: 0.5, blue: 0.5)
        case .green:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .blue:
            return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .purple:
            return Color(red: 0.7, green: 0.4, blue: 1.0)
        case .orange:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .pink:
            return Color(red: 1.0, green: 0.4, blue: 0.6)
        case .teal:
            return Color(red: 0.2, green: 0.7, blue: 0.8)
        }
    }
}

#Preview {
    AppearanceSettingsView()
        .modelContainer(for: [FoodItem.self, AppSettings.self])
}

