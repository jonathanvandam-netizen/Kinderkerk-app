// Koppeling met Supabase. Laat de key leeg om de app zonder database te gebruiken (lokale modus, gegevens in deze browser).
// Te vinden in Supabase: Project Settings → API Keys (Project URL en de "publishable" key).
// Deze sleutel mag openbaar zijn: de database-regels (row level security) beschermen de gegevens.
window.KK_CONFIG = {
  supabaseUrl: 'https://jbtnszlbvuypvotbhapb.supabase.co',
  supabaseKey: 'sb_publishable_3kLD4XQm9Rug4qYcz0xnVg_b1sZ-eLT',
  calendarFunction: 'Agenda',   // naam van de Edge Function voor de agenda (let op hoofdletters)
  slidesScript: 'https://script.google.com/macros/s/AKfycbxB3_tri7BOrPdr7vS8gVNi2_dH6g5gp92zC28hbblzCX7vU_kElJXe9rR6XPNo8Un6QQ/exec',   // URL van de Google Apps Script web-app voor de quiz naar Google Slides (eindigt op /exec)
};
