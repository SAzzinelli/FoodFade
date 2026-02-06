import SwiftUI
import SwiftData
import CloudKit
import UIKit

/// Schermata di benvenuto iniziale con onboarding completo - VERSIONE DEFINITIVA
struct WelcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentStep = 0
    @State private var showApp = false
    @State private var showSplash = true
    @State private var showingAddFood = false
    @State private var selectedCloudOption: CloudOption? = .iCloud // Preseleziona iCloud (Apple-style)
    @State private var notificationPermissionGranted = false
    @State private var isiCloudAvailable = false
    @State private var firstName: String = ""
    @State private var saveError: String?
    
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    
    private var totalSteps: Int {
        isiCloudAvailable ? 6 : 5
    }
    
    var body: some View {
        Group {
            if hasSeenWelcome || showApp {
                ContentView()
            } else if showSplash {
                SplashView(showWelcome: Binding(
                    get: { !showSplash },
                    set: { newValue in
                        if newValue {
                            showSplash = false
                        }
                    }
                ))
            } else {
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    // Background animato con simboli cibo/foglie
                    AnimatedFoodBackground()
                        .opacity(0.08)
                        .ignoresSafeArea()
                    
                    // Contenitore unico per lo step corrente - nessuna transizione orizzontale
                    Group {
                        switch currentStep {
                        case 0:
                            // Step 1: Benvenuto
                            WelcomeStep1View(
                                currentStep: 0,
                                totalSteps: totalSteps,
                                onNext: { 
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        currentStep = 1
                                    }
                                }
                            )
                            .transition(.opacity)
                            
                        case 1:
                            // Step 2: Come ti aiutiamo
                            WelcomeStep2View(
                                currentStep: 1,
                                totalSteps: totalSteps,
                                onNext: { 
                                    // Se iCloud non disponibile, salta lo step 3
                                    if isiCloudAvailable {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 2
                                        }
                                    } else {
                                        // Salta step iCloud, va direttamente agli avvisi
                                        saveCloudChoice(.localOnly)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 2
                                        }
                                    }
                                }
                            )
                            .transition(.opacity)
                            
                        case 2:
                            if isiCloudAvailable {
                                // Step 3: Dove vengono salvati i dati (iCloud) - SOLO se disponibile
                                WelcomeStep3CloudView(
                                    currentStep: 2,
                                    totalSteps: totalSteps,
                                    selectedOption: $selectedCloudOption,
                                    onNext: {
                                        if let option = selectedCloudOption {
                                            saveCloudChoice(option)
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                currentStep = 3
                                            }
                                        }
                                    }
                                )
                                .transition(.opacity)
                            } else {
                                // Step 4: Avvisi (quando iCloud non disponibile, step 2 diventa step 3)
                                WelcomeStep4NotificationsView(
                                    currentStep: 2,
                                    totalSteps: totalSteps,
                                    notificationPermissionGranted: $notificationPermissionGranted,
                                    onNext: { 
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 3
                                        }
                                    }
                                )
                                .transition(.opacity)
                            }
                            
                        case 3:
                            if isiCloudAvailable {
                                // Step 4: Avvisi
                                WelcomeStep4NotificationsView(
                                    currentStep: 3,
                                    totalSteps: totalSteps,
                                    notificationPermissionGranted: $notificationPermissionGranted,
                                    onNext: { 
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 4
                                        }
                                    }
                                )
                                .transition(.opacity)
                            } else {
                                // Step 5: Nome (quando iCloud non disponibile)
                                WelcomeStep5NameView(
                                    currentStep: 3,
                                    totalSteps: totalSteps,
                                    firstName: $firstName,
                                    onNext: {
                                        saveUserProfile()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 4
                                        }
                                    }
                                )
                                .transition(.opacity)
                            }
                            
                        case 4:
                            if isiCloudAvailable {
                                // Step 5: Nome
                                WelcomeStep5NameView(
                                    currentStep: 4,
                                    totalSteps: totalSteps,
                                    firstName: $firstName,
                                    onNext: {
                                        saveUserProfile()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            currentStep = 5
                                        }
                                    }
                                )
                                .transition(.opacity)
                            } else {
                                // Step 6: Inizia (quando iCloud non disponibile)
                                WelcomeStep6StartView(
                                    currentStep: 4,
                                    totalSteps: totalSteps,
                                    onStart: {
                                        hasSeenWelcome = true
                                        showApp = true
                                    }
                                )
                                .transition(.opacity)
                            }
                            
                        case 5:
                            // Step 6: Inizia (solo quando iCloud disponibile)
                            WelcomeStep6StartView(
                                currentStep: 5,
                                totalSteps: totalSteps,
                                onStart: {
                                    hasSeenWelcome = true
                                    showApp = true
                                }
                            )
                            .transition(.opacity)
                            
                        default:
                            EmptyView()
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
        }
        .onAppear {
            checkiCloudAvailability()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppResetPerformed"))) { _ in
            showApp = false
            showSplash = true
            currentStep = 0
            selectedCloudOption = nil
            notificationPermissionGranted = false
        }
        .onChange(of: hasSeenWelcome) { oldValue, newValue in
            if !newValue && oldValue {
                showApp = false
                showSplash = true
                currentStep = 0
                selectedCloudOption = nil
                notificationPermissionGranted = false
            }
        }
        .alert("welcome.save.error.title".localized, isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("common.ok".localized) { saveError = nil }
        } message: {
            if let err = saveError { Text(err) }
        }
    }
    
    private func checkiCloudAvailability() {
        Task {
            let container = CKContainer.default()
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    isiCloudAvailable = (status == .available)
                }
            } catch {
                await MainActor.run {
                    isiCloudAvailable = false
                }
            }
        }
    }
    
    private func saveCloudChoice(_ option: CloudOption) {
        UserDefaults.standard.set(option == .iCloud, forKey: "iCloudSyncEnabled")
        UserDefaults.standard.set(true, forKey: "hasChosenCloudUsage")
        
        do {
            let descriptor = FetchDescriptor<AppSettings>()
            if let settings = try modelContext.fetch(descriptor).first {
                settings.iCloudSyncEnabled = (option == .iCloud)
                settings.hasChosenCloudUsage = true
            } else {
                let settings = AppSettings(
                    iCloudSyncEnabled: (option == .iCloud),
                    hasChosenCloudUsage: true
                )
                modelContext.insert(settings)
            }
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }
    
    private func saveUserProfile() {
        let profile = UserProfile(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: nil,
            hasCompletedOnboarding: true
        )
        modelContext.insert(profile)
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Cloud Option Enum
enum CloudOption {
    case iCloud
    case localOnly
}

// MARK: - Onboarding Progress Indicator
private struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? ThemeManager.shared.onboardingButtonColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentStep)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// MARK: - Step 1: Benvenuto
private struct WelcomeStep1View: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Query private var userProfiles: [UserProfile]
    
    private var leafColor: Color { colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor }
    private var leafColorDark: Color { colorScheme == .dark ? ThemeManager.naturalHomeLogoColor.opacity(0.8) : ThemeManager.shared.primaryColorDark }
    
    private var welcomeTitle: String {
        let gender = GenderHelper.getGender(from: userProfiles.first)
        return GenderHelper.localizedString("onboarding.welcome.title", gender: gender)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Logo
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [leafColor, leafColorDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)
                    
                    // Titolo e sottotitolo
                    VStack(alignment: .center, spacing: 12) {
                        Text(welcomeTitle)
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("onboarding.welcome.subtitle".localized)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 40)
                    
                    // Feature list (3, concise)
                    VStack(alignment: .leading, spacing: 24) {
                        FeatureRow(
                            icon: "plus.circle.fill",
                            title: "onboarding.welcome.feature1.title".localized,
                            description: "onboarding.welcome.feature1.description".localized
                        )
                        
                        FeatureRow(
                            icon: "calendar",
                            title: "onboarding.welcome.feature2.title".localized,
                            description: "onboarding.welcome.feature2.description".localized
                        )
                        
                        FeatureRow(
                            icon: "leaf.fill",
                            title: "onboarding.welcome.feature3.title".localized,
                            description: "onboarding.welcome.feature3.description".localized
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onNext()
                } label: {
                    Text("onboarding.welcome.start".localized)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ThemeManager.shared.onboardingButtonColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Step 2: Come ti aiutiamo
private struct WelcomeStep2View: View {
    let currentStep: Int
    let totalSteps: Int
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Titolo
                    Text("onboarding.help.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    
                    // Testo
                    Text("onboarding.help.text".localized)
                        .font(.system(size: 17, weight: .regular, design: .default))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                    
                    // Bullet (2 max)
                    VStack(alignment: .leading, spacing: 24) {
                        FeatureRow(
                            icon: "checkmark.circle.fill",
                            title: "onboarding.help.feature1.title".localized,
                            description: "onboarding.help.feature1.description".localized
                        )
                        
                        FeatureRow(
                            icon: "bell.fill",
                            title: "onboarding.help.feature2.title".localized,
                            description: "onboarding.help.feature2.description".localized
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onNext()
                } label: {
                    Text("onboarding.help.continue".localized)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ThemeManager.shared.onboardingButtonColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Step 3: Dove vengono salvati i dati (iCloud) - STEP CHIAVE
private struct WelcomeStep3CloudView: View {
    let currentStep: Int
    let totalSteps: Int
    @Binding var selectedOption: CloudOption?
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 32) {
                    // Titolo
                    Text("onboarding.cloud.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                    .padding(.top, 20)
            
            // Testo
            Text("onboarding.cloud.text".localized)
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
            
            // Opzioni
            VStack(spacing: 16) {
                    // OPZIONE 1 - CONSIGLIATA (preselezionata)
                CloudOptionButton(
                    title: "onboarding.cloud.option1.title".localized,
                    description: "onboarding.cloud.option1.description".localized,
                    icon: "icloud.fill",
                    isSelected: selectedOption == .iCloud,
                        isRecommended: true,
                        syncNote: nil
                ) {
                    selectedOption = .iCloud
                }
                
                // OPZIONE 2
                CloudOptionButton(
                    title: "onboarding.cloud.option2.title".localized,
                    description: "onboarding.cloud.option2.description".localized,
                    icon: "iphone",
                    isSelected: selectedOption == .localOnly,
                        isRecommended: false,
                        syncNote: nil
                ) {
                    selectedOption = .localOnly
                }
            }
            .padding(.horizontal, 40)
            
            // Nota di rassicurazione
                VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.cloud.note1".localized)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if selectedOption == .iCloud {
                        Text("onboarding.cloud.note2.icloud".localized)
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("onboarding.cloud.note2.local".localized)
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ctaButton
            }
        }
    }
    
    private var ctaButton: some View {
            Button {
                onNext()
            } label: {
            Text(ctaText)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(selectedOption != nil ? ThemeManager.shared.onboardingButtonColor : Color.gray)
                    .cornerRadius(12)
            }
            .disabled(selectedOption == nil)
            .padding(.horizontal, 40)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }
    
    private var ctaText: String {
        guard let option = selectedOption else {
            return "onboarding.cloud.continue".localized
        }
        return option == .iCloud 
            ? "onboarding.cloud.continue.icloud".localized 
            : "onboarding.cloud.continue.local".localized
    }
}

// MARK: - Cloud Option Button
private struct CloudOptionButton: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let isRecommended: Bool
    let syncNote: String?
    let action: () -> Void
    
    /// Colore icona quando non selezionato (tematizzato: iCloud blu, iPhone grigio)
    private var unselectedIconColor: Color {
        icon == "icloud.fill" ? Color(red: 0.2, green: 0.5, blue: 0.95) : Color(red: 0.45, green: 0.45, blue: 0.5)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icona
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : unselectedIconColor)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color.white.opacity(0.2) : unselectedIconColor.opacity(0.15))
                    .cornerRadius(10)
                    .layoutPriority(0)
                
                // Testo
                VStack(alignment: .leading, spacing: 6) {
                    // Badge "Consigliato" su riga separata
                        if isRecommended {
                            Text("onboarding.cloud.recommended".localized)
                                .font(.system(size: 12, weight: .medium, design: .default))
                                .foregroundColor(isSelected ? .white.opacity(0.9) : unselectedIconColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(isSelected ? Color.white.opacity(0.2) : unselectedIconColor.opacity(0.2))
                                .cornerRadius(6)
                        }
                    
                    // Titolo - quando non selezionato testo nero su sfondo chiaro (sempre leggibile)
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(isSelected ? .white : Color(white: 0.15))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)
                    
                    // Descrizione
                    Text(description)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : Color(white: 0.35))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)
                    
                    // Nota sulla sincronizzazione (solo per iCloud)
                    if let syncNote = syncNote {
                        Text(syncNote)
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : Color(white: 0.45))
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 2)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                Spacer()
                
                // Checkmark se selezionato
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(isSelected ? ThemeManager.shared.onboardingButtonColor : Color(white: 0.95))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? ThemeManager.shared.onboardingButtonColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Step 4: Avvisi
private struct WelcomeStep4NotificationsView: View {
    let currentStep: Int
    let totalSteps: Int
    @Binding var notificationPermissionGranted: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Titolo
                    Text("onboarding.notifications.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
            
            // Testo
            Text("onboarding.notifications.text".localized)
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
            
            // Bullet
                VStack(alignment: .leading, spacing: 24) {
                FeatureRow(
                    icon: "bell.fill",
                    title: "onboarding.notifications.feature.title".localized,
                    description: "onboarding.notifications.feature.description".localized
                )
            }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    // CTA PRIMARIA
                    if !notificationPermissionGranted {
                Button {
                    Task {
                        await requestNotificationPermission()
                    }
                } label: {
                    HStack {
                        Text("onboarding.notifications.enable".localized)
                            .font(.system(size: 17, weight: .semibold, design: .default))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ThemeManager.shared.onboardingButtonColor)
                    .cornerRadius(12)
                }
                        .padding(.horizontal, 40)
                    } else {
                        // Stato attivato - solo indicatore, non bottone
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("onboarding.notifications.enabled".localized)
                                .font(.system(size: 17, weight: .medium, design: .default))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                    }
                    
                    // CTA SECONDARIA (non colpevolizzante)
                    if !notificationPermissionGranted {
                        Button {
                            onNext()
                        } label: {
                            Text("onboarding.notifications.skip".localized)
                                .font(.system(size: 17, weight: .regular, design: .default))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Stato successivo: Avvisi attivi
                        Button {
                            onNext()
                        } label: {
                            Text("onboarding.notifications.continue".localized)
                                .font(.system(size: 17, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(ThemeManager.shared.onboardingButtonColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
    
    private func requestNotificationPermission() async {
        do {
            try await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                notificationPermissionGranted = true
            }
        } catch {
            print("Errore richiesta notifiche: \(error)")
        }
    }
}

// MARK: - Step 5: Nome
private struct WelcomeStep5NameView: View {
    let currentStep: Int
    let totalSteps: Int
    @Binding var firstName: String
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Titolo
                    Text("onboarding.name.title".localized)
                        .font(.system(size: 32, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
            
            // Campo nome
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(ThemeManager.shared.onboardingButtonColor)
                    Text("onboarding.name.label".localized)
                        .font(.system(size: 15, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                }
                
                TextField("onboarding.name.placeholder".localized, text: $firstName)
                    .font(.system(size: 18, weight: .regular, design: .default))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(firstName.isEmpty ? Color.clear : ThemeManager.shared.onboardingButtonColor, lineWidth: 2)
                    )
            }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    // Chiudi la tastiera
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    onNext()
                } label: {
                    Text("onboarding.name.continue".localized)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(firstName.isEmpty ? Color.gray : ThemeManager.shared.onboardingButtonColor)
                        .cornerRadius(12)
                }
                .disabled(firstName.isEmpty)
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Step 6: Inizia
private struct WelcomeStep6StartView: View {
    let currentStep: Int
    let totalSteps: Int
    let onStart: () -> Void
    @State private var checkmarkScale: CGFloat = 0.5
    @State private var checkmarkOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Indicatore di progresso
            OnboardingProgressIndicator(currentStep: currentStep, totalSteps: totalSteps)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Checkmark animato
                    ZStack {
                        // Checkmark animato
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(ThemeManager.shared.onboardingButtonColor)
                            .scaleEffect(checkmarkScale)
                            .opacity(checkmarkOpacity)
                            .overlay(
                                Circle()
                                    .stroke(ThemeManager.shared.onboardingButtonColor, lineWidth: 3)
                                    .scaleEffect(checkmarkScale * 1.2)
                                    .opacity(checkmarkOpacity * 0.5)
                            )
                    }
                    .frame(height: 120)
                    .padding(.top, 20)
                    .onAppear {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                            checkmarkScale = 1.0
                            checkmarkOpacity = 1.0
                        }
                    }
                
                // Titolo
                Text("onboarding.start.title".localized)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Testo
                Text("onboarding.start.text".localized)
                    .font(.system(size: 17, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onStart()
                } label: {
                    Text("onboarding.start.button".localized)
                        .font(.system(size: 17, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(ThemeManager.shared.onboardingButtonColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - Animated Food Background
private struct AnimatedFoodBackground: View {
    @State private var animationOffset: CGFloat = 0
    @State private var timer: Timer?
    
    let foodIcons = ["leaf.fill", "carrot.fill", "apple.fill", "leaf.circle.fill", "drop.fill", "flame.fill"]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<20, id: \.self) { index in
                    let icon = foodIcons[index % foodIcons.count]
                    let xOffset = CGFloat(index % 4) * (geometry.size.width / 4)
                    let yOffset = CGFloat(index / 4) * (geometry.size.height / 5)
                    let delay = Double(index) * 0.3
                    let speed = 1.0 + Double(index % 3) * 0.5
                    
                    Image(systemName: icon)
                        .font(.system(size: CGFloat(30 + (index % 3) * 10)))
                        .foregroundColor(ThemeManager.shared.primaryColor)
                        .position(
                            x: xOffset + sin(animationOffset * speed + delay) * 30,
                            y: yOffset + cos(animationOffset * speed + delay) * 30
                        )
                }
            }
        }
        .task {
            // Animazione continua che non riparte da zero quando la vista si resetta
            // Usa un task che continua anche quando la vista si aggiorna
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~60fps
                animationOffset += 0.01
                if animationOffset > .pi * 2 {
                    animationOffset = 0
                }
            }
        }
    }
}

// MARK: - FeatureRow Component
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    /// Colore tematizzato per icona (topic di riferimento)
    private var iconColor: Color {
        switch icon {
        case "plus.circle.fill": return ThemeManager.naturalHomeLogoColor
        case "calendar": return Color(red: 0.2, green: 0.5, blue: 0.95)
        case "leaf.fill": return Color(red: 0.2, green: 0.7, blue: 0.35)
        case "checkmark.circle.fill": return Color(red: 0.2, green: 0.7, blue: 0.35)
        case "bell.fill": return Color(red: 1.0, green: 0.5, blue: 0.2)
        default: return ThemeManager.shared.onboardingButtonColor
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(iconColor)
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                Text(description)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(for: UserProfile.self)
}
