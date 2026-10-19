-- =====================================================================
-- Uitnodigen via WhatsApp: een beheerder maakt in de app een persoonlijke link voor iemand in het team.
-- Die persoon opent de link, vult zelf zijn e-mailadres in en kan daarna inloggen met een code uit de mail.
-- Een link werkt één keer en is 14 dagen geldig. Draai dit ná schema.sql; opnieuw draaien kan geen kwaad.
-- =====================================================================
create table if not exists public.invite_links (
  token     uuid primary key default gen_random_uuid(),
  leader_id uuid not null references public.leaders(id) on delete cascade,
  expires   timestamptz not null default now() + interval '14 days'
);
alter table public.invite_links enable row level security;   -- geen regels: alleen de functies hieronder komen erbij
revoke all on public.invite_links from anon, authenticated;

-- Beheerder maakt een link (een oude link voor dezelfde persoon vervalt)
create or replace function public.make_invite_link(leader uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  if not public.is_admin() then raise exception 'Alleen een beheerder kan uitnodigen'; end if;
  if exists (select 1 from public.leaders where id = leader and user_id is not null) then
    raise exception 'Deze leiding heeft al een account';
  end if;
  delete from public.invite_links where leader_id = leader;
  insert into public.invite_links (leader_id) values (leader) returning token into t;
  return t;
end $$;

-- Voor het welkomstscherm: de voornaam bij een geldige link (leeg = verlopen of al gebruikt)
create or replace function public.invite_name(t uuid) returns text
language sql stable security definer set search_path = public as $$
  select l.name from public.invite_links i join public.leaders l on l.id = i.leader_id
   where i.token = t and i.expires > now() and l.user_id is null;
$$;

-- De uitgenodigde vult zijn e-mailadres in: daarmee mag hij inloggen
create or replace function public.accept_invite(t uuid, mail text) returns void
language plpgsql security definer set search_path = public as $$
declare lid uuid; m text := lower(trim(mail));
begin
  if m !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Vul een geldig e-mailadres in'; end if;
  select i.leader_id into lid from public.invite_links i join public.leaders l on l.id = i.leader_id
   where i.token = t and i.expires > now() and l.user_id is null;
  if lid is null then raise exception 'Deze uitnodiging is verlopen of al gebruikt'; end if;
  if exists (select 1 from public.leaders where email = m and id <> lid) then
    raise exception 'Dit e-mailadres hoort al bij iemand anders in het team';
  end if;
  perform set_config('kk.claim', 'on', true);   -- de beveiliging van leaders mag dit toestaan
  update public.leaders set email = m, invited = true where id = lid;
  delete from public.invite_links where token = t;
end $$;

revoke execute on function public.make_invite_link(uuid) from public, anon;
grant execute on function public.make_invite_link(uuid) to authenticated;
grant execute on function public.invite_name(uuid) to anon, authenticated;
grant execute on function public.accept_invite(uuid, text) to anon, authenticated;
