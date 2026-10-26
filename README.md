# Tainted Grail — La Caduta di Avalon (adattamento digitale, Godot 4)

Versione digitale per uso personale di **Tainted Grail: La Caduta di Avalon** (Awaken Realms), campagna
in **solitario** (1-4 Personaggi guidati da un giocatore). Componenti, illustrazioni, regole e testi
© Awaken Realms: i paragrafi del Diario di Esplorazione e del Libro dei Segreti vengono dall'app ufficiale
*Tainted Grail Companion* (database `appData.sqlite`, testi italiani), carte e miniature dal modulo
Tabletop Simulator (edizione spagnola, carte ritrascritte e ridisegnate in italiano).

**Gioca nel browser:** https://tannoiser2.github.io/Tainted-Grail/

## Avvio
1. Apri Godot 4 (testato su 4.7) → *Importa* → seleziona `project.godot`.
2. Premi **F5**. F11 alterna schermo intero e finestra.

## Cosa c'è
- **Diario di Esplorazione completo in italiano** (La Caduta di Avalon: 62 Luoghi, 1.027 versi, Libro dei
  Segreti, Sogni, Incubi, testi dei Menhir, aiuti per capitolo):
  - le **condizioni** si verificano da sole sullo stato della partita (status e loro parti, carte Segreto,
    capitolo, Menhir nel Luogo, attributi e risorse della Compagnia) e sono segnate ✔ / ✘;
  - i **tiri di dado** si fanno con un clic, con il modificatore letto dal verso ("sommate +2 per ogni punto
    di Aggressività") e la fascia di risultato evidenziata;
  - i **risultati si applicano da soli**: risorse a chi le riceve (anche "ogni membro della Compagnia"),
    status, Segreti, Gettoni Cerca, Oggetti, Luoghi sostituiti, Incontri da risolvere, "Passare il resto
    della giornata"; quello che non viene riconosciuto compare come promemoria da fare a mano;
  - **Diario libero** dal menu: si usa come l'app ufficiale, digitando il numero del Luogo.
- **Tavolo 3D**: le carte Luogo piazzate come sul tavolo vero (con le Chiavi di Direzione), le **miniature 3D**
  del modulo TTS (Personaggi, Menhir con il Quadrante, Guardiani), telecamera libera (sinistro trascina,
  destro ruota, rotellina zoom).
- **Giornata automatizzata**: Inizio della Giornata (Menhir che si spengono, Luoghi fuori raggio che spariscono,
  Quadranti, Evento del giorno con gli Eventi Casuali aggiunti al mazzo), azioni (Viaggiare con rivelazione dei
  Luoghi collegati, Esplorare, Azione del Luogo "una volta al giorno", Azione del Personaggio, Menhir, Passare),
  Fine della Giornata (Riposo con il Cibo, recupero dell'Energia con la regola dell'Esausto, Sogni e Incubi),
  miglioramenti con l'Esp (costo per coppia di Attributi, carte avanzate scelte fra 3).
- **Combattimento e Diplomazia a Chiavi**: Sequenza di carte con collegamento delle Chiavi riga per riga
  (attributo del personaggio attivo con il livello richiesto, Chiavi Magiche pagando Magia, Chiave in fondo con il
  moltiplicatore), bonus applicati (segnalini, carte, carta dorata per giocare altre carte, Affinità, bonus speciale
  della fase), Capacità al piazzamento e ritardate, attacco nemico dalla tabella (Ferite, prevenzione, segnalini
  persi e Riserva negativa), Opportunità, tratti (Imboscata, Improvviso, Difensivo, Rapido, Finta, Orda,
  Opportunista, Furia, Lento, Guardiano), Panico, fine del turno, Scappare, Evitare, Ricompensa e Bottino.
- **Carte in italiano**: 785 carte del gioco base trascritte (Combattimento, Diplomazia, Incontri, Luoghi,
  Oggetti, Segreti, Abilità, Eventi) e ridisegnate con il testo italiano sull'illustrazione originale.
  Le scansioni dell'edizione italiana potranno sostituirle una alla volta (stesso nome di file in `web/img/it/`).
- **Salvataggio della campagna**: automatico dopo ogni modifica, sul dispositivo e su Firebase. Ogni campagna
  ha un **codice di 6 caratteri** (in alto): dal menu *Riprendi con un codice* la si riapre da qualunque dispositivo.

## Automazione
Tutti i testi di regole del gioco sono codificati in un linguaggio di effetti strutturato
(`tools/automazione/DSL.md`) e raccolti in `data/automazione.json` (`tools/unisci_automazione.py`):
**1.882 voci del Diario** (risultati, requisiti e costi, condizioni, dadi, Sogni, Incubi, Menhir) e **777 carte**
(Oggetti, Segreti, Abilità, Luoghi, Eventi, Incontri, carte Combattimento e Diplomazia, Stai morendo/impazzendo).
L'interprete (`scripts/core/interprete.gd`) li esegue sullo stato della partita:
- **Diario**: condizioni verificate, costi pagati (se non bastano le risorse la scelta non procede), risultati
  applicati, dadi con i modificatori giusti, Incontri richiesti dal Diario con "se vincete / se perdete",
  salti al Libro dei Segreti, scelte del giocatore ("1 Ricchezza o 1 Cibo") proposte con una finestra.
- **Carte dei Personaggi**: Oggetti, Segreti e Abilità con il loro innesco (azione, in qualsiasi momento, inizio e
  fine della giornata, riposo, viaggio, esplorazione, arrivo, inizio dell'Incontro, attivazione, attacco, ferite,
  vittoria…) e i modificatori passivi (costo del Viaggio, Riposo, tratti ignorati, mano iniziale, guadagni…).
- **Abilità**: dal 3° punto di un Attributo si sceglie la carta Abilità e la faccia; perdendo il punto si scarta.
- **Incontri**: Capacità delle carte (al piazzamento, ritardate, durante l'attacco, passive, Cariche), tabelle
  d'attacco, Opportunità, Risposte e bonus speciali della Diplomazia, Evitare, Ricompensa a ogni membro e Bottino
  da dividere, Fallimento, Incontri speciali.
- **Luoghi**: azioni del Luogo (costo, condizione, una volta al giorno), regole immediate (fulmine), Menhir con
  condizione, costo e Quadrante.
- **Eventi e capitoli**: effetti alla rivelazione, Eventi Casuali della giornata, **Cerche** che si completano da
  sole quando la condizione di Successo è vera (o a mano dal pulsante CERCHE), **cambio di capitolo** con la carta
  Preparazione (mazzi Incontro, Parti nel mazzo Eventi, Guardiani, Segreti).
- **Guardiani**: piazzati dalla Preparazione, mossi ogni mattina col dado Guardiano (1-4 direzione, 5 fermo,
  6 se ne va — distribuzione da verificare sul dado vero), Incontro immediato entrando nel loro Luogo.
- **Stai morendo / Stai impazzendo**: effetti quando la carta entra in gioco, limite di Oggetti, Incubi al posto
  dei Sogni, lanci di Quadrante a ogni Viaggio o Esplorazione.
- **Oggetti**: al massimo 1 attivo per parola chiave (Arma, Armatura, Scudo, Compagno, Reliquia, salvo Abilità e
  Segreti che ne permettono 2); dalla scheda del Personaggio (pulsante OGGETTI) si sceglie quale è attivo, si dà a
  chi è nello stesso Luogo (non le carte "non cedibili") o si scarta.
- **Regole particolari delle carte**: perdite modificate (Talismani, Furia…), Esausto solo a 0 Energia, Salute
  al posto dell'Energia da Esausti, pasto con Magia, Riposo senza Esaurimento (Idromele), 4 carte fra cui scegliere
  nei miglioramenti, Menhir pagati con Magia o Energia, Compagni gratuiti, Incontri casuali pescati in 2 e scelti,
  dadi e Quadranti rilanciati (Fortunato, Sensi acuti, Amuleto Portafortuna), scambio dei Quadranti dei Menhir,
  sfide a dadi fra Personaggi; negli Incontri Guardia del corpo, Chiavi di Magia come extra, Chiavi senza costo
  come 1x, Attacco furtivo, Cariche spese come Magia, bonus speciali raddoppiati o trasformati in Frecce su,
  prima carta scoperta del mazzo, ecc. Restano come testo solo le regole dei Tuathan (capitolo 8).
- **Morte**: in cooperativo il Personaggio esce di scena, i suoi Oggetti restano nel Luogo (RACCOGLI OGGETTI) e si
  può prendere un Personaggio rimasto nella scatola sul Luogo rivelato col numero più basso; in solitario, o se non
  restano Personaggi, la partita fallisce e si può invocare la **Misericordia della Madre di Tutti** (status
  "Salvati dalla Dea", Libro dei Segreti verso 500) o tornare al menu.

Il gioco tiene traccia di tutto (gettoni Tempo e Cerca sui Luoghi, quadranti di Menhir, Segreti, Personaggi e nemici, miniature, esiti degli Incontri, lanci di Quadrante, spunte sugli status, Eventi in gioco, rimandi del Diario) e non chiede al giocatore ciò che può verificare da solo: restano solo 7 passi da guardare sulla carta stampata (illustrazioni e la pila delle carte di Tuathan).

## Firebase
Stesso progetto degli altri giochi della ludoteca (`flammerouge-f8669`), radice `taintedgrail/campagne`.
Le regole da aggiungere al Realtime Database sono in `firebase/regole_taintedgrail.json`.

## Struttura
```
scripts/core/     Partita (stato), Giornata, MotoreDiario, Interprete (effetti codificati), Condizioni ed Effetti
                  (lettura del testo, di riserva), Incontro, Personaggi, Preparazione
data/automazione.json  effetti codificati (tools/automazione: DSL.md, lotti, out; tools/unisci_automazione.py)
scripts/ui/       menu, gioco, pannello del Diario, schede dei Personaggi, finestra dell'Incontro, Diario libero
scripts/tavolo/   tavolo 3D
scripts/data/     Dati, Carte, Immagini (caricamento a richiesta da web/), Modelli (miniature .glb)
data/diario/      paragrafi esportati dall'app (tools/esporta_diario.py)
data/carte.json   carte trascritte (tools/unisci_carte.py)
web/img           immagini del modulo TTS; web/img/it le carte ridisegnate in italiano
web/modelli       miniature 3D (tools/estrai_miniature.py)
web/app           illustrazioni dei Luoghi dall'app
tools/            estrazione TTS, esportazione del Diario, trascrizione e ridisegno delle carte
docs/REGOLE.md    riassunto tecnico delle regole
```

## Prove
```
godot --headless --path . -s res://tests/compila.gd          # compila tutti gli script
TG_DB_URL=off godot --headless --path . -s res://tests/prova_automazione.gd   # esegue tutte le voci codificate
TG_PROVA=1 TG_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto.gd   # screenshot
```
