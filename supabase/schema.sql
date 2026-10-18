-- =====================================================================
-- Kinderkerk De Deur — database voor Supabase
-- Plak dit hele bestand in Supabase: SQL Editor → New query → Run.
-- Pas eerst onderaan het e-mailadres van de eerste beheerder aan.
--
-- Regels:
--  * Alleen wie is uitgenodigd kan een account maken.
--  * Iedereen met een account is leiding en ziet alle gegevens.
--  * Alleen beheerders mogen uitnodigen, leiding beheren, kinderen
--    verwijderen en kinderziektes aanpassen.
-- =====================================================================

-- ---------- Tabellen ----------
create table public.invites (
  email      text primary key check (email = lower(email)),
  groep      text not null default '' check (groep in ('onder','boven','')),
  role       text not null default 'leiding' check (role in ('leiding','beheerder')),
  invited_by text not null default '',
  date       date not null default current_date
);

create table public.leaders (
  id    uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  name  text not null default '',
  groep text not null default '' check (groep in ('onder','boven','')),
  role  text not null default 'leiding' check (role in ('leiding','beheerder'))
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

create table public.illnesses (
  id     uuid primary key default gen_random_uuid(),
  name   text not null,
  status text not null check (status in ('ok','warn','bad')),
  text   text not null default ''
);

-- ---------- Wie is leiding / beheerder? ----------
create function public.is_leader() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leaders where id = auth.uid());
$$;

create function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leaders where id = auth.uid() and role = 'beheerder');
$$;

-- ---------- Alleen op uitnodiging ----------
-- Supabase maakt een account aan bij de eerste inlogpoging; dat mag alleen
-- als het e-mailadres is uitgenodigd.
create function public.only_invited() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.invites where email = lower(new.email)) then
    raise exception 'Dit e-mailadres is niet uitgenodigd';
  end if;
  return new;
end $$;

create trigger only_invited before insert on auth.users
  for each row execute function public.only_invited();

-- Na het inloggen zet de app de uitnodiging om in een leiding-account.
create function public.claim_invite() returns void
language plpgsql security definer set search_path = public as $$
declare inv public.invites;
begin
  if auth.uid() is null or exists (select 1 from public.leaders where id = auth.uid()) then return; end if;
  select * into inv from public.invites where email = lower(auth.jwt() ->> 'email');
  if not found then return; end if;
  insert into public.leaders (id, email, name, groep, role) values (auth.uid(), inv.email, '', inv.groep, inv.role);
  delete from public.invites where email = inv.email;
end $$;
revoke execute on function public.claim_invite() from public, anon;
grant execute on function public.claim_invite() to authenticated;

-- Leiding mag eigen naam/groep aanpassen, maar alleen een beheerder wijzigt rollen.
create function public.protect_leader() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.id <> old.id or new.email <> old.email then
    raise exception 'Account-gegevens kunnen niet worden gewijzigd';
  end if;
  if new.role <> old.role and not public.is_admin() then
    raise exception 'Alleen een beheerder kan rollen wijzigen';
  end if;
  return new;
end $$;

create trigger protect_leader before update on public.leaders
  for each row execute function public.protect_leader();

-- ---------- Beveiliging per rij (row level security) ----------
alter table public.invites         enable row level security;
alter table public.leaders         enable row level security;
alter table public.kids            enable row level security;
alter table public.checkins        enable row level security;
alter table public.leader_checkins enable row level security;
alter table public.notes           enable row level security;
alter table public.rosters         enable row level security;
alter table public.illnesses       enable row level security;
alter table public.sundays         enable row level security;
alter table public.periods         enable row level security;

create policy "beheerders beheren uitnodigingen" on public.invites
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "leiding ziet leiding" on public.leaders
  for select to authenticated using (public.is_leader());
create policy "eigen gegevens of beheerder" on public.leaders
  for update to authenticated using (id = auth.uid() or public.is_admin()) with check (id = auth.uid() or public.is_admin());
create policy "beheerder trekt toegang in" on public.leaders
  for delete to authenticated using (public.is_admin() and id <> auth.uid());

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

create policy "leiding ziet periodes" on public.periods
  for select to authenticated using (public.is_leader());
create policy "beheerder beheert periodes" on public.periods
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
  public.invites, public.leaders, public.kids, public.checkins, public.leader_checkins,
  public.notes, public.rosters, public.illnesses, public.sundays, public.periods;

-- ---------- Eerste beheerder ----------
-- Vervang het e-mailadres hieronder door dat van jezelf.
insert into public.invites (email, groep, role, invited_by)
values (lower('JOUW-EMAIL@voorbeeld.nl'), 'boven', 'beheerder', 'installatie');
