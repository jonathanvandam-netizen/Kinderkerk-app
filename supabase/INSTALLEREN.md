# Supabase koppelen — stappenplan

Duurt ongeveer 10 minuten. Je hoeft niets te programmeren.

## 1. Project aanmaken
1. Log in op [supabase.com](https://supabase.com) en klik op **New project**.
2. Naam: `kinderkerk`. Kies een sterk databasewachtwoord en bewaar het goed.
3. Regio: **Central EU (Frankfurt)**. Dan blijven de gegevens in Europa.
4. Klik op **Create new project** en wacht tot het project klaar is.

## 2. Database inrichten
1. Ga links naar **SQL Editor** en klik op **New query**.
2. Kopieer de hele inhoud van [`schema.sql`](schema.sql) en plak die erin.
3. Helemaal onderaan staat `JOUW-EMAIL@voorbeeld.nl`. Vervang dat door je eigen e-mailadres.
   Daarmee word jij de eerste beheerder.
4. Klik op **Run**. Je ziet dan "Success".

## 3. Inlogmail met code
De app werkt met een code van 6 cijfers in plaats van een link. Op een iPhone werkt een link
namelijk niet goed in een geïnstalleerde app. Pas daarom twee mails aan:

1. Ga naar **Authentication → Emails** (of **Email Templates**).
2. Kies **Magic Link**. Zet als onderwerp `Je inlogcode voor de kinderkerk-app` en als bericht:
   ```html
   <h2>Inloggen bij de kinderkerk-app</h2>
   <p>Je code is:</p>
   <p style="font-size:28px;font-weight:bold;letter-spacing:4px">{{ .Token }}</p>
   <p>Vul deze code in de app in. Heb je niet geprobeerd in te loggen? Dan kun je deze mail negeren.</p>
   ```
3. Doe precies hetzelfde bij **Confirm signup**. Die mail krijgt iemand de allereerste keer dat die inlogt.
4. Klik steeds op **Save**.

## 4. Sleutels doorgeven
1. Ga naar **Project Settings → API** (of **Data API** en **API Keys**).
2. Kopieer de **Project URL**, bijvoorbeeld `https://abcdefgh.supabase.co`.
3. Kopieer de **anon public** key. In nieuwere projecten heet die **publishable key**.
4. Geef ze aan Claude, of vul ze zelf in bij `kinderkerk/config.js`.

Deze twee mogen gewoon in de app staan. De regels in de database bepalen wie wat mag zien.
De **service_role** of **secret key** deel je nooit.

## 5. Proberen
1. Open de app, vul je e-mailadres in en vul de code uit de mail in.
2. Vul je naam in.
3. Ga naar **Meer → Demodata in de database zetten** om met nepkinderen te testen.
4. Nodig via **Meer → Team** iemand uit. Diegene kan daarna gewoon inloggen met dat e-mailadres.

## Goed om te weten
- Supabase verstuurt zelf maar een paar mails per uur. Voor testen is dat genoeg. Voordat de app live
  gaat, stellen we een eigen mailservice in (bijvoorbeeld Brevo of Resend) onder **Authentication → SMTP**.
- Bij een gratis Supabase-project dat een week niet gebruikt wordt, wordt de database gepauzeerd.
  Met één klik zet je hem weer aan.
