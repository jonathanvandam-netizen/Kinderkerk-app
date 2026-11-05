-- =====================================================================
-- Rol "planner": mag de planning aanpassen (leiding per zondag, thema's, periodes, gouden week, planning vullen).
-- Gewone leiding mag de planning alleen bekijken en met "Ik kan niet" doorgeven dat ze niet kunnen.
-- Draai dit ná schema.sql (SQL Editor → New query → Run). Opnieuw draaien kan geen kwaad.
-- =====================================================================
alter table public.leaders drop constraint if exists leaders_role_check;
alter table public.leaders add constraint leaders_role_check check (role in ('leiding','planner','beheerder'));

create or replace function public.is_planner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.leaders where user_id = auth.uid() and invited and role in ('planner','beheerder'));
$$;

-- Planning per zondag: iedereen van de leiding ziet hem, alleen planners en beheerders passen hem aan
drop policy if exists "leiding" on public.sundays;
drop policy if exists "leiding ziet planning" on public.sundays;
drop policy if exists "planner past planning aan" on public.sundays;
create policy "leiding ziet planning" on public.sundays for select to authenticated using (public.is_leader());
create policy "planner past planning aan" on public.sundays for all to authenticated using (public.is_planner()) with check (public.is_planner());

-- Periodes: planners en beheerders
drop policy if exists "beheerder beheert periodes" on public.periods;
drop policy if exists "planner beheert periodes" on public.periods;
create policy "planner beheert periodes" on public.periods for all to authenticated using (public.is_planner()) with check (public.is_planner());

-- Gouden week (instelling 'gouden'): ook planners
drop policy if exists "planner past gouden week aan" on public.settings;
create policy "planner past gouden week aan" on public.settings for all to authenticated
  using (public.is_planner() and key = 'gouden') with check (public.is_planner() and key = 'gouden');
