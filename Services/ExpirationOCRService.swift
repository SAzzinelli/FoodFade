import Foundation
import Vision
import UIKit

/// Servizio OCR per estrarre solo la data di scadenza da una foto (Vision). Esclude tutto il resto del testo.
/// In beta: non sempre accurato su tutte le confezioni.
final class ExpirationOCRService {
    static let shared = ExpirationOCRService()
    
    private init() {}
    
    /// Esegue OCR sull'immagine e restituisce la prima data di scadenza plausibile trovata (solo date, niente altro).
    func extractExpirationDate(from image: UIImage) async -> Date? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["it-IT", "en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        var fullText = ""
        do {
            try handler.perform([request])
            guard let observations = request.results else { return nil }
            fullText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        } catch {
            return nil
        }
        
        return parseExpirationDate(from: fullText)
    }
    
    /// Cerca nel testo riconosciuto solo pattern che assomigliano a date; preferisce date future e vicine a parole chiave (scadenza, use by, ecc.).
    private func parseExpirationDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let keywords = ["scadenza", "scade", "da consumare", "use by", "best before", "exp", "data", "validità", "preferibilmente"]
        
        // Pattern per date: DD/MM/YYYY, DD-MM-YY, DD.MM.YY, YYYY-MM-DD, DD MMM YYYY, ecc.
        typealias DateParser = ([String]) -> Date?
        let patterns: [(String, DateParser)] = [
            (#"(\d{1,2})/(\d{1,2})/(\d{2,4})"#, { g in
                guard g.count >= 3 else { return nil as Date? }
                return Self.dateFromDMY(day: g[0], month: g[1], year: g[2])
            }),
            (#"(\d{1,2})-(\d{1,2})-(\d{2,4})"#, { g in
                guard g.count >= 3 else { return nil as Date? }
                return Self.dateFromDMY(day: g[0], month: g[1], year: g[2])
            }),
            (#"(\d{1,2})\.(\d{1,2})\.(\d{2,4})"#, { g in
                guard g.count >= 3 else { return nil as Date? }
                return Self.dateFromDMY(day: g[0], month: g[1], year: g[2])
            }),
            (#"(\d{4})-(\d{1,2})-(\d{1,2})"#, { g in
                guard g.count >= 3 else { return nil as Date? }
                return Self.dateFromYMD(year: g[0], month: g[1], day: g[2])
            }),
            (#"(\d{1,2})\s+(gen|feb|mar|apr|mag|giu|lug|ago|set|ott|nov|dic|jan|may|jun|jul|aug|sep|oct|dec)\w*\s+(\d{2,4})"#, { g in
                guard g.count >= 3 else { return nil as Date? }
                return Self.dateFromDDMonYYYY(day: g[0], month: g[1], year: g[2])
            })
        ]
        
        var candidates: [(date: Date, nearKeyword: Bool)] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for (pattern, parser) in patterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(lowercased.startIndex..., in: lowercased)
            let nsText = lowercased as NSString
            regex?.enumerateMatches(in: lowercased, options: [], range: range) { result, _, _ in
                guard let result = result, result.numberOfRanges >= 2 else { return }
                var groups: [String] = []
                for i in 1..<result.numberOfRanges {
                    let r = result.range(at: i)
                    if r.location != NSNotFound, r.location + r.length <= nsText.length {
                        groups.append(nsText.substring(with: r))
                    }
                }
                guard groups.count >= 3, let date = parser(groups) else { return }
                let startOfDate = calendar.startOfDay(for: date)
                // Scarta date troppo nel passato (più di 1 anno fa) o troppo nel futuro (più di 10 anni)
                if startOfDate < calendar.date(byAdding: .year, value: -1, to: today) ?? today { return }
                if startOfDate > calendar.date(byAdding: .year, value: 10, to: today) ?? today { return }
                
                let textAround = textAroundMatch(text: lowercased, range: result.range)
                let nearKeyword = keywords.contains { textAround.lowercased().contains($0) }
                candidates.append((date, nearKeyword))
            }
        }
        
        // Preferisci date vicine a parole chiave, poi date future più vicine a oggi
        let sorted = candidates.sorted { a, b in
            if a.nearKeyword != b.nearKeyword { return a.nearKeyword }
            let aFuture = a.date >= today
            let bFuture = b.date >= today
            if aFuture != bFuture { return aFuture }
            return abs(a.date.timeIntervalSince(today)) < abs(b.date.timeIntervalSince(today))
        }
        return sorted.first?.date
    }
    
    private func textAroundMatch(text: String, range: NSRange) -> String {
        let ns = text as NSString
        let start = max(0, range.lowerBound - 30)
        let len = min(range.length + 60, ns.length - start)
        guard len > 0 else { return "" }
        let r = NSRange(location: start, length: len)
        guard r.upperBound <= ns.length else { return ns.substring(from: start) }
        return ns.substring(with: r)
    }
    
    private static func dateFromDMY(day: String, month: String, year: String) -> Date? {
        let d = Int(day) ?? 0
        let m = Int(month) ?? 0
        var y = Int(year) ?? 0
        if y < 100 { y += 2000; if y > 2050 { y -= 100 } }
        guard (1...31).contains(d), (1...12).contains(m), y >= 2000, y <= 2030 else { return nil }
        var comp = DateComponents()
        comp.day = d
        comp.month = m
        comp.year = y
        return Calendar.current.date(from: comp)
    }
    
    private static func dateFromYMD(year: String, month: String, day: String) -> Date? {
        let y = Int(year) ?? 0
        let m = Int(month) ?? 0
        let d = Int(day) ?? 0
        guard (1...31).contains(d), (1...12).contains(m), y >= 2000, y <= 2030 else { return nil }
        var comp = DateComponents()
        comp.year = y
        comp.month = m
        comp.day = d
        return Calendar.current.date(from: comp)
    }
    
    private static let monthNames = ["gen": 1, "feb": 2, "mar": 3, "apr": 4, "mag": 5, "giu": 6, "lug": 7, "ago": 8, "set": 9, "ott": 10, "nov": 11, "dic": 12,
                                     "jan": 1, "may": 5, "jun": 6, "jul": 7, "aug": 8, "sep": 9, "oct": 10, "dec": 12]
    
    private static func dateFromDDMonYYYY(day: String, month: String, year: String) -> Date? {
        let d = Int(day) ?? 0
        var y = Int(year) ?? 0
        if y < 100 { y += 2000 }
        let mon = String(month.prefix(3)).lowercased()
        guard let m = monthNames[mon], (1...31).contains(d), y >= 2000 else { return nil }
        var comp = DateComponents()
        comp.day = d
        comp.month = m
        comp.year = y
        return Calendar.current.date(from: comp)
    }
}
