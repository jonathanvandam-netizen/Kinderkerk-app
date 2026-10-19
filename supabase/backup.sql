-- =====================================================================
-- Automatische back-ups: elke zondagavond een kopie van alle gegevens in de tabel backups.
-- De laatste 12 blijven bewaard (ongeveer 3 maanden). Alleen beheerders kunnen ze zien en downloaden
-- (in de app: Meer → Gegevens → Automatische back-ups). Draai dit ná schema.sql; opnieuw draaien kan geen kwaad.
-- =====================================================================
create table if not exists public.backups (
  id       bigint generated always as identity primary key,
  taken_at timestamptz not null default now(),
  data     jsonb not null
);
alter table public.backups enable row level security;
drop policy if exists "beheerder ziet back-ups" on public.backups;
create policy "beheerder ziet back-ups" on public.backups
  for select to authenticated using (public.is_admin());
grant select on public.backups to authenticated;
revoke all on public.backups from anon;

create or replace function public.make_backup() returns void
language plpgsql security definer set search_path = public as $$
begin
  -- via de app alleen voor beheerders; de tijdklok (pg_cron) heeft geen gebruiker en mag altijd
  if auth.uid() is not null and not public.is_admin() then
    raise exception 'Alleen een beheerder kan een back-up maken';
  end if;
  insert into public.backups (data) select jsonb_build_object(
    'leaders',         (select coalesce(jsonb_agg(to_jsonb(t) - 'user_id'), '[]') from public.leaders t),
    'kids',            (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.kids t),
    'checkins',        (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.checkins t),
    'leader_checkins', (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.leader_checkins t),
    'notes',           (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.notes t),
    'rosters',         (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.rosters t),
    'illnesses',       (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.illnesses t),
    'sundays',         (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.sundays t),
    'periods',         (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.periods t),
    'meetings',        (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.meetings t),
    'agenda_items',    (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.agenda_items t),
    'actions',         (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.actions t),
    'settings',        (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.settings t),
    'marks',           (select coalesce(jsonb_agg(to_jsonb(t)), '[]') from public.marks t));
  delete from public.backups where id not in (select id from public.backups order by taken_at desc limit 12);
end $$;
revoke execute on function public.make_backup() from public, anon;
grant execute on function public.make_backup() to authenticated;

-- Tijdklok: elke zondag om 20:00 UTC (21:00 of 22:00 Nederlandse tijd)
create extension if not exists pg_cron;
select cron.schedule('kinderkerk-backup', '0 20 * * 0', 'select public.make_backup()');

-- Meteen een eerste back-up maken
select public.make_backup();
