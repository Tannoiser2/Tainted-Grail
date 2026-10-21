# Tainted Grail: La Caduta di Avalon — Riassunto tecnico delle regole (per il motore Godot)

Fonti: Regolamento ES (24 pp.), Guida rapida "¡Empieza aquí!", Hoja de Juego (scheda di salvataggio), FAQ ufficiale v1.0 (aprile 2021).
Convenzione: **termine italiano (termine spagnolo delle carte)**. `[DA VERIFICARE]` = non ricavabile con certezza dalle fonti: va controllato sulle carte o componenti fisici.
I riferimenti "R.p.N" indicano la pagina del regolamento spagnolo.

---

## 0. Glossario rapido IT ↔ ES

| Italiano | Español (carte) | Note |
|---|---|---|
| Luogo | Localización | carte grandi della mappa |
| Esplorazione / Esplorare | Exploración / Explorar | rimanda al Diario |
| Diario di Esplorazione | Diario de Exploración | "versi" (Versículos) |
| Libro dei Segreti | Libro de los Secretos (LdlS) | |
| Incontro | Encuentro | 4 mazzi colorati |
| Combattimento / Diplomazia | Combate / Diplomacia | |
| Menhir | Menhir | |
| Quadrante | Dial | gettone ottagonale |
| Gettone Tempo / Gettone Missione | Ficha de Tiempo / Ficha de Misión | |
| Energia / Salute / Terrore | Energía / Salud / Terror | "Medidores de Supervivencia" |
| Cibo / Ricchezza / Magia / Rep / Esp | Comida / Riqueza / Magia / Reputación (Rep) / Experiencia (Exp) | |
| Aggressività ↔ Empatia | Agresividad ↔ Empatía | coppia 1 |
| Coraggio ↔ Cautela | Audacia ↔ Cautela | coppia 2 |
| Praticità ↔ Spiritualità | Lógica ↔ Espiritualidad | coppia 3 |
| Abilità | Habilidad | carte a doppia faccia |
| status (parti di status) | Estado (partes) | sulla Hoja de Juego |
| Segreto / Oggetto | Secreto / Objeto | |
| Compagno (oggetto) | Compañero | parola chiave Oggetto |
| Compagnia / membri della compagnia | Equipo / miembros del equipo | gruppo di personaggi |
| Insediamento (amico/nemico) | Asentamiento (amigo/enemigo) | sigillo del Luogo |
| Guardiano | Guardián | |
| Sogno / Incubo | Sueño / Pesadilla | |
| Evento / Evento Casuale | Evento / Evento Aleatorio | |
| Missione / Compito | Misión / Tarea | |
| Passare (il resto della giornata) | Pasar | |
| Sequenza | Secuencia | fila di carte giocate |
| Chiave (di Attributo / di Bonus / Magica / senza costo) | Clave (de Atributo / de Bonificación / Mágica / sin coste) | |
| Chiave di Direzione | Clave de Dirección | numeri sui bordi dei Luoghi |
| Riserva di Combattimento | Reserva de Combate | segnalini accumulati |
| Valore dell'Incontro | Valor del Encuentro | soglia di vittoria |
| Tabella di Combattimento / di Diplomazia | Tabla de Combate / de Diplomacia | |
| Misuratore di Affinità | Medidor de Afinidad | |
| Risposta (dell'avversario) | Respuesta (del oponente) | |
| Attacco di Opportunità | Ataque de oportunidad | |
| Scappare / Fuggire (nemico) | Escapar / Huir | |
| Evitare | Evitar | solo Diplomazia |
| Ricompensa / Bottino / Fallimento | Recompensa / Botín / Fracaso | |
| Tratti del nemico | Rasgos | |
| Capacità | Capacidad | testo della carta |
| Cariche | Cargas | |
| Ferite | Heridas | perdita di Salute |
| Prevenire | Prevenir | ridurre Ferite |
| Panico / Esausto | Pánico / Agotado | |
| Riserva Avanzata | Reserva Avanzada | 25 carte per mazzo |
| Graal / Teschio | Grial / Calavera | facce del quadrante lanciato |
| Narratore | Narrador | ruolo opzionale |
| Misericordia della Madre di Tutti | Misericordia de la Madre de Todos | |
| Foglio di gioco | Hoja de Juego | salvataggio + status |

---

## 1. Componenti e plancia del personaggio

### 1.1 Componenti rilevanti per il motore
- 4 personaggi (Beor, Ailei, Arev, Gusano), ciascuno: tessera personaggio (fronte = Azione del Personaggio + tratto negativo; retro = "Preparación": attributi e risorse iniziali), plancia colorata (blu, verde, marrone, grigio), 80 carte (vedi 1.6).
- 4 mazzi Incontro × 31 carte (grigio, verde, viola, blu), ciascuno con una carta "Tu primer encuentro". 4 livelli di difficoltà.
- 63 Luoghi; 42 Segreti (numerati); 65 Oggetti; 70 Eventi (storia + preparazione capitolo); 22 Eventi Casuali; 36 carte Abilità (= 72 Abilità, doppia faccia).
- 1 carta "Te estás muriendo" (solitario) + 4 "Te estás muriendo" (cooperativo); 4 "Estás enloqueciendo".
- 3 Menhir, 10 quadranti, 8 gettoni Tempo, 4 gettoni Missione, segnalini comuni (rossi = 1) e grandi (viola = 5), 1 dado Guardiano, 1 dado normale, 4 limitatori di Salute a "T".

### 1.2 Tracce di sopravvivenza (Medidores de Supervivencia)
Le tre tracce sono affiancate sulla plancia e **condividono la stessa scala** (righe): Energia (sx), Salute (centro, marcatore a T), Terrore (dx).

| Traccia | Regola | Zona rossa |
|---|---|---|
| **Salute (Salud)** | marcatore a "T". Valore iniziale = spazio con doppia freccia rossa (Beor: 9). | Salute a 0 → carta "Te estás muriendo" (§7.8) |
| **Energia (Energía)** | spesa per azioni. **Invariante: Energia ≤ Salute sempre.** Iniziale = spazio a doppia freccia (Beor: 6). | ultimi 2 spazi (1 e 0) = **Esausto (Agotado)** |
| **Terrore (Terror)** | cresce verso l'alto. Iniziale = doppia freccia (Beor: 0). | 2 spazi rossi in cima → carta "Estás enloqueciendo" (§7.9) |

- **Panico (Pánico)**: se Terrore > Salute (marcatore Terrore sopra la T). Effetti solo in Combattimento/Diplomazia (§6.9).
- Valore massimo delle tracce e posizione esatta delle zone rosse: dipendono dalla plancia `[DA VERIFICARE sulle 4 plance]`.
- Una perdita si applica sempre, anche se non hai abbastanza ("perdi 3 Energia" con 1 → 0). Un **costo** ("Paga") invece richiede di avere la risorsa (FAQ).

### 1.3 Risorse
Cibo (Comida), Ricchezza (Riqueza), Rep (Reputación), Esp (Exp), Magia. Nessun limite massimo nel gioco standard (`[DA VERIFICARE spazi sulla plancia]`). In Modalità Sfida: max 20 risorse (Esp esclusa).
- Scambiabili tra personaggi nello stesso Luogo, fuori da azioni/Incontri: **Cibo, Ricchezza** (+ Oggetti e Segreti non "Personal"). **Rep, Esp, Magia non si scambiano mai.**
- In compagnia un membro può spendere la propria Energia o Magia al posto di un altro (eccezione: Azione del Personaggio, §4.4).

### 1.4 Attributi (Atributos)
Tre coppie opposte; sulla plancia gli attributi sinistri (Aggressività, Coraggio, Praticità) stanno sul bordo sinistro (lato mazzo Combattimento), quelli destri (Empatia, Cautela, Spiritualità) sul bordo destro (lato mazzo Diplomazia), alla stessa riga del loro opposto:
- Aggressività (Agresividad) ↔ Empatia (Empatía)
- Coraggio (Audacia) ↔ Cautela (Cautela)
- Praticità (Lógica) ↔ Spiritualità (Espiritualidad)

Valore di un attributo = segnalini sulla plancia (punti 1–2) + **1 per ogni carta Abilità** associata (dal 3° punto in poi ogni punto è una carta Abilità). Esempio Beor iniziale: Aggr 2, Coraggio 1, Praticità 1, Cautela 1.
Perdere un punto di attributo → si rimuove prima la carta Abilità di quell'attributo (FAQ).

### 1.5 Miglioramenti con Esp (solo in Fine del Giorno, passo 3)
Il costo dipende dal **totale della coppia** dopo l'acquisto (cioè quale punto della coppia stai comprando):

| Punto n° della coppia | Costo standard | Costo Modalità Sfida |
|---|---|---|
| 1° | 2 Esp | 5 |
| 2° | 4 | 10 |
| 3° | 6 | 15 |
| 4° | 8 | 20 |
| 5° e successivi | 10 | 25, 30, … (+5 ogni punto) |

Formula standard: `costo = min(2 * (aggr + emp + 1), 10)` per la coppia interessata. Es.: Aggr 2, Emp 0 → Emp a 1 costa 6; Aggr 2, Emp 2 → Aggr a 3 costa 10.
- **Abilità**: quando un attributo sale a 3 o più, ogni punto è una carta Abilità di quell'attributo, piazzata accanto alla plancia; si sceglie UNA delle due facce e l'altra è persa per sempre. Le 72 Abilità sono uniche (condivise tra i giocatori). Non c'è costo aggiuntivo oltre al punto attributo. `[DA VERIFICARE: scelta libera fra le carte Abilità disponibili di quell'attributo]`.
- **Mazzi**: 2 Esp → pesca 3 carte dalla Riserva Avanzata (Combattimento o Diplomazia), tienine 1 (va nella tua collezione), rimetti le altre 2 e rimescola. (Sfida: 5 Esp, pesca 2 tieni 1.)

### 1.6 Mazzi del personaggio
Per ogni personaggio 80 carte: 25 base Combattimento + 25 base Diplomazia (colore della plancia, n° 1–25 + lettera A/V/M/G = Azul/Verde/Marrón/Gris) + 15 avanzate Combattimento + 15 avanzate Diplomazia con il nome del personaggio (n° 1–15).
- **Mazzo iniziale**: 15 Combattimento (base 1–15, stendardo del colore) a sinistra della plancia, 15 Diplomazia (base 1–15) a destra.
- **Riserva Avanzata** (per tipo): 15 avanzate col nome + 10 base restanti (16–25) mescolate = 25 carte.
- **Costruzione mazzo** (Fine del Giorno, passo 4): puoi aggiungere/togliere carte ottenute; **minimo 15 carte per mazzo**. Le carte tolte NON tornano in Riserva: restano nella collezione del personaggio.
- **Limite della mano**: esiste solo dentro un Incontro: a fine turno si scarta fino a **3** (§6). Fuori dagli Incontri non c'è mano.

### 1.7 Oggetti (Objetos) e slot
Numero di Oggetti posseduti illimitato (Sfida: max 5, Segreti esclusi), ma **attivo al massimo 1 per parola chiave**: Arma, Armadura, Escudo (Scudo), Compañero (Compagno), Reliquia. Gli altri restano coperti.
- Si sceglie quali tenere attivi all'Inizio del Giorno (passo 8) e solo quando si ottiene/perde un oggetto con quella parola chiave (FAQ: niente cambi a metà giornata).
- All'inizio di un Incontro si possono "accantonare" oggetti attivi; una volta iniziato, non si aggiungono oggetti.
- Oggetti con simbolo **F** = Fabbricabili. "Pesca un Oggetto Fabbricabile / di tipo X": scorri il mazzo Oggetti fino alla prima carta valida, prendila, rimescola le altre.
- Alcuni Oggetti si **girano (Voltear)** quando usati; tornano scoperti a fine Incontro.
- La carta "Te estás muriendo" limita il numero di Oggetti `[DA VERIFICARE testo]`; i Segreti non contano mai per i limiti di Oggetti.

---

## 2. Preparazione

### 2.1 Personaggio (per ogni giocatore)
1. Scegli personaggio: tessera + plancia dello stesso colore.
2. Energia e Terrore sugli spazi a doppia freccia rossa.
3. Marcatore a T della Salute sullo spazio a doppia freccia.
4. Attributi iniziali (retro tessera).
5. Risorse iniziali (retro tessera). Beor: 3 Cibo, 1 Ricchezza. Altri: `[DA VERIFICARE retro tessere]`.
6–8. Separa le 80 carte, forma i mazzi iniziali (15+15) e le due Riserve Avanzate (25+25).
9. Tessera sulla plancia, lato azione scoperto.
10. Leggi la missiva: contiene il **numero del personaggio** (spareggi: in caso di disaccordo agisce/decide il numero più basso) `[DA VERIFICARE numeri sulle missive]`.

### 2.2 Mondo
1. Luogo iniziale **101 (Cuanacht)** al centro; tutti i personaggi lì.
2. Menhir sul 101 con quadrante a: **8 (1 giocatore), 7 (2), 6 (3), 5 (4)**.
3. Rivela i 4 Luoghi collegati alle Chiavi di Direzione del 101: **102 (Arboleda del Cazador) sopra, 103 (Feria del Guerrero) sinistra, 104 (Cónclave Calcinado) destra, 105 (Espadas Olvidadas) sotto**.
4. Separa i 4 mazzi Incontro per colore (serviranno al passo 9).
5. Mazzo Segreti (ordinato per numero, non mescolato) e mazzo Oggetti (mescolato). Eventi Casuali: mescolati, mazzo a parte.
6. Nuovo Foglio di gioco.
7. Carte d'aiuto.
8. (Opz.) Narratore.
9. **Preparación del Capítulo 1**: trova la carta tra gli Eventi e segui istruzioni (fronte poi retro):
   - Mazzo Eventi: prendi tutte le Parti del Capitolo 1, impilate dalla **6 (in fondo) alla 1 (in cima)**.
   - Il retro indica la composizione dei mazzi Incontro del capitolo (quali carte per livello) `[DA VERIFICARE: testo del retro della carta "Preparación del Capítulo 1"]`.
10. Inizia il Giorno 1 (con la fase di Inizio del Giorno).

- Si pesca SEMPRE dal mazzo Eventi, mai direttamente dagli Eventi Casuali: sono gli Eventi stessi a dire di mettere N Eventi Casuali in cima al mazzo Eventi.
- Se un Evento/Diario chiede di risolvere una Parte specifica, prendila dal mazzo senza alterare l'ordine del resto.
- Il mazzo Eventi ha una pila degli scarti (serve a contare il tempo); correttamente gestito non si esaurisce mai (FAQ).

---

## 3. Struttura del Giorno (Orden del Día)

Ciclo: **I Inizio del Giorno → II Durante il Giorno → III Fine del Giorno → I …**

### 3.1 I) Inizio del Giorno (Comienzo del Día) — in quest'ordine
1. **Rimuovi i Menhir inattivi**: un Menhir senza quadrante si spegne ora e viene rimosso. I restanti = "Menhir attivi".
2. **Rimuovi i Luoghi fuori raggio**: ogni Luogo deve essere adiacente (ortogonale **o diagonale**, raggio = 1 carta) a un Luogo con Menhir attivo; altrimenti si scarta.
   - Personaggi su un Luogo rimosso: **−2 Salute, +2 Terrore**, si spostano al Luogo più vicino (pari distanza → numero più basso). Non è un Viaggio.
   - Se **sparisce l'ultimo Menhir** della mappa: NON si rimuovono i Luoghi; ma a ogni Inizio del Giorno ogni personaggio **−2 Salute, +2 Terrore** finché muoiono o attivano un Menhir.
3. **Abbassa di 1 il quadrante di ogni Menhir**. Se era già a 1 → togli il quadrante (il Menhir resta in piedi e si spegnerà al passo 1 del giorno seguente).
   - Il valore del quadrante ≈ giorni di vita (8 = "si spegne in 8 Giorni"). Il raggio è **sempre 1 carta**, non dipende dal valore del quadrante.
4. **Abbassa i quadranti Tempo e rimuovi i gettoni Tempo**: ogni quadrante con gettone Tempo (su Segreti, accanto a personaggi, ecc.) −1; se non può scendere (era a 1) si rimuove. Rimuovi i gettoni Tempo dai Luoghi (quelli che marcano azioni "una volta al Giorno"). I **quadranti con gettone Missione non scendono** e i gettoni Missione sui Luoghi restano.
   - Ambiguità: p.8 "rimuovi i gettoni Tempo dalle carte Luogo"; riassunto p.24 "rimuovi 1 gettone Tempo da ogni Luogo che ne ha" `[DA VERIFICARE: usare "−1 per Luogo"; alcuni Luoghi hanno regole proprie sui gettoni]`.
5. **Rivela e leggi un Evento**. Se ha testo di Missione e lucchetto rosso → va nell'area Missioni attive. Gli Eventi normali valgono 1 Giorno; quelli con Missione restano finché la carta non dice altrimenti.
6. **Muovi i Guardiani** (dado per ogni Guardiano, §7.6). Anche il "Cazador Primer Morador" (Segreto 13) si muove qui (FAQ).
7. Discussione dei piani (cooperativo).
8. **Equipaggiamento**: max 1 Oggetto/Segreto attivo per parola chiave, il resto coperto.

### 3.2 II) Durante il Giorno
- A turno ogni giocatore fa **1 azione**, in ordine libero (disaccordo: numero personaggio più basso, poi crescente). Quando tutti hanno fatto 1 azione (o passato), si ricomincia.
- Unirsi all'azione di un altro (stesso Luogo) non conta come propria azione (FAQ). I giocatori possono concordare che un personaggio faccia 2 azioni consecutive (FAQ).
- Termina quando tutti hanno **Passato** o non hanno più Energia → Fine del Giorno.

### 3.3 III) Fine del Giorno (per ogni personaggio)
1. **Riposo (Descansa)**: mangia 1 Cibo → **+1 Salute, −1 Terrore**. Se non mangi (non hai o non vuoi): **Energia → 0**; se l'Energia era già 0 → **−1 Salute**.
2. **Recupera l'Energia**: riporta il marcatore allo spazio iniziale; **se sei Esausto** (Energia negli spazi rossi) recuperi **solo +4**. Sempre Energia ≤ Salute. (Quindi chi non mangia, a 0, recupera solo 4.)
3. **Migliora il personaggio** (spendi Esp, §1.5).
4. **Costruisci i mazzi** (min 15).
5. **Sogna**: se il Luogo ha il sigillo Sogno → leggi il Sogno nel Diario; se hai "Estás enloqueciendo" (Terrore negli spazi rossi) → leggi l'Incubo. Sogno/Incubo si risolve una sola volta e si applica a tutti i personaggi presenti che soddisfano i requisiti.
Poi nuovo Giorno.

---

## 4. Azioni (durante il Giorno)

Ogni azione è indicata da un'icona con il costo X in Energia (alcune costano Salute o Terrore). Personaggi nello stesso Luogo possono unirsi formando una **Compagnia (Equipo)**: solo prima che l'azione inizi; tutti devono approvare; chi non può pagare il costo deve uscire. Si lascia la compagnia durante Combattimento/Diplomazia solo Scappando o per "Te estás muriendo".

| Azione | Costo | Regole | In Compagnia |
|---|---|---|---|
| **Viaggiare (Viajar)** | 1 Energia | Muovi su un Luogo **collegato** (Chiavi di Direzione corrispondenti sui lati adiacenti); solo ortogonale, mai in diagonale. Lati adiacenti senza Chiavi = bloccato. All'arrivo: procedura §4.1. | 1 Energia **per membro**; azioni automatiche e Guardiani si risolvono in compagnia |
| **Esplorare (Explorar)** | 1 Energia | Gira il Luogo attuale, leggi il retro / Diario fino a "La Exploración finaliza" (o fine del verso senza scelte, FAQ). Nessun limite giornaliero nelle regole. | 1 Energia **per membro**; ricompense statiche condivise (da assegnare), quelle "cada miembro" scalano |
| **Azione del Luogo** | indicato sulla carta | Eseguibile se sei nel Luogo. Alcune "una volta al Giorno" (marca con gettone Tempo). | Costo pagato **una volta** (diviso a piacere), risultato **una volta**; Incontro generato risolto in compagnia |
| **Azione del Personaggio** | varia (tessera) | Solo fuori da Incontri ed Esplorazione. | Solo il proprietario la usa; altri possono aiutare a pagare ma lui paga **almeno 1 Energia** |
| **Ispezionare un Menhir** | gratis | Solo Luoghi col sigillo Menhir: leggi la sezione Menhir sul retro (o nel Diario). Se soddisfi i requisiti puoi **attivarlo subito** (§7.7). | |
| **Passare (Pasar)** | 0 | Termina la tua giornata, irreversibile anche con Energia residua. | |
| Altre | — | Azioni su Oggetti, Abilità, Segreti, plancia. | |

- **Riposo** non è un'azione: avviene in Fine del Giorno.
- **Commercio negli Insediamenti**: le regole non definiscono un'azione generica di commercio; acquisti/vendite avvengono tramite Azioni del Luogo o voci del Diario. Alcune azioni sono possibili solo negli Insediamenti, altre solo fuori.

### 4.1 Arrivo in un nuovo Luogo (dopo Viaggio o Movimento speciale)
1. **Rivela nuovi Luoghi**: per ogni Chiave di Direzione sui bordi del nuovo Luogo che punta a uno spazio vuoto, piazza il Luogo con quel numero **solo se** quella posizione è entro 1 carta (anche diagonale) da un Menhir attivo. Se il Luogo con quel numero non esiste più, cerca il Luogo che ha quel numero come **"numero antico"** (es. Chiave 108 → Luogo 110 con antico 108).
2. **Regole immediate (fulmine ⚡)**: risolvile subito, prima di qualsiasi altra azione di altri giocatori. **Se c'è un Guardiano**, l'Incontro col Guardiano viene **prima** della regola ⚡.
- Sigilli del Luogo (fino a 3 accanto al nome): **Menhir**, **Sogno**, **Insediamento nemico** (Incontro all'ingresso, di solito Diplomazia; regole sulla carta), **Insediamento amico**.
- **Movimento speciale** ("vai al Luogo rivelato con numero più basso", "a qualsiasi Luogo collegato"): non è Viaggio, non costa Energia, immediato, ma rivela Luoghi e attiva ⚡ e Guardiani. Gli effetti di movimento del Diario muovono tutta la compagnia (FAQ).
- Dopo l'attivazione di un Menhir: i Luoghi con personaggi che hanno Chiavi verso Luoghi non rivelati ora in raggio li rivelano subito.

---

## 5. Incontri (Encuentros)

### 5.1 Mazzi
| Colore | Contenuto | Tipo |
|---|---|---|
| Verde | natura, bestie; spesso danno Cibo | Combattimento |
| Grigio | uomini, banditi, cavalieri; spesso Oggetti/Ricchezza | Combattimento |
| Viola | soprannaturale | Combattimento |
| Blu | sociale, Insediamenti nemici, sfide personali | Diplomazia |

Daltonici: tacca sul retro — basso-sx grigio, basso-dx verde, alto-dx viola, alto-sx blu. 4 livelli di difficoltà (indicati sulla carta); la composizione per capitolo è data dalle carte "Preparación del Capítulo" (a ogni nuovo capitolo si tolgono le facili e si aggiungono le difficili).
- "Pesca un Incontro [colore]" = carta in cima a quel mazzo. Scartare = **in fondo al mazzo** (vale per Luoghi, Eventi Casuali, Incontri, Segreti, Oggetti; solo gli Eventi hanno pila scarti). "Rimuovere dal gioco" = nella scatola, fuori campagna.
- È **Combattimento** se la carta è grigia/verde/viola e ha ≥1 Chiave sul lato destro; **Diplomazia** se è blu con ≥1 Chiave aperta a destra. (Senza Chiavi: carta da risolvere col solo testo `[DA VERIFICARE se esistono]`.)

### 5.2 Anatomia carta Incontro di Combattimento
1 Difficoltà · 2 icona Guardiano · 3 **Valore** (segnalini in Riserva per vincere) · 4 Nome · 5 Testo · 6 **Tratti** · 7 **Tabella di Combattimento** (fasce di n° segnalini in Riserva → attacco) · 8 **Opportunità** (attacco di opportunità) · 9 **Ricompensa e Bottino** · 10 **Chiavi di Attributo** sul bordo destro (+ chiave inferiore, es. "1x" o "✖").
- Esempi reali: *Vagabundo* — Valore 5, Rápido; 0–1: 1 Ferita; 2–3: 2 Ferite + perdi 1 segnalino; 4: Huir; Opportunità: Huir; Bottino: 1 Oggetto Fabbricabile. *Acólita Arquera* — Valore 8, Guardián + Emboscada; 0–4: 3 Ferite; 5–6: 1 Ferita + perdi 1 segnalino; 7: perdi 2 segnalini; Opportunità: 1 Ferita (inevitabile); Bottino: 1 Ricchezza.
- **Ricompensa** = a ogni membro; **Bottino** = da dividere fra i membri.
- Tabelle possono contenere effetti alternativi ("2 Ferite o scarta 1 Oggetto").

### 5.3 Tratti del nemico (Rasgos) — Combattimento
| Tratto (ES) | Effetto |
|---|---|
| **Emboscada** (Imboscata) | Il 1° personaggio attivato nel combattimento, subito dopo l'attivazione, scarta fino ad avere 1 carta in mano |
| **Repentino** (Improvviso) | Il 1° personaggio attivato subisce subito 2 Ferite |
| **Defensivo** | La prima carta giocata nel passo 2 di ogni attivazione aggiunge 1 segnalino in meno alla Riserva |
| **Rápido** | Max 2 carte giocate per attivazione |
| **Finta** | Le Ferite del passo 3 (attacco) non si possono prevenire |
| **Guardián** | Se non sconfitto resta sulla mappa (§7.6) |
| **Horda** (Orda) | Nel passo 3 il personaggio attivo scarta le 2 carte in cima al suo mazzo Combattimento |
| **Oportunista** | Se un personaggio gioca meno di 2 carte nel passo 2 → attacco di opportunità |
| **Furia** | Il passo 3 (attacco) si risolve due volte |
| **Ladrón** (Ladro) | Se TUTTI i membri scendono a Salute ≤1 durante l'Incontro: perdono tutta la Ricchezza e scartano tutti gli Oggetti; l'Incontro finisce, carta in fondo al mazzo |
| **Destrucción** | A fine Incontro tutti i membri scartano gli Oggetti (non Segreti) "Arma" usati |
| **Lento** | All'inizio ogni membro pesca 1 carta in più; in Fine del turno ogni giocatore pesca 1 carta in più |

- **"Inevitabile" (inevitable)** (es. Opportunità "1 Ferita (inevitable)"): non definito nel regolamento; interpretazione coerente con Finta = non prevenibile `[DA VERIFICARE]`.
- Alcuni tratti si applicano già alla fase di inizio (es. Lento), quindi vanno controllati all'avvio.

### 5.4 Diplomazia: anatomia carta Incontro blu
1 Nome · 2 Testo · 3 **Misuratore di Affinità** (bordo sinistro: spazi verdi sopra, **spazio grigio** = partenza, spazi rossi sotto; alcune Capacità controllano se il marcatore è su verde/rosso) · 4 Difficoltà · 5 **Evitare** (costo/requisiti) · 6 Chiavi di Attributo · 7 **Fasi (Etapas)** · 8 **Tabella di Diplomazia** (per ogni fase: regola del bonus speciale per attributo + **Risposta**, colonna col teschio) · 9 **Fallimento (Fracaso)** · 10 **Ricompensa** (a ogni membro, non si divide).
- Es. *Toque de queda*: fase "Engaña a los guardias": bonus speciale collegato a Chiave Spiritualità → ↑, a Chiave Empatia → ↑; Risposta ↓↓. Ricompensa: +1 Energia. Fallimento: −2 Energia e risolvi l'Incontro grigio "Guerrero del Clan". Evitare: paga 2 Energia.
- Numero di spazi del misuratore: per carta `[DA VERIFICARE]`.

---

## 6. Motore di COMBATTIMENTO e DIPLOMAZIA

### 6.1 Geometria delle carte e delle Chiavi
- Le carte Combattimento/Diplomazia hanno sul **bordo sinistro una colonna di Chiavi** divise in due semichiavi:
  - **metà sinistra "<" = Chiave di Bonus**: mostra il bonus che QUESTA carta ottiene se la chiave si connette alla carta precedente;
  - **metà destra ">" = requisito/apertura per la carta successiva**: icona di Attributo, icona Magia (Chiave Magica), o moltiplicatore (riga inferiore, es. "1x", "2x", "✖").
- Le Chiavi sono a **righe fisse** (circa 4 righe superiori + 1 riga inferiore `[DA VERIFICARE numero righe]`). Due Chiavi si connettono solo se le due metà sono **nella stessa riga** e combaciano fisicamente.
- La **Sequenza** è una fila orizzontale: ogni nuova carta viene sovrapposta alla precedente coprendone illustrazione e testo, lasciando visibile solo la colonna delle chiavi. Le chiavi inferiori si uniscono sempre; nessuna chiave è nascosta.
- **Capacità attiva solo se visibile**: in pratica solo l'ultima carta della Sequenza (+ le **carte passive**, che hanno le Chiavi su lati opposti e non vengono mai coperte).
- La carta Incontro è la "carta 0": la prima carta del combattimento si aggancia alle Chiavi del suo bordo destro.

### 6.2 Tipi di Chiave (connessione)
| Chiave | Condizione di connessione |
|---|---|
| **di Attributo** (cornice scura) | semichiave Attributo X sulla carta precedente + semichiave Bonus sulla nuova; **il personaggio ATTIVO deve avere il livello richiesto in X** (livello stampato `[DA VERIFICARE: icona = livello ≥1, eventuali livelli 2+]`) |
| **Magica** (cornice blu) | entrambe le metà magiche + **pagare 1 Magia** (opzionale; un altro membro può pagare). Il punto Magia si posa sulla chiave; se la carta viene scartata, quel punto è scartato |
| **senza costo** (inferiore, dorata) | si connette **sempre**; bonus = icona sulla nuova carta × moltiplicatore della metà destra della carta precedente ("1x","2x"; "✖" annulla) |

### 6.3 Bonus (icone)
**Combattimento**: 1/2/3 segnalini → aggiungi 1/2/3 alla Riserva di Combattimento · carta verde → pesca 1 · **carta dorata (catena) → abilita una carta aggiuntiva** · carta rossa → scarta l'ultima carta della tua Sequenza · **2x** moltiplica l'icona seguente · **✖** annulla l'icona seguente.
**Diplomazia**: **↑/↓** muovi il marcatore di Affinità · **triquetra = bonus speciale**: guarda la regola della fase attuale per l'Attributo della chiave connessa (se la fase non nomina quell'attributo → nulla) · pesca · carta dorata (aggiuntiva) · scarta ultima carta · 2x · ✖.
- La carta dorata (aggiuntiva) **non si moltiplica** (se accanto a un moltiplicatore, ignoralo) e va **ignorata sulla prima carta** dell'attivazione. L'icona dorata deve stare sulla carta che vuoi giocare (non sulla precedente).
- Icone di Capacità: **Ferite** (perdi Salute); **"Chiave di Attributo fisicamente unita"** = conta le chiavi di quell'attributo fisicamente unite in tutta la Sequenza (non serve che siano connesse).

### 6.4 Trigger delle Capacità
| Icona | Combattimento | Diplomazia |
|---|---|---|
| ⬇ **Al piazzarla** | si risolve dopo aver piazzato la carta; **DOPO i bonus delle Chiavi** (FAQ) | idem |
| ⌛ **Ritardata** | metti 1 gettone Tempo sulla carta; si risolve quando viene tolto l'ultimo gettone (passo 1 di un'attivazione successiva); una sola volta; se la carta viene coperta prima, il gettone si scarta e non si risolve | idem |
| 💀 **Durante l'attacco nemico / Risposta** | attiva nel passo 3, modifica l'attacco | modifica la Risposta |
| Passiva | sempre visibile e attiva | idem |

- **Cariche (Cargas)**: segnalini posti sulla carta; "Paga X Cariche" usabile in qualsiasi momento salvo diverso testo. In compagnia: solo il personaggio attivo può usarle, col consenso del proprietario della carta. Uso su carte coperte `[DA VERIFICARE]`. FAQ: effetti "raddoppia" di una carta non si cumulano spendendo più cariche.
- Effetti simultanei: il giocatore sceglie l'ordine (FAQ; es. due prevenzioni si sommano nell'ordine più favorevole: Armatura improvvisata "Previeni 1 (non può ridurre a 0)" + Grito de guerra "−1" → 0).

### 6.5 Inizio dell'Incontro (entrambi i tipi)
1. Pesca l'Incontro, piazzalo con spazio a destra.
2. Controlla i Tratti (alcuni agiscono subito).
3. **Equipaggiamento**: ogni membro verifica 1 Oggetto per parola chiave; può accantonare Oggetti (non aggiungibili dopo).
4. **Mano iniziale**: ogni membro pesca dal proprio mazzo **3 carte (1–3 personaggi) o 2 (4 personaggi)** (+1 se Lento).
5. **Mulligan**: si può scartare la mano e ripescarne una con 1 carta in meno, ripetibile fino a 1 carta.
6. Diplomazia: marcatore sullo **spazio grigio** dell'Affinità; se ci sono più opzioni/vie scegli.
7. Fase I del turno.
- **Diplomazia — Evitare**: solo PRIMA di iniziare, se la carta ha "Evitar": paga costi/requisiti, carta in fondo al mazzo blu, l'Incontro non avviene. In compagnia: si verifica la Rep o l'attributo **più alto** di un membro (non si sommano); costi di Evitare/Fallimento si applicano a **ogni** membro.

### 6.6 Turno di Combattimento
**I. Scegli il personaggio attivo** tra chi non ha un gettone Tempo sulla plancia (disaccordo → numero più basso). Metti un gettone Tempo sulla sua plancia. Tutti gli effetti dell'attivazione (Ferite, segnalini, penalità) colpiscono **solo il personaggio attivo**.

**II. Attivazione**
1. **Capacità ritardate**: togli 1 gettone Tempo da ogni carta della Sequenza (si fa a ogni attivazione, quindi con più personaggi i gettoni calano per attivazione); se era l'ultimo, risolvi la Capacità. Ordine: da sinistra a destra.
2. **Gioca carte**:
   - a) **Prima carta**: qualsiasi carta dalla mano (se in **Panico**: obbligatoriamente la carta in cima al mazzo). Nessun requisito di chiave; allineata alla precedente. Poi: applica bonus delle Chiavi di Attributo connesse → Chiavi Magiche (pagando) → Chiave inferiore (sempre) → Capacità "al piazzarla"/metti gettone se ritardata. (Defensivo: −1 segnalino su questa prima carta.)
   - b) **Carte aggiuntive** (dalla mano): ciascuna DEVE connettere una chiave con il bonus "carta dorata" (anche tramite Chiave Magica pagata). Altrimenti non puoi giocarne altre. Si risolvono come sopra. Rápido: max 2 carte totali per attivazione.
   - c) **Opportunità**: se non hai giocato nessuna carta → il nemico esegue l'**attacco di opportunità**, poi **peschi 1 carta**. (Oportunista: se <2 carte.)
   - d) **Verifica vittoria**: segnalini in Riserva **≥ Valore** → vittoria (§6.8).
3. **Attacco nemico**: trova nella Tabella la riga corrispondente al n° di segnalini in Riserva e applicalo al personaggio attivo (applica Capacità 💀 visibili, prevenzioni, Finta, Horda; Furia = due volte). Se l'attacco toglie segnalini e non bastano → **Riserva negativa** (§6.9). Poi **verifica vittoria**.
4. **Verifica attivazioni**: se qualcuno non si è ancora attivato → torna a I; altrimenti III.

**III. Fine del turno**
1. **Scarta** fino a 3 carte in mano.
2. **Pesca** 1 carta ciascuno (non chi è in Panico; Lento +1). Mazzo insufficiente → **obbligato a Scappare**.
3. **Resetta le attivazioni**: togli i gettoni Tempo dalle plance (non quelli sulle carte).
4. Nuovo turno (I).

### 6.7 Turno di Diplomazia
Identico al Combattimento con queste differenze:
- Passo 2: dopo le carte, c) **Verifica Affinità** (non c'è attacco di opportunità; giocare 0 carte non ha penalità propria `[DA VERIFICARE]`).
- Passo 3: **Risposta dell'avversario**: applica la Risposta della **fase attuale** al personaggio attivo (es. ↓↓, perdi Energia/Ricchezza, distruggi l'ultima carta della Sequenza), poi **Verifica Affinità**.
- Fine turno: scarta a 3, pesca 1 (non in Panico), **resetta le attivazioni** (passo omesso per errore a p.19, corretto dalla FAQ).
- Mazzo Diplomazia insufficiente quando devi pescare → **Fallimento** dell'Incontro.

**Verifica Affinità**
- Marcatore sullo spazio **più alto** → vinci la fase. Se era l'ultima fase → vinci l'Incontro (Ricompensa a ogni membro, carta in fondo al mazzo, rimescola il mazzo Diplomazia con carte giocate e scartate). Altrimenti: marcatore di nuovo sul **grigio**, segnalino sulla fase completata, e vai direttamente al passo 4 (**niente Risposta** in quell'attivazione, vedi esempio p.21). Alcuni Incontri hanno 2 vie alternative o 2–3 fasi da vincere di seguito.
- Marcatore sullo spazio **più basso** → **Fallimento**: applica "Fracaso" a ogni membro, carta in fondo al mazzo, rimescola.
- "Temptaciones": nessuna condizione speciale; si continua a perdere ad ogni Risposta finché si vince, si scappa o qualcuno esaurisce il mazzo (FAQ).

### 6.8 Fine del Combattimento
- **Vittoria**: Riserva ≥ Valore (controllata in 2d e dopo il passo 3). Ricompensa a ogni membro, Bottino da dividere; carta in fondo al suo mazzo; ogni mazzo Combattimento si rimescola con carte giocate e scartate.
- **Scappare (Escapar)**: in qualsiasi momento **durante la tua attivazione**: −1 Energia, provochi l'attacco di opportunità; poi carta Incontro in fondo al mazzo e rimescoli il tuo mazzo. In compagnia: solo chi scappa esce (subisce l'opportunità), gli altri restano e si va al passo 4; se tutti scappano la carta va in fondo al mazzo. Guardiano non sconfitto → resta sulla mappa.
  - Modalità Sfida: max 1 tentativo per attivazione; −1 Energia, attacco di opportunità, poi lancia il quadrante: **Teschio** = resti nel combattimento; **Graal** = scappi.
- **Il nemico Fugge (Huir)** (risultato di tabella/opportunità): Incontro finito, carta in fondo, **nessun bottino né ricompensa**, non conta come vittoria.
- **"Te estás muriendo"** (Salute 0): il personaggio esce subito dall'Incontro (Scappa) e applica la carta.
- **Ladrón**: vedi tratti.
- **Diplomazia — Scappare**: la compagnia può sempre Scappare: si applica il **Fracaso** a tutti i membri.
- Dopo ogni Incontro: tutte le carte giocate/scartate/distrutte tornano nel mazzo che si rimescola; gli Oggetti girati tornano scoperti.

### 6.9 Regole speciali
- **Panico** (Terrore > Salute): la prima carta del passo 2 è la carta in cima al mazzo (non dalla mano); poi carte aggiuntive dalla mano normalmente; **non peschi** la carta di Fine turno (ma peschi quelle da bonus/Abilità/Capacità).
- **Riserva negativa**: la Riserva non va mai sotto 0; per ogni punto in eccesso il personaggio attivo scarta 1 carta dalla mano (mano vuota → carta in cima al mazzo). Es.: Riserva 2, 1 carta in mano, perdi 4 → Riserva 0, scarta la carta in mano e la cima del mazzo.
- **Scartare a mano vuota**: scarta la carta in cima al mazzo.
- **Combattimento a più personaggi**: Sequenza e Riserva comuni; ogni personaggio si attiva una volta per turno; l'attacco colpisce l'attivo; i requisiti di Attributo delle chiavi sono quelli dell'attivo; un altro membro può pagare la Magia; la Ricompensa vale per tutti, il Bottino si divide. Mano iniziale 2 carte se 4 personaggi.
- **Graal/Teschio**: risultato del lancio del quadrante come moneta (es. Oggetto: "quando ti attivi in Combattimento puoi ottenere 1 segnalino e poi lanciare un quadrante: Graal nulla, Teschio scarta questo Oggetto"; Carta "Métodos extraños": "Lancia un quadrante: Teschio −1 Rep, Graal nulla").

---

## 7. Progressione, mondo e stati speciali

### 7.1 Esp e carte Avanzate — vedi §1.5–1.6.

### 7.2 Segreti (Secretos)
Carte numerate legate alla storia (oggetti unici, poteri, regole). Non fanno parte del mazzo Oggetti, non si perdono né vendono salvo istruzione, non contano nei limiti di Oggetti. "Scarta un Oggetto" non colpisce mai un Segreto (anche se ha parola chiave da Oggetto). Scambiabili nello stesso Luogo fuori dalle azioni, tranne quelli **"Personal"**. Non vanno mai rimossi dalla campagna salvo istruzione esplicita. Possono contenere Missioni o quadranti.

### 7.3 Status (Estados) e Foglio di gioco
Gli status sono globali (se marcato, vale per tutti). Alcuni hanno parti numerate; alcuni hanno trigger ("quando hai 6 parti qualsiasi → LdlS verso 525"). Elenco del Foglio La Caída de Ávalon (N = parti numerate; □n = n caselle senza numero; ✓ = singola casella):
Abandonado 9 · Abasteciendo la revuelta □4 · Aliados de Ávalon 5 · Algo te observa □4 (4 parti → Evento speciale C) · Ayudando a los caballeros □4 · Caído y perdido 7 · Caldero negro 3 · Campeón del pueblo ✓ · Canción de luto 2 · Conocimiento calcinado ✓ · Conocimiento de Raízespesa 2 · Cosuil 5 · Diplomático 3 · Direcciones generales ✓ · El declive de los caballeros 8 (6 parti qualsiasi → verso 525) · El destino de la expedición 9 (parti 1–8 → verso 405) · El enigma del viejoacero ✓ · El legado de Fael ✓ · El secreto del escultor ✓ · El sucesor de Geraint 3 · El último refugio 5 · Encuentros afortunados 5 · Encuentros extraños 8 · Enemigos de Ávalon 3 · Enfrentamientos finales 7 · Exploración de Tuathán 5 · Explorador 8 · Factor decisivo ✓ · Fin del camino ✓ · Gorrón ✓ · Guerra por Ávalon 4 · Incremento 3 · Información perturbadora 3 · Invitado de honor ✓ · La conspiración de Mediocamino 3 · La marca del cazador ✓ · La redención de Gusano ✓ · La tarea de la dama ✓ · La tarea de Morgana ✓ · Las Cuevas Verdes 5 · Lección final 5 · Llamada desde el más allá ✓ · Mano amiga 6 · Matricida ✓ · Menhir itinerante 2 · Misión Anillo de Luna ✓ · Misión diplomática 6 · Misterio insondable 9 · Misterio resuelto ✓ · Monasterio descubierto ✓ · Paz en el distrito ✓ · Pertenencias preciadas ✓ · Pira fría ✓ · Pistas de Cabolejano 5 · Rastreador ✓ · Reconquista ✓ · Redención □5 · Refugio en la tormenta ✓ · Remedio 4 · Restaurando la Orden 8 (6 parti qualsiasi → verso 512) · Ritual del valle 2 · Salvado por la Diosa ✓ · Santuario seguro ✓ · Saqueador 5 · Secretos del bosque 4 · Sueños y profecías 8 · Tesoros ocultos 8 · Un profundo secreto ✓ · Vestigios 5 · Vientos de Rareza ✓. Più l'elenco "Localizaciones retiradas".

### 7.4 Eventi, Missioni, Compiti
- Carta Evento: Titolo, Capitolo e Parte, storia, Missione (lucchetto), Indizio. Missioni anche su Segreti. Le Missioni attive non si rimuovono mai salvo istruzione. Esempio Cap.1: Missione "ottieni il Segreto «Rituales de Menhir» (11)"; Successo: risolvi "Capítulo 1: Parte 5" e scarta questa carta.
- Compiti (Tareas): missioni secondarie del Diario, non legate al capitolo; il programma dovrebbe registrarli (log note).
- **Gettoni/quadranti Missione** non calano all'Inizio del Giorno.

### 7.5 Insediamenti
Sigilli: **Insediamento nemico** → Incontro all'ingresso (di solito Diplomazia, regole sulla carta); **Insediamento amico**. Il commercio è gestito da Azioni del Luogo/Diario (nessuna regola generica). Alcune carte reagiscono al Riposo in Insediamento (es. "Limosna: ogni volta che Riposi in un Insediamento ottieni 1 Cibo").

### 7.6 Guardiani (Guardián)
- Incontri col tratto Guardián. Se fallisci (Scappi) un Incontro Guardiano, la sua carta resta sul Luogo dove è avvenuto (in compagnia: se tutti scappano).
- **Entrare** in un Luogo con Guardiano → Incontro immediato (più Guardiani: si sceglie l'ordine), prima delle regole ⚡.
- **Inizio del Giorno passo 6**: per ogni Guardiano lancia il **dado Guardiano**: (1) **direzione cardinale** → muovilo in quella direzione; (2) **nulla** → resta; (3) **scarto** → rimuovilo, carta in fondo al suo mazzo. Distribuzione delle facce `[DA VERIFICARE]`.
  - Se la direzione porta a un Luogo non rivelato o non collegato → muovilo al Luogo **collegato con numero più alto**.
  - Se resta dove ci sono personaggi, o entra in un Luogo con personaggi → Incontro immediato (tutti i presenti combattono insieme).
- Sconfitto → carta in fondo al mazzo. Max 2 Guardiani tracciati sul Foglio.

### 7.7 Menhir
- Raggio: Luoghi adiacenti ortogonali o diagonali (1 carta) a un Menhir attivo. Si possono rivelare/esplorare solo Luoghi in raggio.
- **Attivazione**: solo in Luoghi col sigillo Menhir, tramite l'azione sul retro del Luogo (anche nel Diario); costi e preparazione del quadrante nel testo (es. "metti il quadrante su 8 (−1 per ogni giocatore della partida)"). I costi scalano col **numero totale di giocatori della partita**, non della compagnia. Attivare richiede di solito risorse di tutti.
- **Riattivazione** di un Menhir già attivo: aumenta la durata; il "potere" residuo del quadrante si perde (si reimposta); non si aggiunge una seconda miniatura.
- **Max 3 Menhir attivi**: per attivarne un 4° si prende la miniatura da un altro Luogo a scelta (FAQ).
- Dopo l'attivazione: rivela subito i Luoghi non rivelati ora in raggio collegati a Luoghi con personaggi.

### 7.8 Morte — "Te estás muriendo"
- Salute a 0 → carta "Te estás muriendo" accanto alla plancia, il personaggio **esce subito da qualsiasi Incontro** (Scappa) e applica le regole della carta. Ogni azione potrebbe essere l'ultima; se non ti curi muori. Testo esatto (solitario più permissivo, 4 cooperative): `[DA VERIFICARE testo carte]`.
- **Solitario**: morte = fine partita.
- **Cooperativo**: la partita continua. Segreti del morto distribuiti agli altri a scelta del suo giocatore (tranne "Personal", che spariscono); Oggetti lasciati nel Luogo (raccoglibili finché il Luogo esiste); risorse nella scatola. Se resta un personaggio nella scatola, il giocatore può prenderlo: preparazione iniziale, miniatura sul **Luogo rivelato col numero più basso**. Se quando un personaggio muore tutti gli altri sono già in uso o morti → **la partita fallisce** per tutti.
- **Misericordia della Madre di Tutti**: se tutti muoiono e non volete ricominciare: marca "Salvado por la Diosa", vai al verso 500 del Libro dei Segreti (riporta all'inizio del capitolo con risorse predefinite). Non disponibile in Modalità Sfida.

### 7.9 Follia — "Estás enloqueciendo"
Terrore negli spazi rossi superiori → carta "Estás enloqueciendo": abilita gli **Incubi** al posto dei Sogni e rende più difficili/rischiosi Esplorare e Viaggiare (testo esatto `[DA VERIFICARE carta]`). Terrore > Salute → Panico negli Incontri.

### 7.10 Fine capitolo / partita
- Un capitolo si completa tramite le Missioni (Evento/Diario/Libro dei Segreti). Poi si segue la "Preparación del Capítulo" successiva (nuovi Eventi, mazzi Incontro più difficili). La campagna termina con la conclusione della storia.
- Fallimento: morte in solitario, o condizione cooperativa di §7.8 (salvo Misericordia).

### 7.11 Salvataggio fra sessioni (Foglio di gioco)
Consigliato salvare solo a fine capitolo (rischio di rinnovare azioni "una volta al Giorno").
**Per personaggio** (diagramma sul Foglio): nome, Luogo, quadrante (eventuale), valori dei 6 attributi + **numeri unici delle Abilità** accanto all'attributo, Energia/Salute/Terrore, Cibo, Ricchezza, Rep, Esp, Magia; Oggetti e Segreti nello scomparto di salvataggio; mazzi Combattimento+Diplomazia uniti con divisori + Riserve Avanzate (e carte fuori mazzo).
**Mondo**: Luoghi delle miniature (personaggi, Guardiani, Menhir) e valori dei quadranti (Menhir 1–3: Luogo+valore; quadranti Missione 1–2: Luogo+valore; Guardiani 1–2: Luogo); note (quadranti dei Segreti, Compiti); Luoghi rivelati (pila con divisore) e non rivelati; Luoghi rimossi a parte; 4 mazzi Incontro (ordine); mazzo Eventi + Missioni attive; status marcati.
- Ripresa: processo inverso. Ad ogni sessione si possono aggiungere/rimuovere giocatori (1–4): i nuovi partono con risorse e mazzi iniziali nel Luogo di un veterano; i Segreti dei rimossi vanno redistribuiti.

### 7.12 Modalità alternative
- **Storia**: preparazione e Eventi scalabili come se ci fosse un membro in meno (es. 3 giocatori: quadrante 6 invece di 5). In solitario si può togliere la T: Salute non limita l'Energia, niente Panico (FAQ: valido per ogni numero di giocatori).
- **Sfida**: T capovolta (`[DA VERIFICARE effetto esatto: più Panico/limitazione Energia]`); inizi con il Segreto 42; Menhir durano 1 Giorno in meno; quando piazzi Eventi Casuali piazzane 1 in meno; costi Esp maggiorati; max 20 risorse e 5 Oggetti; Scappare con lancio del quadrante; niente Misericordia.
- **Gioco libero**: tessera su qualsiasi plancia, colore dei mazzi a scelta.

---

## 8. Cosa deve automatizzare il programma

### 8.1 Macchina a stati proposta

```
GAME
 ├─ SETUP_CAMPAIGN → SETUP_CHAPTER(n)
 └─ DAY_LOOP
     ├─ START_OF_DAY
     │    S1 remove_inactive_menhirs
     │    S2 remove_out_of_range_locations  (relocate chars: -2 Salute +2 Terrore; caso "ultimo Menhir")
     │    S3 tick_menhir_dials
     │    S4 tick_time_dials / clear_location_time_tokens (non i quadranti Missione)
     │    S5 reveal_event  → [EVENT_RESOLUTION] → eventuale QUEST_DISPLAY
     │    S6 move_guardians (dado) → [ENCOUNTER se collisione]
     │    S8 equip_check (1 per parola chiave)
     ├─ DAY_ACTIONS  (round-robin)
     │    PICK_ACTOR (non passati, con Energia>0; spareggio n° personaggio)
     │    CHOOSE_ACTION → PARTY_FORMATION (join/leave prima dell'avvio, verifica pagamenti)
     │    ├─ TRAVEL → ARRIVAL{reveal_locations → guardian_encounter → lightning_rules}
     │    ├─ EXPLORE → JOURNAL_READER (versi, scelte, requisiti, status, redirect LdlS)
     │    ├─ LOCATION_ACTION (once-per-day flag)
     │    ├─ CHARACTER_ACTION
     │    ├─ INSPECT_MENHIR → MENHIR_ACTIVATION
     │    ├─ ITEM/SKILL/SECRET_ACTION
     │    └─ PASS
     │    (ognuna può generare ENCOUNTER, MOVE_SPECIAL, STATUS_CHANGE, DYING/MADNESS)
     │    → fine round quando tutti hanno agito/passato; → END_OF_DAY se tutti passati/Energia 0
     └─ END_OF_DAY (per personaggio): REST → RECOVER_ENERGY → UPGRADE(Esp) → DECKBUILD(min15) → DREAM/NIGHTMARE

ENCOUNTER (sottomacchina, reentrante da qualsiasi punto)
 ENC_DRAW → ENC_CLASSIFY{COMBAT|DIPLOMACY|TEXT}
 [DIPLOMACY] AVOID_OFFER → (paga) END_AVOIDED
 ENC_TRAITS_START → ENC_EQUIP → ENC_DRAW_HANDS(3|2,+Lento) → MULLIGAN_LOOP → (DIPL: affinity=grey, scegli via)
 TURN:
   T_I   CHOOSE_ACTIVE (senza gettone; spareggio n°) ; place activation token ; trigger Emboscada/Repentino se 1° attivato
   T_II1 DELAYED_ABILITIES (sx→dx)
   T_II2a PLAY_FIRST (mano | cima mazzo se Panico) → RESOLVE_KEYS(attr→magic(pay?)→bottom) → ON_PLACE / DELAY_TOKEN
   T_II2b PLAY_EXTRA* (richiede chiave "carta dorata" connessa; limite Rápido) → idem
          [Escape disponibile in qualsiasi momento dell'attivazione]
   T_II2c COMBAT: if cards==0 (o <2 Oportunista) → OPPORTUNITY_ATTACK + draw1
          DIPL:  AFFINITY_CHECK
   T_II2d COMBAT: VICTORY_CHECK
   T_II3 COMBAT: ENEMY_ATTACK(tabella[riserva]; 💀; prevenzioni; Finta; Horda; Furia x2) → VICTORY_CHECK
         DIPL:  RESPONSE(fase) → AFFINITY_CHECK   (saltato se fase appena vinta)
   T_II4 ALL_ACTIVATED? no→T_I  sì→T_III
   T_III DISCARD_TO_3 → DRAW_1 (no Panico; +1 Lento; mazzo vuoto→ESCAPE/FAIL) → CLEAR_ACTIVATIONS → T_I
 ENDS: WIN(ricompensa per membro, bottino diviso) | STAGE_WIN→next stage | FAIL(Fracaso a ciascuno) |
       ESCAPE(per personaggio; -1 Energia + opportunità) | ENEMY_FLED(Huir) | THIEF(Ladrón) | DYING_EXIT
 CLEANUP: carta in fondo al mazzo (o resta sul Luogo se Guardiano non sconfitto), rimescola mazzi personaggi,
          Oggetti girati → scoperti, Destrucción, rimuovi gettoni Tempo dalle carte.

INTERRUPTS globali (controllati dopo ogni modifica di tracce):
 Salute==0 → DYING (esci dall'Incontro) ; Terrore in zona rossa → MADNESS ; Energia>Salute → clamp ;
 Terrore>Salute → flag Panic ; Energia in zona rossa → flag Exhausted ; morte → DEATH_COOP/GAME_OVER
```

### 8.2 Dati per personaggio
- id, nome, numero personaggio (spareggi), colore plancia, Azione del Personaggio, tratto negativo.
- Tracce: `health`, `energy`, `terror` + limiti/zone rosse della plancia (max, `exhausted_threshold`, `madness_threshold`, valori iniziali).
- Risorse: `food`, `wealth`, `rep`, `exp`, `magic`.
- Attributi: 6 valori base (segnalini 0–2) + lista carte Abilità (id, faccia scelta, attributo).
- Mazzi: `combat_deck` (ordine), `diplomacy_deck`, `combat_collection_out` / `diplomacy_collection_out` (carte possedute fuori mazzo), riferimento alle Riserve Avanzate personali (25+25, ordine).
- Oggetti: lista (id, parola chiave, attivo/coperto, girato), Segreti (id, Personal?, quadrante/gettoni sopra), Cariche.
- Flag: `passed_today`, `dying` (carta), `madness` (carta), `in_party_id`, posizione (id Luogo), gettone attivazione (in Incontro), mano (in Incontro).
- Usi "una volta al giorno" legati al personaggio (se presenti su carte).

### 8.3 Dati della partita
- Giocatori (1–4), modalità (Standard/Storia/Sfida/Libero), capitolo corrente, giorno corrente.
- Mappa: griglia (x,y) → Luogo {id, numero, numero antico, Chiavi di Direzione per lato, sigilli, azione, flag once-per-day/gettoni Tempo, gettoni Missione, Oggetti lasciati da morti, Guardiani presenti, Menhir}.
- Mazzo Luoghi non rivelati, Luoghi rimossi dal gioco, mapping Luogo→versione modificata.
- Menhir (max 3): Luogo, valore quadrante (o assente = spento al prossimo S1).
- Quadranti Tempo (su Segreti/personaggi) e quadranti Missione (1–2: Luogo, valore).
- Guardiani (carta, Luogo).
- Mazzo Eventi (ordine), pila scarti Eventi, mazzo Eventi Casuali, Missioni attive, Evento del giorno.
- 4 mazzi Incontro (ordine, composizione per capitolo), mazzo Oggetti (ordine), Segreti disponibili, carte Abilità disponibili.
- Status: dizionario nome → set di parti / contatore / booleano, + trigger (verso LdlS / Evento speciale).
- Diario/LdlS: puntatore al verso corrente, scelte già fatte se rilevanti, Compiti annotati.
- Stato Incontro attivo: carta, tipo, membri, Sequenza (lista carte + Magia posata + gettoni Tempo + Cariche), Riserva di Combattimento / posizione Affinità + fase corrente + fasi vinte, mani, Oggetti accantonati, attivazioni del turno, contatori (prima carta, carte giocate per attivazione).
- RNG con seme (mescolate, dado Guardiano, lancio quadrante Graal/Teschio) per riproducibilità e salvataggi.

### 8.4 Punti [DA VERIFICARE] riassunti
Valori/zone delle tracce per plancia; risorse/attributi iniziali di Ailei, Arev, Gusano; numeri personaggio; testo di "Te estás muriendo" (solo e coop) e "Estás enloqueciendo"; retro della carta "Preparación del Capítulo 1"; numero righe di Chiavi e livelli d'Attributo richiesti; numero spazi Affinità per carta; facce del dado Guardiano; significato esatto di "inevitable"; rimozione gettoni Tempo dai Luoghi (tutti vs 1); uso Cariche su carte coperte; giocare 0 carte in Diplomazia; effetto preciso della T capovolta (Sfida); scelta delle carte Abilità; Incontri senza Chiavi.
