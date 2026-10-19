-- =====================================================================
-- Meldingen op je telefoon. Standaard staan ze UIT: wie wil, zet ze aan in de app onder Mijn account.
-- Twee meldingen: zaterdagavond "Morgen heb jij leiding" en zondagochtend "Vandaag vergadering".
-- Draai dit ná schema.sql en agenda.sql (SQL Editor → New query → Run). Opnieuw draaien kan geen kwaad.
-- De installeerpagina (stap 9) vult de sleutel, het geheim en de project-URL voor je in.
-- =====================================================================
create table if not exists public.push_subs (
  endpoint   text primary key,                       -- adres van één telefoon/browser
  leader_id  uuid not null references public.leaders(id) on delete cascade,
  sub        jsonb not null,                         -- gegevens om een melding te kunnen sturen
  prefs      jsonb not null default '{"leiding":true,"vergadering":true}',
  created_at timestamptz not null default now()
);
alter table public.push_subs enable row level security;

create or replace function public.my_leader_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.leaders where user_id = auth.uid() and invited;
$$;

drop policy if exists "eigen meldingen" on public.push_subs;
create policy "eigen meldingen" on public.push_subs
  for all to authenticated using (leader_id = public.my_leader_id()) with check (leader_id = public.my_leader_id());
grant select, insert, update, delete on public.push_subs to authenticated;
revoke all on public.push_subs from anon;

-- De publieke sleutel heeft de app nodig om meldingen aan te kunnen zetten (niet geheim)
insert into public.settings (key, value) values ('vapid_public', to_jsonb('PUBLIEKE_SLEUTEL'::text))
  on conflict (key) do update set value = excluded.value;

-- Tijdklok (tijden in UTC): zaterdag 17:00 = 18:00/19:00 Nederlandse tijd, zondag 08:00 = 09:00/10:00
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.schedule('kinderkerk-melding-leiding', '0 17 * * 6',
  $$ select net.http_post(url := 'PROJECT_URL/functions/v1/meldingen?wat=leiding', headers := '{"x-kk-geheim":"GEHEIM_WAARDE"}'::jsonb) $$);
select cron.schedule('kinderkerk-melding-vergadering', '0 8 * * 0',
  $$ select net.http_post(url := 'PROJECT_URL/functions/v1/meldingen?wat=vergadering', headers := '{"x-kk-geheim":"GEHEIM_WAARDE"}'::jsonb) $$);
