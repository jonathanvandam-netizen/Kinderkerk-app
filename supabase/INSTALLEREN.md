# Supabase koppelen — stappenplan

Duurt ongeveer 10 minuten. Je hoeft niets te programmeren.

**Makkelijkst (ook op iPad):** open https://jonathanvandam-netizen.github.io/Kinderkerk-app/installeren.html.
Daar kopieer je stap 2 en 3 met één knop, met je e-mailadres er al in.

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

## 4b. Agenda-koppeling (mag ook later)
Staat op de hulppagina als stap 4: draai `agenda.sql` in de SQL Editor en maak onder **Edge Functions** een functie
`agenda` met de code uit `functions/agenda/index.ts`; zet daarna **Verify JWT** uit. Daarna kan iedereen in de app via
**Mijn account → Agenda op je telefoon** zijn beurten en de vergaderingen in zijn eigen agenda zetten.

## 5. Je gegevens overzetten
Zodra de sleutel in de app staat, werkt de app met de database. Wat je tot nu toe op je telefoon hebt ingevoerd,
staat nog in Safari op je telefoon. Zo zet je het over:

1. Maak voor de zekerheid eerst een back-up (**Meer → Gegevens → Back-up maken**) zolang de app nog niet gekoppeld is.
2. Open na de koppeling de app op **dezelfde telefoon** en log in met je e-mailadres en de code uit de mail.
3. Ga naar **Meer → Gegevens → Gegevens van dit toestel overzetten** en bevestig.
   Lukt dat niet (bijv. op een ander toestel), kies dan **Back-up in de database zetten** en kies je back-upbestand.

Alleen echte gegevens gaan mee: kinderen, check-ins, planning, periodes, vergaderingen, Gedrag en Gebed.
Demokinderen, voorbeeldnotities en de voorbeeldperiode Jozef/Mozes blijven achter. De leiding komt in het team,
maar nog zonder uitnodiging. Twee keer overzetten kan geen kwaad: er komt niets dubbel in.

## 6. Leiding uitnodigen
Ga naar **Meer → Team**, tik op een naam en kies **Uitnodigen** met het e-mailadres van die persoon.
Diegene opent de app, vult dat e-mailadres in en daarna de code uit de mail. Leiding die je nog niet uitnodigt,
staat wel in de planning maar kan niet inloggen.

## 7. Eigen mailservice (doe dit vóór je iedereen uitnodigt)
Supabase stuurt zelf maar een paar mails per uur. Als meerdere mensen tegelijk willen inloggen, krijgen ze dan geen code.
Daarom koppel je een gratis mailservice. Hieronder met **Brevo** (300 mails per dag gratis, Europees bedrijf).

**In Brevo**
1. Maak een gratis account op [brevo.com](https://www.brevo.com).
2. Ga naar **Senders, domains & dedicated IPs → Senders → Add a sender**. Vul in:
   naam `Kinderkerk De Deur` en het e-mailadres waarvan de mails moeten komen. Bevestig dat adres via de mail die je krijgt.
   Tip: heeft De Deur een eigen domein (bijv. `@dedeur.nl`), gebruik dan liever een adres daarop en voeg in Brevo
   het domein toe (**Domains → Add a domain**). Dan komen de mails minder snel in de spam. Een Gmail-adres werkt ook,
   maar komt vaker in de spam terecht.
3. Ga naar **SMTP & API → SMTP** en klik op **Generate a new SMTP key**. Bewaar die sleutel goed;
   die is geheim, deel hem met niemand (ook niet met Claude).
   Op dezelfde pagina staan ook de **SMTP server**, **Port** en **Login** die je hieronder nodig hebt.

**In Supabase**
1. Ga naar **Authentication → Emails → SMTP Settings** en zet **Enable Custom SMTP** aan.
2. Vul in:
   - Sender email: het adres uit stap 2 van Brevo
   - Sender name: `Kinderkerk De Deur`
   - Host: `smtp-relay.brevo.com`
   - Port: `587`
   - Username: de **Login** van de Brevo SMTP-pagina
   - Password: de SMTP-sleutel uit stap 3
3. Klik op **Save**.
4. Ga naar **Authentication → Rate Limits** en zet het aantal mails per uur op bijvoorbeeld `30`. Klik op **Save**.
5. Probeer het: log uit in de app en log opnieuw in. Krijg je de code? Dan werkt het. Kijk ook even in je spam.

## 8. Proberen
1. Open de app, vul je e-mailadres in en vul de code uit de mail in.
2. Kijk of je kinderen, de planning en de vergaderingen er staan.
3. Laat één andere leiding inloggen en check samen een kind in: jullie zien het allebei meteen verschijnen.
## Goed om te weten
- Bij een gratis Supabase-project dat een week niet gebruikt wordt, wordt de database gepauzeerd.
  Met één klik zet je hem weer aan.
- Bij een gratis project kun je zelf geen back-ups van Supabase downloaden. Maak daarom af en toe (bijv. elke maand)
  een back-up in de app: **Meer → Gegevens → Back-up maken**.
