# Codifica dei testi di Tainted Grail nel linguaggio degli effetti

Il gioco digitale (Godot) deve **automatizzare tutto quello che è automatizzabile**. Tu traduci testi di
regole (in italiano) in JSON secondo la specifica `tools/automazione/DSL.md` — leggila tutta prima di
iniziare. Per il contesto delle regole c'è `docs/REGOLE.md` (§3-7).

Lavora con precisione: ogni numero, ogni "ogni membro" vs "ottenete", ogni condizione conta. Se un pezzo di
testo non si può esprimere, usa un passo `manuale` SOLO per quel pezzo e codifica il resto. Non usare
`manuale` per cose che il DSL esprime. Puoi scrivere script Python di supporto, ma il lavoro di traduzione
va fatto voce per voce leggendo il testo (niente conversioni automatiche cieche con espressioni regolari).
Alla fine valida il JSON con `python3 -c "import json;json.load(open(PERCORSO))"`.

## Lotti del Diario (`diario_NN.json`)
Ogni voce: `chiave`, `ruolo`, `testo` (BBCode: [b], [i], icone `{i:terror}`, risorse `{r:Ricchezza}`), `contesto`.
Scrivi `tools/automazione/out/diario_NN.json` = `{"voci": {"<chiave>": …}}` con, secondo il ruolo:
- `risultato` → `{"effetti": [...]}` (il risultato di una scelta; "L'Esplorazione termina" non serve codificarlo;
  una frase puramente narrativa → `{"effetti": []}`).
- `requisito o costo di una scelta` → `{"condizione": {...}}` se è un requisito ("Richiede…", "Se avete…",
  "Solo se…"), oppure `{"costo": [...]}` se è un pagamento ("Pagare 2 Ricchezza"); se è entrambe le cose
  usa entrambi i campi. Se è una fascia del dado ("4-5", "Il vostro risultato è stato 6+") →
  `{"condizione": {"tipo":"tiro","da":4,"a":5}}`. "Se vincete" → `incontro_vinto`.
- `condizione` (elemento che si verifica prima di scegliere: "Se avete lo status…", "Continua.", "Altrimenti…",
  fasce del dado) → `{"condizione": {...}}`.
- `testo_verso_con_dado` (testo narrativo che chiede di tirare un dado) → `{"effetti": [{"tipo":"dado","mod":[…],"risultati":[]}]}`
  (le fasce stanno nelle condizioni delle opzioni; se il testo contiene altri effetti codificali prima del dado).
- `sogno`, `incubo` → `{"effetti": [...]}` (gli effetti del Sogno/Incubo; se il Sogno ha condizioni "Ogni Personaggio
  che…" usa `se`). `menhir` → `{"menhir": {"condizione": {...}, "costo": [...], "quadrante": N, "meno_per_giocatore": true/false, "effetti": [...]}}`.

## Lotti delle carte (`<gruppo>_NN.json`)
Ogni voce è una carta già trascritta (campi `img`, `tipo`, testi italiani `it`…). Scrivi
`tools/automazione/out/<gruppo>_NN.json` = `{"carte": {"<img>": {…}}}` con, secondo il gruppo:

- **oggetti_segreti** (Oggetti, Segreti, carte "Stai morendo/impazzendo"): `{"inneschi": [ … §5 … ]}`.
  Per gli Oggetti metti anche `"parola"` (Arma/Armatura/Scudo/Compagno/Reliquia o null) e `"fabbricabile"`.
- **abilita**: `{"facce": [ {"inneschi":[…]}, {"inneschi":[…]} ]}` nello stesso ordine delle facce della carta.
- **luoghi**: `{"azione": {"costo":[…], "effetti":[…], "una_volta_al_giorno": bool, "condizione": {…}|null}`
  (lista se più azioni), `"immediata": {"effetti":[…], "una_volta_al_giorno": bool}|null` (regola col fulmine,
  all'arrivo), `"menhir": {…come sopra…}|null` (dal retro, se c'è), `"esplorazione": {"effetti":[…]}|null`
  (istruzioni del retro diverse dal semplice "esplora nel Diario"), `"permanente": bool`.
- **eventi**: `{"rivelato": [effetti quando l'Evento viene rivelato all'Inizio della Giornata, comprese le istruzioni
  in grassetto come "Metti N Eventi Casuali in cima" o "metti questa carta fra le Cerche attive"],
  "giorno": [inneschi validi per tutta la giornata (Eventi Casuali: es. "chi Viaggia perde 1 Energia" →
  `{"quando":"viaggio","effetti":[…]}`; modificatori → `quando:"sempre"`)],
  "cerca": {"successo": {condizione che completa la Cerca}, "effetti": [effetti del Successo]} | null,
  "preparazione": {per le carte Preparazione del Capitolo: copia/normalizza i dati di preparazione e aggiungi
  "eventi": istruzioni per il mazzo Eventi, "guardiani", "segreti", "effetti": […]} | null}`.
- **combattimento** / **diplomazia** (carte dei Personaggi): `{"capacita": [ {"innesco": "piazza"|"ritardata"|"attacco"|"passiva", "tempo": N, "condizione": {…}|null, "effetti": […]} ]}`
  nello stesso ordine delle Capacità della carta (lista vuota se non ne ha). Per le passive che modificano le regole
  usa passi `modificatore` o `ignora_tratto`; "Scegli l'attacco nemico" → `scegli_attacco`.
- **incontri**: `{"tabella": [{"da":0,"a":1,"effetti":[…]}, …], "opportunita": […], "ricompensa": […], "bottino": […],
  "fallimento": […], "evitare": {"condizione": {…}|null, "costo": […]}|null, "fasi": [{"speciale": {"<attr>": […effetti…], "*": […]}, "risposta": […]}],
  "regola_speciale": [inneschi]|null, "effetto": […] (Incontri speciali senza Chiavi), "inizio": [effetti all'inizio]}`.
  Nelle tabelle: "1 {i:wound}" → ferite 1; "perdi {i:cube2}" → cubi −2; "{i:discard}" → scarta_carte 1;
  "Fuggire" → fuga_nemico; "(inevitabile)" → ferite con `inevitabile`. Ricompensa = a ogni membro (`chi:"compagnia"`),
  Bottino = da dividere (`chi:"diviso"`). Frecce ↑/↓ o `{i:arrowup}`/`{i:arrowdown}` → affinita ±1 ciascuna.
