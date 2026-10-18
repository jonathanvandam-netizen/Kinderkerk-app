# Kinderkerk-app De Deur

Nieuwe app voor de kinderkerk van Evangeliegemeente De Deur. Vervangt de oude Glide-app "Zap!",
die door iemand anders wordt beheerd. Communiceer met Jonathan in het Nederlands, in eenvoudige taal.

## Afspraken
- Alleen **leiding** gebruikt de app, op telefoon én iPad/tablet.
- Eerst rustig bouwen met **nepdata**. Geen echte kinderdata gebruiken. Pas als de app af is, wordt samen met
  de beheerder van Zap! de bestaande data overgezet en gaat de app live.
- Layout en kleuren volgen de kerkapp van De Deur (Donkey Mobile): wit, donkerblauw `#1d3c9c`, lettertype Nunito Sans,
  kaarten op lichtgrijs. Besloten: de kleuren blijven zo (niet de mint/zachtblauw van het logo).
- Navigatie: op de website (groot scherm) bovenin; op telefoon en als geïnstalleerde app een zwevende
  "liquid glass"-balk onderin (Home, Check-in, Meer).
- Fun zone is bewust weggelaten.
- Logo: `kinderkerk/logo-512.png` / `logo-192.png` (het echte logo, kinderen rond een wereldbol met vlam).
- Inloggen: alleen op uitnodiging; iedereen met een account is automatisch leiding; beheerders nodigen uit
  en kunnen toegang intrekken. Inloggen gaat met een 6-cijferige code uit de mail (werkt ook in de geïnstalleerde
  iPhone-app, een link niet).

## Techniek (nu)
- Alles in `kinderkerk/index.html` (vanilla HTML/CSS/JS).
- Twee modi, gekozen via `kinderkerk/config.js`:
  - leeg = **demomodus**: nepdata in `localStorage` (`kinderkerk-demo-v6`), inloggen nagebootst.
  - met Supabase-URL en anon/publishable key = **databasemodus**: Supabase (EU) met inlogcode per mail, alleen op
    uitnodiging, row level security, live bijwerken. De app houdt een kopie in `db` en stuurt elke wijziging via
    `put`/`upd`/`drop` naar de database. Kolomnamen wijken op een paar plekken af (`COLS` in index.html).
- `supabase/schema.sql` = tabellen, regels en triggers; `supabase/INSTALLEREN.md` = stappenplan voor Jonathan.
  Het schema is getest op een lokale Postgres met een nagebootst `auth`-schema.
- `kinderkerk/vendor/supabase.js` = supabase-js 2.45.4 (UMD), in de repo zodat de app ook offline opent.
- `kinderkerk/manifest.webmanifest` voor installeren als app (naam "Kinderkerk"), `kinderkerk/sw.js` zodat de app ook
  zonder internet opent. Iconen: `apple-touch-icon.png` (iPhone, 180px) en `icon-maskable-*.png` (Android, logo met
  witte rand). Knop "Installeer de app" op inlogscherm, Home (wegklikbaar) en Meer: Android = installatievenster,
  iPhone/iPad = uitleg via Safari → Deel → Zet op beginscherm.
- Donkere modus: kleuren als variabelen in `:root`, donkere set onder `html[data-theme=dark]` en `prefers-color-scheme`.
  Keuze Automatisch/Licht/Donker in Mijn account, per toestel in localStorage `kk-theme`. Geen vaste kleuren in CSS.
- Inzoomen staat bewust uit (viewport, `touch-action:pan-x pan-y`, gesture/touch-events); invulvelden zijn 16px, anders
  zoomt iOS in. `sw.js` haalt eigen bestanden altijd vers op (GitHub Pages cachet 10 min) en de app herlaadt één keer bij
  een nieuwe versie. Verhoog `APP_VERSION` in index.html bij elke publicatie (zichtbaar onderaan Meer).
- Lokaal bekijken: `node kinderkerk/serve.js` → http://localhost:5173
- Online via GitHub Pages: https://jonathanvandam-netizen.github.io/Kinderkerk-app/ — `.github/workflows/pages.yml`
  publiceert de map `kinderkerk/` bij elke push naar `main`. De repository is daarvoor openbaar gemaakt.

## Functies
Home (compacte begroeting + leiding check-in; tabs Vandaag/Gebed/Notities; tellers in één kaart; "Programma" = thema,
leiding, sheets en bidden van deze zondag; iPad vanaf 760px twee kolommen), check-in per kind (Bijbel/Werkblad/Geld,
Bijbeltekst alleen bovenbouw, gebedsverlangens, wc-hint, standaard alleen kinderen van de laatste 60 dagen),
leiding check-in, team + uitnodigingen, historie (grafiek + "komt min. 1x/2wk"), roosters (sheets en bidden
bovenbouw, uitbreiden, plek leegmaken, CSV), kinderziektes (beheerder kan aanpassen), gebedslijst.
Kindgegevens (potloodje in check-in, of klik in historie): naam/groep/geboortedatum, leeftijd, laatste keren;
verwijderen alleen beheerder. Verjaardagen (binnen 6 dagen) op Home, in de check-inlijst (🎂) en bij het inchecken.
Planning (Meer → Planning): per zondag thema, Bijbelgedeelte, voorbereiding en leiding onderbouw/bovenbouw; iedereen
mag aanpassen (ruilen = jezelf weghalen, ander erin). Home toont de planning van deze zondag en "Jij hebt leiding: …".
Periodes (Planning, alleen beheerder): 7 weken, thema per groep (bovenbouw leeg = zelfde als onderbouw); week 6 = bidden, week 7 =
puntenwinkeltje + vergadering, om en om klein/groot (nieuwe periode stelt start +7 weken en de andere vergadering voor).
Per zondag onderwerp + Bijbelgedeelte per groep (leeg = periodethema; bovenbouw leeg = als onderbouw, tenzij de
periode voor bovenbouw een eigen thema heeft). Echte stand: periode "Scheppingsverhaal" begon 11-10-2026
(18-10 = week 2, 22-11 = week 7 met grote vergadering; de vorige vergadering was klein). De demodata volgt dit.
Vergadering (Home → tab Vergadering): volgende vergadering = week 7 van de periode (of zelf gepland), agendapunten
vooraf (iedereen), pagina `#/vergadering/<id>` met notulen per agendapunt (autosave), actiepunten (wat/wie/vóór,
afvinken; open actiepunten op de tab), eerdere vergaderingen, Delen = notulen als tekst (WhatsApp/mail).
Tabellen `meetings`, `agenda_items`, `actions`. Schrijfacties naar Supabase gaan via een wachtrij (volgorde blijft).
Keuzes van Jonathan: inchecken blijft altijd via het venster; per kind alleen geboortedatum (geen ouders/medisch/foto).

## Open vragen / volgende stappen
- Supabase-project bestaat al (eu-west-1, Ierland); de Project URL staat in `kinderkerk/config.js`.
  Nog te doen (stap 2–4 van `supabase/INSTALLEREN.md`): `schema.sql` draaien in de SQL Editor (eigen e-mail onderaan
  invullen), inlogmails met `{{ .Token }}`, en de anon/publishable key in `config.js`. Plakken in de SQL Editor lukte
  niet op de iPhone; dit doet Jonathan later op een laptop. Zolang de key leeg is, draait de app in demomodus.
  Vanuit de cloudomgeving is Supabase niet bereikbaar, dus Claude kan het schema niet zelf uitvoeren.
- Daarna: eigen SMTP voor de inlogmails,
  en pas aan het eind samen met de beheerder van Zap! de echte data overzetten.
