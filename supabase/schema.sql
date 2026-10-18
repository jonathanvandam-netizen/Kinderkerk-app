-- =====================================================================
-- Kinderkerk De Deur — database voor Supabase
-- Plak dit hele bestand in Supabase: SQL Editor → New query → Run.
-- Pas eerst onderaan het e-mailadres van de eerste beheerder aan.
--
-- Regels:
--  * Leiding kan in het team staan zonder account (voor de planning).
--  * Pas na "Uitnodigen" (e-mailadres + invited) kan iemand inloggen.
--  * Iedereen die is ingelogd en gekoppeld aan een leiding-rij ziet alle gegevens.
--  * Alleen beheerders mogen uitnodigen, leiding beheren, kinderen
--    verwijderen en kinderziektes aanpassen.
-- =====================================================================

-- ---------- Tabellen ----------
-- Leiding. user_id is leeg zolang iemand (nog) geen account heeft.
create table public.leaders (
  id      uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  email   text unique check (email = lower(email)),
  name    text not null default '',
  groep   text not null default '' check (groep in ('onder','boven','')),
  role    text not null default 'leiding' check (role in ('leiding','beheerder')),
  invited boolean not null default false,   -- mag inloggen
  away    text not null default ''           -- bijv. 'Zwangerschapsverlof'
);

create table public.kids (
  id      uuid primary key default gen_random_uuid(),
  name    text not null check (name <> ''),
  groep   text not null check (groep in ('onder','boven','bezoeker')),
  created date not null default current_date,
  birthdate date
);

create table public.checkins (
  id         uuid primary key default gen_random_uuid(),
  kid_id     uuid not null references public.kids(id) on delete cascade,
  date       date not null,
  items      text[] not null default '{}',
  prayer     text not null default '',
  checked_by text not null default '',
  unique (kid_id, date)
);
create index on public.checkins (date);

create table public.leader_checkins (
  leader_id uuid not null references public.leaders(id) on delete cascade,
  date      date not null,
  primary key (leader_id, date)
);

create table public.notes (
  id         uuid primary key default gen_random_uuid(),
  date       date not null default current_date,
  author     text not null default '',
  text       text not null,
  created_at timestamptz not null default now()
);

create table public.rosters (
  kind   text not null check (kind in ('sheets','bidden')),
  date   date not null,
  kid_id uuid references public.kids(id) on delete set null,
  primary key (kind, date)
);

-- Planning per zondag: thema en leiding (lijsten met leaders.id)
create table public.sundays (
  date    date primary key,
  theme   text not null default '',
  passage text not null default '',
  theme_boven   text not null default '',   -- leeg = zelfde als onderbouw
  passage_boven text not null default '',
  prep    text not null default '',
  onder   uuid[] not null default '{}',
  boven   uuid[] not null default '{}'
);

-- Periodes van 7 weken met een thema per groep; week 7 = vergadering (klein/groot, om en om)
create table public.periods (
  id      uuid primary key default gen_random_uuid(),
  start   date not null unique,
  theme   text not null,                    -- thema onderbouw (of beide)
  theme_boven text not null default '',     -- leeg = zelfde als onderbouw
  meeting text not null default 'klein' check (meeting in ('klein','groot'))
);

-- Vergaderingen met agendapunten (+ notulen) en actiepunten
create table public.meetings (
  id   uuid primary key default gen_random_uuid(),
  date date not null unique,
  kind text not null default 'klein' check (kind in ('klein','groot'))
);

create table public.agenda_items (
  id         uuid primary key default gen_random_uuid(),
  meeting_id uuid not null references public.meetings(id) on delete cascade,
  title      text not null,
  notes      text not null default '',
  author     text not null default '',
  sort       bigint not null default 0,
  created_at timestamptz not null default now()
);

create table public.actions (
  id         uuid primary key default gen_random_uuid(),
  meeting_id uuid references public.meetings(id) on delete set null,
  agenda_id  uuid references public.agenda_items(id) on delete set null,
  text       text not null,
  who        uuid references public.leaders(id) on delete set null,
  due        date,
  done       boolean not null default false,
  author     text not null default '',
  created_at timestamptz not null default now()
);

-- Instellingen, bijv. hoeveel punten een kind krijgt (key 'points')
create table public.settings (
  key   text primary key,
  value jsonb not null
);

create table public.illnesses (
  id     uuid primary key default gen_random_uuid(),
  name   text not null,
  status text not null check (status in ('ok','warn','bad')),
  text   text not null default ''
);

-- ---------- Wie is leiding / beheerder? ----------
create function public.is_leader() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leaders where user_id = auth.uid() and invited);
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leaders where user_id = auth.uid() and invited and role = 'beheerder');
$$;

-- ---------- Alleen op uitnodiging ----------
-- Supabase maakt een account aan bij de eerste inlogpoging; dat mag alleen
-- als het e-mailadres is uitgenodigd.
create function public.only_invited() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.leaders where email = lower(new.email) and invited) then
    raise exception 'Dit e-mailadres is niet uitgenodigd';
  end if;
  return new;
end $$;

create trigger only_invited before insert on auth.users
  for each row execute function public.only_invited();

-- Na het inloggen koppelt de app het account aan de uitgenodigde leiding-rij.
create function public.claim_invite() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or exists (select 1 from public.leaders where user_id = auth.uid()) then return; end if;
  perform set_config('kk.claim', 'on', true);
  update public.leaders set user_id = auth.uid()
   where email = lower(auth.jwt() ->> 'email') and invited and user_id is null;
end $$;
revoke execute on function public.claim_invite() from public, anon;
grant execute on function public.claim_invite() to authenticated;

-- Leiding mag eigen naam/groep/verlof aanpassen; rol, e-mail en toegang alleen een beheerder.
create function public.protect_leader() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('kk.claim', true) = 'on' then return new; end if;   -- koppelen bij inloggen
  if auth.uid() is null then return new; end if;                          -- beheer via de SQL Editor
  if new.id <> old.id then raise exception 'Het id kan niet worden gewijzigd'; end if;
  if not public.is_admin() and (new.role <> old.role or new.invited <> old.invited
      or new.email is distinct from old.email or new.user_id is distinct from old.user_id) then
    raise exception 'Alleen een beheerder kan rol, e-mail of toegang wijzigen';
  end if;
  return new;
end $$;

create trigger protect_leader before update on public.leaders
  for each row execute function public.protect_leader();

-- ---------- Beveiliging per rij (row level security) ----------
alter table public.leaders         enable row level security;
alter table public.kids            enable row level security;
alter table public.checkins        enable row level security;
alter table public.leader_checkins enable row level security;
alter table public.notes           enable row level security;
alter table public.rosters         enable row level security;
alter table public.illnesses       enable row level security;
alter table public.sundays         enable row level security;
alter table public.periods         enable row level security;
alter table public.meetings        enable row level security;
alter table public.agenda_items    enable row level security;
alter table public.actions         enable row level security;
alter table public.settings        enable row level security;

create policy "leiding ziet leiding" on public.leaders
  for select to authenticated using (public.is_leader());
create policy "beheerder voegt leiding toe" on public.leaders
  for insert to authenticated with check (public.is_admin());
create policy "eigen gegevens of beheerder" on public.leaders
  for update to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy "beheerder verwijdert leiding" on public.leaders
  for delete to authenticated using (public.is_admin() and user_id is distinct from auth.uid());

create policy "leiding ziet kinderen" on public.kids
  for select to authenticated using (public.is_leader());
create policy "leiding voegt kinderen toe" on public.kids
  for insert to authenticated with check (public.is_leader());
create policy "leiding wijzigt kinderen" on public.kids
  for update to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "beheerder verwijdert kinderen" on public.kids
  for delete to authenticated using (public.is_admin());

create policy "leiding" on public.checkins
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.leader_checkins
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.notes
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.rosters
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.sundays
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.meetings
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.agenda_items
  for all to authenticated using (public.is_leader()) with check (public.is_leader());
create policy "leiding" on public.actions
  for all to authenticated using (public.is_leader()) with check (public.is_leader());

create policy "leiding ziet periodes" on public.periods
  for select to authenticated using (public.is_leader());
create policy "beheerder beheert periodes" on public.periods
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "leiding ziet instellingen" on public.settings
  for select to authenticated using (public.is_leader());
create policy "beheerder past instellingen aan" on public.settings
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "leiding ziet ziektes" on public.illnesses
  for select to authenticated using (public.is_leader());
create policy "beheerder beheert ziektes" on public.illnesses
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete on all tables in schema public to authenticated;
revoke all on all tables in schema public from anon;

-- ---------- Live bijwerken ----------
-- Zo ziet alle leiding een check-in meteen verschijnen.
alter publication supabase_realtime add table
  public.leaders, public.kids, public.checkins, public.leader_checkins,
  public.notes, public.rosters, public.illnesses, public.sundays, public.periods,
  public.meetings, public.agenda_items, public.actions, public.settings;

-- ---------- Eerste beheerder ----------
-- Vervang het e-mailadres hieronder door dat van jezelf. De rest van de leiding
-- voeg je daarna toe in de app (Meer → Team), met of zonder uitnodiging.
insert into public.leaders (email, name, groep, role, invited)
values (lower('JOUW-EMAIL@voorbeeld.nl'), 'Jonathan', 'boven', 'beheerder', true);
