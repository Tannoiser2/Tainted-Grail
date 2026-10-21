# Linguaggio degli effetti di Tainted Grail (per il motore Godot)

Ogni testo di regola (risultato del Diario, condizione, Capacità di una carta, effetto di un Oggetto…) viene
tradotto in **JSON strutturato**. Il motore esegue il JSON; quello che non si può esprimere va in un passo
`{"tipo":"manuale","testo":"…"}` (il gioco lo mostra come promemoria con il testo, e il giocatore lo esegue).
Regola d'oro: **codifica tutto quello che è meccanico**, salta la pura narrativa; non inventare effetti
che il testo non dice; nel dubbio usa `manuale` per la parte dubbia e codifica il resto.

Nomi delle risorse (`ris`): `salute`, `energia`, `terrore`, `cibo`, `ricchezza`, `magia`, `esp`, `rep`.
Attributi (`attr`): `aggression` (Aggressività), `courage` (Coraggio), `practicality` (Praticità),
`spirituality` (Spiritualità), `caution` (Cautela), `empathy` (Empatia).
Colori degli Incontri: `verde`, `grigio`, `viola`, `blu`.

## 1. Chi (`chi`)
`"attivo"` (il Personaggio che sta agendo / esplorando / combattendo — **predefinito**),
`"compagnia"` (ogni membro della Compagnia: "ogni membro della Compagnia", "ogni Personaggio", "ciascun membro"),
`"tutti"` (tutti i Personaggi della partita, anche altrove), `"scelto"` (un Personaggio a scelta del giocatore,
es. "a te o a un altro Personaggio nel tuo Luogo"), `"diviso"` (una quantità per la Compagnia da dividere a piacere:
"Ottenete 3 Cibo" in compagnia → il gioco la assegna/divide).
Nota: nel Diario "Ottenete N X" (plurale, senza "ogni membro") = `"diviso"`; "Ogni membro… ottiene" = `"compagnia"`.

## 2. Effetti (lista di passi, eseguiti in ordine)
| tipo | campi | significato |
|---|---|---|
| `risorsa` | `ris`, `n` (negativo = perdere), `chi`, opz. `per`: moltiplicatore (vedi §4) | ottieni/perdi risorse. "Recupera tutta la Salute": `n: 99`. "Riporta a N": usa `imposta` |
| `imposta` | `ris`, `n`, `chi` | porta la risorsa esattamente a N ("riporta a 1 il proprio Cibo") |
| `paga` | `ris`, `n`, `chi` (`attivo` o `compagnia`=ognuno, `diviso`=costo comune) | costo obbligatorio: se non si può pagare l'effetto non avviene (usalo per "Paga X:" e per i costi delle scelte) |
| `attributo` | `attr` (o `"scelta"`), `n`, `chi` | +/− punti attributo ("perde 1 punto in un Attributo a sua scelta": `attr:"scelta"`, `n:-1`) |
| `status` | `nome` (italiano come nel testo), `parti` (lista di numeri; [] = status senza parti), `rimuovi` (bool) | ottenere/perdere status o parti |
| `segreto` | `n` (numero), `rimuovi` (bool), opz. `nome` | ottenere / rimuovere (o scartare) la carta Segreto |
| `oggetto` | `modo`: `casuale` / `fabbricabile` / `nome` / `scegli_fra` (pesca `n` e se ne tiene 1) / `scarta` (scarta 1 Oggetto a scelta) / `scarta_tutti` / `scarta_questo`, `n`, opz. `nome`, `parola` (Arma, Armatura…) | Oggetti |
| `gettoni_cerca` | `n` (negativo = spendere), opz. `luogo`: `"qui"` o numero | Gettoni Cerca (della Compagnia o piazzati su un Luogo) |
| `gettone_tempo` | `luogo`: `"qui"` o numero, `n` | piazza gettoni Tempo su un Luogo |
| `quadrante` | `dove`: `"menhir_qui"` / `"menhir"` (a scelta) / `"segreto:N"` / `"luogo:N"`, `n` (variazione) oppure `valore` (imposta), opz. `gettone`: `"tempo"`/`"cerca"` | quadranti di Menhir, Segreti, Luoghi |
| `menhir` | `luogo` (`"qui"` o numero), `quadrante` (numero), `meno_per_giocatore` (bool: "-1 per giocatore") | attiva/piazza un Menhir |
| `luogo` | `azione`: `sostituisci` (`vecchio`: "questo" o numero, `nuovo`: numero) / `prepara` (`n`, piazzalo collegato) / `rimuovi` (`n` o "questo") / `rivela` (`n`) | modifiche alla mappa |
| `muovi` | `dove`: numero di Luogo, oppure `"numero_piu_basso_collegato"`, `"collegato_scelto"`, `"collegato_a:N"` (il Luogo dal numero più basso collegato al Luogo N); `chi` (predefinito `compagnia`) | movimento speciale (non costa Energia) |
| `incontro` | `colore`, opz. `nome` (Incontro specifico), opz. `livello`, opz. `pesca`: N (peschi N e risolvi quello di valore più alto), opz. `esito`: `{"vittoria":[…],"fallimento":[…],"fuga":[…]}` | pesca/risolvi un Incontro |
| `diario` | `luogo` (numero; 999 = Libro dei Segreti), opz. `verso` (numero del verso) | "vai al verso N del Libro dei Segreti", "leggi il verso N del Luogo X" |
| `evento` | `azione`: `risolvi_parte` (`capitolo`, `parte`, `lettera`) / `casuali_in_cima` (`n`, `meno_per_giocatore`) / `scarta_tutti` / `scarta_questo` / `cerca_attiva` (metti questa carta fra le Cerche attive) / `speciale` (`lettera`: risolvi l'Evento Speciale) | mazzo Eventi |
| `capitolo` | `azione`: `completato` / `prepara` (`capitolo`, `lettera`) | fine del capitolo, preparazione del successivo |
| `passa` | `chi` (predefinito `compagnia`) | "Dovete Passare il resto della giornata" |
| `nuova_giornata` | — | "Iniziate immediatamente una nuova giornata ignorando la Fine della Giornata" |
| `fine_esplorazione` | — | "L'Esplorazione termina" (si può omettere: è implicito quando non c'è un verso di destinazione) |
| `altra_scelta` | — | "Prendere un'altra scelta" / "Ritornare all'inizio del Luogo" |
| `dado` | `mod`: lista `[{"attr":…,"per":2}]` o `[{"n":2}]`, `risultati`: `[{"da":1,"a":3,"effetti":[…]}, …]` (`a`: 99 per "N+") | tira un dado (d6) con modificatori e applica la fascia |
| `quadrante_lancio` | `graal`: […], `teschio`: […] | lancia un Quadrante come una moneta |
| `scelta` | `opzioni`: `[{"testo":"…","effetti":[…]}, …]`, opz. `chi` (chi sceglie: `attivo`/`ognuno`) | il giocatore sceglie un'opzione ("paga 1 Cibo o 1 Magia oppure scarta questa carta") |
| `se` | `condizione` (§3), `allora`: […], opz. `altrimenti`: […] | effetto condizionato |
| `ripeti` | `per` (§4), `effetti`: […] | ripete gli effetti per ogni X |
| `nota` | `testo` | informazione da mostrare/ricordare (Compiti, indizi, regole permanenti scritte nel Diario) |
| `manuale` | `testo` | parte non automatizzabile (il gioco la mostra da eseguire a mano) |

**Solo negli Incontri** (Capacità delle carte, tabelle, Risposte, Opportunità, Oggetti in combattimento):
| tipo | campi | significato |
|---|---|---|
| `cubi` | `n` (negativo = perdere segnalini) | Riserva di Combattimento (`{i:cube}` = 1, `{i:cube2}` = 2…) |
| `meno_cubi` | `n` | "perdi N segnalini in meno" in questo attacco |
| `ferite` | `n`, opz. `inevitabile` (true: non prevenibili) | Ferite al personaggio attivo (perdita di Salute) |
| `previeni` | `n`, opz. `minimo`: 1 ("non può essere ridotta a 0") | previeni Ferite dell'attacco/Risposta in corso |
| `affinita` | `n` (↑ = +1, ↓ = −1) | misuratore di Affinità |
| `pesca_carte` | `n`, opz. `chi` | pesca carte di Combattimento/Diplomazia |
| `scarta_carte` | `n`, opz. `da`: `mano` / `mazzo` | scarta carte (icona carta rossa in tabella = 1 dalla mano) |
| `scarta_ultima` | — | scarta l'ultima carta della Sequenza |
| `carta_aggiuntiva` | `n` | puoi giocare N carte aggiuntive (come la Chiave dorata) |
| `fuga_nemico` | — | il nemico Fugge (Huir): fine dell'Incontro senza bottino |
| `scappa` | — | il personaggio Scappa / esce dall'Incontro |
| `vinci` | — | vinci subito l'Incontro |
| `ignora_tratto` | `tratto` (es. "Rapido") | per questo Incontro |
| `scegli_attacco` | — | scegli tu la riga della tabella d'attacco (eccetto Fuggire) |
| `gettone_tempo_carta` | `n` | aggiungi/togli gettoni Tempo dalle carte della Sequenza |
| `cariche` | `n` | Cariche sulla carta |

## 3. Condizioni (`condizione`)
Una condizione è un oggetto; si combinano con `{"tutte":[…]}`, `{"una":[…]}`, `{"non":{…}}`.
| tipo | campi |
|---|---|
| `status` | `nome`, `parti` (tutte richieste; [] = basta avere lo status o una parte qualsiasi), opz. `almeno` (numero di parti) |
| `segreto` | `n` |
| `oggetto` | `nome` oppure `parola` |
| `capitolo` | `da`, `a`, opz. `lettera` |
| `risorsa` | `ris`, `min`, `chi` (`attivo`/`compagnia`=qualcuno/`ognuno`/`totale`) |
| `attributo` | `attr`, `min` (nel Diario: il valore più alto fra i membri della Compagnia) |
| `tiro` | `da`, `a` (fascia del risultato del dado del verso; `a`: 99 per "N+") |
| `menhir_qui` | `attivo` (true: c'è un Menhir attivo; false: non c'è un Menhir) |
| `tutti_personaggi` | — (tutti i Personaggi della partita nella Compagnia) |
| `giocatori` | `da`, `a` |
| `gettoni_cerca` | `min` |
| `luogo_rivelato` | `n` |
| `personaggio` | `id` (`arev`, `ailei`, `beor`, `maggot`) |
| `incontro_vinto` / `incontro_perso` | — (per i versi dopo un Incontro: "Se vincete", "Se perdete") |
| `follia` / `morente` | — (il personaggio ha la carta Stai impazzendo / Stai morendo) |
| `affinita` | `colore`: `verde`/`rosso` (Diplomazia: marcatore negli spazi verdi/rossi) |
| `incontro_tipo` | `tipo_incontro`: `combattimento`/`diplomazia`, opz. `colore` (siamo in un Incontro di quel tipo/colore) |
| `insediamento` | `nemico` (bool) — il Luogo attuale è un Insediamento (amico o nemico) |
| `riserva` | `min` (Combattimento) |
| `carte_giocate` | `max` o `min` (nell'attivazione) |
| `altrimenti` | — ("Altrimenti, scegli questa opzione": vera se nessuna condizione precedente lo è) |
| `sempre` | — ("Continua.") |
| `manuale` | `testo` (da giudicare a mano) |

## 4. Moltiplicatori (`per`)
`{"chiavi":"aggression"}` (Chiavi di quell'attributo fisicamente unite nella Sequenza), `{"cubi_dati":true}`
("per ogni segnalino fornito da questa carta"), `{"attributo":"empathy"}` (punti di quell'attributo),
`{"membri":true}` (per ogni membro della Compagnia), `{"giocatori":true}`, `{"parti_status":"Nome"}`,
`{"risorsa":"magia"}`.

## 5. Inneschi delle carte (`inneschi`: lista)
Per Oggetti, Segreti, Abilità, carte "Stai morendo/impazzendo", Capacità passive:
`{"quando": QUANDO, "effetti": […], opz. "costo": [passi paga], "una_volta": "giorno"|"incontro"|null,
  "facoltativo": true/false, "condizione": {…}}`
QUANDO:
`azione` (ha l'icona azione: si usa come azione durante il giorno; `costo` in Energia),
`in_qualsiasi_momento` (si usa con un pulsante quando si vuole), `inizio_giornata`, `fine_giornata`,
`riposo` (quando Riposi), `viaggio` (quando Viaggi), `esplorazione` (quando Esplori), `arrivo` (entrando in un Luogo),
`inizio_incontro`, `inizio_combattimento`, `inizio_diplomazia`, `attivazione` (quando il tuo personaggio si attiva
in un Incontro), `attacco` (durante l'attacco nemico o la Risposta — icona teschio), `dopo_attacco`,
`collega_chiave` (quando colleghi una Chiave: opz. `attr`), `vittoria`, `vittoria_combattimento`,
`vittoria_diplomazia`, `fallimento`, `fine_incontro`, `perdi_salute` (ogni volta che perdi Salute per un attacco),
`ferite` (ogni volta che subisci Ferite), `ottieni_risorsa` (opz. `ris`, `colore` dell'Incontro), `pesca_incontro`
(opz. `nome`), `sempre` (modificatore passivo).
**Modificatori passivi** (quando = `sempre`), passi di tipo `modificatore`:
`{"tipo":"modificatore","cosa":COSA,"n":…, …}` con COSA:
`costo_energia` (n: −1 = costa 1 in meno, `min`: 1), `costo_viaggio` (primo viaggio del giorno, `primo`: true),
`guadagno` (`ris`, `n`: ±1 su ogni guadagno), `compagni_attivi` (`n`), `reliquie_attive` (`n`), `limite_oggetti` (`n`),
`ignora_tratto` (`tratto`), `ignora_evento` (`nome`), `previeni_ferite` (`n`, `minimo`), `mano_iniziale` (`n`),
`riposo_salute` (`n`), `riposo_terrore` (`n`), `no_riposo_salute`, `no_riposo_terrore`, `solo_incubi`,
`niente_menhir_costo_magia` (`n`), `incontro_in_fondo` (`nome`: rimetti in fondo quando lo peschi), `altro` (`testo`).

## 6. Formato dei file di uscita
Diario: `{"voci": {"<chiave>": {"effetti": […]} | {"condizione": {…}} | {"costo": […]} }}` con la chiave data nel lotto.
Carte: `{"carte": {"<img>": {…campi indicati nel lotto…}}}`.
Esempi:
- "Ogni membro della Compagnia ottiene 2 {i:terror} e perde 1 {i:energy}. L'Esplorazione termina." →
  `[{"tipo":"risorsa","ris":"terrore","n":2,"chi":"compagnia"},{"tipo":"risorsa","ris":"energia","n":-1,"chi":"compagnia"}]`
- "Ottenete la parte 3 dello status “Canto Funebre”." → `[{"tipo":"status","nome":"Canto Funebre","parti":[3]}]`
- "Se avete almeno 1 Rep e non avete lo status “Scroccone”" →
  `{"tutte":[{"tipo":"risorsa","ris":"rep","min":1,"chi":"compagnia"},{"non":{"tipo":"status","nome":"Scroccone","parti":[]}}]}`
- "Pagare 1 Ricchezza o 1 Cibo" (requisito di una scelta) → costo
  `[{"tipo":"scelta","opzioni":[{"testo":"1 Ricchezza","effetti":[{"tipo":"paga","ris":"ricchezza","n":1,"chi":"diviso"}]},{"testo":"1 Cibo","effetti":[{"tipo":"paga","ris":"cibo","n":1,"chi":"diviso"}]}]}]`
- "Richiede 1 {i:empathy}" → condizione `{"tipo":"attributo","attr":"empathy","min":1}`
- "Tirate un dado e sommate +2 per ogni punto della vostra Aggressività" (testo del verso, le fasce sono le opzioni) →
  nel verso: `{"tipo":"dado","mod":[{"attr":"aggression","per":2}],"risultati":[]}` e ogni fascia come condizione `{"tipo":"tiro","da":1,"a":3}`
- Oggetto "{i:action} 1 {i:energy}: ottieni 3 {i:health} e scarta questo Oggetto." →
  `{"inneschi":[{"quando":"azione","costo":[{"tipo":"paga","ris":"energia","n":1}],"effetti":[{"tipo":"risorsa","ris":"salute","n":3},{"tipo":"oggetto","modo":"scarta_questo"}]}]}`
- "Quando il tuo Personaggio si attiva in Combattimento, puoi ottenere {i:cube} e poi lanciare un Quadrante. Graal: nulla. Teschio: scarta questo Oggetto." →
  `{"inneschi":[{"quando":"attivazione","facoltativo":true,"condizione":{"tipo":"incontro_tipo","tipo_incontro":"combattimento"},"effetti":[{"tipo":"cubi","n":1},{"tipo":"quadrante_lancio","graal":[],"teschio":[{"tipo":"oggetto","modo":"scarta_questo"}]}]}]}`

## 7. Estensioni usate nelle codifiche e accettate dal motore
- `se` con `"chi": "ognuno"|"compagnia"|"tutti"`: la condizione si valuta membro per membro e gli effetti
  con `chi: "attivo"` vanno a quel membro ("Ogni membro con almeno 1 Empatia ottiene 1 Terrore").
- `per` anche su `paga` (`{"giocatori":true}`, `{"membri":true}`), e moltiplicatori `{"cariche":true}`
  (Cariche rimosse), `{"tiro":true}` (risultato del dado); `per` frazionari nei modificatori del dado.
- Modificatori del dado: `{"ris":"salute","per":1}`, `{"parti_status":"Nome","per":1}`.
- Condizioni: `segreto` con `nome` invece di `n`; `gettoni_cerca` con `luogo`; `gettone_tempo` (`luogo`, `min`).
- Voci "requisito o costo" del Diario con un campo `effetti` accanto a `costo`/`condizione`; voci "condizione"
  con `effetti` che contengono il `dado` da tirare prima di valutare le fasce.
- Capacità delle carte Combattimento/Diplomazia con `costo` (es. Cariche) e `facoltativo`; `cariche` con `n`
  negativo come costo (se non bastano, la Capacità non si applica).
- Inneschi con `gira: true` (una volta per Incontro), `collega_chiave` con `attr`, carte "Stai morendo" con
  `ottenuta` (effetti quando la carta entra in gioco), `chi: "proprietario"`.
- Preparazioni dei Capitoli: `eventi.parti_dal_fondo`, `eventi.varianti`, `eventi.scarta_dalla_cima`,
  `guardiani` (`colore`, `nome`, `luogo`: `rivelato_numero_piu_basso`/`_alto`, `giocatori`, `condizione`), `segreti`.
- `meno_cubi: 99` / `previeni: 99` = "tutte".

I passi `manuale` e i modificatori `cosa: "altro"` restano da eseguire al tavolo: il gioco li mostra con ☐.
