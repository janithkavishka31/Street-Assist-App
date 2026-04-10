-- ============================================================
--  StreetAssist — Complete Database Schema
--  Run this once against your Supabase project
--  Order: extensions → enums → base tables → dependent tables
--         → auth trigger → RLS policies → indexes
-- ============================================================


-- ------------------------------------------------------------
-- 1. EXTENSIONS
-- ------------------------------------------------------------

create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";


-- ------------------------------------------------------------
-- 2. ENUMS
-- ------------------------------------------------------------

create type verification_status_enum as enum (
  'pending',
  'approved',
  'rejected'
);

create type help_category_enum as enum (
  'technicalAndRepair',
  'physicalAndLogistics',
  'roadsideAndEmergency',
  'errandsAndSocial'
);

create type request_scope_enum as enum (
  'help_zone_only',
  'help_zone_and_global'
);

create type request_status_enum as enum (
  'open',
  'accepted',
  'completed',
  'canceled'
);

create type zone_role_enum as enum (
  'creator',
  'member'
);

create type zone_member_status_enum as enum (
  'active',
  'left',
  'banned'
);

create type points_reason_enum as enum (
  'assist_completed',
  'bonus',
  'adjustment'
);

create type leaderboard_mode_enum as enum (
  'helper',
  'requester'
);

create type skill_key_enum as enum (
  'technical',
  'physical',
  'roadside',
  'errands'
);


-- ------------------------------------------------------------
-- 3. BASE TABLES (no foreign key dependencies)
-- ------------------------------------------------------------

-- Users (mirrors auth.users — populated via trigger)
create table public.users (
  id                uuid          primary key default uuid_generate_v4(),
  full_name         text          not null,
  email             text          unique,
  phone             text          unique,
  quick_bio         text,
  agreed_to_terms   boolean       not null default false,
  created_at        timestamptz   not null default now(),
  updated_at        timestamptz   not null default now()
);

-- Skill reference table (4 rows, seeded below)
create table public.skills (
  id      smallint        primary key generated always as identity,
  key     skill_key_enum  not null unique,
  title   text            not null
);

-- Help zones
create table public.help_zones (
  id                    uuid                      primary key default uuid_generate_v4(),
  zone_name             text                      not null,
  organization_name     text                      not null,
  join_code             text                      not null unique,
  verification_status   verification_status_enum  not null default 'pending',
  created_by_user_id    uuid                      not null references public.users(id) on delete restrict,
  created_at            timestamptz               not null default now()
);

-- Leaderboard week snapshots
create table public.leaderboard_weeks (
  id              uuid    primary key default uuid_generate_v4(),
  week_start_date date    not null unique,
  created_at      timestamptz not null default now()
);


-- ------------------------------------------------------------
-- 4. DEPENDENT TABLES
-- ------------------------------------------------------------

-- User settings (1:1 with users)
create table public.user_settings (
  user_id           uuid                not null primary key references public.users(id) on delete cascade,
  is_helper_enabled boolean             not null default false,
  default_scope     request_scope_enum  not null default 'help_zone_and_global',
  updated_at        timestamptz         not null default now()
);

-- User ↔ skill join table
create table public.user_skills (
  user_id     uuid        not null references public.users(id) on delete cascade,
  skill_id    smallint    not null references public.skills(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, skill_id)
);

-- Zone membership
create table public.zone_memberships (
  id          uuid                    primary key default uuid_generate_v4(),
  zone_id     uuid                    not null references public.help_zones(id) on delete cascade,
  user_id     uuid                    not null references public.users(id) on delete cascade,
  role        zone_role_enum          not null default 'member',
  status      zone_member_status_enum not null default 'active',
  joined_at   timestamptz             not null default now(),
  unique (zone_id, user_id)
);

-- Zone verification document submissions
create table public.help_zone_verification_submissions (
  id                    uuid                      primary key default uuid_generate_v4(),
  zone_id               uuid                      not null references public.help_zones(id) on delete cascade,
  submitted_by_user_id  uuid                      not null references public.users(id) on delete restrict,
  document_url          text                      not null,
  status                verification_status_enum  not null default 'pending',
  reviewed_by_user_id   uuid                      references public.users(id) on delete set null,
  reviewed_at           timestamptz,
  created_at            timestamptz               not null default now()
);

-- Help requests
create table public.help_requests (
  id                uuid                not null primary key default uuid_generate_v4(),
  requester_user_id uuid                not null references public.users(id) on delete restrict,
  category          help_category_enum  not null,
  service_title     text                not null,
  description       text                not null,
  scope             request_scope_enum  not null default 'help_zone_and_global',
  zone_id           uuid                references public.help_zones(id) on delete set null,
  status            request_status_enum not null default 'open',
  latitude          double precision    not null,
  longitude         double precision    not null,
  address_label     text,
  created_at        timestamptz         not null default now(),
  updated_at        timestamptz         not null default now()
);

-- Help request photos (up to 5 per request)
create table public.help_request_photos (
  id          uuid        primary key default uuid_generate_v4(),
  request_id  uuid        not null references public.help_requests(id) on delete cascade,
  photo_url   text        not null,
  sort_order  int         not null,
  created_at  timestamptz not null default now(),
  unique (request_id, sort_order),
  constraint max_sort_order check (sort_order between 0 and 4)
);

-- Help request acceptances (1:1 with request)
create table public.help_request_acceptances (
  id              uuid        primary key default uuid_generate_v4(),
  request_id      uuid        not null unique references public.help_requests(id) on delete cascade,
  helper_user_id  uuid        not null references public.users(id) on delete restrict,
  accepted_at     timestamptz not null default now(),
  completed_at    timestamptz,
  canceled_at     timestamptz
);

-- Points ledger (append-only audit trail)
create table public.points_ledger (
  id          uuid                primary key default uuid_generate_v4(),
  user_id     uuid                not null references public.users(id) on delete cascade,
  points      int                 not null,
  reason      points_reason_enum  not null,
  request_id  uuid                references public.help_requests(id) on delete set null,
  created_at  timestamptz         not null default now()
);

-- User gamification summary (denormalized for fast reads)
create table public.user_gamification (
  user_id               uuid        primary key references public.users(id) on delete cascade,
  total_points          int         not null default 0,
  weekly_assists        int         not null default 0,
  current_streak_days   int         not null default 0,
  best_streak_days      int         not null default 0,
  last_assist_at        timestamptz,
  updated_at            timestamptz not null default now()
);

-- Weekly leaderboard entries
create table public.leaderboard_entries (
  id                    uuid                    primary key default uuid_generate_v4(),
  leaderboard_week_id   uuid                    not null references public.leaderboard_weeks(id) on delete cascade,
  mode                  leaderboard_mode_enum   not null,
  user_id               uuid                    not null references public.users(id) on delete cascade,
  points                int                     not null default 0,
  rank                  int                     not null,
  title_label           text,
  unique (leaderboard_week_id, mode, user_id),
  unique (leaderboard_week_id, mode, rank)
);


-- ------------------------------------------------------------
-- 5. SEED DATA
-- ------------------------------------------------------------

insert into public.skills (key, title) values
  ('technical',  'Technical & Repair'),
  ('physical',   'Physical & Logistics'),
  ('roadside',   'Roadside & Emergency'),
  ('errands',    'Errands & Social');


-- ------------------------------------------------------------
-- 6. UPDATED_AT AUTO-UPDATE TRIGGER
-- ------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_users_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();

create trigger trg_user_settings_updated_at
  before update on public.user_settings
  for each row execute function public.set_updated_at();

create trigger trg_help_requests_updated_at
  before update on public.help_requests
  for each row execute function public.set_updated_at();

create trigger trg_user_gamification_updated_at
  before update on public.user_gamification
  for each row execute function public.set_updated_at();


-- ------------------------------------------------------------
-- 7. AUTH TRIGGER (links Supabase auth.users → public.users)
--    Fires when a new user signs up via Supabase Auth
-- ------------------------------------------------------------

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, full_name, email, phone, quick_bio, agreed_to_terms)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    coalesce(new.phone, nullif(new.raw_user_meta_data->>'phone', '')),
    nullif(new.raw_user_meta_data->>'quick_bio', ''),
    coalesce((new.raw_user_meta_data->>'agreed_to_terms')::boolean, false)
  );

  insert into public.user_settings (user_id)
  values (new.id);

  insert into public.user_gamification (user_id)
  values (new.id);

  insert into public.user_skills (user_id, skill_id)
  select
    new.id,
    s.id
  from public.skills s
  join (
    select jsonb_array_elements_text(
      coalesce(new.raw_user_meta_data->'skills', '[]'::jsonb)
    ) as key
  ) keys on s.key::text = keys.key
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();


-- ------------------------------------------------------------
-- 8. ROW LEVEL SECURITY
-- ------------------------------------------------------------

alter table public.users                             enable row level security;
alter table public.user_settings                     enable row level security;
alter table public.user_skills                       enable row level security;
alter table public.help_zones                        enable row level security;
alter table public.help_zone_verification_submissions enable row level security;
alter table public.zone_memberships                  enable row level security;
alter table public.help_requests                     enable row level security;
alter table public.help_request_photos               enable row level security;
alter table public.help_request_acceptances          enable row level security;
alter table public.points_ledger                     enable row level security;
alter table public.user_gamification                 enable row level security;
alter table public.leaderboard_weeks                 enable row level security;
alter table public.leaderboard_entries               enable row level security;
alter table public.skills                            enable row level security;

-- skills: public read
create policy "skills_public_read" on public.skills
  for select using (true);

-- users: read own row; others can read basic profile
create policy "users_read_own" on public.users
  for select using (auth.uid() = id);

create policy "users_update_own" on public.users
  for update using (auth.uid() = id);

-- user_settings: own only
create policy "user_settings_own" on public.user_settings
  for all using (auth.uid() = user_id);

-- user_skills: own only
create policy "user_skills_own" on public.user_skills
  for all using (auth.uid() = user_id);

-- help_zones: any authenticated user can read approved zones
create policy "help_zones_read" on public.help_zones
  for select using (auth.uid() is not null);

create policy "help_zones_insert" on public.help_zones
  for insert with check (auth.uid() = created_by_user_id);

create policy "help_zones_update_creator" on public.help_zones
  for update using (auth.uid() = created_by_user_id);

-- zone_memberships: members can read their zone's memberships
create policy "zone_memberships_read" on public.zone_memberships
  for select using (
    auth.uid() = user_id or
    exists (
      select 1 from public.zone_memberships zm
      where zm.zone_id = zone_memberships.zone_id
        and zm.user_id = auth.uid()
        and zm.status = 'active'
    )
  );

create policy "zone_memberships_insert_self" on public.zone_memberships
  for insert with check (auth.uid() = user_id);

create policy "zone_memberships_update_own" on public.zone_memberships
  for update using (auth.uid() = user_id);

-- verification submissions: only submitter and zone creator can see
create policy "zone_submissions_read" on public.help_zone_verification_submissions
  for select using (
    auth.uid() = submitted_by_user_id or
    exists (
      select 1 from public.help_zones hz
      where hz.id = zone_id and hz.created_by_user_id = auth.uid()
    )
  );

create policy "zone_submissions_insert" on public.help_zone_verification_submissions
  for insert with check (auth.uid() = submitted_by_user_id);

-- help_requests: open/global visible to all helpers; zone-scoped visible to zone members
create policy "help_requests_read" on public.help_requests
  for select using (
    auth.uid() is not null and (
      scope = 'help_zone_and_global' or
      auth.uid() = requester_user_id or
      exists (
        select 1 from public.zone_memberships zm
        where zm.zone_id = help_requests.zone_id
          and zm.user_id = auth.uid()
          and zm.status = 'active'
      )
    )
  );

create policy "help_requests_insert" on public.help_requests
  for insert with check (auth.uid() = requester_user_id);

create policy "help_requests_update_own" on public.help_requests
  for update using (auth.uid() = requester_user_id);

-- help_request_photos: same visibility as the parent request
create policy "help_request_photos_read" on public.help_request_photos
  for select using (
    exists (
      select 1 from public.help_requests hr
      where hr.id = request_id and (
        hr.scope = 'help_zone_and_global' or
        hr.requester_user_id = auth.uid()
      )
    )
  );

create policy "help_request_photos_insert" on public.help_request_photos
  for insert with check (
    exists (
      select 1 from public.help_requests hr
      where hr.id = request_id and hr.requester_user_id = auth.uid()
    )
  );

-- help_request_acceptances
create policy "acceptances_read" on public.help_request_acceptances
  for select using (
    auth.uid() = helper_user_id or
    exists (
      select 1 from public.help_requests hr
      where hr.id = request_id and hr.requester_user_id = auth.uid()
    )
  );

create policy "acceptances_insert" on public.help_request_acceptances
  for insert with check (auth.uid() = helper_user_id);

create policy "acceptances_update_helper" on public.help_request_acceptances
  for update using (auth.uid() = helper_user_id);

-- points_ledger: read own only
create policy "points_ledger_read_own" on public.points_ledger
  for select using (auth.uid() = user_id);

-- user_gamification: read own; leaderboard read all
create policy "gamification_read_own" on public.user_gamification
  for select using (auth.uid() = user_id);

-- leaderboard: public read for authenticated users
create policy "leaderboard_weeks_read" on public.leaderboard_weeks
  for select using (auth.uid() is not null);

create policy "leaderboard_entries_read" on public.leaderboard_entries
  for select using (auth.uid() is not null);


-- ------------------------------------------------------------
-- 9. INDEXES
-- ------------------------------------------------------------

-- Geo index for map-based request queries
create index idx_help_requests_location
  on public.help_requests (latitude, longitude);

-- Fast open request lookups
create index idx_help_requests_status_scope
  on public.help_requests (status, scope);

-- Zone membership lookups
create index idx_zone_memberships_user
  on public.zone_memberships (user_id, status);

create index idx_zone_memberships_zone
  on public.zone_memberships (zone_id, status);

-- Help zone join code lookup (for manual code entry)
create index idx_help_zones_join_code
  on public.help_zones (join_code);

-- Leaderboard queries
create index idx_leaderboard_entries_week_mode
  on public.leaderboard_entries (leaderboard_week_id, mode, rank);

-- Points ledger per user
create index idx_points_ledger_user
  on public.points_ledger (user_id, created_at desc);

-- Request photos ordering
create index idx_help_request_photos_request
  on public.help_request_photos (request_id, sort_order);