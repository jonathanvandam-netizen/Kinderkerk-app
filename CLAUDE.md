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
  - leeg = **demomodus**: nepdata in `localStorage` (`kinderkerk-demo-v2`), inloggen nagebootst.
  - met Supabase-URL en anon/publishable key = **databasemodus**: Supabase (EU) met inlogcode per mail, alleen op
    uitnodiging, row level security, live bijwerken. De app houdt een kopie in `db` en stuurt elke wijziging via
    `put`/`upd`/`drop` naar de database. Kolomnamen wijken op een paar plekken af (`COLS` in index.html).
- `supabase/schema.sql` = tabellen, regels en triggers; `supabase/INSTALLEREN.md` = stappenplan voor Jonathan.
  Het schema is getest op een lokale Postgres met een nagebootst `auth`-schema.
- `kinderkerk/vendor/supabase.js` = supabase-js 2.45.4 (UMD), in de repo zodat de app ook offline opent.
- `kinderkerk/manifest.webmanifest` voor installeren als app, `kinderkerk/sw.js` zodat de app ook zonder internet opent.
- Lokaal bekijken: `node kinderkerk/serve.js` → http://localhost:5173

## Functies
Home (Vandaag/Gebed/Notities, aantallen, rooster van vandaag), check-in per kind (Bijbel/Werkblad/Geld,
Bijbeltekst alleen bovenbouw, gebedsverlangens, wc-hint, standaard alleen kinderen van de laatste 60 dagen),
leiding check-in, team + uitnodigingen, historie (grafiek + "komt min. 1x/2wk"), roosters (sheets en bidden
bovenbouw, uitbreiden, plek leegmaken, CSV), kinderziektes (beheerder kan aanpassen), gebedslijst.
Kindgegevens (potloodje in check-in, of klik in historie): naam/groep wijzigen, laatste keren; verwijderen alleen beheerder.

## Open vragen / volgende stappen
- Jonathan heeft een Supabase-account. Hij volgt `supabase/INSTALLEREN.md` en geeft URL en anon key door;
  die komen in `kinderkerk/config.js`.
- Daarna: app online zetten (bijv. GitHub Pages of Netlify), eigen SMTP voor de inlogmails,
  en pas aan het eind samen met de beheerder van Zap! de echte data overzetten.
