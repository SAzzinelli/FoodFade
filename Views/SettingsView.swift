import SwiftUI
import SwiftData
import UIKit

/// Vista impostazioni – header Fridgy, sezioni a card, grafica rivista
struct SettingsView: View {
    private static let fridgyBlue = Color(red: 100/255, green: 175/255, blue: 230/255)
    private let cardCornerRadius: CGFloat = 16
    private let cardHorizontalPadding: CGFloat = 20

    @Query private var settings: [AppSettings]
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingCustomDaysPicker = false
    @State private var showingResetAlert = false
    @State private var showingFridgyChat = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasShownFirstAddPrompt") private var hasShownFirstAddPrompt = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    private var listTint: Color {
        colorScheme == .dark ? Color.primary : ThemeManager.shared.primaryColor
    }

    var body: some View {
        NavigationStack {
            List {
                fridgyHeaderSection
                homeSection
                notificationsSection
                fridgySection
                appearanceSection
                dataSection
                infoSection
                resetSection
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, AppTheme.spacingBelowLargeTitle, for: .scrollContent)
            .tint(listTint)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                        Text("FoodFade")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                    }
                }
            }
            .sheet(isPresented: $showingCustomDaysPicker) {
                CustomDaysPickerView(customDays: $viewModel.customNotificationDays)
                    .onDisappear {
                        if viewModel.notificationDaysBefore == -1 { viewModel.saveSettings() }
                    }
            }
            .sheet(isPresented: $showingFridgyChat) {
                NavigationStack {
                    FridgyChatListView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("common.close".localized) {
                                    showingFridgyChat = false
                                }
                            }
                        }
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.checkiCloudStatus()
            }
            .alert("Ripristinare FoodFade?", isPresented: $showingResetAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Ripristina", role: .destructive) { performReset() }
            } message: {
                Text("Tutti i prodotti, le statistiche e le impostazioni verranno cancellati. Questa azione non può essere annullata.")
            }
        }
        .tint(listTint)
    }

    // MARK: - Header con Fridgy

    private var fridgyHeaderSection: some View {
        Section {
            VStack(spacing: 16) {
                Image("FridgySettingsHeader")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 200)
                VStack(spacing: 6) {
                    Text("Personalizza la tua esperienza")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Configura aspetto, notifiche e sincronizzazione.")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: cardHorizontalPadding, bottom: 8, trailing: cardHorizontalPadding))
        .listRowBackground(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .listRowSeparator(.hidden)
    }

    // MARK: - Sezioni a card

    private var homeSection: some View {
        Section {
            Picker(selection: $viewModel.homeSummaryStyle) {
                ForEach(HomeSummaryStyle.allCases, id: \.self) { style in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(style.displayName).font(.system(size: 16, weight: .medium))
                        Text(style.description).font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .tag(style)
                }
            } label: {
                SettingsRowLabel(icon: "chart.pie.fill", semantic: .settingsRing, text: "Riepilogo")
            }
            .onChange(of: viewModel.homeSummaryStyle) { _, _ in viewModel.saveSettings() }

            if viewModel.homeSummaryStyle == .ring {
                Picker(selection: $viewModel.progressRingMode) {
                    ForEach(ProgressRingMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mode.displayName).font(.system(size: 16, weight: .medium))
                            Text(mode.description).font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        .tag(mode)
                    }
                } label: {
                    SettingsRowLabel(icon: "circle.lefthalf.filled", semantic: .settingsRing, text: "Modalità anello")
                }
                .onChange(of: viewModel.progressRingMode) { _, _ in viewModel.saveSettings() }
            }

            Toggle(isOn: $viewModel.shoppingListTabEnabled) {
                SettingsRowLabel(icon: "cart.fill", semantic: .settingsRing, text: "Lista della spesa")
            }
            .tint(toggleTint)
            .onChange(of: viewModel.shoppingListTabEnabled) { _, _ in viewModel.saveSettings() }

            Toggle(isOn: $viewModel.ocrExpirationEnabled) {
                SettingsRowLabel(icon: "camera.viewfinder", semantic: .settingsRing, text: "settings.ocr_expiration.title".localized)
            }
            .tint(toggleTint)
            .onChange(of: viewModel.ocrExpirationEnabled) { _, _ in viewModel.saveSettings() }
        } header: {
            sectionHeader(icon: "slider.horizontal.3", title: "Funzionalità")
        } footer: {
            Text("Cosa mostrare in Home, barra in basso e in Aggiungi prodotto.")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $viewModel.notificationsEnabled) {
                SettingsRowLabel(icon: "bell.fill", semantic: .settingsAlerts, text: "Avvisi prima della scadenza")
            }
            .tint(ThemeManager.shared.semanticIconColor(for: .settingsAlerts))
            .onChange(of: viewModel.notificationsEnabled) { _, _ in viewModel.saveSettings() }

            if viewModel.notificationsEnabled {
                Picker(selection: $viewModel.notificationDaysBefore) {
                    Text("1 giorno prima").tag(1)
                    Text("2 giorni prima").tag(2)
                    Text("Personalizzato").tag(-1)
                } label: {
                    SettingsRowLabel(icon: "calendar", semantic: .settingsCalendar, text: "Quanto prima")
                }
                .onChange(of: viewModel.notificationDaysBefore) { _, newValue in
                    if newValue == -1 { showingCustomDaysPicker = true }
                    else { viewModel.saveSettings() }
                }

                if viewModel.notificationDaysBefore == -1 {
                    Button {
                        showingCustomDaysPicker = true
                    } label: {
                        HStack {
                            SettingsRowLabel(icon: "calendar", semantic: .settingsCalendar, text: "Giorni personalizzati")
                            Spacer()
                            Text("\(viewModel.customNotificationDays) \(viewModel.customNotificationDays == 1 ? "giorno" : "giorni")")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                    }
                }
            }
        } header: {
            sectionHeader(icon: "bell.badge.fill", title: "Notifiche")
        } footer: {
            if viewModel.notificationsEnabled {
                Text("Ricevi un avviso quando c'è qualcosa da consumare.")
            }
        }
    }

    private var fridgySection: some View {
        Section {
            // 1. Disponibilità
            HStack {
                Image(systemName: viewModel.isAppleIntelligenceAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(viewModel.isAppleIntelligenceAvailable ? Self.fridgyBlue : .secondary)
                Text("fridgy.title".localized).foregroundColor(.primary)
                Spacer()
                Text(viewModel.isAppleIntelligenceAvailable ? "fridgy.available".localized : "fridgy.unavailable".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // 2. Suggerimenti
            Toggle(isOn: $viewModel.intelligenceEnabled) {
                SettingsRowLabel(icon: "sparkles", color: Self.fridgyBlue, text: "fridgy.toggle".localized)
            }
            .tint(Self.fridgyBlue)
            .onChange(of: viewModel.intelligenceEnabled) { _, newValue in
                viewModel.saveSettings()
                IntelligenceManager.shared.isEnabled = newValue
            }

            // 3. Chatta con Fridgy (in sheet per evitare schermata bianca al ritorno)
            if viewModel.intelligenceEnabled && viewModel.isAppleIntelligenceAvailable {
                Button {
                    showingFridgyChat = true
                } label: {
                    HStack {
                        SettingsRowLabel(icon: "bubble.left.and.bubble.right.fill", color: Self.fridgyBlue, text: "fridgy.chat.title".localized)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            }
        } header: {
            HStack(spacing: 8) {
                sectionHeader(icon: "sparkles", title: "fridgy.title".localized)
                Text("BETA")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Self.fridgyBlue)
                    .clipShape(Capsule())
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.intelligenceEnabled {
                    Text(viewModel.isAppleIntelligenceAvailable ? "fridgy.footer.enabled.available".localized : "fridgy.footer.enabled.unavailable".localized)
                } else {
                    Text("fridgy.footer.disabled".localized)
                }
                Text("fridgy.footer.beta".localized)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var appearanceSection: some View {
        Section {
            NavigationLink {
                AppearanceModeView()
            } label: {
                SettingsRowLabel(icon: "circle.lefthalf.filled", semantic: .settingsAppearance, text: "Aspetto app")
            }
            NavigationLink {
                AccentColorSettingsView()
            } label: {
                SettingsRowLabel(icon: "paintpalette.fill", semantic: .settingsAppearance, text: "Colori applicazione")
            }
            if UIApplication.shared.supportsAlternateIcons {
                NavigationLink {
                    AppIconPickerView()
                } label: {
                    SettingsRowLabel(icon: "app.badge.fill", semantic: .settingsAppearance, text: "settings.app_icon.section".localized)
                }
            }
        } header: {
            sectionHeader(icon: "paintbrush.pointed.fill", title: "Aspetto")
        }
    }

    private var dataSection: some View {
        Section {
            HStack {
                SettingsRowLabel(icon: "icloud.fill", semantic: .settingsCloud, text: "iCloud")
                Spacer()
                Text(viewModel.iCloudStatus).foregroundColor(.secondary)
            }

            if viewModel.iCloudStatus == "Attiva" {
                Button {
                    viewModel.restoreFromiCloud()
                } label: {
                    SettingsRowLabel(icon: "arrow.down.circle", semantic: .settingsCloud, text: "settings.icloud.restore".localized)
                }
            }

            NavigationLink {
                BackupRestoreView()
            } label: {
                SettingsRowLabel(icon: "arrow.triangle.2.circlepath", semantic: .settingsBackup, text: "Backup e Ripristino")
            }
        } header: {
            sectionHeader(icon: "externaldrive.fill", title: "Dati")
        } footer: {
            if viewModel.iCloudStatus == "Attiva" {
                Text("Sincronizzazione automatica tra dispositivi. Puoi anche esportare/importare backup locali.")
            } else {
                Text("Esporta o importa i dati manualmente per backup locali.")
            }
        }
    }

    private var infoSection: some View {
        Section {
            HStack {
                Text("settings.version".localized)
                    .foregroundColor(.primary)
                Spacer()
                Text(viewModel.appVersion)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("FoodFade © 2026")
                    .font(.subheadline)
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
            }
        } header: {
            sectionHeader(icon: "info.circle.fill", title: "settings.info".localized)
        }
    }

    private var resetSection: some View {
        Section {
            Button {
                showingResetAlert = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Ripristina FoodFade")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        } footer: {
            Text("settings.reset.footer".localized)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Stili condivisi

    private func sectionHeader(icon: String, title: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
    }

    private var toggleTint: Color {
        colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.semanticIconColor(for: .settingsRing)
    }

    private func performReset() {
        let foodItemDescriptor = FetchDescriptor<FoodItem>()
        if let foodItems = try? modelContext.fetch(foodItemDescriptor) {
            for item in foodItems { modelContext.delete(item) }
        }
        let userProfileDescriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(userProfileDescriptor) {
            for profile in profiles { modelContext.delete(profile) }
        }
        let customFoodTypeDescriptor = FetchDescriptor<CustomFoodType>()
        if let customTypes = try? modelContext.fetch(customFoodTypeDescriptor) {
            for type in customTypes { modelContext.delete(type) }
        }
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let existingSettings = try? modelContext.fetch(settingsDescriptor) {
            for setting in existingSettings { modelContext.delete(setting) }
        }
        try? modelContext.save()

        let defaultSettings = AppSettings.defaultSettings()
        modelContext.insert(defaultSettings)
        try? modelContext.save()

        hasSeenWelcome = false
        hasShownFirstAddPrompt = false
        ThemeManager.shared.accentColor = .natural
        ThemeManager.shared.appearanceMode = .system
        ThemeManager.shared.animationsEnabled = true
        NotificationCenter.default.post(name: NSNotification.Name("AppResetPerformed"), object: nil)
    }
}

// MARK: - Row label (icon + text)
private struct SettingsRowLabel: View {
    var icon: String
    var semantic: SemanticIconContext? = nil
    var color: Color? = nil
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(resolvedColor)
            Text(text).foregroundColor(.primary)
        }
    }

    private var resolvedColor: Color {
        if let color { return color }
        if let semantic { return ThemeManager.shared.semanticIconColor(for: semantic) }
        return .secondary
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [FoodItem.self, AppSettings.self])
}
