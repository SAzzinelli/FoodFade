# Changelog – FoodFade 1.0.2 (Build 10)

**Per App Store Connect – Sezione "Cosa c'è di nuovo"**

---

## Novità

- **Schermata finale onboarding** – Nuova schermata "Tutto pronto!" con immagine Fridgy Bravo, titolo e sottotitolo aggiornati e tre punti chiari (riduci gli sprechi, evita scadenze dimenticate, tieni tutto sotto controllo). CTA "Iniziamo".
- **Codice a barre inseribile a mano** – Nel form "Nuovo prodotto" puoi digitare o incollare il codice a barre oltre a scansionarlo. I codici con spazi (es. da copia-incolla) vengono normalizzati in automatico. Premendo "Fine" sulla tastiera parte la ricerca nome, immagine e ingredienti come con la scansione.
- **Descrizione sotto il codice a barre** – Testo esplicativo: "Con la scansione vengono aggiunti automaticamente nome, immagine e ingredienti. La scadenza devi inserirla tu."
- **Sheet "Consumato" con quantità** – Quando un prodotto ha quantità > 1, il tap su "Consumato" apre una sheet (non a schermo intero) con +/− per scegliere quante unità segnare, "Tutti (N)", Annulla e Conferma. Se quantità = 1, un tap segna tutto subito.
- **Dettatura data di scadenza** – In "Nuovo prodotto", nella sezione scadenza puoi usare "Detta la data di scadenza": overlay con blur, "Sto ascoltando...", e inserimento data da voce.
- **KPI "In casa"** – In home il KPI dell’inventario si chiama "In casa" (prima "Totale") e usa il colore blu d’accento.

---

## Miglioramenti

- **Onboarding** – Pulsanti in stile liquid glass a capsula; tutta l’area del pulsante è cliccabile (non solo il testo). Campo nome a capsula. Animazione sfondo a loop continuo senza interruzioni.
- **Dettaglio prodotto** – Titolo "Dettagli prodotto"; toolbar con Modifica (matita) e menu con Elimina; una sola barra sotto "X giorni rimanenti" (spessa 18pt, che diminuisce verso la scadenza); niente sezione Timeline.
- **Inventario "In casa"** – Large title "In casa"; card con angoli arrotondati sempre visibili; swipe per Eliminare (rosso, icona cestino); menu contestuale su ogni riga (Segna consumato, Modifica, Elimina).
- **Badge "Non in scadenza"** – Il badge "Sicuro" è stato rinominato in "Non in scadenza" (badge, KPI, vista prodotti sicuri).
- **Prodotti recenti in home** – Una riga "Scade tra X giorni", senza "Vedi tutti".
- **KPI in home** – Icone bianche in cerchi colorati (rosso, arancione, giallo, verde).
- **Tab bar** – Cinque tab con icone fill; inventario come "In casa" (icona cabinet).
- **Statistiche** – Waste Score con emoji/%; messaggi tipo "100% di spreco evitato", "Continua così"; giorni in cerchio in Abitudini; quando non ci sono dati, icona e messaggio centrati al centro come nella lista della spesa.
- **Impostazioni** – Sezione Fridgy con sottotitolo; ripristino con pulsante rosso e footer; correzione colore testo secondario (etichette leggibili in chiaro/scuro).
- **Empty state** – Stile unificato nelle viste "Da consumare", "Scadono oggi", "In arrivo", "Non in scadenza", "Tutto ok": icona verde 60pt, titolo 20pt, sottotitolo 15pt.
- **Titoli schermate** – Titoli di pagina in nero (legibili in tema chiaro).
- **Nuovo prodotto** – Ordine campi: Nome prodotto, Codice a barre, Scadenza, Dove lo conservi, Quantità, Prezzo, Etichetta, Notifiche. Placeholder e hint coerenti; stepper quantità; note centrate.
- **Codice a barre** – Normalizzazione automatica (solo cifre, niente spazi); lookup prodotto anche da inserimento manuale (tasto Fine).
- **iCloud** – Identificatore container corretto per sincronizzazione (`iCloud.com.food.fade.FoodFade`).

---

## Correzioni

- **Onboarding** – Corretta la struttura del codice nello step Notifiche (parentesi graffe) che poteva causare errori di compilazione.
- **Localizzazione** – Testo sotto il codice a barre in italiano visualizzato correttamente in app ("Scansionando...").
- **Impostazioni** – Colore del testo secondario (terziario) corretto per tema chiaro/scuro.

---

## Riferimento tecnico

- Versione: **1.0.2** (build 10).
- Requisiti: iOS 17+ (deployment target del progetto); stile liquid glass dove utilizzato.
