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
- Ogni valore dei Personaggi si corregge a mano con un clic (sinistro +1, destro −1) sulla scheda.

## Firebase
Stesso progetto degli altri giochi della ludoteca (`flammerouge-f8669`), radice `taintedgrail/campagne`.
Le regole da aggiungere al Realtime Database sono in `firebase/regole_taintedgrail.json`.

## Struttura
```
scripts/core/     Partita (stato), Giornata, MotoreDiario, Condizioni, Effetti, Incontro, Personaggi, Preparazione
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
TG_PROVA=1 TG_DB_URL=off xvfb-run -s "-screen 0 1920x1080x24" godot --path . -s res://tests/foto.gd   # screenshot
```
