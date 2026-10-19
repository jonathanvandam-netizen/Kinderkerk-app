# Kinderkerk-app De Deur

Nieuwe app voor de kinderkerk van Evangeliegemeente De Deur. Vervangt de oude Glide-app "Zap!",
die door iemand anders wordt beheerd. Communiceer met Jonathan in het Nederlands, in eenvoudige taal.

## Afspraken
- Alleen **leiding** gebruikt de app, op telefoon én iPad/tablet.
- Jonathan wil nu al met echte kinderen werken. **Echte kindernamen komen nooit in de code of de repository**
  (die is openbaar, net als de website). Ze komen er alleen in via de importpagina `#/import` (beheerder; staat sinds versie 37 niet meer in Meer, alles is al geïmporteerd):
  in demomodus alleen in de browser van dat toestel, in databasemodus in Supabase (alleen voor ingelogde leiding).
  Importregel: `Naam;groep;geboortedatum` (datum als 9-10-2013, 2013-10-09 of 9 oktober 2013; toekomst/ongeldig = leeg).
  Dubbel = zelfde naam én groep. Verzonnen demokinderen (`demo:true` of naam in `DEMO_KIDS`) haal je weg via
  de knop "Demokinderen weghalen" (importpagina en Meer) of het vinkje bij importeren.
  Namen uit schermafbeeldingen van Zap! nooit overnemen in code, tests of commits.
- Layout en kleuren volgen de kerkapp van De Deur (Donkey Mobile): wit, donkerblauw `#1d3c9c`, lettertype Nunito Sans,
  kaarten op lichtgrijs. Besloten: de kleuren blijven zo (niet de mint/zachtblauw van het logo).
- Navigatie: op de website (scherm vanaf 1000px) bovenin; op telefoon en als geïnstalleerde app een zwevende
  "liquid glass"-balk onderin (Home, Check-in, Gedrag, Planning, Vergadering, Meer).
- Fun zone is bewust weggelaten.
- Logo: `kinderkerk/logo-512.png` / `logo-192.png` (het echte logo, kinderen rond een wereldbol met vlam).
- Leiding kan in het team staan zonder account (voor de planning). Een beheerder voegt leiding toe, en pas na
  "Uitnodigen" (e-mailadres) kan iemand inloggen; toegang intrekken laat iemand in team en planning staan.
  Uitnodigen kan ook **via WhatsApp** (databasemodus): beheerder tikt "Uitnodigen via WhatsApp" → `make_invite_link` maakt
  een link `#/uitnodiging/<code>` (één keer bruikbaar, 14 dagen geldig, tabel `invite_links`, `supabase/uitnodigen.sql`);
  de uitgenodigde opent hem, ziet "Welkom, <naam>!" (`invite_name`), vult zelf zijn e-mailadres in (`accept_invite` zet
  email + invited) en krijgt meteen een inlogcode. Knoppen: "Stuur via WhatsApp" (wa.me-link) en "Kopieer bericht".
  Per leiding een veld Verlof/afwezig met icoontje op basis van de tekst (`awayIcon`, bewust maar 4 soorten:
  🤰 zwangerschap, 🤒 ziek, 🏖️ vakantie, 🗓️ overig) en snelknoppen. Inloggen: alleen op uitnodiging; Inloggen gaat met een 6-cijferige code uit de mail (werkt ook in de geïnstalleerde
  iPhone-app, een link niet).

## Techniek (nu)
- Alles in `kinderkerk/index.html` (vanilla HTML/CSS/JS).
- Twee modi, gekozen via `kinderkerk/config.js`:
  - leeg = **lokale modus**: gegevens in `localStorage` (`kinderkerk-demo-v8`), inloggen nagebootst. Jonathan gebruikt
    dit nu al **echt** (echte kinderen, planning, notulen) op zijn telefoon. Daarom: `STORE_KEY` nooit ophogen en
    nooit iets van de gebruiker overschrijven; aanpassingen aan startdata alleen via een veilige samenvoeg-migratie
    (`demoRev`). Geen "DEMODATA"-label meer en geen knop "Demodata opnieuw laden".
    Meer → Gegevens (beheerder): Back-up maken (JSON via deelvenster of download) en Back-up terugzetten (alleen lokaal,
    ook om naar de iPad over te zetten). In databasemodus (beheerder): "Gegevens van dit toestel overzetten" (leest de
    oude localStorage, daarna `kk-moved`) of "Back-up in de database zetten" (`cloudImport`/`cloudPlan`): alleen echte
    gegevens (geen demokinderen + hun check-ins, geen voorbeeldnotities, niet de periode Jozef/Mozes, leiding check-ins pas
    vanaf de eerste echte check-in); leiding op naam gekoppeld (niets dubbel), nieuwe leiding zonder uitnodiging; kolommen
    per tabel in `TABLE_COLS`; upsert, dus opnieuw doen kan. Getest met een nagebootste Supabase die kolommen en uuid's controleert.
  - met Supabase-URL en anon/publishable key = **databasemodus**: Supabase (EU) met inlogcode per mail, alleen op
    uitnodiging, row level security, live bijwerken. De app houdt een kopie in `db` en stuurt elke wijziging via
    `put`/`upd`/`drop` naar de database. Kolomnamen wijken op een paar plekken af (`COLS` in index.html).
    **Zonder internet**: put/upd/drop gaan in een wachtrij (`outbox`, localStorage `kk-outbox`) die `flush()` één voor één
    verstuurt; bij netwerkfout blijft hij staan en wordt het om de 15 s, bij 'online' en bij terugkeer naar de app opnieuw
    geprobeerd. `refresh()` wacht tot de wachtrij leeg is. De laatst geladen gegevens staan in `kk-cache` (per gebruiker),
    zodat de app ook zonder internet opent (`openFromCache`). Bovenin het label `#sync` ("Geen internet · 2 wachten").
    Uitloggen met wachtende wijzigingen vraagt eerst bevestiging en wist wachtrij + cache.
    Automatische back-ups: `supabase/backup.sql` (tabel `backups`, functie `make_backup()`, pg_cron elke zondag 20:00 UTC,
    laatste 12 bewaard, alleen beheerders). In de app: Meer → Gegevens → Automatische back-ups (ophalen → bewaren als
    bestand; terugzetten via "Back-up in de database zetten"). Herinnering op Home voor beheerders als de laatste zelf
    bewaarde back-up (localStorage `kk-last-backup`) ouder is dan 35 dagen.
    Pauze voorkomen: `.github/workflows/wakker-houden.yml` tikt de database elke 3 dagen aan (GitHub zet zulke taken uit na
    60 dagen zonder wijzigingen in de repository; dan stuurt GitHub een mail om hem weer aan te zetten).
- `supabase/schema.sql` = tabellen, regels en triggers; `supabase/INSTALLEREN.md` = stappenplan voor Jonathan.
  Hulppagina `kinderkerk/installeren.html` (online /installeren.html): kopieerknoppen voor de database-code (met e-mail
  ingevuld) en de inlogmail; pages.yml zet `schema.sql` ernaast (`kinderkerk/schema.sql` staat in .gitignore).
  Het schema is getest op een lokale Postgres met een nagebootst `auth`-schema.
- `kinderkerk/vendor/supabase.js` = supabase-js 2.45.4 (UMD), in de repo zodat de app ook offline opent.
- `kinderkerk/manifest.webmanifest` voor installeren als app (naam "Kinderkerk"), `kinderkerk/sw.js` zodat de app ook
  zonder internet opent. Iconen: `apple-touch-icon.png` (iPhone, 180px) en `icon-maskable-*.png` (Android, logo met
  witte rand). Knop "Installeer de app" op inlogscherm, Home (wegklikbaar) en Meer: Android = installatievenster,
  iPhone/iPad = uitleg via Safari → Deel → Zet op beginscherm.
- Donkere modus: kleuren als variabelen in `:root`, donkere set onder `html[data-theme=dark]` en `prefers-color-scheme`.
  Keuze Automatisch/Licht/Donker in Mijn account, per toestel in localStorage `kk-theme`. Geen vaste kleuren in CSS. Let op: een variabele nooit naar zichzelf laten verwijzen (`--x:var(--x)` = ongeldig/doorzichtig).
- Inzoomen staat bewust uit (viewport, `touch-action:pan-x pan-y`, gesture/touch-events); invulvelden zijn 16px, anders
  zoomt iOS in. `sw.js` haalt eigen bestanden altijd vers op (GitHub Pages cachet 10 min) en de app herlaadt één keer bij
  een nieuwe versie. Verhoog `APP_VERSION` in index.html bij elke publicatie (zichtbaar onderaan Meer).
- Lokaal bekijken: `node kinderkerk/serve.js` → http://localhost:5173
- Online via GitHub Pages: https://jonathanvandam-netizen.github.io/Kinderkerk-app/ — `.github/workflows/pages.yml`
  publiceert de map `kinderkerk/` bij elke push naar `main`. De repository is daarvoor openbaar gemaakt.

## Functies
Home (compacte begroeting + grote knop "Kinderen inchecken" met daaronder "Leiding inchecken"; kaart Gebedsverlangens (Kind ziek? bewust niet op Home, wel in
het incheckvenster en Meer); de tellers zijn klikbaar (Kinderen/Totaal = "Wie is er?", Leiding = leiding inchecken). Leiding op de planning telt automatisch
als aanwezig (`leaderPlanned`), extra leiding check je in (`leaderExtra`, tabel leader_checkins); geen tabs meer (Notities weg sinds versie 38: zet zoiets bij agendapunten of actiepunten; tabel `notes` blijft bestaan); tellers in één kaart; "Programma" = thema,
leiding en sheets van deze zondag; iPad vanaf 760px twee kolommen), check-in per kind (Bijbel/Werkblad/Geld,
Bijbeltekst alleen bovenbouw, gebedsverlangens, wc-hint, standaard alleen kinderen van de laatste 60 dagen; volgorde = wie de
laatste 12 weken het vaakst kwam bovenaan, gelijk = op naam; ingecheckte kinderen blijven op hun plek),
leiding check-in, team + uitnodigingen, historie (grafiek + "komt min. 1x/2wk"), Sheets (alleen bovenbouw, zie hieronder), kinderziektes (beheerder kan aanpassen). Het rooster "Bidden bovenbouw" is weg (op
verzoek van Jonathan); daarvoor is Gebed.
Kindgegevens (potloodje in check-in, of klik in historie): naam/groep/geboortedatum, leeftijd, laatste keren;
verwijderen alleen beheerder. Verjaardagen (binnen 6 dagen) op Home, in de check-inlijst (🎂) en bij het inchecken.
Jarig zingen: bij het inchecken knop "🎂 Vandaag gezongen" (+100 punten, instelbaar) van 6 dagen vóór tot 4 weken ná
de verjaardag zolang er nog niet gezongen is (kind trakteert vaak later). Opgeslagen als item 'jarig' in de check-in.
Home toont bij Jarig "Gezongen" of "🎵 Nog zingen".
Jarig op Home alleen voor kinderen die de laatste 60 dagen echt zijn ingecheckt (niet alleen geïmporteerd).
Nieuw kind: item 'nieuw' (🌟, standaard 50 punten per groep, instelbaar bij Punten). Alleen voor een kind dat net met
"+ Kind" is toegevoegd (`state.newKidId`): "🌟 … is nieuw!" met de knop al aangevinkt. Bestaande/geïmporteerde kinderen
zonder check-ins krijgen de knop níet (keuze van Jonathan). Naam lijkt op een bestaand kind (`similarKids`: zelfde naam zonder
hoofdletters/accenten, alleen voornaam, of kleine typfout bij (bijna) gelijke voornaam; broertjes/zusjes met dezelfde
achternaam níet): waarschuwing tijdens typen en bevestigen bij opslaan.
Meer is ingedeeld in Algemeen (Team), Op zondag (Gebedsverlangens, Sheets, Kinderziektes, Punten), Kinderen
(Kinderen beheren, Historie) en Gegevens (beheerder).
Afwezig + vervanger (bewust rustig): Mijn account → "Wanneer kan ik niet?" (van/t/m/reden; opslag in tabel `notes`,
text = `afwezig:{"leader","from","to","why"}`, `absentOn`). Planning zet ⚠️ achter die naam (tabel, kaarten, chips). Op Home alleen
bij een botsing een gele regel met "Vervanger zoeken" (`myClashes`); in het venster van een zondag waarop jij leiding hebt de knop
"🔁 Kun je niet? Vervanger zoeken via WhatsApp" (`swapLink` = wa.me met kant-en-klare tekst).
Groep nakijken (bovenaan Kinderen beheren, alleen als er iets is): onderbouwkind met leeftijd op 1 september ≥ grens (settings
'groepsgrens', standaard 8, beheerder past aan in de kaart) → "Naar bovenbouw"; bezoeker met ≥3 check-ins → Onderbouw/Bovenbouw/
"Blijft bezoeker". "Laat zo" = note `groep-ok:{"kid","sep"}` (geldt dat schooljaar; bezoeker altijd).
Kinderen beheren (Meer): status "Komt niet meer" (`inactive`) per kind of in één keer voor iedereen van 13+;
gestopte kinderen verdwijnen uit check-in, Jarig, Historie en roosters (gegevens blijven, terugzetten kan).
Planning (eigen knop in de menubalk): periodethema bovenaan, daaronder "Wie is wanneer aan de beurt": standaard een **tabel**
zoals het rooster dat de leiding gewend is (Datum | Bovenbouw | Onderbouw | Thema, kopregel per periode; op de telefoon
staat het thema onder de namen), of "Uitgebreid" (kaarten; keuze per toestel in localStorage `kk-planview`), met per zondag thema, Bijbelgedeelte, voorbereiding en leiding onderbouw/bovenbouw, sheets en bidden, en een filter "Alleen mijn beurten"; iedereen
mag aanpassen (ruilen = jezelf weghalen, ander erin). Home toont de planning van deze zondag en "Jij hebt leiding: …".
Planning verder vullen (beheerder, knop onder de planning): `planPattern` zoekt per groep in de laatste 12 ingevulde zondagen de
kleinste cyclus (1–6 weken) waarbij ≥75% klopt (losse ruilen storen niet), `planFillPlan` vult alleen lege zondagen tot een half jaar
vooruit (of tot het eind van de laatste periode); bevestigen met uitleg van het gevonden patroon. Herinnering voor beheerders op Home
en Planning als de planning binnen 8 weken op is (`planRunsOut`). Getest: 0 afwijkingen van het echte rooster (`dienst()`).
Periodes (Planning, alleen beheerder): 7 weken, thema per groep (bovenbouw leeg = zelfde als onderbouw); week 6 = bidden, week 7 =
puntenwinkeltje + vergadering, om en om klein/groot (nieuwe periode stelt start +7 weken en de andere vergadering voor).
Per zondag onderwerp + Bijbelgedeelte per groep (leeg = periodethema; bovenbouw leeg = als onderbouw, tenzij de
periode voor bovenbouw een eigen thema heeft). Echte stand: periode "Scheppingsverhaal" begon 11-10-2026
(18-10 = week 2, 22-11 = week 7 met grote vergadering; de vorige vergadering was klein). De demodata volgt dit.
Vergadering (eigen knop in de menubalk, `#/vergadering`; bewust niet op Home): volgende vergadering = week 7 van de periode (of zelf gepland), agendapunten
vooraf (iedereen), pagina `#/vergadering/<id>` met notulen per agendapunt (autosave), actiepunten (wat/wie/vóór,
afvinken; open actiepunten op het overzicht; over de vóór-datum = `isLate`: rood vlak + "⚠️ Te laat", kop "· N te laat", bovenaan door `byDue`), eerdere vergaderingen, Delen = notulen als tekst (WhatsApp/mail).
Tabellen `meetings`, `agenda_items`, `actions`. Schrijfacties naar Supabase gaan via een wachtrij (volgorde blijft).
Per vergadering een notulist; actiepunten met één of meer personen (`who` = lijst). Notulen typt alleen de notulist;
anderen zien ze alleen-lezen en live ("Toch typen" kan, `state.notesOpen`), zodat niemand elkaars tekst overschrijft. Delen geeft een verslag zoals de
notulen van De Deur: Algemeen (datum, notulist, volgende meeting), Agenda, Notulen, Actiepunten, Reeds uitgevoerd.
Demo bevat de echte notulen van 4-10-2026 (Jonathan gaf toestemming dat dit openbaar in de code staat) en de echte
themaplanning Scheppingsverhaal (week 1–5 scheppingsdagen, 6 bidden, 7 quiz + winkeltje). Demo-updates via `demoRev`
vervangen alleen vergaderingen/planning, nooit kinderen.
Terugblik (`terugblikData`/`openTerugblik`): vanaf de vergadering in week 7 (12:45) tot 3 weken later een kaart op Home en bovenaan
Vergadering, wegdrukken per toestel (localStorage `kk-terugblik` = lijst periode-id's). Op de vergaderpagina van week 7 blijft een
knop "🎉 Terugblik". Bewust simpel (wens van Jonathan): zondagen, kinderen gemiddeld, nieuwe kinderen (eerste check-in ooit in de periode),
elke zondag geweest en een bedankje aan de leiding. Telt per week (zondag t/m zaterdag). Delen = tekst (WhatsApp). Alleen zichtbaar als er check-ins zijn.
Quiz (`#/quiz`, Meer → Op zondag, alleen bovenbouw-leiding en beheerders; onderbouw ziet hem niet): op Home onder het programma
een knop "❓ Quizvraag bedenken" (voor die zondag; in week 7 "Quiz van vandaag: spelen of downloaden"). Vraag = open (antwoord mag
leeg) of meerkeuze A–D (min. 2 antwoorden; tik de letter(s) van het goede aan, meer goede antwoorden mag: `ok` = lijst, oude vragen
hebben één getal → `okList`). Quizpagina en het venster op Home: vragen van die week, tikken = aanpassen/weghalen.
"Quiz spelen in de app": groot scherm, gekleurde vakken (A rood, B blauw, C oranje, D paars; groen = alleen voor goed). Tik op een
antwoord → goed (groen, "Goed zo! 🎉") of fout (rood, schudt, goede antwoorden groen); open vraag: "Antwoord tonen".
Downloaden: alleen PowerPoint en Google Slides (Jonathan wil geen spreadsheet/Excel). PowerPoint via PptxGenJS 3.12.0
(`vendor/pptxgen.bundle.js`, pas geladen bij het downloaden; titeldia met logo, per vraag een vraag- en een antwoorddia; daarna haalt
de app uit [Content_Types].xml de Overrides naar niet-bestaande slideMasterN weg, anders weigert PowerPoint het bestand). Eerst maken,
dan venster met "Delen / bewaren" (`offerFile`/`fileShare`: de iPhone opent het deelvenster alleen direct na een tik) en Downloaden.
Google Slides: de app stuurt de .pptx (base64, met de Supabase access_token) naar een Google Apps Script web-app van de beheerder
(`google/quiz-naar-slides.gs`, URL in config.js als `slidesScript`; pages.yml zet hem als slides-script.txt naast installeren.html,
stap 8). Het script controleert de token bij Supabase /auth/v1/user, zet het bestand in Drive (map "Kinderkerk quiz") om naar Google
Slides (Drive API-service v3 of v2; zonder die service blijft het een .pptx in Drive), deelt "iedereen met link kan bewerken" en geeft
de link terug → venster "Openen in Google Slides". Getest met een nagebootste Google-omgeving (gstest) en Supabase-stub; echt Google
is vanaf hier niet bereikbaar. Zonder slidesScript: oude route (bewaren → docs.google.com → zelf uploaden). PowerPoint werkt (getest door Jonathan).
Opslag zonder extra database-stap in tabel `notes`: text = `quiz:{"q","a"}` of `quiz:{"q","opts":[…],"ok":[…]}` (`QUIZ_PREFIX`, `quizOf`).
Punten: kinderen krijgen fysieke punten (voor het puntenwinkeltje in week 7); de app houdt geen saldo bij, maar toont
bij het inchecken "X krijgt N punten" (aanwezig + per meegenomen ding, per groep) en ⭐ in de lijsten.
Waarden instelbaar door beheerder onder Meer → Punten (tabel `settings`, key 'points'). Startwaarden (van Jonathan,
per ding, opgeteld, geen punten voor alleen aanwezig): bovenbouw Bijbel 10, Werkblad 10, Geld 5, Bijbeltekst 10;
onderbouw Bijbel 10, Werkblad 15, Geld 10; bezoekers als onderbouw.
Gedrag (eigen knop in de menubalk, `#/gedrag`; `#/smileys` werkt ook): per kind smileys geven (😊) en waarschuwingen (⚠️). 7 smileys =
iets uit de grabbelbak graaien; knop "Gegraaid" trekt er 7 af (rest telt door). Waarschuwingen tellen per zondag:
1e naam op het bord, 2e streepje erachter, 3e eruit en bij ouders/verzorgers in de dienst (bevestigen). Lijst = alleen vandaag
ingecheckte kinderen; onderin knop "Alle kinderen" (de rest van de groep), tabs per groep (standaard je eigen groep), secties "Mag graaien" en "Op het bord";
tik op de naam om terug te draaien. Opslag: tabel `marks` (kid_id, date, kind smiley/warn/grab, author), lokaal `db.marks`.
Gouden Week komt later (Jonathan legt uit).
Gebed (`#/gebed`, in Meer bovenaan + kaart op Home; bewust niet in de menubalk, die is vol): gebedspunten van vandaag (of
de laatste zondag als het geen zondag is). Bij kinderkerk bidden kinderen voor de gebedspunten van het inchecken + 1 kind
van de onderbouw voor de collecte. "Kies wie er bidden" kiest per gebedspunt een ingecheckt kind (alle groepen, liefst niet
het kind zelf) en een onderbouwkind voor de collecte; "Ander kind" kiest opnieuw. Eerlijk (`fairPick`): minst vaak aan de
beurt → langst geleden → toeval, zodat ook kinderen die weinig komen even vaak bidden. Beurten = marks 'pray' (ref = id van
het gebedspunt) en 'collecte'; losse gebedspunten = marks 'prayer' (tekst in `note`). Tik op een kindnaam = alle
gebedspunten van dat kind + nieuw punt. Op Home en Check-in staat op een dag zonder zondag/check-ins: "Hé, vandaag is het
geen zondag. Zoek je de gebedslijst? Klik hier." Sheets (Meer → Sheets, `#/roosters`): niet meer vooruit ingepland. Op zondag kiest de app met "Kies wie de sheets doet"
eerlijk (`fairPick` + `sheetTurns`) uit de ingecheckte bovenbouw; "Ander kind" en "Zelf een kind kiezen" kunnen ook.
Overzicht "Hoe vaak al?" en "Eerdere keren". Opslag blijft `rosters` (kind 'sheets'). In de planning staat voor
toekomstige zondagen "kiest de app op zondag". Migratie demoRev 4 haalde oude vooruit-planning weg.
Rondleiding (`TOUR_ALL`, 16 stappen, bovenbouw/beheerder 18: extra "Quizvraag bedenken" op Home en "De quiz in week 7" met Google Slides → Drive van het one80kids-account; `only:() => canQuiz()`): start vanzelf de eerste keer op een toestel (localStorage `kk-tour`), en via
Mijn account → "Rondleiding starten". Gaat echt langs de pagina's (stap: `nav` = menuknop, `route` = pagina openen,
`el` = wat oplichten, eerste die bestaat; `open` = venster openen, bijv. Mijn account; `only` = voorwaarde, bijv. de
agenda-stap alleen in databasemodus). Legt ook de agenda-koppeling uit (past zich vanzelf aan). Voortgangsbalk "Stap x van y".
Tests moeten `kk-tour` op '1' zetten, anders zit de rondleiding in de weg. Omdat config.js nu een sleutel heeft, moeten
lokale tests `config.js` vervangen door `window.KK_CONFIG={}` (Playwright route), anders start de databasemodus.
Agenda-koppeling (Mijn account → "Agenda op je telefoon", alleen databasemodus): keuze "Alleen mijn beurten" of "Alle
zondagen" (localStorage `kk-cal`), knop webcal-link + link kopiëren (Google) + nieuwe link. Link = Edge Function
`supabase/functions/agenda/index.ts` (`?t=<code>&wat=mijn|alles`, Verify JWT uit; in Supabase heet de functie `Agenda` met
hoofdletter, ingesteld via `calendarFunction` in config.js) die een .ics maakt; persoonlijke code in
tabel `calendar_tokens` (`supabase/agenda.sql`, los van schema.sql, opnieuw draaien kan). Tijden van Jonathan: kinderkerk
10:30–12:15 (10:30 briefing en gebed, 10:45–11:00 klaarzetten), vergadering 12:45, groot 1,5 uur, klein 30 min.
Vergaderingen staan in beide keuzes. Getest met een .ics-parser; Deno is hier niet beschikbaar.
Dagen: `kkDay()` = vandaag op zondag (of als er vandaag al check-ins zijn), anders afgelopen zondag. Check-in, Gedrag,
Gebed, Sheets, leiding check-in en "Wie is er?" gaan over `kkDay()`; programma en "Jij hebt leiding" over aankomende
zondag. Teksten via `dayLabel(d)`: "vandaag" alleen voor vandaag, doordeweeks "afgelopen zondag 18 oktober" /
"aankomende zondag 25 oktober". Home-tab heet doordeweeks "Overzicht".
Keuzes van Jonathan: inchecken blijft altijd via het venster; per kind alleen geboortedatum (geen ouders/medisch/foto).

## Echte leiding (demo, alleen voornamen)
Bovenbouw: Jonathan (beheerder; Julian mag ook beheerder worden), Nora, Julian, Jamilla, Sandy (zwangerschapsverlof; normaal met Julian).
Onderbouw: Melissa, Dina, Tim, Chanel (Tim en Chanel gaan later ook met zwangerschapsverlof).
Rooster: bovenbouw wisselt elke week (Jonathan+Nora / Julian+Jamilla); onderbouw 2 weken dienst, 2 weken vrij
(Melissa+Dina / Tim+Chanel). 18-10-2026: Jonathan+Nora en Melissa+Dina (hun 2e week); 25-10: Julian+Jamilla en Tim+Chanel.
De demodata volgt dit (`dienst()` in index.html).

## Open vragen / volgende stappen
- Live in databasemodus (Supabase eu-west-1, eigen SMTP via apart Gmail-adres, mailtemplates met `{{ .Token }}`, agenda, back-ups,
  uitnodigen via WhatsApp, Google Slides-script in het one80kids-account). Julian is uitgenodigd en beheerder.
  Vanuit de cloudomgeving zijn Supabase en Google niet bereikbaar, dus Claude kan die niet zelf controleren.
- Nog te doen (Jonathan): overige leiding uitnodigen, gesprek met de oudsten over privacy, Julian inwerken als tweede beheerder
  (ook toegang tot Supabase en het one80kids-Google-account), een paar zondagen naast Zap! draaien en dan Zap! stoppen,
  Gouden Week uitleggen. Advies: eerst de leiding een paar zondagen laten werken en hun feedback ophalen, niet meer functies.
