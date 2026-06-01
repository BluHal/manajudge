# Esempi di domande per manajudge

Raccolta di domande reali che un giocatore di Magic potrebbe porre al giudice AI, dalle più
semplici alle casistiche da torneo. Servono come ispirazione per gli utenti, come banco di
prova manuale e come base per ampliare il set di valutazione (`data/eval/eval-set.json`).

Le domande sono in **italiano** (l'app risponde in italiano citando le regole in inglese).
Quelle marcate con 🃏 nominano carte specifiche (mettono alla prova il lookup su Scryfall);
quelle marcate con 🔗 sono pensate come **follow-up** della domanda precedente (mettono alla
prova la memoria di sessione e la riscrittura).

---

## 1. Regole di base (giocatore casual)

- Come si vince una partita a Magic?
- In che ordine si svolgono le fasi di un turno?
- Cosa posso fare durante la fase principale?
- Qual è la differenza tra un'istantaneo e una stregoneria?
- Posso giocare più di una terra per turno?
- Cosa succede se finisco le carte in libreria?
- Come funziona il mulligan a inizio partita?
- Cosa vuol dire che una creatura ha la "debolezza da evocazione"?
- Posso attaccare con una creatura il turno stesso in cui l'ho giocata?
- Quanti punti vita ho all'inizio della partita?

## 2. Stack, priorità e tempi

- Come funziona lo stack e in che ordine si risolvono le magie?
- Cos'è la priorità e quando la ricevo?
- Posso rispondere a una magia avversaria con un'altra magia?
- Se entrambi non facciamo nulla, cosa succede agli oggetti sullo stack?
- 🔗 E se invece volessi rispondere prima che si risolva?
- Cosa succede quando due abilità innescate vanno sullo stack nello stesso momento?
- Posso attivare un'abilità mentre una magia è ancora sullo stack?
- La riserva di mana quando si svuota?

## 3. Combattimento

- Come si dichiarano gli attaccanti e i bloccanti?
- Posso bloccare con più creature un solo attaccante?
- Cosa succede se la creatura che blocca viene rimossa prima del danno?
- Come si assegna il danno da combattimento se ho più bloccanti?
- Una creatura con travolgere quanto danno passa al giocatore?
- 🔗 E se quella creatura avesse anche tocco letale?
- Le creature attaccanti vengono TAPpate? Posso evitarlo?
- Cosa succede nella sottofase di fine combattimento?

## 4. Parole chiave (keyword abilities)

- Come funziona il volare e chi può bloccare una creatura che vola?
- Cosa fa esattamente il tocco letale?
- Come funziona il legame vitale: guadagno vita anche se la creatura viene distrutta?
- Indistruttibile protegge anche dal danno letale e dalle azioni basate sullo stato?
- 🔗 E protegge anche da effetti come "sacrifica una creatura"?
- Cosa fa la prodezza (prowess) e quando si innesca?
- Come interagisce primo colpo con travolgere?
- La protezione da un colore: cosa previene esattamente (le 4 cose)?

## 5. Interazioni tra carte specifiche 🃏

- 🃏 Se lancio Lightning Bolt su una creatura con protezione dal rosso, cosa succede?
- 🃏 Posso usare Swords to Plowshares su una creatura con indistruttibile? Funziona?
- 🃏 Doom Blade può bersagliare una creatura nera?
- 🃏 Come interagisce Tarmogoyf con le carte nei cimiteri di entrambi i giocatori?
- 🃏 Se controllo Blood Artist e sacrifico più creature contemporaneamente, quante volte si innesca?
- 🃏 Counterspell può neutralizzare un'abilità innescata o solo le magie?
- 🃏 Pacifism su una creatura: può ancora essere TAPpata per le sue abilità?
- 🃏 Se Snapcaster Mage dà flashback a un'istantaneo, cosa succede alla carta dopo averlo lanciato?
- 🃏 Humility e una creatura con +1/+1: come si combinano sui layer?

## 6. Casistiche avanzate (layers, sostituzione, SBA)

- Come si applica il sistema dei layer quando più effetti modificano le caratteristiche?
- In che ordine applico un effetto che imposta forza/costituzione e uno che li aumenta?
- Cosa sono le azioni basate sullo stato e quando vengono controllate?
- Cosa succede se controllo due effetti di sostituzione applicabili allo stesso evento?
- Un effetto di sostituzione può applicarsi due volte allo stesso evento?
- Come funziona la regola delle leggende con due permanenti leggendari uguali?
- Cosa succede a un'Aura quando il permanente a cui è attaccata lascia il campo?
- Se una creatura diventa 0/0 a causa di un effetto, quando muore esattamente?
- Come si gestisce una magia con tutti i bersagli diventati illegali alla risoluzione?

## 7. Zone, copie e bersagli

- Cosa significa che un oggetto "cambia zona" e perché conta?
- Quando copio una magia, chi sceglie i nuovi bersagli?
- Una copia di una creatura copia anche i segnalini +1/+1?
- Se un permanente lascia il campo e ritorna, è lo stesso oggetto o uno nuovo?
- Posso bersagliare una creatura con velo/blocco-bersaglio con un effetto che non la bersaglia?

## 8. Multiplayer e situazioni di torneo

- Come funziona la priorità in una partita multiplayer?
- In Commander, come funziona il danno da comandante?
- Cosa succede agli effetti "fino alla fine del turno" se un giocatore esce dalla partita?
- Differenza tra "concedere" e "perdere" una partita in un match al meglio dei tre?
- Posso prendere indietro un'azione se mi sono sbagliato? (in torneo)

## 9. Domande ambigue / fuori copertura (per testare l'onestà)

Queste servono a verificare che il giudice **ammetta l'incertezza** invece di inventare:

- La mia carta funziona contro quella del mio avversario? *(senza specificare quali)*
- Posso fare questa combo? *(senza descriverla)*
- Chi vince in questa situazione? *(contesto insufficiente)*
- È legale questa carta nel mio formato? *(domanda su legalità/banlist, fuori dalle CR)*

---

## Note d'uso

- I **follow-up** (🔗) funzionano solo nella stessa conversazione: il giudice riscrive la
  domanda usando il contesto (es. *"e se avesse anche tocco letale?"* → domanda completa).
- Per le interazioni 🃏 il giudice recupera il **testo oracle reale** della carta; se sbagli
  il nome, prova a scriverlo per esteso o in inglese.
- Ogni risposta mostra le **fonti** (numeri di regola CR + carte usate) e un **badge di
  confidenza**: se è "bassa", trattala con cautela e verifica le fonti.
