import SwiftUI
import SwiftData

/// Lista delle chat con Fridgy: più conversazioni con topic/cronologia in memoria.
struct FridgyChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var intelligenceManager = IntelligenceManager.shared
    @Query(sort: \FridgyChat.createdAt, order: .reverse) private var chats: [FridgyChat]
    
    @State private var path: [UUID] = []
    /// Caricamento esplicito per evitare lista vuota al primo ingresso (SwiftData @Query a volte non è pronto subito).
    @State private var loadedChats: [FridgyChat]?
    
    var body: some View {
        // Struttura sempre uguale (NavigationStack) per evitare "pop" quando isFridgyAvailable diventa true in ritardo
        NavigationStack(path: $path) {
            Group {
                if !intelligenceManager.isFridgyAvailable {
                    unavailableView
                } else {
                    listContent
                }
            }
            .navigationDestination(for: UUID.self) { chatId in
                FridgyChatDetailWrapper(chatId: chatId)
            }
        }
        .onAppear {
            loadChats()
            // Ritenta dopo un attimo: al primo ingresso il context può non essere ancora pronto
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                loadChats()
            }
        }
        .onChange(of: chats.count) { _, _ in
            loadChats()
        }
        .navigationTitle("fridgy.chat.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if intelligenceManager.isFridgyAvailable {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let chat = FridgyChat(title: "fridgy.chat.new_title".localized)
                        modelContext.insert(chat)
                        do {
                            try modelContext.save()
                            path.append(chat.id)
                        } catch {
                            print("FridgyChatListView: salvataggio chat fallito: \(error)")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
    }
    
    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("fridgy.chat.unavailable".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Lista da mostrare: preferisce il caricamento esplicito (loadedChats) per evitare vuoto al primo ingresso; fallback a @Query.
    private var chatsToShow: [FridgyChat] {
        if let loaded = loadedChats { return loaded }
        return chats
    }
    
    private func loadChats() {
        let descriptor = FetchDescriptor<FridgyChat>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        if let list = try? modelContext.fetch(descriptor) {
            loadedChats = list
        }
    }
    
    private var listContent: some View {
        Group {
            if chatsToShow.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(chatsToShow) { chat in
                        NavigationLink(value: chat.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chat.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                if let last = chat.messages.sorted(by: { $0.createdAt < $1.createdAt }).last {
                                    Text(last.text)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                } else {
                                    Text("fridgy.chat.no_messages".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: deleteChats)
                }
            }
        }
    }

    /// Placeholder quando non c'è nessuna chat: immagine Fridgy al centro + invito a iniziarne una (opacità ridotta).
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            Image("FridgyChatPlaceholder")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 220, maxHeight: 220)
                .opacity(0.75)
            VStack(spacing: 12) {
                Text("fridgy.chat.empty_prompt".localized)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(0.9)
                Text("fridgy.chat.empty_disclaimer".localized)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(0.85)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func deleteChats(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(chatsToShow[index])
        }
        try? modelContext.save()
        loadChats()
    }
}

/// Carica la chat per ID dal context e mostra il dettaglio (così la lista si aggiorna dopo il save).
private struct FridgyChatDetailWrapper: View {
    let chatId: UUID
    @Environment(\.modelContext) private var modelContext
    @State private var chat: FridgyChat?
    
    var body: some View {
        Group {
            if let chat = chat {
                FridgyChatDetailView(chat: chat)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            fetchChat()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                fetchChat()
            }
        }
    }
    
    /// Fetch senza predicate (evita problemi di binding) e filtro per id. Forza il caricamento della relazione messages.
    private func fetchChat() {
        guard chat == nil else { return }
        let descriptor = FetchDescriptor<FridgyChat>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let all = try? modelContext.fetch(descriptor)
        guard let found = all?.first(where: { $0.id == chatId }) else { return }
        _ = found.messages.count
        chat = found
    }
}

#Preview {
    NavigationStack {
        FridgyChatListView()
            .modelContainer(for: [FridgyChat.self, FridgyMessage.self], inMemory: true)
    }
}
