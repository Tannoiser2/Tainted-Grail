# Trascrizione delle carte di Tainted Grail (edizione spagnola → dati strutturati in italiano)

Scopo: un motore di gioco (Godot) deve **automatizzare tutto** Tainted Grail: La Caduta di Avalon
(combattimento e diplomazia a Chiavi, mappa dei Luoghi, Oggetti, Segreti, Eventi). Le carte del modulo
Tabletop Simulator sono scansioni dell'**edizione spagnola**: tu le leggi, le trascrivi in JSON con
i campi strutturati che servono al motore, e dai la **traduzione italiana** di ogni testo. In più indichi
dove si trovano i testi sulla carta, perché un programma ridisegnerà la carta in italiano sopra
l'illustrazione originale.

Le regole del gioco riassunte sono in `docs/REGOLE.md` (leggi almeno i §5 e §6 prima di iniziare
se trascrivi carte di Combattimento/Diplomazia o Incontri).

## Come lavorare
- Ti viene dato un **lotto** (`tools/trascrizione/lotti/<nome>.json`): un elenco di carte, ognuna con
  `img` (percorso relativo a `web/img/`), eventualmente `retro` (faccia posteriore, se ha contenuto),
  `mazzo` e `nome_tts` (nome dato dal modulo TTS, a volte vuoto o in inglese).
- Guarda ogni immagine con lo strumento **Read** (`/home/claude/Tainted-Grail/web/img/<img>`). Le carte
  sono larghe ~600-900 px: per leggere testi piccoli o icone **ritaglia e ingrandisci** con Python/PIL, es.
  `python3 -c "from PIL import Image; im=Image.open(P); w,h=im.size; im.crop((0,0,w//3,h)).resize((w//3*2,h*2)).save('/tmp/claude-0/x.png')"`
  (usa una cartella temporanea tua sotto `/tmp/claude-0/-home-claude/0edb0af6-34ef-5e68-a89e-1d3d9d881694/scratchpad/` e nomi univoci).
- Scrivi **un solo file JSON** (percorso indicato nel compito): `{"carte": [ ... ]}`, una voce per carta del
  lotto, nello stesso ordine, ognuna con `"img"` identico a quello del lotto. UTF-8, JSON valido
  (verificalo alla fine con `python3 -c "import json;json.load(open(PERCORSO))"`).
- Se una carta del lotto è identica (stessa illustrazione e testo) a una precedente, trascrivila comunque
  (è veloce: copia i campi).
- Se qualcosa è illeggibile o incerto, scrivi la migliore lettura e spiega in `"dubbi"` (stringa).

## Regole generali
- `"es"`: testo spagnolo **fedele**; `"it"`: traduzione italiana con la **terminologia ufficiale** (glossario
  sotto e `tools/trascrizione/glossario_app.json`, che contiene i nomi italiani ufficiali di Luoghi, Segreti,
  Oggetti, Incontri e status presi dall'app italiana: usali sempre quando la carta nomina uno di essi).
- Testi di regole: niente parafrasi creative, stessa struttura e stessi numeri. Tono narrativo per i testi
  di ambientazione (corsivi).
- **Icone nel testo**: scrivile fra graffe con il nome del vocabolario: `{i:health}`, `{i:wound}`… Il foglio con
  le icone e i loro nomi è `tools/trascrizione/foglio_icone.png` (guardalo prima di iniziare). Le icone di
  Combattimento/Diplomazia sono spiegate sulla carta di riferimento
  `web/img/oggetti/carta_de_referencia_1_7908cc.webp` (fronte) e `_b.webp` (retro, glossario icone).
  Se un'icona non è nel foglio, inventa un nome breve minuscolo e segnalalo in `"dubbi"`.
  Vocabolario: attributi `aggression` (orso, Agresividad), `courage` (cinghiale, Audacia), `practicality`
  (serpente/anguilla, Lógica), `empathy` (uccello, Empatía), `caution` (creatura arrotolata, Cautela),
  `spirituality` (gufo, Espiritualidad); `health` (cuore rosso), `energy` (omino che corre, verde),
  `terror` (viola), `wound` (Herida, artigli bianchi), `woundinevitable` (artigli rossi), `skull` (teschio:
  attacco nemico/Risposta), `cube` (segnalino rosso di Riserva; `cube2`, `cube3` se raffigurati 2-3 cubi),
  `draw` (carta verde con croce: pesca una carta), `discard` (carta rossa strappata: scarta l'ultima carta
  della Sequenza), `extra` (carta dorata col fulmine: azione/carta aggiuntiva), `arrowup`, `arrowdown`
  (Affinità), `special` (triquetra: bonus speciale di Diplomazia), `place` (freccia in giù sul piedistallo:
  si attiva al piazzarla), `delay` (clessidra nell'esagono: si attiva quando si toglie l'ultimo gettone
  Tempo), `menhir`, `dream` (occhio blu: Sogno), `settlement_friend` (sigillo verde), `settlement_enemy`
  (sigillo rosso), `thunder` (fulmine: regola immediata), `journal` (libro con lente: continua nel Diario),
  `action` (icona d'azione verde con omino e costo), `magic` (simbolo Magia ◊◊), `grail`, `skull_coin`.
- **Risorse nel testo**: scrivile come `{r:Ricchezza}`, `{r:Cibo}`, `{r:Magia}`, `{r:Esp}`, `{r:Rep}` (sono le
  parole colorate in arancio sulle carte: Riqueza, Comida, Magia, Exp, Rep).
- Grassetti e corsivi: rendili con `[b]…[/b]` e `[i]…[/i]` (BBCode).
- **Aree di testo** (`"aree"`): per ridisegnare la carta in italiano servono i rettangoli che contengono i
  testi spagnoli, in coordinate **normalizzate** 0..1 rispetto all'immagine (`[x0, y0, x1, y1]`, origine in alto
  a sinistra). Uno per il titolo (`"titolo"`, solo l'interno del cartiglio), uno per ogni blocco di testo
  (`"testo"`, il riquadro scuro/chiaro che lo contiene, interno), più eventuali altri (`"tratti"`, `"tabella"`,
  `"ricompensa"`…). Misurali sull'immagine (puoi stamparne le dimensioni e ritagliare per controllare).
  Precisione richiesta: ±2%. Non includere icone di Chiave o bordi.

## Glossario spagnolo → italiano (ufficiale)
Localización = Luogo · Explorar = Esplorare · Diario de Exploración = Diario di Esplorazione · Versículo = verso ·
Libro de los Secretos = Libro dei Segreti · Encuentro = Incontro · Combate = Combattimento · Diplomacia =
Diplomazia · Secuencia = Sequenza · Clave = Chiave · Reserva de Combate = Riserva di Combattimento ·
Valor = Valore · Afinidad = Affinità · Respuesta = Risposta · Ataque de oportunidad = Attacco di opportunità ·
Oportunidad = Opportunità · Escapar = Scappare · Huir = Fuggire · Evitar = Evitare · Recompensa = Ricompensa ·
Botín = Bottino · Fracaso = Fallimento · Herida = Ferita · Prevenir = Prevenire · Inevitable = Inevitabile ·
Rasgo = Tratto · Emboscada = Imboscata · Repentino = Improvviso · Defensivo = Difensivo · Rápido = Rapido ·
Finta = Finta · Guardián = Guardiano · Horda = Orda · Oportunista = Opportunista · Furia = Furia ·
Ladrón = Ladro · Destrucción = Distruzione · Lento = Lento · Grial = Graal · Calavera = Teschio ·
Dial = Quadrante · Ficha de Tiempo = Gettone Tempo · Ficha de Misión = Gettone Cerca (nell'app: "Gettone Cerca") ·
Misión = Cerca · Tarea = Compito · Energía = Energia · Salud = Salute · Terror = Terrore · Comida = Cibo ·
Riqueza = Ricchezza · Magia = Magia · Exp = Esp · Rep = Rep · Agresividad = Aggressività · Audacia = Coraggio ·
Lógica = Praticità · Empatía = Empatia · Cautela = Cautela · Espiritualidad = Spiritualità · Atributo =
Attributo · Habilidad = Abilità · Objeto = Oggetto · Arma = Arma · Armadura = Armatura · Escudo = Scudo ·
Compañero = Compagno · Reliquia = Reliquia · Secreto = Segreto · Estado = status ("lo status «X»",
"la parte 2 dello status «X»") · Asentamiento = Insediamento · Menhir = Menhir · Sueño = Sogno ·
Pesadilla = Incubo · Evento Aleatorio = Evento Casuale · Comienzo del Día = Inizio della Giornata ·
Fin del Día = Fine della Giornata · Descansar = Riposare · Pasar = Passare · Viajar = Viaggiare ·
Equipo = Compagnia · miembro del equipo = membro della Compagnia · personaje = Personaggio ·
Roba una carta = Pesca una carta · Descarta = Scarta · Mazo = Mazzo · Mano = Mano ·
Reserva avanzada = Riserva Avanzata · Activación = Attivazione · Carga = Carica · Voltear = Girare ·
Wyrd/Rareza = Wyrd (Rareza = "Wyrd", es. "Confín de la Rareza" → usa il nome del glossario).
Nell'app italiana: "L'Esplorazione termina", "Ogni membro della Compagnia ottiene…", "Ottenete…".

## Schemi per tipo di carta (campo `"tipo"`)

### A. `"combattimento"` / `"diplomazia"` — carte dei mazzi dei Personaggi
Verticali, nome in alto in un cartiglio (verde/rosso/blu/marrone secondo il personaggio), colonna di
**Chiavi** sul bordo sinistro, riquadro con la Capacità in basso, numero in basso a destra ("1/25 V",
"3/15 A"…; la lettera è il colore del mazzo base: A=Azul, V=Verde, M=Marrón, G=Gris; le carte avanzate
dei personaggi hanno il nome del personaggio sul cartiglio in alto e il numero n/15).

La colonna delle Chiavi ha **4 righe** in alto (posizioni fisse, dall'alto: righe 1, 2, 3, 4; guarda le
altezze: circa y≈0.11, 0.26, 0.41, 0.57) e **1 riga in fondo** (y≈0.9). Ogni riga ha due **semichiavi**:
- **sinistra** (`"bonus"`, con la punta "<" verso il bordo sinistro): il bonus che questa carta ottiene se si
  collega alla carta precedente in quella riga: `cube` (1 segnalino), `cube2`, `cube3`, `draw`, `extra`
  (carta dorata: permette di giocare un'altra carta), `discard` (carta rossa: scarta l'ultima carta della
  Sequenza), `arrowup`, `arrowdown`, `special` (triquetra), oppure `null` se la semichiave sinistra non c'è.
  Indica anche la **cornice** della semichiave sinistra: `"attributo"` (cornice rossa/scura normale) o
  `"magia"` (cornice **blu**: Chiave Magica, si paga 1 Magia).
- **destra** (`"apre"`, con la punta ">" verso l'interno): l'icona che fa da requisito per la carta
  successiva: un attributo (`aggression`, `courage`, `practicality`, `empathy`, `caution`, `spirituality`),
  `magic` (cornice blu senza attributo), oppure `null`.
- **Riga in fondo**: `"bonus"` (semichiave sinistra, es. `cube`, `draw`, `arrowup`, `null` se vuota) e
  `"molt"` (semichiave destra: `"1x"`, `"2x"`, `"3x"`, `"x"` se è la ✖ rossa che annulla, `null` se vuota).
- Una carta può avere più icone nella stessa semichiave (es. 2 cubi): usa `cube2`, oppure scrivi la lista
  `["cube","draw"]`.

```json
{"img": "...", "tipo": "combattimento", "mazzo": "base|avanzato", "personaggio": "ailei", "colore": "V",
 "numero": "1/25", "copie": 1,
 "nome": {"es": "Ataque cauteloso", "it": "Attacco prudente"},
 "chiavi": [
   {"riga": 1, "bonus": "cube", "cornice": "attributo", "apre": "aggression"},
   {"riga": 2, "bonus": null, "apre": "courage"},
   {"riga": 3, "bonus": "extra", "cornice": "attributo", "apre": "practicality"},
   {"riga": 4, "bonus": null, "apre": null}],
 "fondo": {"bonus": "cube", "molt": "2x"},
 "capacita": {"innesco": "attacco", "tempo": 0,
              "es": "Pierde {i:cube} menos, prevén 1 {i:wound}.",
              "it": "Perdi {i:cube} in meno, previeni 1 {i:wound}."},
 "passiva": false,
 "aree": {"titolo": [0.35,0.06,0.93,0.13], "testo": [[0.36,0.74,0.95,0.85]]}}
```
`"innesco"` della Capacità: `"piazza"` (icona freccia giù sul piedistallo: al piazzarla), `"ritardata"`
(clessidra: quando si toglie l'ultimo gettone Tempo; `"tempo"` = numero di gettoni se indicato, altrimenti 1),
`"attacco"` (teschio: durante l'attacco nemico / la Risposta), `"passiva"` (nessuna icona; effetto sempre attivo),
`null` se la carta non ha Capacità. `"passiva": true` se la carta ha Chiavi su lati opposti (carta passiva).
Elenca SEMPRE tutte e 4 le righe (anche vuote).

### B. `"incontro"` — carte Incontro (mazzi grigio/blanco, verde, viola/morado, blu/azul)
Combattimento (grigio, verde, viola) o Diplomazia (blu). Leggi con attenzione il §5 di REGOLE.md.
Campi comuni: `colore` (`grigio`, `verde`, `viola`, `blu`), `livello` (1-4, il numero fra parentesi quadre sul
dorso o il simbolo di difficoltà), `guardiano` (true se c'è l'icona del Guardiano), `nome` {es,it},
`testo` {es,it} (narrativo), `chiavi_destra`: le semichiavi sul **bordo destro** (righe 1-4, attributo o
`magic` o null) + `fondo_molt` ("1x","2x","x" o null), `aree`.

Combattimento: `"valore"` (numero da raggiungere nella Riserva), `"tratti"`: lista in italiano
(`["Rapido","Guardiano"]`), `"tabella"`: righe dall'alto `[{"da":0,"a":1,"es":"1 {i:wound}","it":"1 {i:wound}"}, …]`
(l'ultima riga "7+" → `"a": 99`), `"opportunita"` {es,it}, `"ricompensa"` {es,it} e `"bottino"` {es,it}
(separali se la carta li distingue: Recompensa = a ogni membro, Botín = da dividere).

Diplomazia: `"affinita"`: `{"verdi": n, "rossi": m}` (spazi del misuratore sopra e sotto quello grigio iniziale),
`"evitare"` {es,it} o null, `"fasi"`: lista delle fasi (Etapas) in ordine, ognuna
`{"nome": {es,it}, "speciale": {"empathy": "↑", "spirituality": "↑↑", …} (bonus della triquetra per
attributo, scrivi frecce o testo {es,it} se è un effetto), "risposta": {"es":"{i:arrowdown}{i:arrowdown}","it":…}}`,
`"fallimento"` {es,it}, `"ricompensa"` {es,it}.

Carte speciali nei mazzi Incontro (es. "Tu primer encuentro", eventi come "Calma antes de la tempestad"
senza tabella né Chiavi): `"speciale": true`, `nome`, `testo` {es,it}, `aree`.

### C. `"luogo"` — carte Luogo (mappa)
Verticali: numero nel cartiglio (a volte un secondo numero piccolo = **numero antico**), nome, sigilli sotto il
nome, **Chiavi di Direzione** sui quattro bordi (numeri con freccia: in alto, a sinistra, a destra, in basso),
eventuale regola immediata (fulmine), Azione del Luogo (icona d'azione con costo in Energia, nome, effetto,
eventuale "(una vez al Día)"), testo d'ambientazione in corsivo.
```json
{"img":"...","tipo":"luogo","numero":101,"antico":null,"nome":{"es":"Cuanacht","it":"Cuanacht"},
 "sigilli":["dream","settlement_friend","menhir"],
 "direzioni":{"su":102,"sinistra":103,"destra":104,"giu":105},
 "immediata": null,
 "azione":{"costo":1,"risorsa":"energy","nome":{"es":"Ayuda a los vecinos","it":"Aiutare i vicini"},
           "es":"Obtén 1 de {r:Rep} (una vez al Día)","it":"Ottieni 1 {r:Rep} (una volta al giorno)",
           "una_volta_al_giorno":true},
 "ambientazione":{"es":"…","it":"…"},
 "aree":{"titolo":[…],"azione":[…],"ambientazione":[…]}}
```
`direzioni`: `null` per i lati senza numero. Il nome italiano del Luogo prendilo da `glossario_app.json`
(`luoghi`, per numero). Se la carta ha più azioni, `azione` diventa una lista.

### D. `"oggetto"` — carte Oggetto (dorso "Objeto")
`nome` {es,it} (usa i nomi di `glossario_app.json` → `oggetti` quando corrispondono), `parola` (parola chiave in
alto: `Arma`, `Armatura`, `Scudo`, `Compagno`, `Reliquia` oppure null), `fabbricabile` (true se c'è la "F"
nel cerchio), `effetto` {es,it}, `aree` (titolo, parola, testo).

### E. `"segreto"` — carte Segreto (dorso "Secreto" con numero)
`numero` (grande, nel cerchio a sinistra), `nome` {es,it} (glossario `segreti` per numero!), `parola`
(se c'è una parola chiave come Arma/Compagno, o "Personale"), `effetto` {es,it}, `quadrante` (true se la carta
prevede un Quadrante), `aree`.

### F. `"abilita"` — carte Abilità (orizzontali, doppia faccia: fronte `img` e retro `retro`)
Per ogni faccia: `numero` (il numero grande a sinistra, es. 63), `nome` {es,it}, `attributo` (icona in basso:
owl = spirituality, ecc.), `effetto` {es,it}. JSON: `{"img":…, "tipo":"abilita", "facce":[{…fronte…},{…retro…}],
"aree":{…}}` (aree della faccia fronte; le due facce hanno lo stesso schema grafico).

### G. `"evento"` — carte Evento (orizzontali)
Storia/Preparazione capitolo (titolo verticale a sinistra tipo "Preparación del Capítulo 1 (Reverso)" o
"Capítulo 1: Parte 3"), Eventi Casuali (titolo grande al centro, es. "Bestia de caza"), Eventi Speciali
(lettera A, B, C… a sinistra). Campi: `sottotipo` (`preparazione`, `storia`, `casuale`, `speciale`),
`capitolo` (numero o null), `parte` (numero o null), `lettera` (A/B per i capitoli divisi o per gli eventi
speciali), `titolo` {es,it}, `testo` {es,it} (tutto il testo, con [b]/[i]), `cerca` {es,it} (riquadro della
Missione col lucchetto, se presente), `indizio` {es,it} (se presente), `aree`. Se la carta ha anche un retro con
testo (`retro` nel lotto), trascrivi anche quello in `"retro": {…stessi campi…}`.

### H. `"speciale"` — altre carte (Te estás muriendo, Estás enloqueciendo, carte di riferimento…)
`nome` {es,it}, `testo` {es,it} completo, `aree`.
