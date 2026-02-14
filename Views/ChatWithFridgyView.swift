import SwiftUI

/// Chat con Fridgy: l'utente può fare domande come in un chatbot (conservazione, sprechi, idee).
struct ChatWithFridgyView: View {
    struct Message: Identifiable {
        let id = UUID()
        let isFromUser: Bool
        let text: String
    }
    
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private let fridgyBlue = Color(red: 100/255, green: 175/255, blue: 230/255)
    
    var body: some View {
        Group {
            if !IntelligenceManager.shared.isFridgyAvailable {
                unavailableView
            } else {
                chatView
            }
        }
        .navigationTitle("fridgy.chat.title".localized)
        .navigationBarTitleDisplayMode(.inline)
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
    
    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
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
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
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
    }
    
    private func messageBubble(_ msg: Message) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if msg.isFromUser { Spacer(minLength: 40) }
            if !msg.isFromUser {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(fridgyBlue)
            }
            Text(msg.text)
                .font(.system(size: 15))
                .foregroundColor(msg.isFromUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(msg.isFromUser ? fridgyBlue : Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            if !msg.isFromUser { Spacer(minLength: 40) }
        }
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        errorMessage = nil
        messages.append(Message(isFromUser: true, text: text))
        isLoading = true
        
        // Storia: coppie (utente, Fridgy) prima di questo messaggio (già aggiunto in messages)
        var pairs: [(user: String, assistant: String)] = []
        var i = 0
        while i < messages.count - 1 {
            if messages[i].isFromUser && i + 1 < messages.count && !messages[i + 1].isFromUser {
                pairs.append((messages[i].text, messages[i + 1].text))
                i += 2
            } else {
                i += 1
            }
        }
        
        Task {
            do {
                let reply = try await FridgyServiceImpl.shared.generateChatReply(userMessage: text, history: pairs)
                await MainActor.run {
                    messages.append(Message(isFromUser: false, text: reply))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    messages.append(Message(isFromUser: false, text: "fridgy.chat.error_reply".localized))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ChatWithFridgyView()
    }
}
