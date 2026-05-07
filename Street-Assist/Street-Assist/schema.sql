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
  requester_completed_at timestamptz,
  payment_completed_at   timestamptz,
  paid_amount            numeric(10,2),
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

-- Request ratings (used for 5-star bonus and leaderboard quality scoring)
create table public.help_request_ratings (
  id             uuid        primary key default uuid_generate_v4(),
  request_id     uuid        not null unique references public.help_requests(id) on delete cascade,
  rater_user_id  uuid        not null references public.users(id) on delete restrict,
  rated_user_id  uuid        not null references public.users(id) on delete restrict,
  score          int         not null check (score between 1 and 5),
  comment        text,
  created_at     timestamptz not null default now()
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

-- Per-mode streak tracking (helper/requester)
create table public.user_mode_streaks (
  id                        uuid                  primary key default uuid_generate_v4(),
  user_id                   uuid                  not null references public.users(id) on delete cascade,
  mode                      leaderboard_mode_enum not null,
  current_streak_days       int                   not null default 0,
  best_streak_days          int                   not null default 0,
  last_checkin_date         date,
  weekly_streak_completed_at timestamptz,
  updated_at                timestamptz           not null default now(),
  unique (user_id, mode)
);

-- Daily check-in log (one per user+mode+day)
create table public.user_daily_checkins (
  id             uuid                  primary key default uuid_generate_v4(),
  user_id        uuid                  not null references public.users(id) on delete cascade,
  mode           leaderboard_mode_enum not null,
  check_in_date  date                  not null,
  created_at     timestamptz           not null default now(),
  unique (user_id, mode, check_in_date)
);

-- Reward vouchers (weekly top10 and gift box)
create table public.discount_vouchers (
  id               uuid                  primary key default uuid_generate_v4(),
  user_id          uuid                  not null references public.users(id) on delete cascade,
  mode             leaderboard_mode_enum not null,
  source           text                  not null check (source in ('weekly_top10', 'gift_box')),
  discount_percent int                   not null check (discount_percent in (5, 10, 20)),
  valid_from       timestamptz           not null default now(),
  valid_until      timestamptz           not null,
  is_used          boolean               not null default false,
  request_id       uuid                  references public.help_requests(id) on delete set null,
  created_at       timestamptz           not null default now()
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

-- Active helper locations (real-time tracking for nearby helper discovery)
create table public.helper_locations (
  id              uuid          primary key default uuid_generate_v4(),
  user_id         uuid          not null unique references public.users(id) on delete cascade,
  latitude        double precision not null,
  longitude       double precision not null,
  updated_at      timestamptz   not null default now()
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

create trigger trg_user_mode_streaks_updated_at
  before update on public.user_mode_streaks
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
-- 7.5 LEADERBOARD REFRESH FUNCTION
-- ------------------------------------------------------------

create or replace function public.refresh_weekly_leaderboard_entries(p_week_start_date date default null)
returns void language plpgsql as $$
declare
  v_week_start date := coalesce(
    p_week_start_date,
    (date_trunc('week', (now() at time zone 'utc') + interval '1 day') - interval '1 day')::date
  );
  v_week_end date := v_week_start + interval '7 days';
  v_week_id uuid;
begin
  insert into public.leaderboard_weeks (week_start_date)
  values (v_week_start)
  on conflict (week_start_date) do nothing;

  select lw.id into v_week_id
  from public.leaderboard_weeks lw
  where lw.week_start_date = v_week_start;

  delete from public.leaderboard_entries le
  where le.leaderboard_week_id = v_week_id
    and le.mode in ('helper', 'requester');

  -- Helper mode points
  with helper_completed as (
    select
      ha.helper_user_id as user_id,
      count(*)::int as completed_count
    from public.help_request_acceptances ha
    where ha.completed_at >= v_week_start
      and ha.completed_at < v_week_end
    group by ha.helper_user_id
  ),
  helper_five_star as (
    select
      hr.rated_user_id as user_id,
      count(*) filter (where hr.score = 5)::int as five_star_count,
      avg(hr.score)::numeric as avg_rating
    from public.help_request_ratings hr
    where hr.created_at >= v_week_start
      and hr.created_at < v_week_end
    group by hr.rated_user_id
  ),
  helper_checkins as (
    select
      dc.user_id,
      count(*)::int as checkin_count
    from public.user_daily_checkins dc
    where dc.mode = 'helper'
      and dc.check_in_date >= v_week_start
      and dc.check_in_date < v_week_end
    group by dc.user_id
  ),
  helper_scores as (
    select
      u.id as user_id,
      coalesce(hc.completed_count, 0) * 10
      + coalesce(hf.five_star_count, 0) * 5
      + coalesce(hk.checkin_count, 0) * 5 as points,
      hf.avg_rating
    from public.users u
    left join helper_completed hc on hc.user_id = u.id
    left join helper_five_star hf on hf.user_id = u.id
    left join helper_checkins hk on hk.user_id = u.id
  ),
  helper_ranked as (
    select
      hs.user_id,
      hs.points,
      dense_rank() over (order by hs.points desc, hs.avg_rating desc nulls last, hs.user_id) as rank
    from helper_scores hs
    where hs.points > 0
  )
  insert into public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  select
    uuid_generate_v4(),
    v_week_id,
    'helper'::leaderboard_mode_enum,
    hr.user_id,
    hr.points,
    hr.rank,
    case hr.rank
      when 1 then 'Platinum Helper'
      when 2 then 'Elite Guardian'
      when 3 then 'Steady Pulse'
      else null
    end
  from helper_ranked hr;

  -- Requester mode points
  with requester_completed as (
    select
      hr.requester_user_id as user_id,
      count(*)::int as completed_count
    from public.help_requests hr
    where hr.status = 'completed'
      and hr.updated_at >= v_week_start
      and hr.updated_at < v_week_end
    group by hr.requester_user_id
  ),
  requester_five_star as (
    select
      rr.rated_user_id as user_id,
      count(*) filter (where rr.score = 5)::int as five_star_count,
      avg(rr.score)::numeric as avg_rating
    from public.help_request_ratings rr
    where rr.created_at >= v_week_start
      and rr.created_at < v_week_end
    group by rr.rated_user_id
  ),
  requester_checkins as (
    select
      dc.user_id,
      count(*)::int as checkin_count
    from public.user_daily_checkins dc
    where dc.mode = 'requester'
      and dc.check_in_date >= v_week_start
      and dc.check_in_date < v_week_end
    group by dc.user_id
  ),
  requester_scores as (
    select
      u.id as user_id,
      coalesce(rc.completed_count, 0) * 10
      + coalesce(rf.five_star_count, 0) * 5
      + coalesce(rk.checkin_count, 0) * 5 as points,
      rf.avg_rating
    from public.users u
    left join requester_completed rc on rc.user_id = u.id
    left join requester_five_star rf on rf.user_id = u.id
    left join requester_checkins rk on rk.user_id = u.id
  ),
  requester_ranked as (
    select
      rs.user_id,
      rs.points,
      dense_rank() over (order by rs.points desc, rs.avg_rating desc nulls last, rs.user_id) as rank
    from requester_scores rs
    where rs.points > 0
  )
  insert into public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  select
    uuid_generate_v4(),
    v_week_id,
    'requester'::leaderboard_mode_enum,
    rr.user_id,
    rr.points,
    rr.rank,
    case rr.rank
      when 1 then 'Platinum Requester'
      when 2 then 'Community Catalyst'
      when 3 then 'Steady Supporter'
      else null
    end
  from requester_ranked rr;
end;
$$;


-- ------------------------------------------------------------
-- 8. DEMO MODE ACCESS (RLS OFF)
-- ------------------------------------------------------------

-- University demo mode: disable RLS on app tables and storage objects.
alter table public.users                             disable row level security;
alter table public.user_settings                     disable row level security;
alter table public.user_skills                       disable row level security;
alter table public.help_zones                        disable row level security;
alter table public.help_zone_verification_submissions disable row level security;
alter table public.zone_memberships                  disable row level security;
alter table public.help_requests                     disable row level security;
alter table public.help_request_photos               disable row level security;
alter table public.help_request_acceptances          disable row level security;
alter table public.help_request_ratings              disable row level security;
alter table public.points_ledger                     disable row level security;
alter table public.user_gamification                 disable row level security;
alter table public.user_mode_streaks                 disable row level security;
alter table public.user_daily_checkins               disable row level security;
alter table public.discount_vouchers                 disable row level security;
alter table public.leaderboard_weeks                 disable row level security;
alter table public.leaderboard_entries               disable row level security;
alter table public.skills                            disable row level security;
alter table public.helper_locations                  disable row level security;


-- ------------------------------------------------------------
-- 10. INDEXES
-- ------------------------------------------------------------

-- Geo index for map-based request queries
create index idx_help_requests_location
  on public.help_requests (latitude, longitude);

-- Geo index for nearby helpers
create index idx_helper_locations_geo
  on public.helper_locations (latitude, longitude);

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

-- Gamification summary lookup
create index idx_user_gamification_points
  on public.user_gamification (total_points desc);

-- Mode streak lookups
create index idx_user_mode_streaks_user_mode
  on public.user_mode_streaks (user_id, mode);

-- Daily check-in lookups
create index idx_user_daily_checkins_user_mode_date
  on public.user_daily_checkins (user_id, mode, check_in_date desc);

-- Voucher lookups
create index idx_discount_vouchers_user_mode_valid
  on public.discount_vouchers (user_id, mode, is_used, valid_until desc);

-- Request photos ordering
create index idx_help_request_photos_request
  on public.help_request_photos (request_id, sort_order);

-- Ratings lookup
create index idx_help_request_ratings_rated_user
  on public.help_request_ratings (rated_user_id, created_at desc);

create index idx_help_request_ratings_rater
  on public.help_request_ratings (rater_user_id);

create index idx_help_request_ratings_request
  on public.help_request_ratings (request_id);


-- ------------------------------------------------------------
-- 11. COMPATIBILITY PATCHES FOR EXISTING PROJECTS
-- ------------------------------------------------------------
-- Safe to run on existing DBs when app fields evolve.
alter table if exists public.help_requests
  add column if not exists requester_completed_at timestamptz,
  add column if not exists payment_completed_at timestamptz,
  add column if not exists paid_amount numeric(10,2);

alter table if exists public.help_request_acceptances
  add column if not exists completed_at timestamptz,
  add column if not exists canceled_at timestamptz;

-- Refresh PostgREST schema cache so new columns are discoverable immediately.
notify pgrst, 'reload schema';

-- ------------------------------------------------------------
-- 12. LEADERBOARD REFRESH (FLOW FIX)
-- ------------------------------------------------------------
-- Uses ROW_NUMBER (not dense_rank) to satisfy unique rank constraint
-- and uses payment_completed_at for requester weekly completion timing.
create or replace function public.refresh_weekly_leaderboard_entries(p_week_start_date date default null)
returns void language plpgsql as $$
declare
  v_week_start date := coalesce(
    p_week_start_date,
    (date_trunc('week', (now() at time zone 'utc') + interval '1 day') - interval '1 day')::date
  );
  v_week_end date := v_week_start + interval '7 days';
  v_week_id uuid;
begin
  insert into public.leaderboard_weeks (week_start_date)
  values (v_week_start)
  on conflict (week_start_date) do nothing;

  select lw.id into v_week_id
  from public.leaderboard_weeks lw
  where lw.week_start_date = v_week_start;

  delete from public.leaderboard_entries le
  where le.leaderboard_week_id = v_week_id
    and le.mode in ('helper', 'requester');

  with helper_completed as (
    select
      ha.helper_user_id as user_id,
      count(*)::int as completed_count
    from public.help_request_acceptances ha
    where ha.completed_at >= v_week_start
      and ha.completed_at < v_week_end
    group by ha.helper_user_id
  ),
  helper_five_star as (
    select
      hr.rated_user_id as user_id,
      count(*) filter (where hr.score = 5)::int as five_star_count,
      avg(hr.score)::numeric as avg_rating
    from public.help_request_ratings hr
    where hr.created_at >= v_week_start
      and hr.created_at < v_week_end
    group by hr.rated_user_id
  ),
  helper_checkins as (
    select
      dc.user_id,
      count(*)::int as checkin_count
    from public.user_daily_checkins dc
    where dc.mode = 'helper'
      and dc.check_in_date >= v_week_start
      and dc.check_in_date < v_week_end
    group by dc.user_id
  ),
  helper_scores as (
    select
      u.id as user_id,
      coalesce(hc.completed_count, 0) * 10
      + coalesce(hf.five_star_count, 0) * 5
      + coalesce(hk.checkin_count, 0) * 5 as points,
      hf.avg_rating
    from public.users u
    left join helper_completed hc on hc.user_id = u.id
    left join helper_five_star hf on hf.user_id = u.id
    left join helper_checkins hk on hk.user_id = u.id
  ),
  helper_ranked as (
    select
      hs.user_id,
      hs.points,
      row_number() over (order by hs.points desc, hs.avg_rating desc nulls last, hs.user_id) as rank
    from helper_scores hs
    where hs.points > 0
  )
  insert into public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  select
    uuid_generate_v4(),
    v_week_id,
    'helper'::leaderboard_mode_enum,
    hr.user_id,
    hr.points,
    hr.rank,
    case hr.rank
      when 1 then 'Platinum Helper'
      when 2 then 'Elite Guardian'
      when 3 then 'Steady Pulse'
      else null
    end
  from helper_ranked hr;

  with requester_completed as (
    select
      hr.requester_user_id as user_id,
      count(*)::int as completed_count
    from public.help_requests hr
    where hr.status = 'completed'
      and hr.payment_completed_at is not null
      and hr.payment_completed_at >= v_week_start
      and hr.payment_completed_at < v_week_end
    group by hr.requester_user_id
  ),
  requester_five_star as (
    select
      rr.rated_user_id as user_id,
      count(*) filter (where rr.score = 5)::int as five_star_count,
      avg(rr.score)::numeric as avg_rating
    from public.help_request_ratings rr
    where rr.created_at >= v_week_start
      and rr.created_at < v_week_end
    group by rr.rated_user_id
  ),
  requester_checkins as (
    select
      dc.user_id,
      count(*)::int as checkin_count
    from public.user_daily_checkins dc
    where dc.mode = 'requester'
      and dc.check_in_date >= v_week_start
      and dc.check_in_date < v_week_end
    group by dc.user_id
  ),
  requester_scores as (
    select
      u.id as user_id,
      coalesce(rc.completed_count, 0) * 10
      + coalesce(rf.five_star_count, 0) * 5
      + coalesce(rk.checkin_count, 0) * 5 as points,
      rf.avg_rating
    from public.users u
    left join requester_completed rc on rc.user_id = u.id
    left join requester_five_star rf on rf.user_id = u.id
    left join requester_checkins rk on rk.user_id = u.id
  ),
  requester_ranked as (
    select
      rs.user_id,
      rs.points,
      row_number() over (order by rs.points desc, rs.avg_rating desc nulls last, rs.user_id) as rank
    from requester_scores rs
    where rs.points > 0
  )
  insert into public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  select
    uuid_generate_v4(),
    v_week_id,
    'requester'::leaderboard_mode_enum,
    rr.user_id,
    rr.points,
    rr.rank,
    case rr.rank
      when 1 then 'Platinum Requester'
      when 2 then 'Community Catalyst'
      when 3 then 'Steady Supporter'
      else null
    end
  from requester_ranked rr;
end;
$$;