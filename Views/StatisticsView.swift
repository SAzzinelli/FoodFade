import SwiftUI
import SwiftData
import Charts

/// Vista delle statistiche - UI/UX basata su screen (Waste Score, grafico, per categoria, dettagli)
struct StatisticsView: View {
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    @Query private var userProfiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var themeManager = ThemeManager.shared
    @State private var statsData: StatisticsData?
    
    private var userGender: GenderHelper.Gender {
        GenderHelper.getGender(from: userProfiles.first)
    }
    
    private var primaryColor: Color {
        themeManager.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : themeManager.primaryColor
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if let data = statsData {
                    VStack(spacing: 20) {
                        // Card di ingresso alle viste dettaglio
                        VStack(spacing: 12) {
                            NavigationLink {
                                WasteScoreDetailView(data: data, primaryColor: primaryColor, primaryColorDark: themeManager.primaryColorDark)
                            } label: {
                                StatEntryCard(
                                    icon: "chart.pie.fill",
                                    title: "Waste Score",
                                    description: "Quanto hai usato in tempo rispetto a quanto è scaduto. 100% = nessuno spreco.",
                                    iconColor: primaryColor
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if data.hasChartData {
                                NavigationLink {
                                    UsedVsWastedDetailView(data: data, primaryColor: primaryColor)
                                } label: {
                                    StatEntryCard(
                                        icon: "chart.bar.fill",
                                        title: "Cibo usato vs sprecato",
                                        description: "Confronto tra prodotti consumati e scaduti nel tempo.",
                                        iconColor: .blue
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if data.hasCategoryStats {
                                NavigationLink {
                                    CategoryDetailView(data: data, primaryColor: primaryColor)
                                } label: {
                                    StatEntryCard(
                                        icon: "square.grid.2x2.fill",
                                        title: "Per categoria",
                                        description: "Andamento per Frigorifero, Congelatore e Dispensa.",
                                        iconColor: .green
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if data.averageConsumptionDays != nil {
                                NavigationLink {
                                    AverageDaysDetailView(data: data, primaryColor: primaryColor)
                                } label: {
                                    StatEntryCard(
                                        icon: "clock.badge.checkmark",
                                        title: "Quanto tieni i prodotti",
                                        description: "In media dopo quanti giorni consumi i prodotti.",
                                        iconColor: Color(red: 0.2, green: 0.6, blue: 0.7)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            NavigationLink {
                                DetailsDetailView(data: data, primaryColor: primaryColor)
                            } label: {
                                StatEntryCard(
                                    icon: "list.bullet.rectangle",
                                    title: "Dettagli",
                                    description: "Prodotti più aggiunti e statistiche di utilizzo.",
                                    iconColor: Color(red: 0.5, green: 0.4, blue: 0.8)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                } else {
                    emptyState
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Statistiche")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ConsumedHistoryView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 18))
                            .foregroundColor(.primary)
                    }
                }
            }
            .tint(primaryColor)
            .onAppear { calculateStatistics() }
            .onChange(of: allItems.count) { _, _ in calculateStatistics() }
        }
    }
    
    // MARK: - Card di ingresso (icona colorata, descrizione, freccia)
    private struct StatEntryCard: View {
        let icon: String
        let title: String
        let description: String
        let iconColor: Color
        
        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(iconColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(20)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
    }
    
    private var emptyState: some View {
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
        .padding(40)
    }
    
    // MARK: - Statistics Calculation
    private func calculateStatistics() {
        let calendar = Calendar.current
        let now = Date()
        
        let periodStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        let periodItems = allItems.filter { $0.createdAt >= periodStart }
        
        guard !allItems.isEmpty else {
            statsData = nil
            return
        }
        
        var consumed = 0
        var expired = 0
        var expiringSoon = 0
        for item in periodItems {
            if item.isConsumed {
                consumed += 1
            } else {
                if item.expirationStatus == .expired { expired += 1 }
                else if item.expirationStatus == .soon || item.expirationStatus == .today { expiringSoon += 1 }
            }
        }
        
        let monthlyStats = MonthlyStats(consumed: consumed, expired: expired, expiringSoon: expiringSoon)
        let total = consumed + expired
        let wasteScore = total > 0 ? Double(consumed) / Double(total) : 1.0
        
        let recentTrend = calculateRecentTrend(calendar: calendar, now: now)
        let avgDays = calculateAverageConsumptionDays(items: allItems.filter { $0.isConsumed })
        let wasteByType = calculateWasteByType(items: allItems)
        let advice = generateWeeklyAdvice(monthlyStats: monthlyStats, wasteByType: wasteByType, avgDays: avgDays)
        let topAdded = calculateTopProducts(items: allItems, filterConsumed: false)
        let topWasted = calculateTopProducts(items: allItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }, filterConsumed: false)
        let weeklyData = calculateWeeklyData(calendar: calendar, now: now)
        let categoryStats = calculateCategoryStats(items: periodItems)
        
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
            weeklyData: weeklyData,
            categoryStats: categoryStats
        )
    }
    
    private func calculateCategoryStats(items: [FoodItem]) -> [CategoryStat] {
        FoodCategory.allCases.map { category in
            let inCategory = items.filter { $0.category == category }
            let consumed = inCategory.filter { $0.isConsumed }.count
            let total = inCategory.count
            return CategoryStat(category: category, consumed: consumed, total: total)
        }.filter { $0.total > 0 }
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
    
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM"
        return f
    }()
    
    private func calculateWeeklyData(calendar: Calendar, now: Date) -> [WeeklyDataPoint]? {
        var weeklyPoints: [WeeklyDataPoint] = []
        for weekOffset in 0..<4 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }
            let weekItems = allItems.filter { item in
                item.createdAt >= weekStart && item.createdAt < weekEnd
            }
            let consumed = weekItems.filter { $0.isConsumed }.count
            let expired = weekItems.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
            let weekLabel = calendar.dateComponents([.weekOfYear, .year], from: weekStart)
            let weekString = "Sett. \(weekLabel.weekOfYear ?? 0)"
            let dateLabel = Self.shortDateFormatter.string(from: weekStart)
            weeklyPoints.append(WeeklyDataPoint(week: weekString, dateLabel: dateLabel, consumed: consumed, expired: expired))
        }
        return weeklyPoints.isEmpty ? nil : weeklyPoints.reversed()
    }
    
    }

// MARK: - Dettaglio Waste Score
private struct WasteScoreDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    let primaryColorDark: Color
    @State private var animatedWasteScore: Double = 0
    @State private var improveTip: String?
    @State private var isLoadingImprove = false
    private let fridgyService = FridgyServiceImpl.shared
    
    private func emoji(percentage: Double) -> String {
        if percentage >= 1.0 { return "🎉" }
        if percentage >= 0.8 { return "👍" }
        return "⚠️"
    }
    private func title(percentage: Double) -> String {
        if percentage >= 1.0 { return "Perfetto!" }
        if percentage >= 0.8 { return "Quasi perfetto" }
        return "Attenzione agli sprechi"
    }
    private func subtitle(wasted: Int) -> String {
        if wasted == 0 { return "Nessun prodotto scaduto questo mese" }
        return "\(wasted) \(wasted == 1 ? "prodotto scaduto" : "prodotti scaduti") questo mese"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Contenuto: score e periodo
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.content".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(spacing: 16) {
                        Text("Waste Score")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        ZStack {
                            Circle()
                                .stroke(Color(.systemGray5), lineWidth: 18)
                                .frame(width: 160, height: 160)
                            Circle()
                                .trim(from: 0, to: animatedWasteScore)
                                .stroke(primaryColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .frame(width: 160, height: 160)
                                .animation(.spring(response: 1.5, dampingFraction: 0.8), value: animatedWasteScore)
                            VStack(spacing: 6) {
                                Text(emoji(percentage: data.wasteScore)).font(.system(size: 40))
                                Text("\(Int(animatedWasteScore * 100))%").font(.system(size: 36, weight: .bold)).foregroundColor(.primary)
                            }
                        }
                        Text(title(percentage: data.wasteScore)).font(.system(size: 18, weight: .bold)).foregroundColor(.primary)
                        Text("\(Int(data.wasteScore * 100))% di spreco evitato").font(.system(size: 15)).foregroundColor(.secondary)
                        Text(subtitle(wasted: data.monthlyStats.expired)).font(.system(size: 14)).foregroundColor(.secondary).multilineTextAlignment(.center)
                        Button("Continua così") { }.font(.system(size: 16, weight: .medium)).foregroundColor(primaryColor).buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nel periodo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack(spacing: 16) {
                            Label("\(data.monthlyStats.consumed) consumati", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.green)
                            Label("\(data.monthlyStats.expired) scaduti", systemImage: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                
                // Cos'è? e come migliorare
                VStack(alignment: .leading, spacing: 8) {
                    Label("stats.what_is".localized, systemImage: "book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 10) {
                        Label("stats.what_is".localized, systemImage: "book.closed.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Il Waste Score è la percentuale di prodotti che hai consumato prima della scadenza. 100% significa che nulla è andato sprecato; più il valore è basso, più prodotti sono scaduti senza essere usati. Controlla spesso le scadenze e pianifica i pasti per migliorare.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Come migliorare", systemImage: "lightbulb.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        if isLoadingImprove {
                            FridgySkeletonLoader()
                        } else if let tip = improveTip {
                            Text(tip)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else if !IntelligenceManager.shared.isFridgyAvailable {
                            Text("Attiva i suggerimenti Fridgy nelle Impostazioni per ricevere consigli personalizzati.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Waste Score")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) { animatedWasteScore = data.wasteScore }
            loadImproveTip()
        }
    }
    
    private func loadImproveTip() {
        guard IntelligenceManager.shared.isFridgyAvailable,
              let payload = FridgyPayload.forWasteScoreImprovement(statistics: data) else { return }
        isLoadingImprove = true
        Task {
            do {
                let text = try await fridgyService.generateMessage(from: payload.promptContext)
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    improveTip = sanitized.isEmpty ? nil : String(sanitized.prefix(120))
                    isLoadingImprove = false
                }
            } catch {
                await MainActor.run {
                    improveTip = nil
                    isLoadingImprove = false
                }
            }
        }
    }
}

// MARK: - Dettaglio Cibo usato vs sprecato
private struct UsedVsWastedDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cos'è?
                VStack(alignment: .leading, spacing: 8) {
                    Label("stats.what_is".localized, systemImage: "book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("stats.used_vs_wasted.description".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                // Contenuto
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.content".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cibo usato vs sprecato")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("Confronto tra prodotti consumati e scaduti")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        if let weeklyData = data.weeklyData {
                            Text("Ultime 4 settimane")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Chart(weeklyData) { point in
                                BarMark(x: .value("Data", point.dateLabel), y: .value("Consumati", point.consumed))
                                    .foregroundStyle(primaryColor)
                                BarMark(x: .value("Data", point.dateLabel), y: .value("Scaduti", point.expired))
                                    .foregroundStyle(.red)
                            }
                            .chartXAxis { AxisMarks(values: .automatic) { _ in AxisValueLabel().font(.system(size: 11)) } }
                            .chartYAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 11)) } }
                            .frame(height: 220)
                            HStack(spacing: 20) {
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(primaryColor).frame(width: 12, height: 12)
                                    Text("Consumati").font(.system(size: 13)).foregroundColor(.secondary)
                                }
                                HStack(spacing: 6) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.red).frame(width: 12, height: 12)
                                    Text("Scaduti").font(.system(size: 13)).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Cibo usato vs sprecato")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Per categoria
private struct CategoryDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private var totalItems: Int {
        data.categoryStats.reduce(0) { $0 + $1.total }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cos'è?
                VStack(alignment: .leading, spacing: 8) {
                    Label("stats.what_is".localized, systemImage: "book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("stats.by_category.description".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                // Contenuto
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.content".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Per categoria")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(totalItems) prodotti nel periodo · Consumati vs totali per luogo")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        ForEach(data.categoryStats, id: \.category) { stat in
                            HStack(spacing: 12) {
                                Image(systemName: stat.category.iconFill)
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.color(for: stat.category))
                                    .frame(width: 32)
                                Text(stat.category.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                                Spacer(minLength: 8)
                                if stat.total > 0 && stat.consumed == stat.total {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 16))
                                }
                                Text("\(stat.consumed)/\(stat.total)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Per categoria")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Quanto tieni i prodotti
private struct AverageDaysDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    var body: some View {
        Group {
            if let avgDays = data.averageConsumptionDays {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Quanto tieni i prodotti")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .stroke(Color(red: 0.2, green: 0.6, blue: 0.7).opacity(0.4), lineWidth: 2)
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "clock.badge.checkmark")
                                        .font(.system(size: 28))
                                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.7))
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("In media li consumi dopo")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.primary)
                                    HStack(spacing: 12) {
                                        Text("\(avgDays)")
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                            .frame(width: 56, height: 56)
                                            .background(Color(red: 0.2, green: 0.6, blue: 0.7))
                                            .clipShape(Circle())
                                        Text(avgDays == 1 ? "giorno" : "giorni")
                                            .font(.system(size: 18))
                                            .foregroundColor(.primary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            Text("Media calcolata sui prodotti che hai segnato come consumati.")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    .padding(20)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Quanto tieni i prodotti")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Dettaglio Dettagli (prodotti più aggiunti)
private struct DetailsDetailView: View {
    let data: StatisticsData
    let primaryColor: Color
    
    private var totalAdded: Int {
        data.topAddedProducts.reduce(0) { $0 + $1.count }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Cos'è?
                VStack(alignment: .leading, spacing: 8) {
                    Label("stats.what_is".localized, systemImage: "book.closed.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("stats.details.description".localized)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                // Contenuto
                VStack(alignment: .leading, spacing: 8) {
                    Text("stats.section.content".localized)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Prodotti più aggiunti")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        Text("\(data.topAddedProducts.count) prodotti · \(totalAdded) inserimenti totali")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        if data.topAddedProducts.isEmpty {
                            Text("I dettagli compariranno man mano che usi l'app")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(Array(data.topAddedProducts.prefix(10).enumerated()), id: \.element.name) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color(red: 0.5, green: 0.4, blue: 0.8))
                                        .clipShape(Circle())
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(.primary)
                                        Text("aggiunto \(item.count) \(item.count == 1 ? "volta" : "volte")")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    if !data.topWastedProducts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Prodotti più sprecati")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Text("\(data.topWastedProducts.count) prodotti scaduti senza consumo")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            ForEach(Array(data.topWastedProducts.prefix(5).enumerated()), id: \.element.name) { index, item in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                    Text(item.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(item.count)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Dettagli")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Category stat per "Per categoria"
struct CategoryStat {
    let category: FoodCategory
    let consumed: Int
    let total: Int
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
    let categoryStats: [CategoryStat]
    
    var hasCategoryStats: Bool {
        !categoryStats.isEmpty
    }
    
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
            weeklyData: nil,
            categoryStats: []
        )
    }
}

struct WeeklyDataPoint: Identifiable {
    let id = UUID()
    let week: String
    /// Per il grafico: "1 feb", "8 feb"...
    let dateLabel: String
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
