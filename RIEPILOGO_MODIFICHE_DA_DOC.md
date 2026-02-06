# Riepilogo modifiche (da cursor_problemi_layout_inventario_e_ric.md)

Riferimento: le conversazioni esportate. Questo file confronta le richieste del doc con lo stato attuale del codice.

---

## ✅ Già implementato / allineato

| Richiesta (dal doc) | Dove nel codice |
|---------------------|-----------------|
| **Sheet Consumato con +/−** (non a schermo intero, [−] numero [+], "Tutti (N)", Annulla/Conferma) | `Components/ConsumedQuantitySheet.swift`; usata in `ItemDetailView` e `InventoryView` (menu contestuale). |
| **Quantità = 1** → un tap segna tutto; **quantità > 1** → tap apre la sheet | `ItemDetailView` (pulsante Consumato), `InventoryView` (voce menu "Segna come consumato"). |
| **Primo detent sheet ~38%** (`.fraction(0.38)`) | `ConsumedQuantitySheet`: `.presentationDetents([.fraction(0.38), .medium, .large])`. |
| **Overlay con blur per dettatura** ("Sto ascoltando...", Usa il calendario, Annulla) | `Components/DictationListeningOverlay.swift`; in `AddFoodView` al tap su "Detta la data di scadenza". |
| **AddFoodView**: placeholder nome, "Dove lo conservi?", badge data in cerchio, hint Salva, Note centrate, Stepper quantità | `Views/AddFoodView.swift`. |
| **Modifica dal dettaglio** (toolbar: matita + menu con Elimina) | `ItemDetailView`: toolbar con Modifica (pencil) e menu (⋯) con Elimina. |
| **Titolo schermata dettaglio** "Dettagli prodotto" | `ItemDetailView`: `.navigationTitle("itemdetail.title".localized)`. |
| **"Sicuro" → "Non in scadenza"** (badge, KPI, SafeItemsView) | `ExpirationStatus.displayName`, usato in InventoryView, ItemDetailView, KPIStatusView, SafeItemsView. |
| **Prodotti recenti**: una riga "Scade tra X giorni", niente "Vedi tutti" | `HomeView`: `RecentItemRow`. |
| **KPI**: icone bianche in cerchi colorati (rosso, arancione, giallo, verde) | `HomeView`: `SummaryCardContent`. |
| **Tab bar**: 5 tab, "In casa" (cabinet.fill), Lista spesa (placeholder), icone fill | `FoodFadeApp` / tab bar. |
| **Impostazioni**: sezione Fridgy con sottotitolo, Ripristino con pulsante rosso e footer piccolo | `SettingsView`. |
| **Statistiche**: Waste Score (emoji/%), "100% di spreco evitato", "Continua così", giorni in cerchio in Abitudini, toolbarBackground grigio | `StatisticsView`. |
| **Empty state unificati** (icona verde 60pt, titolo 20pt, sottotitolo 15pt) | ToConsumeView, ExpiringTodayView, IncomingView, SafeItemsView, AllOkView. |
| **Titoli pagine in nero** (`UIColor.label`) | `FoodFadeApp`, `SettingsViewModel`. |
| **Inventario**: large title "In casa" | `InventoryView`: `.navigationBarTitleDisplayMode(.large)`. |
| **Menu contestuale** su riga (Segna consumato, Modifica, Elimina con trash) | `FoodItemRowView`: `.contextMenu` con trash per Elimina. |
| **Una sola barra** sotto "X giorni rimanenti" (nessuna sezione Timeline); barra **18pt**, che **diminuisce** verso la scadenza | `ItemDetailView`: sezione Timeline rimossa; `expirationProgressBar` sotto il countdown (altezza 18, fill = giorni rimanenti / totale). |
| **Card in lista In casa**: angoli arrotondati sempre visibili | `InventoryView`: `.listRowBackground(Color.clear)` sulle righe. |
| **Swipe Elimina** in lista In casa (rossa, icona cestino) | `InventoryView`: `.swipeActions(edge: .trailing)` con Elimina + `.tint(.red)` + `Label(..., systemImage: "trash")`. |
| **iCloud container ID** (`iCloud.com.food.fade.FoodFade`) | `SettingsViewModel`: costante `kCloudKitContainerID` e uso in `restoreFromiCloud` / `checkCloudKitSyncStatus`. |

---

## ❌ Non applicabile / viste rimosse

- **Lista della spesa** (selezione lista, dropdown → sheet, swipe per eliminare liste, "Nuova lista" con icona): nel progetto c’è solo `ShoppingListPlaceholderView`; le viste `ShoppingListView` / `ShoppingItem` sono state rimosse. Le modifiche del doc sulla “lista spesa” si applicano quando/se reintroduci quella vista.
- **Storico consumi** (swipe per eliminare singoli, "Elimina tutto lo storico"): la vista `ConsumedHistoryView` è stata rimossa dal progetto. Riapplicabile quando/se la storico consumi torna.
- **Sheet "Aggiungi da consumati"** (opaca, voci in nero): dipende da una funzionalità “lista spesa” / consumati che al momento non è presente.

---

## Completato

Le azioni sotto (dettaglio, inventario, iCloud) sono state applicate.

1. ~~**Dettaglio prodotto**~~: rimuovere sezione Timeline, mettere **una sola barra** sotto "X giorni rimanenti" (spessa, che diminuisce verso la scadenza).
2. ~~**Inventario**~~: aggiungere `.listRowBackground(Color.clear)` alle righe; opzionale: swipe Elimina (rosso, cestino).
3. ~~**iCloud**~~: correggere in `SettingsViewModel` l’identificatore del container in `iCloud.com.food.fade.FoodFade`.

