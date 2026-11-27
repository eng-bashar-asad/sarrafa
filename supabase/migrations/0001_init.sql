-- Each row belongs to the signed-in user (owner); RLS lets a user see and change only their own rows.
create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null check (length(trim(name)) between 1 and 80),
  country text not null,
  kind text not null default 'person' check (kind in ('person','company','branch')),
  created_at timestamptz not null default now(),
  unique (owner, name, country)
);
create sequence public.ops_no_seq start 1001;
create table public.ops (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null default auth.uid() references auth.users on delete cascade,
  no bigint not null default nextval('public.ops_no_seq') unique,
  data jsonb not null check (jsonb_typeof(data->'entries') = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ops_owner_idx on public.ops(owner);
create table public.settings (
  owner uuid primary key default auth.uid() references auth.users on delete cascade,
  data jsonb not null default '{}'::jsonb
);
alter table public.accounts enable row level security;
alter table public.ops enable row level security;
alter table public.settings enable row level security;
create policy own_accounts on public.accounts for all to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy own_ops on public.ops for all to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
create policy own_settings on public.settings for all to authenticated using (owner = (select auth.uid())) with check (owner = (select auth.uid()));
-- Operations are never deleted (cancel = reversal entries), so no one gets delete on ops.
revoke delete on public.ops from authenticated, anon;
-- An account with movements cannot be deleted.
create or replace function public.account_in_use() returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if exists (select 1 from public.ops o, jsonb_array_elements(o.data->'entries') e where o.owner = old.owner and e->>'acc' = old.id::text) then
    raise exception 'الحساب عليه حركات ولا يمكن حذفه';
  end if;
  return old;
end $$;
create trigger accounts_no_delete_used before delete on public.accounts for each row execute function public.account_in_use();
