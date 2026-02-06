import SwiftUI
import SwiftData

/// Vista delle impostazioni - VERSIONE FINALE LOCKATA
struct SettingsView: View {
    @Query private var settings: [AppSettings]
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingCustomDaysPicker = false
    @State private var showingResetAlert = false
    @State private var showingiCloudRestoreInfo = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("hasShownFirstAddPrompt") private var hasShownFirstAddPrompt = false
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            List {
                // 0. INTRODUZIONE
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                AnyShapeStyle(Color(red: 1.0, green: 0.6, blue: 0.2))
                            )
                        
                        VStack(spacing: 6) {
                            Text("Personalizza la tua esperienza")
                                .font(.system(size: 20, weight: .bold, design: .default))
                                .foregroundColor(.primary)
                            
                            Text("Configura l'aspetto, le notifiche e le preferenze di sincronizzazione per rendere FoodFade perfetto per te.")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(nil)
                        }
                        .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
                .listRowBackground(Color(.secondarySystemGroupedBackground))
                
                // 1. ANELLO DI PROGRESSO
                Section {
                    Picker(selection: $viewModel.progressRingMode) {
                        ForEach(ProgressRingMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                Text(mode.description)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .tag(mode)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "chart.pie.fill")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsRing))
                            Text("Modalità anello")
                                .foregroundColor(.primary)
                        }
                    }
                    .onChange(of: viewModel.progressRingMode) { oldValue, newValue in
                        viewModel.saveSettings()
                    }
                } header: {
                    Text("Anello")
                } footer: {
                    Text("Scegli come visualizzare l'anello nella schermata Home")
                }
                
                // 2. AVVISI
                Section {
                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.fill")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsAlerts))
                            Text("Avvisami prima della scadenza")
                                .foregroundColor(.primary)
                        }
                    }
                    .tint(ThemeManager.shared.semanticIconColor(for: .settingsAlerts))
                    .onChange(of: viewModel.notificationsEnabled) { oldValue, newValue in
                        viewModel.saveSettings()
                    }
                    
                    if viewModel.notificationsEnabled {
                        // Picker per "Quanto prima"
                        Picker(selection: $viewModel.notificationDaysBefore) {
                            Text("1 giorno prima").tag(1)
                            Text("2 giorni prima").tag(2)
                            Text("Personalizzato").tag(-1)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsCalendar))
                                Text("Quanto prima")
                                    .foregroundColor(.primary)
                            }
                        }
                        .onChange(of: viewModel.notificationDaysBefore) { oldValue, newValue in
                            if newValue == -1 {
                                showingCustomDaysPicker = true
                            } else {
                                viewModel.saveSettings()
                            }
                        }
                        
                        // Mostra i giorni custom se selezionato
                        if viewModel.notificationDaysBefore == -1 {
                            Button {
                                showingCustomDaysPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsCalendar))
                                    Text("Giorni personalizzati")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(viewModel.customNotificationDays) \(viewModel.customNotificationDays == 1 ? "giorno" : "giorni")")
                                        .foregroundColor(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Avvisi")
                } footer: {
                    if viewModel.notificationsEnabled {
                        Text("Ti avvisiamo solo se c'è qualcosa da consumare")
                    }
                }
                
                // 2b. INSERIMENTO SCADENZA
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsExpirationInput))
                        Text("settings.expiration.input.short".localized)
                            .foregroundColor(.primary)
                        Spacer()
                        Menu {
                            ForEach(ExpirationInputMethod.allCases, id: \.self) { method in
                                Button {
                                    viewModel.expirationInputMethod = method
                                    viewModel.saveSettings()
                                } label: {
                                    Text(method.displayName)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(viewModel.expirationInputMethod.displayName)
                                    .foregroundColor(.primary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("settings.expiration.section".localized)
                } footer: {
                    Text("settings.expiration.footer".localized)
                }
                
                // 3. FRIDGY (descrizioni sotto senza menzione Apple Intelligence)
                Section {
                    Toggle(isOn: $viewModel.intelligenceEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsSuggestions))
                            Text("fridgy.toggle".localized)
                                .foregroundColor(.primary)
                        }
                    }
                    .tint(ThemeManager.shared.semanticIconColor(for: .settingsSuggestions))
                    .onChange(of: viewModel.intelligenceEnabled) { oldValue, newValue in
                        viewModel.saveSettings()
                        IntelligenceManager.shared.isEnabled = newValue
                    }
                    
                    if viewModel.isAppleIntelligenceAvailable {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsAvailable))
                            Text("fridgy.title".localized)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("fridgy.available".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                            Text("fridgy.title".localized)
                                .foregroundColor(.primary)
                            Spacer()
                            Text("fridgy.unavailable".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("fridgy.title".localized)
                } footer: {
                    if viewModel.intelligenceEnabled {
                        if viewModel.isAppleIntelligenceAvailable {
                            Text("fridgy.footer.enabled.available".localized)
                        } else {
                            Text("fridgy.footer.enabled.unavailable".localized)
                        }
                    } else {
                        Text("fridgy.footer.disabled".localized)
                    }
                }
                
                // 4. ASPETTO
                Section {
                    NavigationLink {
                        AppearanceSettingsView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsAppearance))
                            Text("Personalizza")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Aspetto")
                } footer: {
                    Text("Personalizza l'interfaccia")
                }
                
                // 5. SINCRONIZZAZIONE
                Section {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsCloud))
                        Text("Sincronizzazione iCloud")
                            .foregroundColor(.primary)
                        Spacer()
                        Text(viewModel.iCloudStatus)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    
                    // Azione manuale di ripristino (solo se iCloud è attivo)
                    if viewModel.iCloudStatus == "Attiva" {
                        Button {
                            showingiCloudRestoreInfo = true
                            viewModel.restoreFromiCloud()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle")
                                    .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsCloud))
                                Text("Ripristina dati da iCloud")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        // Verifica stato sincronizzazione
                        Button {
                            viewModel.checkCloudKitSyncStatus()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsCloud))
                                Text("Verifica stato sincronizzazione")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                } header: {
                    Text("Sincronizzazione")
                } footer: {
                    if viewModel.iCloudStatus == "Attiva" {
                        Text("I tuoi dati vengono sincronizzati automaticamente sui dispositivi collegati allo stesso Apple ID.")
                    } else {
                        Text("iCloud non è disponibile su questo dispositivo.")
                    }
                }
                
                // 6. BACKUP MANUALE
                Section {
                    NavigationLink {
                        BackupRestoreView()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsBackup))
                            Text("Backup e Ripristino")
                                .foregroundColor(.primary)
                        }
                    }
                } header: {
                    Text("Backup Manuale")
                } footer: {
                    Text("Esporta o importa i tuoi dati manualmente. Utile per backup locali o trasferimento dati.")
                }
                
                // 7. INFORMAZIONI
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsInfo))
                        Text("Versione")
                            .foregroundColor(.primary)
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("FoodFade")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Riduci gli sprechi alimentari con consapevolezza e semplicità")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("© 2026 - Simone Azzinelli")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } header: {
                    Text("Informazioni")
                }
                
                // 8. RIPRISTINO
                Section {
                    Button {
                        showingResetAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsReset))
                            Text("Ripristina FoodFade")
                                .foregroundColor(ThemeManager.shared.semanticIconColor(for: .settingsReset))
                        }
                    }
                } footer: {
                    Text("settings.reset.footer".localized)
                }
            }
            .tint(ThemeManager.shared.primaryColor)
            .navigationTitle("Impostazioni")
            .sheet(isPresented: $showingCustomDaysPicker) {
                CustomDaysPickerView(customDays: $viewModel.customNotificationDays)
                    .onDisappear {
                        if viewModel.notificationDaysBefore == -1 {
                            viewModel.saveSettings()
                        }
                    }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                viewModel.checkiCloudStatus()
            }
            .alert("Ripristinare FoodFade?", isPresented: $showingResetAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Ripristina", role: .destructive) {
                    performReset()
                }
            } message: {
                Text("Tutti i prodotti, le statistiche e le impostazioni verranno cancellati. Questa azione non può essere annullata.")
            }
            .alert("Ripristino da iCloud", isPresented: $showingiCloudRestoreInfo) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("La sincronizzazione è stata avviata. Potrebbe richiedere alcuni minuti.")
            }
        }
        .tint(ThemeManager.shared.primaryColor)
    }
    
    private func performReset() {
        // Cancella tutti i FoodItem
        let foodItemDescriptor = FetchDescriptor<FoodItem>()
        if let foodItems = try? modelContext.fetch(foodItemDescriptor) {
            for item in foodItems {
                modelContext.delete(item)
            }
        }
        
        // Cancella tutti i UserProfile
        let userProfileDescriptor = FetchDescriptor<UserProfile>()
        if let profiles = try? modelContext.fetch(userProfileDescriptor) {
            for profile in profiles {
                modelContext.delete(profile)
            }
        }
        
        // Cancella tutti i CustomFoodType
        let customFoodTypeDescriptor = FetchDescriptor<CustomFoodType>()
        if let customTypes = try? modelContext.fetch(customFoodTypeDescriptor) {
            for type in customTypes {
                modelContext.delete(type)
            }
        }
        
        // Cancella tutte le AppSettings (e ricrea quelle di default dopo)
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let existingSettings = try? modelContext.fetch(settingsDescriptor) {
            for setting in existingSettings {
                modelContext.delete(setting)
            }
        }
        
        // Salva le cancellazioni
        try? modelContext.save()
        
        // Ricrea le impostazioni di default
        let defaultSettings = AppSettings.defaultSettings()
        modelContext.insert(defaultSettings)
        try? modelContext.save()
        
        // Resetta gli AppStorage
        hasSeenWelcome = false
        hasShownFirstAddPrompt = false
        
        // Resetta il ThemeManager ai valori di default
        ThemeManager.shared.accentColor = .natural
        ThemeManager.shared.appearanceMode = .system
        ThemeManager.shared.animationsEnabled = true
        
        // Forza l'app a tornare all'onboarding postando una notifica
        NotificationCenter.default.post(name: NSNotification.Name("AppResetPerformed"), object: nil)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [FoodItem.self, AppSettings.self])
}
