# Kinderkerk-app De Deur

Nieuwe app voor de kinderkerk van Evangeliegemeente De Deur. Vervangt de oude Glide-app "Zap!",
die door iemand anders wordt beheerd. Communiceer met Jonathan in het Nederlands, in eenvoudige taal.

## Afspraken
- Alleen **leiding** gebruikt de app, op telefoon én iPad/tablet.
- Eerst rustig bouwen met **nepdata**. Geen echte kinderdata gebruiken. Pas als de app af is, wordt samen met
  de beheerder van Zap! de bestaande data overgezet en gaat de app live.
- Layout volgt de kerkapp (Donkey Mobile): wit, donkerblauw `#1d3c9c`, lettertype Nunito Sans, kaarten op lichtgrijs.
- Navigatie: op de website (groot scherm) bovenin; op telefoon en als geïnstalleerde app een zwevende
  "liquid glass"-balk onderin (Home, Check-in, Meer).
- Fun zone is bewust weggelaten.
- Logo: `kinderkerk/logo-512.png` / `logo-192.png` (het echte logo, kinderen rond een wereldbol met vlam).
- Inloggen: alleen op uitnodiging; iedereen met een account is automatisch leiding; beheerders nodigen uit
  en kunnen toegang intrekken. Nu nog nagebootst (magic link als knop).

## Techniek (nu)
- Alles in `kinderkerk/index.html` (vanilla HTML/CSS/JS), demodata in `localStorage` (`kinderkerk-demo-v2`).
- `kinderkerk/manifest.webmanifest` voor installeren als app, `kinderkerk/sw.js` zodat de app ook zonder internet opent.
- Lokaal bekijken: `node kinderkerk/serve.js` → http://localhost:5173

## Functies
Home (Vandaag/Gebed/Notities, aantallen, rooster van vandaag), check-in per kind (Bijbel/Werkblad/Geld,
Bijbeltekst alleen bovenbouw, gebedsverlangens, wc-hint, standaard alleen kinderen van de laatste 60 dagen),
leiding check-in, team + uitnodigingen, historie (grafiek + "komt min. 1x/2wk"), roosters (sheets en bidden
bovenbouw, uitbreiden, plek leegmaken, CSV), kinderziektes (beheerder kan aanpassen), gebedslijst.
Kindgegevens (potloodje in check-in, of klik in historie): naam/groep wijzigen, laatste keren; verwijderen alleen beheerder.

## Open vragen / volgende stappen
- Kleuren: mint/zachtblauw van het logo, of donkerblauw van de kerkapp houden?
- Daarna: echte backend, voorstel Supabase (EU-regio) met magic-link-login, alleen op uitnodiging en
  row-level security, zodat alle leiding dezelfde data ziet.
