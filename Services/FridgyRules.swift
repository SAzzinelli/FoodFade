import Foundation

/// Regole assolute di Fridgy - "Costituzione" della mascotte
struct FridgyRules {
    /// Restituisce true se il nome sembra un alimento reale (non un nome di prova tipo "nfvjdofj").
    /// Evita suggerimenti fuori contesto per prodotti creati per test.
    static func isReasonableProductName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        // Nomi multi-parola di solito sono reali (es. "Latte intero")
        if trimmed.contains(" ") { return true }
        let lower = trimmed.lowercased()
        let vowels = lower.filter { "aeiouàèéìòù".contains($0) }.count
        let letters = lower.filter { $0.isLetter }.count
        guard letters >= 2 else { return false }
        // Parola singola: deve avere almeno 2 vocali o essere molto breve (es. "Tè")
        if vowels >= 2 { return true }
        if trimmed.count <= 3 && vowels >= 1 { return true }
        // Troppe consonanti senza vocali = probabile gibberish (es. nfvjdofj)
        return false
    }
    
    /// Parole proibite che Fridgy non può mai usare
    static let forbiddenWords: Set<String> = [
        "sicuro", "rischioso", "fa bene", "dovresti", "meglio per la salute",
        "devi", "devi fare", "è necessario", "obbligatorio", "consigliato dalla medicina",
        "pericoloso", "nocivo", "dannoso", "salutare", "terapeutico"
    ]
    
    /// Limiti assoluti
    static let maxWords = 20
    static let maxSentences = 1
    
    /// Prompt base che definisce chi è Fridgy (non cambia mai)
    static let basePrompt = """
    Sei Fridgy, una mascotte silenziosa che fornisce suggerimenti opzionali e non giudicanti su come usare ingredienti già presenti.
    Non dai consigli medici.
    Non prendi decisioni.
    Non giudichi.
    Se non c'è un buon suggerimento, rispondi con 'nessun suggerimento'.
    Usa solo linguaggio suggeritivo ("puoi", "idea", "potrebbe").
    Massimo 1 frase, massimo 20 parole.
    """
    
    /// Regole di conservazione: il modello deve rispettare il contesto (luogo attuale) e non suggerire spostamenti assurdi
    static let storageContextPrompt = """
    CONTESTO CONSERVAZIONE (obbligatorio):
    - Ogni alimento ha già un luogo di conservazione: Frigorifero, Congelatore o Dispensa.
    - NON suggerire MAI di spostare un alimento da un luogo all'altro (es. non dire "tieni in frigo", "metti in dispensa", "congela").
    - NON suggerire di mettere in frigo: biscotti, cracker, pane secco, pasta, riso, conserve, miele, marmellata chiusa, olio, barrette.
    - NON suggerire di mettere in dispensa: latticini, carne, pesce, salumi, yogurt, formaggi freschi, cibo già aperto che va in frigo.
    - I suggerimenti devono riguardare SOLO utilizzo, ricette, consumo entro scadenza, non dove conservare (è già deciso dall'utente).
    """
    
    /// Coerenza culinaria: i suggerimenti devono restare sul tema, niente abbinamenti assurdi
    static let culinaryCoherencePrompt = """
    COERENZA CULINARIA (obbligatorio):
    - Suggerisci SOLO ricette e utilizzi culinariamente sensati. Resta sul tema cibo/cucina reale.
    - NON abbinare mai: biscotti, cracker, dolci da forno, cioccolato, marmellata, barrette con piatti salati (risotto, pasta al sugo, brodo, carne, pesce, verdure in padella).
    - NON proporre di mettere biscotti nel risotto, nella pasta, nelle zuppe, nelle insalate o in piatti salati.
    - Dolci e prodotti da colazione (biscotti, cereali dolci, miele su pietanze salate) vanno suggeriti solo per colazione/dessert/snack dolce, mai in primi o secondi.
    - Se gli ingredienti non si prestano a un piatto coerente, rispondi con 'nessun suggerimento' invece di inventare abbinamenti assurdi.
    """
    
    /// Valida l'output di Fridgy secondo le regole assolute
    static func validate(_ output: String) -> ValidationResult {
        // 1. Controlla lunghezza
        let words = output.split(separator: " ").count
        if words > maxWords {
            return .rejected(reason: "Troppe parole (\(words) > \(maxWords))")
        }
        
        let sentences = output.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if sentences.count > maxSentences {
            return .rejected(reason: "Troppe frasi (\(sentences.count) > \(maxSentences))")
        }
        
        // 2. Controlla parole proibite
        let lowercased = output.lowercased()
        for forbidden in forbiddenWords {
            if lowercased.contains(forbidden) {
                return .rejected(reason: "Contiene parola proibita: '\(forbidden)'")
            }
        }
        
        // 3. Controlla "nessun suggerimento"
        if lowercased.contains("nessun suggerimento") || lowercased.contains("nessuna idea") {
            return .noSuggestion
        }
        
        // 4. Controlla che non sia troppo generico
        let genericPhrases = [
            "consuma i prodotti",
            "usa gli alimenti",
            "mangia il cibo",
            "evita sprechi"
        ]
        let isTooGeneric = genericPhrases.allSatisfy { lowercased.contains($0) }
        if isTooGeneric && words < 5 {
            return .rejected(reason: "Suggerimento troppo generico")
        }
        
        // 5. Controlla che aggiunga valore
        if output.trimmingCharacters(in: .whitespaces).count < 10 {
            return .rejected(reason: "Suggerimento troppo breve, non aggiunge valore")
        }
        
        // 6. Abbinamenti assurdi: dolci/colazione in piatti salati
        let absurdSweet = ["biscotti", "cracker", "cioccolato", "marmellata", "barrette", "cereali", "miele"]
        let savoryDishes = ["zuppa", "zuppe", "risotto", "pasta ", "brodo", "insalata", "minestra", "minestrone", "ragù", "sugo "]
        let lower = output.lowercased()
        let hasSweet = absurdSweet.contains { lower.contains($0) }
        let hasSavory = savoryDishes.contains { lower.contains($0) }
        if hasSweet && hasSavory {
            return .rejected(reason: "Abbinamento culinario non sensato (dolce in piatto salato)")
        }
        
        return .accepted
    }
    
    /// Pulisce e normalizza l'output prima della validazione
    static func sanitize(_ output: String) -> String {
        var cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Rimuovi prefissi comuni del modello
        let prefixes = [
            "Fridgy: ",
            "Suggerimento: ",
            "Consiglio: ",
            "💡 ",
            "💡"
        ]
        
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Risultato della validazione
enum ValidationResult {
    case accepted
    case rejected(reason: String)
    case noSuggestion
    
    var shouldShow: Bool {
        switch self {
        case .accepted:
            return true
        case .rejected, .noSuggestion:
            return false
        }
    }
}

/// Builder per prompt Fridgy specifici per contesto
struct FridgyPromptBuilder {
    /// Prompt per Home (opportunità generica)
    static func homePrompt(items: [FoodItem]) -> String {
        let activeItems = items.filter { !$0.isConsumed && FridgyRules.isReasonableProductName($0.name) }
        let expiring = activeItems.filter { $0.expirationStatus == .today || $0.expirationStatus == .expired }
        let soon = activeItems.filter { $0.expirationStatus == .soon }
        let opened = activeItems.filter { $0.isOpened }
        
        var context = "Alimenti disponibili: "
        context += activeItems.prefix(5).map { $0.name }.joined(separator: ", ")
        
        if !expiring.isEmpty {
            context += "\nScadono oggi: \(expiring.prefix(3).map { $0.name }.joined(separator: ", "))"
        }
        if !soon.isEmpty {
            context += "\nScadono presto: \(soon.prefix(3).map { $0.name }.joined(separator: ", "))"
        }
        if !opened.isEmpty {
            context += "\nGià aperti: \(opened.prefix(3).map { $0.name }.joined(separator: ", "))"
        }
        
        return """
        \(FridgyRules.basePrompt)
        
        Contesto:
        \(context)
        
        Genera UN suggerimento generico su come usare questi ingredienti già presenti.
        Se non c'è un'opportunità concreta, rispondi 'nessun suggerimento'.
        """
    }
    
    /// Prompt per Dettaglio alimento (consiglio specifico). Non usare se !isReasonableProductName(item.name).
    static func itemPrompt(item: FoodItem, compatibleItems: [FoodItem]) -> String {
        var context = "Alimento: \(item.name)"
        context += "\nStato: \(item.isOpened ? "aperto" : "chiuso")"
        let d = item.daysRemaining
        context += "\nScade tra: \(d) \(d == 1 ? "giorno" : "giorni")"
        
        if !compatibleItems.isEmpty {
            context += "\nIngredienti compatibili disponibili: \(compatibleItems.prefix(3).map { $0.name }.joined(separator: ", "))"
        }
        
        return """
        \(FridgyRules.basePrompt)
        
        Contesto:
        \(context)
        
        Genera UN suggerimento specifico per usare QUESTO alimento.
        Se non c'è un suggerimento concreto, rispondi 'nessun suggerimento'.
        """
    }
    
    /// Prompt per Statistiche (insight descrittivo). Waste score alto = molti consumati in tempo (bene), basso = molti scaduti (male).
    static func statisticsPrompt(items: [FoodItem], statistics: StatisticsData) -> String {
        let consumed = items.filter { $0.isConsumed }.count
        let expired = items.filter { !$0.isConsumed && $0.expirationStatus == .expired }.count
        let scorePercent = Int(statistics.wasteScore * 100)
        
        var context = "Statistiche periodo:"
        context += "\nConsumati in tempo: \(consumed)"
        context += "\nScaduti (non consumati): \(expired)"
        context += "\nWaste Score: \(scorePercent)% (percentuale consumati prima della scadenza; più alto = meno sprechi)"
        context += "\nQuesto mese: \(statistics.monthlyStats.consumed) consumati, \(statistics.monthlyStats.expired) scaduti."
        
        return """
        \(FridgyRules.basePrompt)
        
        Contesto Statistiche / Waste Score:
        \(context)
        
        Genera UN insight breve e utile: se il waste score è alto riconosci il risultato positivo; se è basso suggerisci un'idea pratica (es. controllare le scadenze, mettere in vista i prodotti in scadenza). Massimo 25 parole, tono amichevole e non giudicante.
        Se non c'è un pattern interessante, rispondi 'nessun suggerimento'.
        """
    }
}
