import SwiftUI
import UIKit

/// Sotto-view per la scelta dell'icona app: lista con anteprima icona, nome e indicatore di selezione.
struct AppIconPickerView: View {
    @AppStorage(AppIconManager.userDefaultsKey) private var appIconName: String = ""
    @State private var showError = false
    @State private var errorMessage = ""

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
    }

    private func selectIcon(_ option: AppIconManager.Option) {
        AppIconManager.setIcon(option) { success, error in
            if !success {
                errorMessage = error?.localizedDescription ?? "settings.app_icon.error".localized
                showError = true
            }
            // Successo: non mostriamo alert (iOS mostra già quello di sistema)
        }
    }
}

// MARK: - Anteprima icona (60x60): mostra le vere icone dall’asset catalog
private struct AppIconThumbnail: View {
    let option: AppIconManager.Option

    private let cornerRadius: CGFloat = 13

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(iconGradient)
            Image(option.previewImageName)
                .resizable()
                .scaledToFit()
                .frame(width: imageSize, height: imageSize)
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var imageSize: CGFloat {
        switch option {
        case .opt1: return 44
        default: return 56
        }
    }

    private var iconGradient: LinearGradient {
        switch option {
        case .primary:
            return LinearGradient(
                colors: [Color(red: 0.35, green: 0.95, blue: 0.85), Color(red: 0.1, green: 0.5, blue: 0.95)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .opt1:
            return LinearGradient(
                colors: [Color(red: 1, green: 0.9, blue: 0.55), Color(red: 0.95, green: 0.55, blue: 0.25)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .opt2:
            return LinearGradient(
                colors: [Color(red: 1, green: 0.6, blue: 0.2), Color(red: 0.95, green: 0.8, blue: 0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

#Preview {
    NavigationStack {
        AppIconPickerView()
    }
}
