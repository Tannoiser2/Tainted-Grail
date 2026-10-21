# Seconda passata: eliminare i passi `manuale`

Il gioco deve tenere traccia di tutto e **non chiedere mai al giocatore** cose che può sapere da solo.
Ogni voce di questi lotti contiene almeno un passo o una condizione `manuale` (o un modificatore `cosa:"altro"`)
nella `codifica_attuale`. Rifai la codifica della voce **completa** usando anche le estensioni del §7 e del §8 di
`tools/automazione/DSL.md` (leggilo tutto, soprattutto il §8).

Regole:
- Riscrivi l'intera voce (stesso formato della prima passata: vedi `tools/automazione/ISTRUZIONI.md`), non solo il pezzo.
- Elimina ogni `manuale` che si può esprimere con il DSL (§2-§8). Quello che dipende da una decisione dei giocatori
  diventa una `scelta` con opzioni chiare e i loro effetti (es. "Concludere il Capitolo ora" / "Continuare").
- Le Cerche con un obiettivo solo narrativo ("Raggiungi il Cuore di Tuathan (185)") avanzano dal Diario: metti
  `"successo": null` (il gioco non deve chiedere nulla), lascia gli indizi come `nota`.
- Per le carte di Combattimento/Diplomazia con "Se {i:discard}, …" usa una capacità con `"innesco": "scartata"`.
  "Ogni volta che rimuovi {i:delay}" → `"innesco": "tempo_rimosso"`.
- Resta `manuale` solo ciò che richiede di guardare l'illustrazione stampata o è davvero impossibile da esprimere;
  in quel caso scrivi il testo come istruzione chiara.
- Lavora voce per voce leggendo il testo (puoi scrivere script di supporto in una TUA sottocartella dello scratchpad).
- Scrivi `tools/automazione/out2/<nome_lotto>.json` con lo stesso formato dell'uscita della prima passata
  (`{"voci": {chiave: …}}` oppure `{"carte": {img: …}}`; per le carte anche le `copie_img` se presenti) e validalo con
  `python3 -c "import json;json.load(open(PERCORSO))"`.
- Alla fine riporta: voci rifatte, quanti `manuale` restano e perché, eventuali campi nuovi che hai dovuto inventare.
