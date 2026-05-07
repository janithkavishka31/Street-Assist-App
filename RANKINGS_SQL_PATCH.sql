-- ============================================================
-- RANKINGS FEATURE SQL PATCH
-- Run this in Supabase SQL Editor to enable the Rankings tab
-- (Must be run BEFORE the app can display Rankings data)
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Create leaderboard_weeks table
CREATE TABLE IF NOT EXISTS public.leaderboard_weeks (
  id              uuid                    PRIMARY KEY DEFAULT uuid_generate_v4(),
  week_start_date date                    NOT NULL UNIQUE,
  created_at      timestamptz             NOT NULL DEFAULT now()
);

-- 2. Create points_ledger table (audit trail)
CREATE TABLE IF NOT EXISTS public.points_ledger (
  id          uuid                        PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     uuid                        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  points      int                         NOT NULL,
  reason      points_reason_enum          NOT NULL,
  request_id  uuid                        REFERENCES public.help_requests(id) ON DELETE SET NULL,
  created_at  timestamptz                 NOT NULL DEFAULT now()
);

-- 3. Create user_gamification table (denormalized for fast reads)
CREATE TABLE IF NOT EXISTS public.user_gamification (
  user_id               uuid                PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  total_points          int                 NOT NULL DEFAULT 0,
  weekly_assists        int                 NOT NULL DEFAULT 0,
  current_streak_days   int                 NOT NULL DEFAULT 0,
  best_streak_days      int                 NOT NULL DEFAULT 0,
  last_assist_at        timestamptz,
  updated_at            timestamptz         NOT NULL DEFAULT now()
);

-- 4. Create user_mode_streaks table (per-mode streak tracking)
CREATE TABLE IF NOT EXISTS public.user_mode_streaks (
  id                          uuid                      PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id                     uuid                      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  mode                        leaderboard_mode_enum     NOT NULL,
  current_streak_days         int                       NOT NULL DEFAULT 0,
  best_streak_days            int                       NOT NULL DEFAULT 0,
  last_checkin_date           date,
  weekly_streak_completed_at  timestamptz,
  updated_at                  timestamptz               NOT NULL DEFAULT now(),
  UNIQUE (user_id, mode)
);

-- 5. Create user_daily_checkins table
CREATE TABLE IF NOT EXISTS public.user_daily_checkins (
  id             uuid                      PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        uuid                      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  mode           leaderboard_mode_enum     NOT NULL,
  check_in_date  date                      NOT NULL,
  created_at     timestamptz               NOT NULL DEFAULT now(),
  UNIQUE (user_id, mode, check_in_date)
);

-- 6. Create discount_vouchers table
CREATE TABLE IF NOT EXISTS public.discount_vouchers (
  id               uuid                      PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id          uuid                      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  mode             leaderboard_mode_enum     NOT NULL,
  source           text                      NOT NULL CHECK (source IN ('weekly_top10', 'gift_box')),
  discount_percent int                       NOT NULL CHECK (discount_percent IN (5, 10, 20)),
  valid_from       timestamptz               NOT NULL DEFAULT now(),
  valid_until      timestamptz               NOT NULL,
  is_used          boolean                   NOT NULL DEFAULT false,
  request_id       uuid                      REFERENCES public.help_requests(id) ON DELETE SET NULL,
  created_at       timestamptz               NOT NULL DEFAULT now()
);

-- 7. Create leaderboard_entries table
CREATE TABLE IF NOT EXISTS public.leaderboard_entries (
  id                    uuid                      PRIMARY KEY DEFAULT uuid_generate_v4(),
  leaderboard_week_id   uuid                      NOT NULL REFERENCES public.leaderboard_weeks(id) ON DELETE CASCADE,
  mode                  leaderboard_mode_enum     NOT NULL,
  user_id               uuid                      NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  points                int                       NOT NULL DEFAULT 0,
  rank                  int                       NOT NULL,
  title_label           text,
  UNIQUE (leaderboard_week_id, mode, user_id),
  UNIQUE (leaderboard_week_id, mode, rank)
);

-- 8. Create help_request_ratings table
CREATE TABLE IF NOT EXISTS public.help_request_ratings (
  id             uuid                    PRIMARY KEY DEFAULT uuid_generate_v4(),
  request_id     uuid                    NOT NULL UNIQUE REFERENCES public.help_requests(id) ON DELETE CASCADE,
  rater_user_id  uuid                    NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  rated_user_id  uuid                    NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  score          int                     NOT NULL CHECK (score BETWEEN 1 AND 5),
  comment        text,
  created_at     timestamptz             NOT NULL DEFAULT now()
);

-- 8.5 Add requester/payment completion columns to help_requests
ALTER TABLE IF EXISTS public.help_requests
  ADD COLUMN IF NOT EXISTS requester_completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS payment_completed_at timestamptz,
  ADD COLUMN IF NOT EXISTS paid_amount numeric(10,2);

-- 9. Add updated_at trigger for user_gamification
CREATE OR REPLACE TRIGGER trg_user_gamification_updated_at
  BEFORE UPDATE ON public.user_gamification
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- 10. Add updated_at trigger for user_mode_streaks
CREATE OR REPLACE TRIGGER trg_user_mode_streaks_updated_at
  BEFORE UPDATE ON public.user_mode_streaks
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- 11. Create refresh_weekly_leaderboard_entries function
CREATE OR REPLACE FUNCTION public.refresh_weekly_leaderboard_entries(p_week_start_date date DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_week_start date := COALESCE(
    p_week_start_date,
    (DATE_TRUNC('week', (NOW() AT TIME ZONE 'utc') + INTERVAL '1 day') - INTERVAL '1 day')::date
  );
  v_week_end date := v_week_start + INTERVAL '7 days';
  v_week_id uuid;
BEGIN
  INSERT INTO public.leaderboard_weeks (week_start_date)
  VALUES (v_week_start)
  ON CONFLICT (week_start_date) DO NOTHING;

  SELECT lw.id INTO v_week_id
  FROM public.leaderboard_weeks lw
  WHERE lw.week_start_date = v_week_start;

  DELETE FROM public.leaderboard_entries le
  WHERE le.leaderboard_week_id = v_week_id
    AND le.mode IN ('helper', 'requester');

  -- Helper mode: completed requests (10 pts) + 5-star ratings (5 pts) + daily check-ins (5 pts)
  WITH helper_completed AS (
    SELECT
      ha.helper_user_id AS user_id,
      COUNT(*)::int AS completed_count
    FROM public.help_request_acceptances ha
    WHERE ha.completed_at >= v_week_start
      AND ha.completed_at < v_week_end
    GROUP BY ha.helper_user_id
  ),
  helper_five_star AS (
    SELECT
      hr.rated_user_id AS user_id,
      COUNT(*) FILTER (WHERE hr.score = 5)::int AS five_star_count,
      AVG(hr.score)::numeric AS avg_rating
    FROM public.help_request_ratings hr
    WHERE hr.created_at >= v_week_start
      AND hr.created_at < v_week_end
    GROUP BY hr.rated_user_id
  ),
  helper_checkins AS (
    SELECT
      dc.user_id,
      COUNT(*)::int AS checkin_count
    FROM public.user_daily_checkins dc
    WHERE dc.mode = 'helper'
      AND dc.check_in_date >= v_week_start
      AND dc.check_in_date < v_week_end
    GROUP BY dc.user_id
  ),
  helper_scores AS (
    SELECT
      u.id AS user_id,
      COALESCE(hc.completed_count, 0) * 10
      + COALESCE(hf.five_star_count, 0) * 5
      + COALESCE(hk.checkin_count, 0) * 5 AS points,
      hf.avg_rating
    FROM public.users u
    LEFT JOIN helper_completed hc ON hc.user_id = u.id
    LEFT JOIN helper_five_star hf ON hf.user_id = u.id
    LEFT JOIN helper_checkins hk ON hk.user_id = u.id
  ),
  helper_ranked AS (
    SELECT
      hs.user_id,
      hs.points,
      DENSE_RANK() OVER (ORDER BY hs.points DESC, hs.avg_rating DESC NULLS LAST, hs.user_id) AS rank
    FROM helper_scores hs
    WHERE hs.points > 0
  )
  INSERT INTO public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  SELECT
    uuid_generate_v4(),
    v_week_id,
    'helper'::leaderboard_mode_enum,
    hr.user_id,
    hr.points,
    hr.rank,
    CASE hr.rank
      WHEN 1 THEN 'Platinum Helper'
      WHEN 2 THEN 'Elite Guardian'
      WHEN 3 THEN 'Steady Pulse'
      ELSE NULL
    END
  FROM helper_ranked hr;

  -- Requester mode: completed requests (10 pts) + 5-star ratings (5 pts) + daily check-ins (5 pts)
  WITH requester_completed AS (
    SELECT
      hr.requester_user_id AS user_id,
      COUNT(*)::int AS completed_count
    FROM public.help_requests hr
    WHERE hr.status = 'completed'
      AND hr.updated_at >= v_week_start
      AND hr.updated_at < v_week_end
    GROUP BY hr.requester_user_id
  ),
  requester_five_star AS (
    SELECT
      rr.rated_user_id AS user_id,
      COUNT(*) FILTER (WHERE rr.score = 5)::int AS five_star_count,
      AVG(rr.score)::numeric AS avg_rating
    FROM public.help_request_ratings rr
    WHERE rr.created_at >= v_week_start
      AND rr.created_at < v_week_end
    GROUP BY rr.rated_user_id
  ),
  requester_checkins AS (
    SELECT
      dc.user_id,
      COUNT(*)::int AS checkin_count
    FROM public.user_daily_checkins dc
    WHERE dc.mode = 'requester'
      AND dc.check_in_date >= v_week_start
      AND dc.check_in_date < v_week_end
    GROUP BY dc.user_id
  ),
  requester_scores AS (
    SELECT
      u.id AS user_id,
      COALESCE(rc.completed_count, 0) * 10
      + COALESCE(rf.five_star_count, 0) * 5
      + COALESCE(rk.checkin_count, 0) * 5 AS points,
      rf.avg_rating
    FROM public.users u
    LEFT JOIN requester_completed rc ON rc.user_id = u.id
    LEFT JOIN requester_five_star rf ON rf.user_id = u.id
    LEFT JOIN requester_checkins rk ON rk.user_id = u.id
  ),
  requester_ranked AS (
    SELECT
      rs.user_id,
      rs.points,
      DENSE_RANK() OVER (ORDER BY rs.points DESC, rs.avg_rating DESC NULLS LAST, rs.user_id) AS rank
    FROM requester_scores rs
    WHERE rs.points > 0
  )
  INSERT INTO public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  SELECT
    uuid_generate_v4(),
    v_week_id,
    'requester'::leaderboard_mode_enum,
    rr.user_id,
    rr.points,
    rr.rank,
    CASE rr.rank
      WHEN 1 THEN 'Platinum Requester'
      WHEN 2 THEN 'Community Catalyst'
      WHEN 3 THEN 'Steady Supporter'
      ELSE NULL
    END
  FROM requester_ranked rr;
END;
$$;

-- 12. Disable RLS on new tables (demo mode)
ALTER TABLE public.leaderboard_weeks              DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_ledger                  DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_gamification              DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_mode_streaks              DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_daily_checkins            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.discount_vouchers              DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_entries            DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.help_request_ratings           DISABLE ROW LEVEL SECURITY;

-- 13. Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_gamification_points ON public.user_gamification(total_points DESC);
CREATE INDEX IF NOT EXISTS idx_user_mode_streaks_user_mode ON public.user_mode_streaks(user_id, mode);
CREATE INDEX IF NOT EXISTS idx_user_daily_checkins_user_date ON public.user_daily_checkins(user_id, check_in_date);
CREATE INDEX IF NOT EXISTS idx_discount_vouchers_user_mode ON public.discount_vouchers(user_id, mode);
CREATE INDEX IF NOT EXISTS idx_leaderboard_entries_week_mode ON public.leaderboard_entries(leaderboard_week_id, mode, rank);
CREATE INDEX IF NOT EXISTS idx_help_request_ratings_rater ON public.help_request_ratings(rater_user_id);
CREATE INDEX IF NOT EXISTS idx_help_request_ratings_rated ON public.help_request_ratings(rated_user_id);
CREATE INDEX IF NOT EXISTS idx_help_request_ratings_request ON public.help_request_ratings(request_id);

-- ============================================================
-- DONE! Run this once, then restart the app.
-- ============================================================

-- 14. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';

-- 15. Leaderboard refresh flow fix:
-- - Use ROW_NUMBER to avoid unique rank conflicts on ties
-- - Use payment_completed_at for requester weekly completed scoring
CREATE OR REPLACE FUNCTION public.refresh_weekly_leaderboard_entries(p_week_start_date date DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE
  v_week_start date := COALESCE(
    p_week_start_date,
    (DATE_TRUNC('week', (NOW() AT TIME ZONE 'utc') + INTERVAL '1 day') - INTERVAL '1 day')::date
  );
  v_week_end date := v_week_start + INTERVAL '7 days';
  v_week_id uuid;
BEGIN
  INSERT INTO public.leaderboard_weeks (week_start_date)
  VALUES (v_week_start)
  ON CONFLICT (week_start_date) DO NOTHING;

  SELECT lw.id INTO v_week_id
  FROM public.leaderboard_weeks lw
  WHERE lw.week_start_date = v_week_start;

  DELETE FROM public.leaderboard_entries le
  WHERE le.leaderboard_week_id = v_week_id
    AND le.mode IN ('helper', 'requester');

  WITH helper_completed AS (
    SELECT
      ha.helper_user_id AS user_id,
      COUNT(*)::int AS completed_count
    FROM public.help_request_acceptances ha
    WHERE ha.completed_at >= v_week_start
      AND ha.completed_at < v_week_end
    GROUP BY ha.helper_user_id
  ),
  helper_five_star AS (
    SELECT
      hr.rated_user_id AS user_id,
      COUNT(*) FILTER (WHERE hr.score = 5)::int AS five_star_count,
      AVG(hr.score)::numeric AS avg_rating
    FROM public.help_request_ratings hr
    WHERE hr.created_at >= v_week_start
      AND hr.created_at < v_week_end
    GROUP BY hr.rated_user_id
  ),
  helper_checkins AS (
    SELECT
      dc.user_id,
      COUNT(*)::int AS checkin_count
    FROM public.user_daily_checkins dc
    WHERE dc.mode = 'helper'
      AND dc.check_in_date >= v_week_start
      AND dc.check_in_date < v_week_end
    GROUP BY dc.user_id
  ),
  helper_scores AS (
    SELECT
      u.id AS user_id,
      COALESCE(hc.completed_count, 0) * 10
      + COALESCE(hf.five_star_count, 0) * 5
      + COALESCE(hk.checkin_count, 0) * 5 AS points,
      hf.avg_rating
    FROM public.users u
    LEFT JOIN helper_completed hc ON hc.user_id = u.id
    LEFT JOIN helper_five_star hf ON hf.user_id = u.id
    LEFT JOIN helper_checkins hk ON hk.user_id = u.id
  ),
  helper_ranked AS (
    SELECT
      hs.user_id,
      hs.points,
      ROW_NUMBER() OVER (ORDER BY hs.points DESC, hs.avg_rating DESC NULLS LAST, hs.user_id) AS rank
    FROM helper_scores hs
    WHERE hs.points > 0
  )
  INSERT INTO public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  SELECT
    uuid_generate_v4(),
    v_week_id,
    'helper'::leaderboard_mode_enum,
    hr.user_id,
    hr.points,
    hr.rank,
    CASE hr.rank
      WHEN 1 THEN 'Platinum Helper'
      WHEN 2 THEN 'Elite Guardian'
      WHEN 3 THEN 'Steady Pulse'
      ELSE NULL
    END
  FROM helper_ranked hr;

  WITH requester_completed AS (
    SELECT
      hr.requester_user_id AS user_id,
      COUNT(*)::int AS completed_count
    FROM public.help_requests hr
    WHERE hr.status = 'completed'
      AND hr.payment_completed_at IS NOT NULL
      AND hr.payment_completed_at >= v_week_start
      AND hr.payment_completed_at < v_week_end
    GROUP BY hr.requester_user_id
  ),
  requester_five_star AS (
    SELECT
      rr.rated_user_id AS user_id,
      COUNT(*) FILTER (WHERE rr.score = 5)::int AS five_star_count,
      AVG(rr.score)::numeric AS avg_rating
    FROM public.help_request_ratings rr
    WHERE rr.created_at >= v_week_start
      AND rr.created_at < v_week_end
    GROUP BY rr.rated_user_id
  ),
  requester_checkins AS (
    SELECT
      dc.user_id,
      COUNT(*)::int AS checkin_count
    FROM public.user_daily_checkins dc
    WHERE dc.mode = 'requester'
      AND dc.check_in_date >= v_week_start
      AND dc.check_in_date < v_week_end
    GROUP BY dc.user_id
  ),
  requester_scores AS (
    SELECT
      u.id AS user_id,
      COALESCE(rc.completed_count, 0) * 10
      + COALESCE(rf.five_star_count, 0) * 5
      + COALESCE(rk.checkin_count, 0) * 5 AS points,
      rf.avg_rating
    FROM public.users u
    LEFT JOIN requester_completed rc ON rc.user_id = u.id
    LEFT JOIN requester_five_star rf ON rf.user_id = u.id
    LEFT JOIN requester_checkins rk ON rk.user_id = u.id
  ),
  requester_ranked AS (
    SELECT
      rs.user_id,
      rs.points,
      ROW_NUMBER() OVER (ORDER BY rs.points DESC, rs.avg_rating DESC NULLS LAST, rs.user_id) AS rank
    FROM requester_scores rs
    WHERE rs.points > 0
  )
  INSERT INTO public.leaderboard_entries (id, leaderboard_week_id, mode, user_id, points, rank, title_label)
  SELECT
    uuid_generate_v4(),
    v_week_id,
    'requester'::leaderboard_mode_enum,
    rr.user_id,
    rr.points,
    rr.rank,
    CASE rr.rank
      WHEN 1 THEN 'Platinum Requester'
      WHEN 2 THEN 'Community Catalyst'
      WHEN 3 THEN 'Steady Supporter'
      ELSE NULL
    END
  FROM requester_ranked rr;
END;
$$;
