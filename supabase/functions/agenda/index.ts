// Agenda-koppeling voor de kinderkerk-app (Supabase Edge Function "agenda").
// Een telefoonagenda abonneert zich op deze link en haalt zelf de wijzigingen op:
//   https://<project>.supabase.co/functions/v1/agenda?t=<persoonlijke code>&wat=mijn|alles
// "mijn"  = alleen de zondagen waarop jij leiding hebt + de vergaderingen
// "alles" = elke zondag (jouw beurten duidelijk gemarkeerd) + de vergaderingen
// De persoonlijke code staat in de tabel calendar_tokens (zie supabase/agenda.sql); de app maakt hem aan
// onder Mijn account. Zet bij deze functie "Verify JWT" uit: een agenda-app kan niet inloggen.
import { createClient } from 'jsr:@supabase/supabase-js@2';

// ---------- Tijden (van Jonathan) ----------
const KK_START = '1030', KK_END = '1215';               // kinderkerk: 10:30 briefing, dienst klaar ± 12:15
const MEETING_START = '1245';                            // vergadering na de dienst
const MEETING_MIN = { groot:90, klein:30 };
const PERIOD_WEEKS = 7;

// ---------- Datums (als tekst 'YYYY-MM-DD', rekenen op 12:00 UTC zodat zomertijd niet stoort) ----------
const day = s => new Date(s + 'T12:00:00Z');
const iso = d => d.toISOString().slice(0, 10);
const addDays = (s, n) => { const d = day(s); d.setUTCDate(d.getUTCDate() + n); return iso(d); };
const weekday = s => day(s).getUTCDay();
const nextSunday = s => addDays(s, (7 - weekday(s)) % 7);
const compact = s => s.replace(/-/g, '');
const addMinutes = (hhmm, min) => { const t = +hhmm.slice(0, 2) * 60 + +hhmm.slice(2) + min; return String(Math.floor(t / 60)).padStart(2, '0') + String(t % 60).padStart(2, '0'); };

// ---------- Planning (zelfde regels als in de app) ----------
function weekInfo(date, periods){
  const p = periods.filter(x => x.start <= date).sort((a, b) => a.start.localeCompare(b.start)).pop();
  if (!p) return null;
  const week = Math.round((day(date) - day(p.start)) / 6048e5) + 1;
  return week > PERIOD_WEEKS ? null : { p, week, special:week === 6 ? 'Bidden' : week === 7 ? 'Puntenwinkeltje' : '' };
}
const periodTheme = (p, grp) => grp === 'boven' && p.theme_boven ? p.theme_boven : p.theme;
const periodSplit = p => !!p.theme_boven && p.theme_boven !== p.theme;
function topic(s, date, grp, periods){
  const w = weekInfo(date, periods), def = w ? w.special || periodTheme(w.p, grp) : '';
  if (grp === 'onder') return { theme:s.theme || def, passage:s.passage || '' };
  const split = w && periodSplit(w.p);
  return { theme:s.theme_boven || (split ? def : s.theme || def), passage:s.passage_boven || (split ? '' : s.passage || '') };
}

// ---------- iCalendar ----------
const esc = t => String(t ?? '').replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n');
function fold(line){   // regels van max. 75 bytes
  const enc = new TextEncoder(), out = [];
  let cur = '', n = 0;
  for (const ch of line){
    const b = enc.encode(ch).length;
    if (n + b > (out.length ? 74 : 75)){ out.push(cur); cur = ''; n = 0; }
    cur += ch; n += b;
  }
  out.push(cur);
  return out.join('\r\n ');
}
const VTIMEZONE = ['BEGIN:VTIMEZONE','TZID:Europe/Amsterdam',
  'BEGIN:DAYLIGHT','TZOFFSETFROM:+0100','TZOFFSETTO:+0200','TZNAME:CEST','DTSTART:19700329T020000','RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=-1SU','END:DAYLIGHT',
  'BEGIN:STANDARD','TZOFFSETFROM:+0200','TZOFFSETTO:+0100','TZNAME:CET','DTSTART:19701025T030000','RRULE:FREQ=YEARLY;BYMONTH=10;BYDAY=-1SU','END:STANDARD',
  'END:VTIMEZONE'];
function vevent({ uid, date, start, end, summary, description, free, stamp }){
  return ['BEGIN:VEVENT', `UID:${uid}`, `DTSTAMP:${stamp}`,
    `DTSTART;TZID=Europe/Amsterdam:${compact(date)}T${start}00`, `DTEND;TZID=Europe/Amsterdam:${compact(date)}T${end}00`,
    `SUMMARY:${esc(summary)}`, `DESCRIPTION:${esc(description)}`, `TRANSP:${free ? 'TRANSPARENT' : 'OPAQUE'}`, 'END:VEVENT'];
}

/* Bouwt de agenda. data = { me, leaders, sundays, periods, meetings, agenda }, wat = 'mijn' | 'alles' */
function buildIcs(data, wat, today, now = new Date()){
  const { me, leaders, sundays, periods, meetings, agenda } = data;
  const stamp = now.toISOString().replace(/[-:]/g, '').slice(0, 15) + 'Z';
  const name = id => leaders.find(l => l.id === id)?.name || '';
  const names = ids => (ids || []).map(name).filter(Boolean).join(', ') || 'nog niemand';
  const from = addDays(today, -56), to = addDays(today, 366);
  const byDate = Object.fromEntries(sundays.map(s => [s.date, s]));
  const empty = date => ({ date, theme:'', passage:'', theme_boven:'', passage_boven:'', prep:'', onder:[], boven:[] });
  let dates;
  if (wat === 'alles'){ dates = []; for (let d = nextSunday(from); d <= addDays(today, 182); d = addDays(d, 7)) dates.push(d); }
  else dates = sundays.filter(s => s.date >= from && s.date <= to && [...(s.onder || []), ...(s.boven || [])].includes(me.id)).map(s => s.date).sort();
  const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//De Deur//Kinderkerk-app//NL', 'CALSCALE:GREGORIAN', 'METHOD:PUBLISH',
    `X-WR-CALNAME:${wat === 'alles' ? 'Kinderkerk' : 'Kinderkerk – mijn beurten'}`, 'X-WR-TIMEZONE:Europe/Amsterdam',
    'REFRESH-INTERVAL;VALUE=DURATION:PT1H', 'X-PUBLISHED-TTL:PT1H', ...VTIMEZONE];
  for (const date of dates){
    const s = byDate[date] || empty(date), w = weekInfo(date, periods);
    const grp = (s.onder || []).includes(me.id) ? 'onder' : (s.boven || []).includes(me.id) ? 'boven' : '';
    const o = topic(s, date, 'onder', periods), b = topic(s, date, 'boven', periods);
    const desc = [];
    if (grp) desc.push('10:30 korte briefing en openen in gebed', '10:45–11:00 alles klaarzetten', '');
    if (o.theme === b.theme && o.passage === b.passage){ if (o.theme) desc.push('Thema: ' + o.theme); if (o.passage) desc.push('Bijbelgedeelte: ' + o.passage); }
    else { desc.push(`Onderbouw: ${o.theme || '–'}${o.passage ? ' (' + o.passage + ')' : ''}`, `Bovenbouw: ${b.theme || '–'}${b.passage ? ' (' + b.passage + ')' : ''}`); }
    if (s.prep) desc.push('Voorbereiding: ' + s.prep);
    desc.push('', 'Leiding onderbouw: ' + names(s.onder), 'Leiding bovenbouw: ' + names(s.boven));
    if (w) desc.push('', `Week ${w.week} van ${PERIOD_WEEKS} · ${w.p.theme}${w.week === 6 ? ' · bidden' : w.week === 7 ? ' · puntenwinkeltje' : ''}`);
    const summary = grp ? `Kinderkerk: jij hebt leiding (${grp === 'onder' ? 'onderbouw' : 'bovenbouw'})` : 'Kinderkerk';
    lines.push(...vevent({ uid:`zondag-${compact(date)}-${me.id}@kinderkerk-dedeur`, date, start:KK_START, end:KK_END, summary,
      description:desc.join('\n').trim(), free:!grp, stamp }));
  }
  // vergaderingen: opgeslagen, plus week 7 van elke periode waarvoor nog geen vergadering bestaat
  const list = meetings.map(m => ({ ...m }));
  periods.forEach(p => { const d = addDays(p.start, 7 * (PERIOD_WEEKS - 1)); if (!list.some(m => m.date === d)) list.push({ id:'p-' + p.id, date:d, kind:p.meeting }); });
  for (const m of list.filter(m => m.date >= from && m.date <= to)){
    const items = agenda.filter(a => a.meeting_id === m.id).sort((a, b) => (a.sort || 0) - (b.sort || 0)).map(a => '• ' + a.title);
    const desc = [items.length ? 'Agenda:\n' + items.join('\n') : 'Nog geen agendapunten.', m.notulist ? '\nNotulist: ' + name(m.notulist) : ''].join('\n').trim();
    lines.push(...vevent({ uid:`vergadering-${m.id}@kinderkerk-dedeur`, date:m.date, start:MEETING_START, end:addMinutes(MEETING_START, MEETING_MIN[m.kind] || 30),
      summary:`${m.kind === 'groot' ? 'Grote' : 'Kleine'} vergadering kinderkerk`, description:desc, stamp }));
  }
  lines.push('END:VCALENDAR');
  return lines.map(fold).join('\r\n') + '\r\n';
}

// ---------- Webadres ----------
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
Deno.serve(async req => {
  const url = new URL(req.url), t = url.searchParams.get('t') || '', wat = url.searchParams.get('wat') === 'alles' ? 'alles' : 'mijn';
  if (!UUID.test(t)) return new Response('Deze agenda-link klopt niet.', { status:404 });
  const sb = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'), { auth:{ persistSession:false } });
  const { data:tok } = await sb.from('calendar_tokens').select('leader_id').eq('token', t).maybeSingle();
  if (!tok) return new Response('Deze agenda-link werkt niet meer. Maak een nieuwe in de app (Mijn account).', { status:404 });
  const q = (table, cols) => sb.from(table).select(cols).then(r => { if (r.error) throw r.error; return r.data; });
  try {
    const [leaders, sundays, periods, meetings, agenda] = await Promise.all([
      q('leaders', 'id,name,groep'), q('sundays', '*'), q('periods', '*'), q('meetings', '*'), q('agenda_items', 'meeting_id,title,sort')]);
    const me = leaders.find(l => l.id === tok.leader_id);
    if (!me) return new Response('Onbekende leiding.', { status:404 });
    const today = new Date().toLocaleDateString('sv-SE', { timeZone:'Europe/Amsterdam' });
    return new Response(buildIcs({ me, leaders, sundays, periods, meetings, agenda }, wat, today), {
      headers:{ 'Content-Type':'text/calendar; charset=utf-8', 'Content-Disposition':'inline; filename="kinderkerk.ics"', 'Cache-Control':'no-cache' } });
  } catch(e){
    console.error(e);
    return new Response('De agenda kon even niet worden geladen.', { status:500 });
  }
});
