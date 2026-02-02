import SwiftUI

/// Vista per selezionare giorni personalizzati per le notifiche
struct CustomDaysPickerView: View {
    @Binding var customDays: Int
    @Environment(\.dismiss) private var dismiss
    
    @State private var daysText: String
    
    init(customDays: Binding<Int>) {
        self._customDays = customDays
        self._daysText = State(initialValue: "\(customDays.wrappedValue)")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Giorni", text: $daysText)
                        .keyboardType(.numberPad)
                        .onChange(of: daysText) { oldValue, newValue in
                            // Filtra solo numeri
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                daysText = filtered
                            }
                        }
                } header: {
                    Text("Numero di giorni")
                } footer: {
                    Text("Inserisci un numero tra 1 e 30 per ricevere la notifica X giorni prima della scadenza")
                }
            }
            .navigationTitle("Giorni personalizzati")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        if let days = Int(daysText), days > 0 && days <= 30 {
                            customDays = days
                            dismiss()
                        }
                    }
                    .disabled(Int(daysText) == nil || Int(daysText)! <= 0 || Int(daysText)! > 30)
                }
            }
        }
    }
}

#Preview {
    CustomDaysPickerView(customDays: .constant(3))
}

