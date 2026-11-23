-- LEVEL UP: run this once in Supabase Dashboard > SQL Editor > New query.
-- Uses only the public anon key in the browser; never put a service_role key in index.html.

create table if not exists public.player_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.player_saves enable row level security;
drop policy if exists "Players read own save" on public.player_saves;
create policy "Players read own save" on public.player_saves for select to authenticated using (auth.uid() = user_id);
drop policy if exists "Players insert own save" on public.player_saves;
create policy "Players insert own save" on public.player_saves for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Players update own save" on public.player_saves;
create policy "Players update own save" on public.player_saves for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null default 'Player',
  created_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists "Signed-in players can search profiles" on public.profiles;
create policy "Signed-in players can search profiles" on public.profiles for select to authenticated using (true);
drop policy if exists "Players create own profile" on public.profiles;
create policy "Players create own profile" on public.profiles for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Players update own profile" on public.profiles;
create policy "Players update own profile" on public.profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.level_up_create_profile()
returns trigger language plpgsql security definer set search_path = '' as $$
declare chosen_username text;
begin
  chosen_username := lower(coalesce(new.raw_user_meta_data ->> 'username', 'player_' || substr(new.id::text, 1, 8)));
  insert into public.profiles(user_id, username, display_name)
  values (new.id, chosen_username, chosen_username)
  on conflict (user_id) do nothing;
  return new;
end;
$$;
drop trigger if exists level_up_create_profile on auth.users;
create trigger level_up_create_profile after insert on auth.users
for each row execute function public.level_up_create_profile();

-- Backfill profiles for accounts that existed before this setup was installed.
insert into public.profiles(user_id, username, display_name)
select id, lower(coalesce(raw_user_meta_data ->> 'username', 'player_' || substr(id::text, 1, 8))),
       lower(coalesce(raw_user_meta_data ->> 'username', 'player_' || substr(id::text, 1, 8)))
from auth.users on conflict (user_id) do nothing;

create table if not exists public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  receiver_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  check (sender_id <> receiver_id)
);
create unique index if not exists friend_requests_one_pending on public.friend_requests(sender_id, receiver_id) where status = 'pending';
alter table public.friend_requests enable row level security;
drop policy if exists "Players view their own requests" on public.friend_requests;
create policy "Players view their own requests" on public.friend_requests for select to authenticated using (auth.uid() = sender_id or auth.uid() = receiver_id);
drop policy if exists "Players send friend requests" on public.friend_requests;
create policy "Players send friend requests" on public.friend_requests for insert to authenticated with check (auth.uid() = sender_id and status = 'pending');

create table if not exists public.friendships (
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
alter table public.friendships enable row level security;
drop policy if exists "Players view their friendships" on public.friendships;
create policy "Players view their friendships" on public.friendships for select to authenticated using (auth.uid() = user_a or auth.uid() = user_b);

create or replace function public.accept_friend_request(request_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare req public.friend_requests%rowtype;
begin
  select * into req from public.friend_requests
  where id = request_id and receiver_id = auth.uid() and status = 'pending'
  for update;
  if not found then raise exception 'Friend request not found'; end if;
  insert into public.friendships(user_a, user_b)
  values (least(req.sender_id, req.receiver_id), greatest(req.sender_id, req.receiver_id))
  on conflict do nothing;
  update public.friend_requests set status = 'accepted' where id = request_id;
end;
$$;
grant execute on function public.accept_friend_request(uuid) to authenticated;
