import Foundation
import Combine
import Speech
import AVFoundation

/// Servizio per dettare la data di scadenza con riconoscimento vocale (modello integrato iOS, italiano).
@MainActor
final class ExpirationDictationService: ObservableObject {
    static let shared = ExpirationDictationService()
    
    @Published private(set) var isListening = false
    @Published private(set) var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published private(set) var errorMessage: String?
    /// Livello audio 0...1 per il waveform (aggiornato dal tap del microfono).
    @Published private(set) var audioLevel: Float = 0
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    }
    
    var isAvailable: Bool {
        guard let recognizer = speechRecognizer else { return false }
        return recognizer.isAvailable
    }
    
    /// Richiedi autorizzazione riconoscimento vocale e microfono.
    func requestAuthorization() async -> Bool {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }
        await MainActor.run { authorizationStatus = speechStatus }
        
        guard speechStatus == .authorized else {
            await MainActor.run {
                errorMessage = "Autorizzazione al riconoscimento vocale non concessa."
            }
            return false
        }
        
        // Richiedi permesso microfono (audio session)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            await MainActor.run {
                errorMessage = "Impossibile usare il microfono."
            }
            return false
        }
        
        return true
    }
    
    /// Avvia l'ascolto; al primo risultato valido (data riconosciuta) chiama onDate e termina.
    func startListening(onDate: @escaping (Date) -> Void, onError: ((String) -> Void)? = nil) async {
        errorMessage = nil
        
        guard await requestAuthorization() else {
            onError?(errorMessage ?? "Autorizzazione mancante")
            return
        }
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let msg = "Riconoscimento vocale non disponibile su questo dispositivo."
            errorMessage = msg
            onError?(msg)
            return
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let level = Self.rmsLevel(from: buffer)
            Task { @MainActor in
                self?.audioLevel = level
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            await MainActor.run { isListening = true }
        } catch {
            await MainActor.run {
                isListening = false
                errorMessage = "Impossibile avviare l'audio."
            }
            onError?(errorMessage ?? "Errore audio")
            return
        }
        
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                if let error = error {
                    self.stopListening()
                    if (error as NSError).code != 216 { // 216 = cancelled
                        self.errorMessage = error.localizedDescription
                        onError?(error.localizedDescription)
                    }
                    return
                }
                guard let result = result, result.isFinal else { return }
                let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty, let date = Self.parseDate(from: text) {
                    self.stopListening()
                    onDate(date)
                }
            }
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        audioLevel = 0
    }
    
    /// Calcola livello RMS dal buffer (0...1 circa).
    private static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }
        var sum: Float = 0
        for frame in 0..<frameLength {
            let s = channelData[0][frame]
            sum += s * s
        }
        let rms = sqrt(sum / Float(frameLength))
        return min(1, rms * 8)
    }
    
    /// Parsing della data da testo italiano (es. "7 marzo 2026", "sette marzo 2026", "7/3/26").
    static func parseDate(from text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let locale = Locale(identifier: "it_IT")
        
        // Formati con DateFormatter
        let formatters: [(String, DateFormatter)] = [
            ("d MMMM yyyy", {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = "d MMMM yyyy"
                f.timeZone = TimeZone.current
                return f
            }()),
            ("d MMM yyyy", {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = "d MMM yyyy"
                f.timeZone = TimeZone.current
                return f
            }()),
            ("d/M/yyyy", {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = "d/M/yyyy"
                f.timeZone = TimeZone.current
                return f
            }()),
            ("d/M/yy", {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = "d/M/yy"
                f.timeZone = TimeZone.current
                return f
            }()),
            ("d-MM-yyyy", {
                let f = DateFormatter()
                f.locale = locale
                f.dateFormat = "d-MM-yyyy"
                f.timeZone = TimeZone.current
                return f
            }()),
        ]
        
        for (_, formatter) in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        // Sostituisci numeri parlati con cifre (es. "sette" -> "7")
        let withDigits = replaceItalianNumberWords(in: trimmed)
        for (_, formatter) in formatters {
            if let date = formatter.date(from: withDigits) {
                return date
            }
        }
        
        // NSDataDetector per date naturali
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        if let detector = detector {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            let matches = detector.matches(in: trimmed, options: [], range: range)
            if let match = matches.first, let date = match.date {
                return date
            }
        }
        
        return nil
    }
    
    private static func replaceItalianNumberWords(in text: String) -> String {
        let pairs: [(String, String)] = [
            ("uno", "1"), ("due", "2"), ("tre", "3"), ("quattro", "4"), ("cinque", "5"),
            ("sei", "6"), ("sette", "7"), ("otto", "8"), ("nove", "9"), ("dieci", "10"),
            ("undici", "11"), ("dodici", "12"), ("tredici", "13"), ("quattordici", "14"),
            ("quindici", "15"), ("sedici", "16"), ("diciassette", "17"), ("diciotto", "18"),
            ("diciannove", "19"), ("venti", "20"), ("ventuno", "21"), ("ventidue", "22"),
            ("trenta", "30"), ("trentuno", "31")
        ]
        var result = text.lowercased()
        for (word, digit) in pairs {
            result = result.replacingOccurrences(of: word, with: digit)
        }
        return result
    }
}
