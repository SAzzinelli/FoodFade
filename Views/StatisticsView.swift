import SwiftUI
import SwiftData
import Charts

/// Vista delle statistiche e insight - VERSIONE FINALE DEFINITIVA
struct StatisticsView: View {
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var statsData: StatisticsData?
    @State private var animatedWasteScore: Double = 0.0
    @State private var fridgyInsights: [(message: String, context: FridgyContext)] = []
    @State private var isLoadingFridgy: Bool = false
    private let fridgyService: FridgyService = FridgyServiceImpl.shared
    
    private var userGender: GenderHelper.Gender {
        GenderHelper.getGender(from: userProfiles.first)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let data = statsData {
                    VStack(spacing: 24) {
                        // 1. Waste Score
                        wasteScoreCard(data: data)
                        
                        // 2. Andamento recente
                        if data.hasRecentTrend {
                            recentTrendCard(data: data)
                        }
                        
                        // 2.5. Grafico andamento
                        if data.hasChartData {
                            trendChartCard(data: data)
                        }
                        
                        // 3. Riepilogo periodo
                        monthlySummaryCard(data: data)
                        
                        // 4. Abitudini
                        if data.hasHabits {
                            habitsCard(data: data)
                        }
                        
                        // 5. Insight Fridgy (solo se Fridgy è disponibile e ha un messaggio)
                        if IntelligenceManager.shared.isFridgyAvailable {
                            fridgyInsightsSection(data: data)
                        }
                        
                        // 6. Dettagli (solo se dati > 0)
                        if data.hasDetails {
                            detailsCard(data: data)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                } else {
                    // Empty state iniziale
                    VStack(spacing: 16) {
                        Spacer()
                        
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Nessun dato disponibile")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Aggiungi qualche prodotto per iniziare")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistiche")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        ConsumedHistoryView()
                    } label: {
                        Label("history.title".localized, systemImage: "clock.arrow.circlepath")
                    }
                }
            }
            .tint(themeManager.primaryColor)
            .onAppear {
                calculateStatistics()
                loadFridgyInsights()
            }
            .onChange(of: allItems.count) { oldValue, newValue in
                calculateStatistics()
                loadFridgyInsights()
            }
        }
    }
    
    // MARK: - 1. Waste Score Card
    private func wasteScoreCard(data: StatisticsData) -> some View {
        VStack(spacing: 16) {
            Text("Waste Score")
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            ZStack {
                // Anello di sfondo
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)
                    .frame(width: 180, height: 180)
                
                // Anello animato
                Circle()
                    .trim(from: 0, to: animatedWasteScore)
                    .stroke(
                        LinearGradient(
                            colors: [themeManager.primaryColor, themeManager.primaryColorDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                    .shadow(color: themeManager.primaryColor.opacity(0.3), radius: 8, x: 0, y: 0)
                    .animation(.spring(response: 1.5, dampingFraction: 0.8), value: animatedWasteScore)
                
                VStack(spacing: 4) {
                    Text("\(Int(animatedWasteScore * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .default))
                        .foregroundColor(.primary)
                        .animation(.none, value: animatedWasteScore)
                    
                    Text(wasteScoreLabel(percentage: data.wasteScore))
                        .font(.system(size: 16, weight: .medium, design: .default))
                        .foregroundColor(.secondary)
                }
            }
            
            Text(wasteScoreSubtitle(wastedCount: data.monthlyStats.expired))
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                animatedWasteScore = data.wasteScore
            }
        }
        .onChange(of: data.wasteScore) { oldValue, newValue in
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                animatedWasteScore = newValue
            }
        }
    }
    
    // MARK: - 2. Andamento recente
    private func recentTrendCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Come sta andando")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            Text(data.recentTrendMessage)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 3. Riepilogo periodo
    private func monthlySummaryCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Questo mese")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            if data.monthlyStats.consumed == 0 && data.monthlyStats.expiringSoon == 0 && data.monthlyStats.expired == 0 {
                Text("Nessun dato questo mese.\nAggiungi qualche prodotto per iniziare.")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                VStack(spacing: 12) {
                    StatRow(title: "Consumati", value: "\(data.monthlyStats.consumed)")
                    StatRow(title: "In scadenza", value: "\(data.monthlyStats.expiringSoon)")
                    StatRow(title: "Scaduti", value: "\(data.monthlyStats.expired)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 4. Abitudini
    private func habitsCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Abitudini")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Card 1: Tempo medio
                if let avgDays = data.averageConsumptionDays {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quanto tieni i prodotti")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                        
                        Text("In media li consumi dopo \(avgDays) \(avgDays == 1 ? "giorno" : "giorni")")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                
                // Card 2: Tipologia
                if data.monthlyStats.expired > 0, let wasteByType = data.wasteByType, !wasteByType.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dove sprechi di più")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(wasteByType.prefix(2)), id: \.key) { item in
                                HStack {
                                    Text(item.key.rawValue)
                                        .font(.system(size: 16, weight: .regular, design: .default))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(item.value))%")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 5. Consiglio della settimana
    private func adviceCard(advice: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("stats.advice.title".localized)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            Text(advice)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - 6. Dettagli
    private func detailsCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Dettagli")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            if data.topAddedProducts.isEmpty && data.topWastedProducts.isEmpty {
                Text("I dettagli compariranno man mano che usi l'app")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 16) {
                    if !data.topAddedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prodotti più aggiunti")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(data.topAddedProducts.prefix(3)), id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .regular, design: .default))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if !data.topWastedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prodotti più sprecati")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(data.topWastedProducts.prefix(3)), id: \.name) { item in
                                HStack {
                                    Text(item.name)
                                        .font(.system(size: 16, weight: .regular, design: .default))
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold, design: .default))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Functions
    private func wasteScoreLabel(percentage: Double) -> String {
        let percent = Int(percentage * 100)
        if percent == 100 {
            return "Tutto ok"
        } else if percent >= 80 {
            return "Qualche spreco"
        } else {
            return "Attenzione agli sprechi"
        }
    }
    
    private func wasteScoreSubtitle(wastedCount: Int) -> String {
        if wastedCount == 0 {
            return "Nessuna scadenza sprecata"
        } else {
            return "Alcuni prodotti non sono stati consumati"
        }
    }
    
    // MARK: - Statistics Calculation
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calcola inizio mese
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        // Filtra elementi del mese corrente
        let thisMonthItems = allItems.filter { item in
            item.createdAt >= startOfMonth
        }
        
        // Se non ci sono dati, nascondi tutto
        guard !allItems.isEmpty else {
            statsData = nil
            return
        }
        
        // Statistiche mensili
        var consumed = 0
        var expired = 0
        var expiringSoon = 0
        
        for item in thisMonthItems {
            if item.isConsumed {
                consumed += 1
            } else {
                if item.expirationStatus == .expired {
                    expired += 1
                } else if item.expirationStatus == .soon || item.expirationStatus == .today {
                    expiringSoon += 1
                }
            }
        }
        
        let monthlyStats = MonthlyStats(consumed: consumed, expired: expired, expiringSoon: expiringSoon)
        
        // Waste Score (0-1, dove 1 = nessuno spreco)
        let total = consumed + expired
        let wasteScore = total > 0 ? Double(consumed) / Double(total) : 1.0
        
        // Andamento recente (confronto ultime 2 settimane)
        let recentTrend = calculateRecentTrend(calendar: calendar, now: now)
        
        // Tempo medio di consumo
        let avgDays = calculateAverageConsumptionDays(items: allItems.filter { $0.isConsumed })
        
        // Sprechi per tipo (percentuali)
        let wasteByType = calculateWasteByType(items: allItems)
        
        // Consiglio settimanale
        let advice = generateWeeklyAdvice(
            monthlyStats: monthlyStats,
            wasteByType: wasteByType,
            avgDays: avgDays
        )
        
        // Top prodotti
        let topAdded = calculateTopProducts(items: allItems, filterConsumed: false)
        let topWasted = calculateTopProducts(items: allItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }, filterConsumed: false)
        
        // Dati per il grafico (ultime 4 settimane)
        let weeklyData = calculateWeeklyData(calendar: calendar, now: now)
        
        statsData = StatisticsData(
            wasteScore: wasteScore,
            monthlyStats: monthlyStats,
            recentTrendMessage: recentTrend.message,
            hasRecentTrend: recentTrend.hasData,
            averageConsumptionDays: avgDays,
            wasteByType: wasteByType,
            weeklyAdvice: advice,
            topAddedProducts: topAdded,
            topWastedProducts: topWasted,
            weeklyData: weeklyData
        )
    }
    
    private func calculateRecentTrend(calendar: Calendar, now: Date) -> (message: String, hasData: Bool) {
        // Ultime 2 settimane
        guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now),
              let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return ("Situazione stabile nelle ultime settimane", false)
        }
        
        let firstWeek = allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .expired &&
            item.createdAt >= twoWeeksAgo && item.createdAt < oneWeekAgo
        }
        
        let secondWeek = allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .expired &&
            item.createdAt >= oneWeekAgo && item.createdAt <= now
        }
        
        let firstCount = firstWeek.count
        let secondCount = secondWeek.count
        
        guard firstCount > 0 || secondCount > 0 else {
            return ("Situazione stabile nelle ultime settimane", false)
        }
        
        if secondCount < firstCount {
            return ("Stai sprecando meno rispetto alla settimana scorsa 👍", true)
        } else if secondCount > firstCount {
            return ("Hai sprecato più prodotti rispetto alla settimana scorsa", true)
        } else {
            return ("Situazione stabile nelle ultime settimane", true)
        }
    }
    
    private func calculateAverageConsumptionDays(items: [FoodItem]) -> Int? {
        guard !items.isEmpty else { return nil }
        
        let calendar = Calendar.current
        var totalDays = 0
        var count = 0
        
        for item in items {
            let days = calendar.dateComponents([.day], from: item.createdAt, to: item.lastUpdated).day ?? 0
            if days > 0 {
                totalDays += days
                count += 1
            }
        }
        
        guard count > 0 else { return nil }
        return totalDays / count
    }
    
    private func calculateWasteByType(items: [FoodItem]) -> [FoodType: Double]? {
        let wastedItems = items.filter { !$0.isConsumed && $0.expirationStatus == .expired }
        guard !wastedItems.isEmpty else { return nil }
        
        var typeCounts: [FoodType: Int] = [:]
        var total = 0
        
        for item in wastedItems {
            if let type = item.foodType {
                typeCounts[type, default: 0] += 1
                total += 1
            }
        }
        
        guard total > 0 else { return nil }
        
        return typeCounts.mapValues { Double($0) / Double(total) * 100.0 }
    }
    
    private func generateWeeklyAdvice(
        monthlyStats: MonthlyStats,
        wasteByType: [FoodType: Double]?,
        avgDays: Int?
    ) -> String? {
        // Template consigli con supporto genere
        if monthlyStats.expired == 0 {
            let advice = GenderHelper.localizedString("stats.message.excellent", gender: userGender)
            // Fallback se la stringa non viene trovata
            return advice != "stats.message.excellent" ? advice : "Ottimo lavoro! Stai riducendo gli sprechi."
        }
        
        if let avgDays = avgDays, avgDays > 7 {
            return "Alcuni prodotti restano inutilizzati per molti giorni."
        }
        
        // Conta prodotti freschi aggiunti questo mese
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let freshCount = allItems.filter { $0.isFresh && $0.createdAt >= startOfMonth }.count
        
        if freshCount > 5 {
            return "Stai aggiungendo molti prodotti freschi: controlla quelli in scadenza."
        }
        
        let advice = GenderHelper.localizedString("stats.message.good", gender: userGender)
        // Fallback se la stringa non viene trovata
        return advice != "stats.message.good" ? advice : "Stai facendo bene! Continua così."
    }
    
    private func calculateTopProducts(items: [FoodItem], filterConsumed: Bool) -> [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        
        for item in items {
            if filterConsumed && !item.isConsumed {
                continue
            }
            counts[item.name, default: 0] += 1
        }
        
        return counts.map { (name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    private func calculateWeeklyData(calendar: Calendar, now: Date) -> [WeeklyDataPoint]? {
        var weeklyPoints: [WeeklyDataPoint] = []
        
        // Calcola dati per ultime 4 settimane
        for weekOffset in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
                continue
            }
            
            let weekItems = allItems.filter { item in
                item.createdAt >= weekStart && item.createdAt < weekEnd
            }
            
            let consumed = weekItems.filter { $0.isConsumed }.count
            let expired = weekItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
            
            let weekLabel = calendar.dateComponents([.weekOfYear, .year], from: weekStart)
            let weekString = "Sett. \(weekLabel.weekOfYear ?? 0)"
            
            weeklyPoints.append(WeeklyDataPoint(week: weekString, consumed: consumed, expired: expired))
        }
        
        return weeklyPoints.isEmpty ? nil : weeklyPoints.reversed() // Più recente per ultimo
    }
    
    // MARK: - Trend Chart Card
    private func trendChartCard(data: StatisticsData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Andamento settimanale")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundColor(.primary)
            
            if let weeklyData = data.weeklyData {
                Chart(weeklyData) { point in
                    LineMark(
                        x: .value("Settimana", point.week),
                        y: .value("Consumati", point.consumed)
                    )
                    .foregroundStyle(themeManager.primaryColor)
                    .interpolationMethod(.catmullRom)
                    
                    LineMark(
                        x: .value("Settimana", point.week),
                        y: .value("Scaduti", point.expired)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Settimana", point.week),
                        y: .value("Consumati", point.consumed)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.primaryColor.opacity(0.3), themeManager.primaryColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.system(size: 11))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.system(size: 11))
                    }
                }
                
                // Legenda
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(themeManager.primaryColor)
                            .frame(width: 8, height: 8)
                        Text("Consumati")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("Scaduti")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Fridgy Insights Section
    private func fridgyInsightsSection(data: StatisticsData) -> some View {
        // Debug
        print("🔍 fridgyInsightsSection: isLoadingFridgy = \(isLoadingFridgy), fridgyInsights.count = \(fridgyInsights.count)")
        
        // Mostra skeleton loader se sta caricando
        if isLoadingFridgy {
            return AnyView(
                VStack(spacing: 12) {
                    FridgySkeletonLoader()
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                }
            )
        }
        
        // Mostra Fridgy se ha messaggi
        guard !fridgyInsights.isEmpty else {
            print("🔍 fridgyInsightsSection: fridgyInsights è vuoto, mostrando EmptyView")
            return AnyView(EmptyView())
        }
        
        print("🔍 fridgyInsightsSection: mostrando FridgyCard")
        return AnyView(
            VStack(spacing: 12) {
                ForEach(Array(fridgyInsights.enumerated()), id: \.offset) { index, insight in
                    FridgyCard(context: insight.context, message: insight.message)
                        .frame(maxWidth: CGFloat.infinity, alignment: .leading)
                }
            }
        )
    }
    
    private func loadFridgyInsights() {
        // La VIEW decide se mostrare Fridgy (controlla se è abilitato)
        guard IntelligenceManager.shared.isFridgyAvailable else {
            print("🔍 Fridgy: non disponibile (isFridgyAvailable = false)")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        guard let data = statsData else {
            print("🔍 Fridgy: statsData è nil")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        print("🔍 Fridgy: items.count = \(allItems.count), statsData presente")
        
        // La BUSINESS LOGIC decide il payload
        guard let payload = FridgyPayload.forStatistics(items: allItems, statistics: data) else {
            print("🔍 Fridgy: payload è nil (nessun suggerimento generato)")
            fridgyInsights = []
            isLoadingFridgy = false
            return
        }
        
        print("🔍 Fridgy: payload generato, context = \(payload.context), caricamento in corso...")
        
        // Mostra skeleton loader
        isLoadingFridgy = true
        
        // Il SERVIZIO genera il testo
        Task {
            do {
                let text = try await fridgyService.generateMessage(from: payload.promptContext)
                
                print("🔍 Fridgy: testo generato = '\(text)'")
                
                // Validazione: controlla che il testo sia valido
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !sanitized.isEmpty && sanitized.count <= 100 {
                    await MainActor.run {
                        fridgyInsights = [(message: sanitized, context: payload.context)]
                        isLoadingFridgy = false
                        print("🔍 Fridgy: messaggio salvato, fridgyInsights.count = \(fridgyInsights.count)")
                    }
                } else {
                    print("🔍 Fridgy: testo non valido (vuoto o troppo lungo: \(sanitized.count) caratteri)")
                    await MainActor.run {
                        fridgyInsights = []
                        isLoadingFridgy = false
                    }
                }
            } catch {
                print("🔍 Fridgy: errore durante generazione - \(error.localizedDescription)")
                // Se Apple Intelligence non è disponibile o c'è un errore, Fridgy non mostra nulla
                await MainActor.run {
                    fridgyInsights = []
                    isLoadingFridgy = false
                }
            }
        }
    }
}

// MARK: - Data Models
struct StatisticsData {
    let wasteScore: Double
    let monthlyStats: MonthlyStats
    let recentTrendMessage: String
    let hasRecentTrend: Bool
    let averageConsumptionDays: Int?
    let wasteByType: [FoodType: Double]?
    let weeklyAdvice: String?
    let topAddedProducts: [(name: String, count: Int)]
    let topWastedProducts: [(name: String, count: Int)]
    let weeklyData: [WeeklyDataPoint]?
    
    var hasHabits: Bool {
        averageConsumptionDays != nil || (wasteByType != nil && monthlyStats.expired > 0)
    }
    
    var hasDetails: Bool {
        !topAddedProducts.isEmpty || !topWastedProducts.isEmpty
    }
    
    var hasChartData: Bool {
        weeklyData != nil && !weeklyData!.isEmpty
    }
    
    static var empty: StatisticsData {
        StatisticsData(
            wasteScore: 0.0,
            monthlyStats: MonthlyStats(consumed: 0, expired: 0, expiringSoon: 0),
            recentTrendMessage: "",
            hasRecentTrend: false,
            averageConsumptionDays: nil,
            wasteByType: nil,
            weeklyAdvice: nil,
            topAddedProducts: [],
            topWastedProducts: [],
            weeklyData: nil
        )
    }
}

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let week: String
    let consumed: Int
    let expired: Int
}

struct MonthlyStats {
    let consumed: Int
    let expired: Int
    let expiringSoon: Int
}

// MARK: - Stat Row
private struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: FoodItem.self)
}
