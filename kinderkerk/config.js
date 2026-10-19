// Koppeling met Supabase. Laat de key leeg om de app zonder database te gebruiken (lokale modus, gegevens in deze browser).
// Te vinden in Supabase: Project Settings → API Keys (Project URL en de "publishable" key).
// Deze sleutel mag openbaar zijn: de database-regels (row level security) beschermen de gegevens.
// TIJDELIJK UIT: de database staat klaar, maar de inlogmail met code werkt pas als de eigen mailservice (SMTP) gekoppeld is.
// Daarna weer invullen: sb_publishable_3kLD4XQm9Rug4qYcz0xnVg_b1sZ-eLT
window.KK_CONFIG = {
  supabaseUrl: 'https://jbtnszlbvuypvotbhapb.supabase.co',
  supabaseKey: '',
};
