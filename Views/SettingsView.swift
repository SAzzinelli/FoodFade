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
                                LinearGradient(
                                    colors: [
                                        ThemeManager.shared.primaryColor,
                                        ThemeManager.shared.primaryColorDark
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
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
                        Label("Modalità anello", systemImage: "chart.pie.fill")
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
                        Label("Avvisami prima della scadenza", systemImage: "bell.fill")
                    }
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
                            Label("Quanto prima", systemImage: "calendar")
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
                                    Label("Giorni personalizzati", systemImage: "calendar")
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
                
                // 3. FRIDGY (descrizioni sotto senza menzione Apple Intelligence)
                Section {
                    Toggle(isOn: $viewModel.intelligenceEnabled) {
                        Label("fridgy.toggle".localized, systemImage: "sparkles")
                    }
                    .onChange(of: viewModel.intelligenceEnabled) { oldValue, newValue in
                        viewModel.saveSettings()
                        IntelligenceManager.shared.isEnabled = newValue
                    }
                    
                    if viewModel.isAppleIntelligenceAvailable {
                        HStack {
                            Label("fridgy.title".localized, systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Spacer()
                            Text("fridgy.available".localized)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Label("fridgy.title".localized, systemImage: "xmark.circle.fill")
                                .foregroundColor(.secondary)
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
                        Label("Personalizza", systemImage: "paintbrush.fill")
                    }
                } header: {
                    Text("Aspetto")
                } footer: {
                    Text("Personalizza l'interfaccia")
                }
                
                // 5. SINCRONIZZAZIONE
                Section {
                    HStack {
                        Label("Sincronizzazione iCloud", systemImage: "icloud.fill")
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
                            Label("Ripristina dati da iCloud", systemImage: "arrow.down.circle")
                        }
                        
                        // Verifica stato sincronizzazione
                        Button {
                            viewModel.checkCloudKitSyncStatus()
                        } label: {
                            Label("Verifica stato sincronizzazione", systemImage: "checkmark.circle")
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
                        Label("Backup e Ripristino", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Text("Backup Manuale")
                } footer: {
                    Text("Esporta o importa i tuoi dati manualmente. Utile per backup locali o trasferimento dati.")
                }
                
                // 7. INFORMAZIONI
                Section {
                    HStack {
                        Label("Versione", systemImage: "info.circle.fill")
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
                        Label("Ripristina FoodFade", systemImage: "arrow.counterclockwise")
                            .foregroundColor(.red)
                    }
                }
            }
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
        ThemeManager.shared.accentColor = .default
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
