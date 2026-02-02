# Pagine per App Store Connect (FoodFade)

Questa cartella contiene due pagine da pubblicare online per ottenere gli URL richiesti da App Store Connect:

- **privacy.html** → URL da inserire in “URL norme sulla privacy”
- **support.html** → URL da inserire in “URL di assistenza”

## Opzione 1: GitHub Pages (gratis, consigliata)

1. Crea un repository su GitHub (es. `FoodFade-app` o `foodfade-website`).
2. Carica in the repo **solo** i file `privacy.html` e `support.html` (puoi metterli nella root del repo).
3. Vai in **Settings** del repo → **Pages** → Source: **Deploy from a branch** → branch `main` (o `master`), cartella **/ (root)** → Save.
4. Dopo qualche minuto avrai un URL tipo:  
   `https://TUOUSERNAME.github.io/NOMEREPO/`

   Gli URL da mettere in App Store Connect saranno:
   - **Privacy:** `https://TUOUSERNAME.github.io/NOMEREPO/privacy.html`
   - **Assistenza:** `https://TUOUSERNAME.github.io/NOMEREPO/support.html`

5. Incolla questi due indirizzi nelle rispettive sezioni in App Store Connect (Privacy dell’app e URL di assistenza).

## Opzione 2: Altri servizi gratis

- **Netlify** o **Vercel**: trascina la cartella `AppStore-Web` nel loro drag‑and‑drop e otterrai un URL tipo `https://nome-progetto.netlify.app`.
- **Google Sites**: crea un sito, incolla il testo di privacy e support in due pagine e usa i link che ti fornisce.

## Modifiche da fare

- In **support.html** sostituisci `foodfade.app@gmail.com` con l’indirizzo email che vuoi usare davvero per l’assistenza.
- Se cambi qualcosa nella privacy (es. uso di nuovi servizi), aggiorna la data in “Ultimo aggiornamento” in **privacy.html**.
