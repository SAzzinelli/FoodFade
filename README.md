# FoodFade

App iOS per gestire inventario alimentare, scadenze e lista della spesa. Meno sprechi, più controllo.

**Sviluppatore:** Simone Azzinelli

---

## Funzionalità

- **Inventario** — Aggiungi prodotti a mano o con codice a barre, indica dove li tieni (frigo, congelatore, dispensa) e la data di scadenza
- **Avvisi** — Notifiche prima della scadenza (1–2 giorni o personalizzato)
- **Home** — Riepilogo: cosa scade oggi, da consumare a breve, anello di progresso
- **Lista della spesa** — Aggiungi, spunta, importa da consumati, esporta in Promemoria
- **Storico consumi** — Cosa hai consumato per giorno e settimana
- **Statistiche** — Andamento, consumati vs scaduti, suggerimenti
- **Fridgy** — Suggerimenti intelligenti su cosa consumare
- **Aspetto** — Tema chiaro/scuro e colore d’accento (arancione, blu, verde, viola, ecc.)
- **Sincronizzazione iCloud** — Opzionale, per tenere i dati su più dispositivi
- **Backup e ripristino** — Export/import dati

Localizzazione: **Italiano** e **Inglese**.

---

## Requisiti

- Xcode 15+
- iOS 17+ (o il deployment target impostato nel progetto)
- Apple Developer Account per distribuzione su App Store

---

## Come aprire e buildare

1. Clona il repository:
   ```bash
   git clone https://github.com/SAzzinelli/FoodFade.git
   cd FoodFade
   ```
2. Apri il progetto in Xcode:
   ```bash
   open FoodFade.xcodeproj
   ```
3. Seleziona un simulatore o dispositivo e premi **Run** (⌘R).

Non sono richiesti CocoaPods o Swift Package Manager: il progetto è standalone.

---

## Struttura del progetto

| Cartella      | Contenuto |
|---------------|-----------|
| `Views/`      | Schermate principali (Home, Inventario, Impostazioni, Aggiungi prodotto, ecc.) |
| `ViewModels/` | Logica di presentazione |
| `Models/`     | Modelli dati (FoodItem, ShoppingItem, UserProfile, …) |
| `Services/`   | Servizi (notifiche, barcode, backup, Fridgy, iCloud, …) |
| `Components/` | Componenti riutilizzabili (anello progresso, card, picker, …) |
| `Utilities/`  | Estensioni, tema, localizzazione |
| `AppStore-Web/` | Sito (home, privacy, assistenza) per GitHub Pages e App Store Connect |

---

## Sito web e App Store

Le pagine in `AppStore-Web/` (home, privacy, assistenza) sono pensate per essere pubblicate su **GitHub Pages** e forniscono gli URL da inserire in App Store Connect (Privacy e Assistenza).

- **Assistenza:** simone.azzinelli@labafirenze.com

---

## Licenza

Progetto privato. Tutti i diritti riservati – Simone Azzinelli.
