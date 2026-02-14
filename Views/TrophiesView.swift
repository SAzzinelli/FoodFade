import SwiftUI
import SwiftData

/// Vista trofei: griglia di trofei; tap su una card apre sheet con progresso e livelli
struct TrophiesView: View {
    @Query(sort: \FoodItem.createdAt, order: .reverse) private var allItems: [FoodItem]
    @StateObject private var trophyService = TrophyService.shared
    @State private var selectedTrophyProgress: TrophyProgress?
    @Environment(\.colorScheme) private var colorScheme

    private var primaryColor: Color {
        ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor
    }
    
    private var progressList: [TrophyProgress] {
        TrophyService.shared.progressForAllTrophies(items: allItems)
    }

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(progressList) { progress in
                        Button {
                            selectedTrophyProgress = progress
                        } label: {
                            TrophyCard(
                                trophy: progress.trophy,
                                isUnlocked: progress.isUnlocked,
                                unlockDate: trophyService.unlockDate(for: progress.trophy),
                                primaryColor: primaryColor,
                                dateFormatter: Self.dateFormatter
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("trophy.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trophyService.markTrophiesAsSeen()
        }
        .sheet(item: $selectedTrophyProgress) { progress in
            TrophyDetailSheet(progress: progress, primaryColor: primaryColor)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 44))
                .foregroundStyle(primaryColor)
            Text("trophy.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
}

private struct TrophyCard: View {
    let trophy: Trophy
    let isUnlocked: Bool
    let unlockDate: Date?
    let primaryColor: Color
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? primaryColor.opacity(0.2) : Color(.tertiarySystemFill))
                    .frame(width: 64, height: 64)
                Image(systemName: trophy.iconName)
                    .font(.system(size: 28))
                    .foregroundColor(isUnlocked ? primaryColor : .secondary)
            }
            VStack(spacing: 4) {
                Text(trophy.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(trophy.displayDescription)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                if isUnlocked, let date = unlockDate {
                    Text(String(format: "trophy.unlocked_on".localized, dateFormatter.string(from: date)))
                        .font(.system(size: 10))
                        .foregroundColor(primaryColor.opacity(0.9))
                } else {
                    Text("trophy.locked".localized)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Sheet Dettaglio trofeo (progresso, barra, livelli)
private struct TrophyDetailSheet: View {
    let progress: TrophyProgress
    let primaryColor: Color
    @Environment(\.dismiss) private var dismiss
    @State private var appeared = false
    
    private var isPercentTrophy: Bool { progress.trophy == .wasteFighter }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icona + titolo
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(progress.isUnlocked ? primaryColor.opacity(0.2) : Color(.tertiarySystemFill))
                                .frame(width: 88, height: 88)
                            Image(systemName: progress.trophy.iconName)
                                .font(.system(size: 40))
                                .foregroundColor(progress.isUnlocked ? primaryColor : .secondary)
                        }
                        .scaleEffect(appeared ? 1 : 0.6)
                        .opacity(appeared ? 1 : 0)
                        
                        Text(progress.trophy.displayName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                        Text(progress.trophy.displayDescription)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)
                    
                    // Barra progresso
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(progress.isUnlocked ? "trophy.progress.done".localized : "\(progress.progressPercent)%")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(progress.isUnlocked ? primaryColor : .primary)
                            Spacer()
                            if !progress.isUnlocked {
                                if isPercentTrophy {
                                    Text("\(progress.currentValue)% / \(progress.targetValue)%")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("\(progress.currentValue) / \(progress.targetValue)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(.tertiarySystemFill))
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(progress.isUnlocked ? primaryColor : primaryColor.opacity(0.6))
                                    .frame(width: max(0, geo.size.width * progress.progress))
                            }
                        }
                        .frame(height: 10)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    
                    Text(progress.progressSubtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    
                    // Livelli (es. 1 prodotto, 5 prodotti, 10 prodotti)
                    if !progress.trophy.levels.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("trophy.levels.title".localized)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                            VStack(spacing: 8) {
                                ForEach(Array(progress.trophy.levels.enumerated()), id: \.offset) { _, level in
                                    let reached = isPercentTrophy ? (progress.progressPercent >= level) : (progress.currentValue >= level)
                                    HStack(spacing: 12) {
                                        Image(systemName: reached ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(reached ? primaryColor : Color(.tertiaryLabel))
                                        Text(levelLabel(for: level))
                                            .font(.system(size: 15))
                                            .foregroundColor(reached ? .primary : .secondary)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(reached ? primaryColor.opacity(0.08) : Color(.tertiarySystemFill).opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    
                    if progress.isUnlocked, let date = progress.unlockDate {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(primaryColor)
                            Text(String(format: "trophy.unlocked_on".localized, formatDate(date)))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) { dismiss() }
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            }
        }
    }
    
    private func levelLabel(for level: Int) -> String {
        if progress.trophy == .wasteFighter {
            return "\(level)%"
        }
        let unit = progress.trophy.levelUnitKey.localized
        return "\(level) \(unit)"
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}

#Preview {
    NavigationStack {
        TrophiesView()
            .modelContainer(for: FoodItem.self)
    }
}
