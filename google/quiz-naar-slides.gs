/**
 * Kinderkerk-app: quiz naar Google Slides
 * ---------------------------------------
 * Dit script draait in het Google-account van de beheerder. De app stuurt de quiz (als PowerPoint) hierheen;
 * het script zet hem in Google Drive (map "Kinderkerk quiz") om naar een echte Google Slides-presentatie
 * en geeft de link terug. Iedereen met de link kan de presentatie openen en aanpassen.
 *
 * Alleen leiding die is ingelogd in de app mag dit gebruiken: het script controleert dat bij Supabase.
 *
 * Instellen (eenmalig, zie de stappen op de installeerpagina van de app):
 *  1. script.google.com → Nieuw project → plak deze code (vervang wat er staat).
 *  2. Links bij "Services" op + → kies "Drive API" → Toevoegen (dan wordt het een echte Google Slides).
 *  3. Implementeren → Nieuwe implementatie → type "Web-app" → Uitvoeren als: Ik, Toegang: Iedereen → Implementeren.
 *  4. Geef toestemming en kopieer de URL van de web-app (eindigt op /exec). Die komt in config.js van de app.
 */
const SUPABASE_URL = 'https://jbtnszlbvuypvotbhapb.supabase.co';
const SUPABASE_KEY = 'sb_publishable_3kLD4XQm9Rug4qYcz0xnVg_b1sZ-eLT';   // publieke sleutel, mag openbaar
const FOLDER_NAME = 'Kinderkerk quiz';
const SLIDES = 'application/vnd.google-apps.presentation';
const PPTX = 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

function doPost(e) {
  try {
    const body = JSON.parse(e.postData.contents);
    // Is dit iemand die echt is ingelogd in de kinderkerk-app?
    const check = UrlFetchApp.fetch(SUPABASE_URL + '/auth/v1/user', {
      headers: { Authorization: 'Bearer ' + body.token, apikey: SUPABASE_KEY }, muteHttpExceptions: true });
    if (check.getResponseCode() !== 200) return reply_({ error: 'Je bent niet ingelogd in de kinderkerk-app.' });

    const name = String(body.name || 'Quiz').replace(/\.pptx$/i, '').slice(0, 120);
    const blob = Utilities.newBlob(Utilities.base64Decode(body.data), PPTX, name + '.pptx');
    const folder = folder_();
    let id = null;
    try { id = convert_(blob, name, folder.getId()); } catch (err) { id = null; }
    const file = id ? DriveApp.getFileById(id) : folder.createFile(blob);   // zonder Drive API: PowerPoint-bestand in Drive
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.EDIT);
    return reply_({ url: 'https://docs.google.com/presentation/d/' + file.getId() + '/edit', converted: !!id });
  } catch (err) {
    return reply_({ error: String(err && err.message || err) });
  }
}

// Omzetten naar Google Slides met de Drive API (Services → Drive API). Werkt met versie 3 en met versie 2.
function convert_(blob, name, folderId) {
  if (typeof Drive === 'undefined') return null;
  if (Drive.Files.create) return Drive.Files.create({ name: name, mimeType: SLIDES, parents: [folderId] }, blob).id;
  return Drive.Files.insert({ title: name, mimeType: SLIDES, parents: [{ id: folderId }] }, blob, { convert: true }).id;
}

function folder_() {
  const it = DriveApp.getFoldersByName(FOLDER_NAME);
  return it.hasNext() ? it.next() : DriveApp.createFolder(FOLDER_NAME);
}

function reply_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

// Even testen in de editor: kies deze functie en tik op Uitvoeren. Dan vraagt Google ook meteen om toestemming.
function test() {
  Logger.log('Map: ' + folder_().getUrl());
}
