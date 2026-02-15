import SwiftUI
import SwiftData

/// Dettaglio di una singola chat con Fridgy: cronologia persistita e invio messaggi.
struct FridgyChatDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chat: FridgyChat
    
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let fridgyBlue = Color(red: 100/255, green: 175/255, blue: 230/255)
    
    private var sortedMessages: [FridgyMessage] {
        chat.messages.sorted { $0.createdAt < $1.createdAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedMessages) { msg in
                            messageBubble(msg)
                        }
                        if isLoading {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14))
                                    .foregroundColor(fridgyBlue)
                                ProgressView()
                                    .scaleEffect(0.9)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    if let last = sortedMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            if let err = errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
            
            HStack(alignment: .bottom, spacing: 10) {
                TextField("fridgy.chat.placeholder".localized, text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .lineLimit(1...5)
                    .disabled(isLoading)
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : fridgyBlue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            try? modelContext.save()
        }
    }
    
    private func messageBubble(_ msg: FridgyMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isFromUser { Spacer(minLength: 40) }
            if !msg.isFromUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(fridgyBlue)
            }
            messageText(msg.text, isFromUser: msg.isFromUser)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isFromUser ? fridgyBlue : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !msg.isFromUser { Spacer(minLength: 40) }
        }
    }

    /// Testo con supporto Markdown (**bold**, *italic*, ecc.); fallback a testo semplice se il parsing fallisce.
    @ViewBuilder
    private func messageText(_ raw: String, isFromUser: Bool) -> some View {
        if let attributed = try? AttributedString(markdown: raw) {
            Text(attributed)
                .font(.system(size: 15))
                .foregroundColor(isFromUser ? .white : .primary)
        } else {
            Text(raw)
                .font(.system(size: 15))
                .foregroundColor(isFromUser ? .white : .primary)
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        errorMessage = nil
        
        let userMsg = FridgyMessage(text: text, isFromUser: true, chat: chat)
        chat.messages.append(userMsg)
        
        if chat.title == "fridgy.chat.new_title".localized {
            let topic = text.count > 28 ? String(text.prefix(25)) + "…" : text
            chat.title = topic
        }
        
        try? modelContext.save()
        isLoading = true
        
        let history = buildHistory(forNewUserMessage: text)
        
        Task {
            do {
                let reply = try await FridgyServiceImpl.shared.generateChatReply(userMessage: text, history: history)
                await MainActor.run {
                    let assistantMsg = FridgyMessage(text: reply, isFromUser: false, chat: chat)
                    chat.messages.append(assistantMsg)
                    try? modelContext.save()
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    let fallback = FridgyMessage(text: "fridgy.chat.error_reply".localized, isFromUser: false, chat: chat)
                    chat.messages.append(fallback)
                    try? modelContext.save()
                    isLoading = false
                }
            }
        }
    }
    
    private func buildHistory(forNewUserMessage newText: String) -> [(user: String, assistant: String)] {
        let previous = Array(sortedMessages.dropLast())
        var pairs: [(user: String, assistant: String)] = []
        var i = 0
        while i < previous.count - 1 {
            if previous[i].isFromUser && !previous[i + 1].isFromUser {
                pairs.append((previous[i].text, previous[i + 1].text))
                i += 2
            } else {
                i += 1
            }
        }
        return pairs
    }
}

#Preview {
    NavigationStack {
        FridgyChatDetailView(chat: FridgyChat(title: "Preview"))
            .modelContainer(for: [FridgyChat.self, FridgyMessage.self], inMemory: true)
    }
}
