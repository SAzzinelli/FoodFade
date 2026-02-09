import SwiftUI
import UIKit

/// Sotto-view per la scelta dell'icona app: lista con anteprima icona, nome e indicatore di selezione.
struct AppIconPickerView: View {
    @AppStorage(AppIconManager.userDefaultsKey) private var appIconName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var successIconName = ""
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var selectedIconRaw: String {
        appIconName.isEmpty ? AppIconManager.Option.primary.rawValue : appIconName
    }
    
    var body: some View {
        List {
            ForEach(AppIconManager.Option.allCases, id: \.rawValue) { option in
                Button {
                    selectIcon(option)
                } label: {
                    HStack(spacing: 16) {
                        AppIconThumbnail(option: option)
                        Text(option.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedIconRaw == option.rawValue {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ThemeManager.shared.primaryColor)
                        }
                    }
                }
            }
        }
        .tint(colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor)
        .navigationTitle("settings.app_icon.section".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.app_icon.error.title".localized, isPresented: $showError) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("settings.app_icon.changed.title".localized, isPresented: $showSuccessAlert) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text(String(format: "settings.app_icon.changed.message".localized, successIconName))
        }
    }
    
    private func selectIcon(_ option: AppIconManager.Option) {
        AppIconManager.setIcon(option) { success, error in
            if success {
                successIconName = option.displayName
                showSuccessAlert = true
            } else {
                errorMessage = error?.localizedDescription ?? "settings.app_icon.error".localized
                showError = true
            }
        }
    }
}

// MARK: - Anteprima icona (60x60, stile icona app)
private struct AppIconThumbnail: View {
    let option: AppIconManager.Option
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(backgroundColor)
            .overlay {
                imageContent
            }
            .frame(width: 60, height: 60)
    }
    
    @ViewBuilder
    private var imageContent: some View {
        switch option {
        case .primary:
            Image("AppIconLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
        case .opt1:
            Image(systemName: "leaf.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
        case .opt2:
            Image(systemName: "snowflake")
                .font(.system(size: 26))
                .foregroundStyle(.white)
        }
    }
    
    private var backgroundColor: some ShapeStyle {
        switch option {
        case .primary:
            return AnyShapeStyle(LinearGradient(
                colors: [
                    themeManager.primaryColor,
                    themeManager.primaryColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .opt1:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.2, green: 0.6, blue: 0.3), Color(red: 0.15, green: 0.5, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        case .opt2:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.4, green: 0.75, blue: 1.0), Color(red: 0.3, green: 0.65, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
}

#Preview {
    NavigationStack {
        AppIconPickerView()
    }
}
