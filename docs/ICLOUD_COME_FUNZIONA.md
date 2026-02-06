# Come funziona iCloud in FoodFade (Swift + SwiftData)

Riepilogo a livello di codice: dove si decide l’uso di CloudKit, come viene creato il database e perché la sync può “non andare”.

---

## 1. Dove si decide se usare iCloud

### 1.1 Due “fonti di verità”

L’app usa **due posti** per sapere se iCloud è attivo:

| Dove | Cosa | Quando si aggiorna |
|------|------|--------------------|
| **UserDefaults** | `iCloudSyncEnabled`, `hasChosenCloudUsage` | Subito quando l’utente sceglie (onboarding o in futuro da Impostazioni) |
| **SwiftData (AppSettings)** | `settings.iCloudSyncEnabled`, `settings.hasChosenCloudUsage` | Stesso momento, salvato nel `modelContext` |

- **FoodFadeApp** legge **solo UserDefaults** per creare il `ModelContainer` (vedi sotto).
- **SettingsViewModel** legge **AppSettings** (e CloudKit) per mostrare lo stato (“Attiva” / “Disattivata” / “Non disponibile”).

Quindi: la **scelta effettiva** per il container è quella in **UserDefaults**. AppSettings serve per UI e per allineare UserDefaults quando l’app si apre e trova già delle impostazioni (es. dopo reinstall).

### 1.2 Scelta dell’utente (onboarding)

**File:** `Views/WelcomeView.swift`

- `checkiCloudAvailability()` usa `CKContainer.default().accountStatus()` per sapere se iCloud è disponibile (solo “sì/no”, non il container custom).
- Quando l’utente sceglie “iCloud” o “Solo su questo iPhone”, viene chiamato `saveCloudChoice(option)`:
  - imposta **UserDefaults**: `iCloudSyncEnabled` (true/false), `hasChosenCloudUsage = true`;
  - aggiorna o crea **AppSettings** nel `modelContext` con gli stessi valori e fa `save()`.

Da lì in poi, la “scelta iCloud” è sia in UserDefaults sia in SwiftData.

---

## 2. Creazione del ModelContainer (il cuore)

**File:** `FoodFadeApp.swift` → proprietà `modelContainer`

Questo è il punto che decide **davvero** se i dati vanno su iCloud o solo in locale.

```swift
let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
let hasChosen = UserDefaults.standard.bool(forKey: "hasChosenCloudUsage")

let cloudKitConfig: ModelConfiguration.CloudKitDatabase
if !hasChosen || useiCloud {
    cloudKitConfig = .automatic   // ← iCloud ATTIVO
} else {
    cloudKitConfig = .none        // ← solo locale
}

let configuration = ModelConfiguration(
    isStoredInMemoryOnly: false,
    cloudKitDatabase: cloudKitConfig
)
let container = try ModelContainer(for: schema, configurations: [configuration])
```

- **`!hasChosen`** = utente non ha ancora scelto (prima apertura / dopo reinstall) → si usa **`.automatic`** così, dopo reinstall, i dati su iCloud possono tornare.
- **`useiCloud == true`** = utente ha scelto iCloud → **`.automatic`**.
- **`hasChosen && !useiCloud`** = utente ha scelto “solo su questo iPhone” → **`.none`** (nessun CloudKit).

Il **ModelContainer viene creato una sola volta** (quando l’app carica la scena con `.modelContainer(modelContainer)`). La sua configurazione (CloudKit sì/no) **non cambia** fino al prossimo avvio dell’app. Quindi:

- Se l’utente disattiva iCloud a metà sessione, il container resta “con iCloud” fino al riavvio.
- Dopo riavvio, con `hasChosen == true` e `useiCloud == false`, il container sarà creato con `.none`.

---

## 3. Container CloudKit e entitlements

**File:** `FoodFade.entitlements`

- Container iCloud: `iCloud.com.food.fade.FoodFade`
- Servizi: `CloudDocuments`, `CloudKit`

**File:** `ViewModels/SettingsViewModel.swift`

- `kCloudKitContainerID = "iCloud.com.food.fade.FoodFade"` (deve essere uguale agli entitlements).

Con `ModelConfiguration(cloudKitDatabase: .automatic)`, SwiftData usa quel container per la sync. Non c’è altro codice che “attiva” CloudKit: basta quella configurazione + schema con i model che vuoi sincronizzare.

---

## 4. Sincronizzazione: chi fa cosa

- **SwiftData + CloudKit**: la sync è **gestita dal sistema**. Non c’è codice che “carica/scarica” record a mano.
- Quando il container è con `cloudKitDatabase: .automatic`:
  - le modifiche nel `modelContext` (insert/update/delete) vengono messe in coda e sincronizzate in background;
  - i cambiamenti che arrivano da altri dispositivi vengono applicati al contesto in modo asincrono.

**“Ripristina da iCloud”** in Impostazioni (`restoreFromiCloud()` in `SettingsViewModel`):

- Verifica account iCloud e che `iCloudSyncEnabled` sia true.
- Fa fetch + save nel `modelContext` per “svegliare” il contesto.
- **Non** fa un “download esplicito” da CloudKit: si affida al fatto che SwiftData/CloudKit già sincronizzano. Serve solo a dare un “refresh” e un po’ di log in console.

Quindi se “non va”, di solito il problema non è quel bottone, ma una di queste cose:

- container creato con `.none` (o mai ricreato dopo aver attivato iCloud);
- ambiente CloudKit (Development vs Production);
- schema/modelli non compatibili con CloudKit;
- account iCloud / rete / permessi.

---

## 5. Perché potrebbe “non andare”

### 5.1 Container creato senza iCloud

- **Cause tipiche:**
  - `hasChosenCloudUsage` è true e `iCloudSyncEnabled` è false (utente ha scelto “solo dispositivo”).
  - Dopo la scelta iCloud, l’app non è stata **riavviata** e il container era stato creato prima (es. con `.none` in un avvio precedente).
- **Cosa controllare:** in `FoodFadeApp`, subito dopo `let cloudKitConfig = ...`, aggiungi un `print(cloudKitConfig)` e verifica in console che sia `.automatic` quando ti aspetti iCloud.

### 5.2 Development vs Production

- In **Debug** (run da Xcode) si usa l’ambiente **Development** di CloudKit.
- In **Release** (Archive / TestFlight / App Store) si usa **Production**.
- I dati non si “vedono” tra i due: dispositivo in Debug e dispositivo in Release usano database CloudKit diversi. Per testare sync tra dispositivi serve stessa configurazione (entrambi Debug o entrambi Release/TestFlight).

### 5.3 UserDefaults e AppSettings fuori sync

- Se qualcuno scrive solo in AppSettings e non in UserDefaults (o viceversa), alla prossima apertura il container potrebbe essere creato con la scelta sbagliata.
- Nel codice attuale, onboarding e (dove presente) sync da AppSettings a UserDefaults in `FoodFadeApp` dovrebbero tenere tutto allineato; se aggiungi altre schermate che cambiano iCloud, aggiorna **entrambi**.

### 5.4 Disponibilità iCloud

- `CKContainer.accountStatus()` deve essere `.available`.
- Se l’utente non è loggato in iCloud, o iCloud Drive è disattivato, la sync non parte. Il codice controlla questo in `checkiCloudStatus()` e in `restoreFromiCloud()`.

### 5.5 Schema / modelli SwiftData

- Per la sync CloudKit, i model devono essere “compatibili” (tipi supportati, ecc.). Se un model non è sincronizzabile, SwiftData/CloudKit può fallire in modo silenzioso o con errori in console. Controlla che tutti i tipi usati nei model siano supportati da CloudKit.

---

## 6. Dove si nasconde il problema REALE (revisore)

Questi punti non invalidano il ragionamento sopra, ma sono i “bordi” dove nasce il bug.

### 6.1 `!hasChosen || useiCloud` è corretto… ma pericoloso

La logica è giusta per il ripristino post-reinstall, ma introduce un edge case:

1. App installata, utente non ha ancora scelto.
2. Container creato con `.automatic`.
3. SwiftData parte subito (prima dell’onboarding).
4. Poi l’utente sceglie “solo locale” → scrivi UserDefaults.
5. Ma il container **è già** CloudKit per questa sessione.

Risultato: l’utente pensa “no iCloud”, ma in questa sessione i dati sono già andati su iCloud; al prossimo riavvio sarà locale, ma intanto c’è stata una “sessione CloudKit” a sua insaputa (zona grigia UX + privacy).

**Possibili soluzioni:** mostrare l’onboarding **prima** di applicare `.modelContainer`, oppure forzare restart dell’app dopo la scelta iCloud (brutal ma pulito).

### 6.2 UserDefaults = single point of failure

- **UserDefaults** si azzerano alla reinstallazione.
- **SwiftData + CloudKit** no (i dati su iCloud restano).

Al primo avvio dopo reinstall: `hasChosen == false`, `iCloudSyncEnabled == false` (default) → container = `.automatic` ✅, ma non c’è attesa per far arrivare i dati da CloudKit. SwiftData può partire con DB “vuoto” e popolare **dopo**. Se nel frattempo crei AppSettings o mostri UI basata sul fetch iniziale, sembra che “non abbia ripristinato nulla”, ma in realtà la sync sta ancora arrivando.

### 6.3 AppSettings creato troppo presto

Se fai: container con `.automatic` → fetch AppSettings → zero risultati → crei AppSettings vuoto → save(), **puoi sovrascrivere lo stato prima che CloudKit abbia finito il merge**. Best practice: non creare AppSettings “di default” finché non sei sicuro, oppure usare un flag tipo `didBootstrapSettings`, oppure aspettare un remote change prima di inizializzare.

---

## 7. Diagnostica: check rapidissimo

In **FoodFadeApp** (creazione `modelContainer`) sono stati aggiunti:

- **Print** a ogni avvio:
  - `hasChosen`, `iCloudSyncEnabled`, `cloudKitConfig`, `iCloud available (ubiquityIdentityToken)`.
- **Observer** su `NSPersistentStoreRemoteChange`: quando CloudKit manda un update, in console esce `📡 CloudKit ha mandato un update`.

**Cosa fare:**

1. **Reinstall → primo avvio** → guarda cosa stampa (hasChosen, useiCloud, cloudKitConfig, iCloud available).
2. **Dopo 10–20 secondi** → arrivano log `📡 CloudKit ha mandato un update`?
   - Se **no** → CloudKit non sta parlando (ambiente, account, rete, o container creato con `.none`).
   - Se **sì** → la sync arriva in ritardo; il “non ripristina” può essere timing (UI/fetch troppo presto, o bootstrap AppSettings che sovrascrive).

---

## 8. Flusso a colpo d’occhio

```
Avvio app
    → FoodFadeApp.modelContainer viene valutato
    → Legge UserDefaults: iCloudSyncEnabled, hasChosenCloudUsage
    → Crea ModelContainer con .automatic oppure .none
    → (Opzionale) Se non esistono AppSettings, le crea e fa save
    → (Opzionale) Se esistono AppSettings e hasChosenCloudUsage, copia iCloudSyncEnabled in UserDefaults

Onboarding (WelcomeView)
    → saveCloudChoice(iCloud / localOnly)
    → UserDefaults + AppSettings aggiornati
    → La scelta “conta” dal prossimo avvio per il container (se l’app non viene chiusa e riaperta)

Uso normale
    → Con .automatic, SwiftData invia/riceve modifiche da CloudKit in background
    → "Ripristina da iCloud" fa solo fetch + save per dare un refresh
```

La diagnostica (print + observer) è già in `FoodFadeApp`; usa la console per interpretare reinstall, primo avvio e arrivo (o meno) dei remote change.
