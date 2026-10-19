# Kinderkerk-app De Deur

Nieuwe app voor de kinderkerk van Evangeliegemeente De Deur. Vervangt de oude Glide-app "Zap!",
die door iemand anders wordt beheerd. Communiceer met Jonathan in het Nederlands, in eenvoudige taal.

## Afspraken
- Alleen **leiding** gebruikt de app, op telefoon én iPad/tablet.
- Jonathan wil nu al met echte kinderen werken. **Echte kindernamen komen nooit in de code of de repository**
  (die is openbaar, net als de website). Ze komen er alleen in via Meer → Kinderen importeren (beheerder):
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
Home (compacte begroeting + leiding check-in; kaart Gebed boven Kind ziek; tabs Vandaag/Notities (Gebed-tab bewust weg, dubbel); tellers in één kaart; "Programma" = thema,
leiding en sheets van deze zondag; iPad vanaf 760px twee kolommen), check-in per kind (Bijbel/Werkblad/Geld,
Bijbeltekst alleen bovenbouw, gebedsverlangens, wc-hint, standaard alleen kinderen van de laatste 60 dagen),
leiding check-in, team + uitnodigingen, historie (grafiek + "komt min. 1x/2wk"), Sheets (alleen bovenbouw, zie hieronder), kinderziektes (beheerder kan aanpassen). Het rooster "Bidden bovenbouw" is weg (op
verzoek van Jonathan); daarvoor is Gebed.
Kindgegevens (potloodje in check-in, of klik in historie): naam/groep/geboortedatum, leeftijd, laatste keren;
verwijderen alleen beheerder. Verjaardagen (binnen 6 dagen) op Home, in de check-inlijst (🎂) en bij het inchecken.
Jarig zingen: bij het inchecken knop "🎂 Vandaag gezongen" (+100 punten, instelbaar) van 6 dagen vóór tot 4 weken ná
de verjaardag zolang er nog niet gezongen is (kind trakteert vaak later). Opgeslagen als item 'jarig' in de check-in.
Home toont bij Jarig "Gezongen" of "🎵 Nog zingen".
Jarig op Home alleen voor kinderen die de laatste 60 dagen echt zijn ingecheckt (niet alleen geïmporteerd).
Kinderen beheren (Meer): status "Komt niet meer" (`inactive`) per kind of in één keer voor iedereen van 13+;
gestopte kinderen verdwijnen uit check-in, Jarig, Historie en roosters (gegevens blijven, terugzetten kan).
Planning (eigen knop in de menubalk): periodethema bovenaan, daaronder "Wie is wanneer aan de beurt": standaard een **tabel**
zoals het rooster dat de leiding gewend is (Datum | Bovenbouw | Onderbouw | Thema, kopregel per periode; op de telefoon
staat het thema onder de namen), of "Uitgebreid" (kaarten; keuze per toestel in localStorage `kk-planview`), met per zondag thema, Bijbelgedeelte, voorbereiding en leiding onderbouw/bovenbouw, sheets en bidden, en een filter "Alleen mijn beurten"; iedereen
mag aanpassen (ruilen = jezelf weghalen, ander erin). Home toont de planning van deze zondag en "Jij hebt leiding: …".
Periodes (Planning, alleen beheerder): 7 weken, thema per groep (bovenbouw leeg = zelfde als onderbouw); week 6 = bidden, week 7 =
puntenwinkeltje + vergadering, om en om klein/groot (nieuwe periode stelt start +7 weken en de andere vergadering voor).
Per zondag onderwerp + Bijbelgedeelte per groep (leeg = periodethema; bovenbouw leeg = als onderbouw, tenzij de
periode voor bovenbouw een eigen thema heeft). Echte stand: periode "Scheppingsverhaal" begon 11-10-2026
(18-10 = week 2, 22-11 = week 7 met grote vergadering; de vorige vergadering was klein). De demodata volgt dit.
Vergadering (eigen knop in de menubalk, `#/vergadering`; bewust niet op Home): volgende vergadering = week 7 van de periode (of zelf gepland), agendapunten
vooraf (iedereen), pagina `#/vergadering/<id>` met notulen per agendapunt (autosave), actiepunten (wat/wie/vóór,
afvinken; open actiepunten op het overzicht), eerdere vergaderingen, Delen = notulen als tekst (WhatsApp/mail).
Tabellen `meetings`, `agenda_items`, `actions`. Schrijfacties naar Supabase gaan via een wachtrij (volgorde blijft).
Per vergadering een notulist; actiepunten met één of meer personen (`who` = lijst). Delen geeft een verslag zoals de
notulen van De Deur: Algemeen (datum, notulist, volgende meeting), Agenda, Notulen, Actiepunten, Reeds uitgevoerd.
Demo bevat de echte notulen van 4-10-2026 (Jonathan gaf toestemming dat dit openbaar in de code staat) en de echte
themaplanning Scheppingsverhaal (week 1–5 scheppingsdagen, 6 bidden, 7 quiz + winkeltje). Demo-updates via `demoRev`
vervangen alleen vergaderingen/planning, nooit kinderen.
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
Rondleiding (`TOUR`): start vanzelf de eerste keer op een toestel (localStorage `kk-tour`), en via Mijn account →
"Rondleiding starten" (daar staat ook de donkere modus). Licht per stap een knop van de menubalk uit (onder of boven).
Tests moeten `kk-tour` op '1' zetten, anders zit de rondleiding in de weg.
Agenda-koppeling (Mijn account → "Agenda op je telefoon", alleen databasemodus): keuze "Alleen mijn beurten" of "Alle
zondagen" (localStorage `kk-cal`), knop webcal-link + link kopiëren (Google) + nieuwe link. Link = Edge Function
`supabase/functions/agenda/index.ts` (`?t=<code>&wat=mijn|alles`, Verify JWT uit; in Supabase heet de functie `Agenda` met
hoofdletter, ingesteld via `calendarFunction` in config.js) die een .ics maakt; persoonlijke code in
tabel `calendar_tokens` (`supabase/agenda.sql`, los van schema.sql, opnieuw draaien kan). Tijden van Jonathan: kinderkerk
10:30–12:15 (10:30 briefing en gebed, 10:45–11:00 klaarzetten), vergadering 12:45, groot 1,5 uur, klein 30 min.
Vergaderingen staan in beide keuzes. Getest met een .ics-parser; Deno is hier niet beschikbaar.
Keuzes van Jonathan: inchecken blijft altijd via het venster; per kind alleen geboortedatum (geen ouders/medisch/foto).

## Echte leiding (demo, alleen voornamen, nog niet uitgenodigd)
Bovenbouw: Jonathan (beheerder), Nora, Julian, Jamilla, Sandy (zwangerschapsverlof; normaal met Julian).
Onderbouw: Melissa, Dina, Tim, Chanel (Tim en Chanel gaan later ook met zwangerschapsverlof).
Rooster: bovenbouw wisselt elke week (Jonathan+Nora / Julian+Jamilla); onderbouw 2 weken dienst, 2 weken vrij
(Melissa+Dina / Tim+Chanel). 18-10-2026: Jonathan+Nora en Melissa+Dina (hun 2e week); 25-10: Julian+Jamilla en Tim+Chanel.
De demodata volgt dit (`dienst()` in index.html).

## Open vragen / volgende stappen
- Supabase-project (eu-west-1, Ierland) is gekoppeld (versie 22): schema.sql + agenda.sql + Edge Function `agenda`,
  eigen SMTP via een apart Gmail-adres voor de app (app-wachtwoord; los van het gedeelde kinderkerk-adres), en de
  mailtemplates Magic Link + Confirm sign up met `{{ .Token }}`. Sleutel in config.js.
  Vanuit de cloudomgeving is Supabase niet bereikbaar, dus Claude kan de database niet zelf controleren.
  Nog te doen: gegevens overzetten (Meer → Gegevens), leiding uitnodigen, agenda-koppeling testen.
- Pas aan het eind samen met de beheerder van Zap! de echte data overzetten.
