-- =====================================================================
-- Agenda-koppeling: persoonlijke code per leiding voor de agenda-link.
-- Draai dit ná schema.sql (SQL Editor → New query → Run). Opnieuw draaien kan geen kwaad.
-- Iedereen ziet en beheert alleen zijn eigen code. De Edge Function "agenda" leest de codes met de
-- service-sleutel die alleen binnen Supabase bestaat.
-- =====================================================================
create table if not exists public.calendar_tokens (
  leader_id uuid primary key references public.leaders(id) on delete cascade,
  token     uuid not null unique default gen_random_uuid()
);
alter table public.calendar_tokens enable row level security;

create or replace function public.my_leader_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from public.leaders where user_id = auth.uid() and invited;
$$;

drop policy if exists "eigen agenda-code" on public.calendar_tokens;
create policy "eigen agenda-code" on public.calendar_tokens
  for all to authenticated using (leader_id = public.my_leader_id()) with check (leader_id = public.my_leader_id());

grant select, insert, update, delete on public.calendar_tokens to authenticated;
revoke all on public.calendar_tokens from anon;
