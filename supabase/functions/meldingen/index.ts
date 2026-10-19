// Meldingen voor de kinderkerk-app (Supabase Edge Function "meldingen", Verify JWT uit).
// - De tijdklok (supabase/meldingen.sql) roept ?wat=leiding (zaterdag) en ?wat=vergadering (zondag) aan, met de kop x-kk-geheim.
// - De app roept ?wat=test aan met de inlog van de gebruiker: die krijgt dan zelf een testmelding.
// Geheimen (Edge Functions → Secrets): VAPID_PUBLIC, VAPID_PRIVATE en KK_GEHEIM (de installeerpagina maakt ze, stap 9).
import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const APP_URL = 'https://jonathanvandam-netizen.github.io/Kinderkerk-app/';
const CORS = { 'Access-Control-Allow-Origin':'*', 'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods':'POST, OPTIONS' };

// ---------- Datums ('YYYY-MM-DD') ----------
const addDays = (s, n) => { const d = new Date(s + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };
const todayNL = () => new Intl.DateTimeFormat('en-CA', { timeZone:'Europe/Amsterdam' }).format(new Date());
const PERIOD_WEEKS = 7;

// ---------- Welke melding naar wie (zonder database, zodat het los te testen is) ----------
function absentOn(notes, leaderId, date){
  return notes.some(n => { if (!n.text || !n.text.startsWith('afwezig:')) return false;
    try { const a = JSON.parse(n.text.slice(8)); return a.leader === leaderId && a.from <= date && date <= (a.to || a.from); } catch(e){ return false; } });
}
function periodOf(periods, date){
  const p = periods.filter(x => x.start <= date).sort((a, b) => a.start.localeCompare(b.start)).pop();
  if (!p) return null;
  const week = Math.round((new Date(date + 'T12:00:00Z').getTime() - new Date(p.start + 'T12:00:00Z').getTime()) / 6048e5) + 1;
  return week > PERIOD_WEEKS ? null : { p, week };
}
function berichten(wat, today, { sundays, meetings, periods, notes }){
  const out = [];
  if (wat === 'leiding'){
    const date = addDays(today, 1), s = sundays.find(x => x.date === date);
    if (!s) return out;
    const w = periodOf(periods, date);
    for (const [grp, ids] of [['onderbouw', s.onder || []], ['bovenbouw', s.boven || []]]){
      const theme = (grp === 'bovenbouw' ? s.theme_boven || s.theme : s.theme) || (w ? (w.week === 6 ? 'Bidden' : w.week === 7 ? 'Afsluiting en puntenwinkeltje' : grp === 'bovenbouw' && w.p.theme_boven ? w.p.theme_boven : w.p.theme) : '');
      for (const id of ids) out.push(absentOn(notes, id, date)
        ? { leader:id, pref:'leiding', title:'Morgen sta je ingepland ⚠️', body:`Je hebt aangegeven dat je dan niet kunt (${grp}). Heb je al een vervanger?`, url:APP_URL + '#/planning' }
        : { leader:id, pref:'leiding', title:'Morgen heb jij leiding 🙌', body:`${grp[0].toUpperCase() + grp.slice(1)}${theme ? ' · ' + theme : ''}. Om 10:30 briefing en gebed.`, url:APP_URL + '#/' });
    }
  }
  if (wat === 'vergadering'){
    const m = meetings.find(x => x.date === today), p = periods.find(x => addDays(x.start, 7 * (PERIOD_WEEKS - 1)) === today);
    const kind = m ? m.kind : p ? p.meeting : null;
    if (kind) out.push({ leader:'*', pref:'vergadering', title:'Vandaag vergadering 👥', body:`${kind === 'groot' ? 'Grote' : 'Kleine'} vergadering om 12:45, na de dienst.`, url:APP_URL + '#/vergadering' });
  }
  return out;
}

// ---------- Versturen ----------
const json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers:{ ...CORS, 'content-type':'application/json' } });
Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers:CORS });
  const wat = new URL(req.url).searchParams.get('wat') || '';
  const db = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
  let msgs, onlyLeader = null;
  if (wat === 'test'){
    const token = (req.headers.get('authorization') || '').replace(/^Bearer /i, '');
    const { data } = await db.auth.getUser(token);
    const { data:l } = data?.user ? await db.from('leaders').select('id').eq('user_id', data.user.id).eq('invited', true).maybeSingle() : { data:null };
    if (!l) return json({ error:'Niet ingelogd' }, 401);
    onlyLeader = l.id;
    msgs = [{ leader:l.id, pref:null, title:'Het werkt! 🎉', body:'Je krijgt nu meldingen van de kinderkerk-app.', url:APP_URL }];
  } else {
    const geheim = Deno.env.get('KK_GEHEIM');
    if (!geheim || req.headers.get('x-kk-geheim') !== geheim) return json({ error:'Geen toegang' }, 401);
    const [sundays, meetings, periods, notes] = await Promise.all([
      db.from('sundays').select('*').gte('date', todayNL()).lte('date', addDays(todayNL(), 2)),
      db.from('meetings').select('date,kind').eq('date', todayNL()),
      db.from('periods').select('*'),
      db.from('notes').select('text').like('text', 'afwezig:%'),
    ]).then(r => r.map(x => x.data || []));
    msgs = berichten(wat, todayNL(), { sundays, meetings, periods, notes });
  }
  if (!msgs.length) return json({ sent:0 });
  webpush.setVapidDetails(APP_URL, Deno.env.get('VAPID_PUBLIC'), Deno.env.get('VAPID_PRIVATE'));
  let q = db.from('push_subs').select('*');
  if (onlyLeader) q = q.eq('leader_id', onlyLeader);
  const { data:subs } = await q;
  let sent = 0, removed = 0;
  for (const m of msgs) for (const s of (subs || []).filter(s => (m.leader === '*' || s.leader_id === m.leader) && (!m.pref || s.prefs?.[m.pref] !== false))){
    try { await webpush.sendNotification(s.sub, JSON.stringify({ title:m.title, body:m.body, url:m.url })); sent++; }
    catch(e){ if (e.statusCode === 404 || e.statusCode === 410){ await db.from('push_subs').delete().eq('endpoint', s.endpoint); removed++; } else console.error(e); }
  }
  return json({ sent, removed });
});
