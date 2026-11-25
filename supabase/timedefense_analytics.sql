-- ============================================================================
-- TimeDefense — Playtest Analytics & Balance Feedback Loop Schema
-- Isolated section inside your existing Supabase project (zero changes to
-- existing Home-dashboard / family / budget tables).
--
-- HOW TO APPLY (one-time, ~15 seconds):
--   1. Open Supabase Dashboard -> SQL Editor -> New Query
--   2. Paste this entire file and click "Run"
--   3. All Web, Android APK, and Desktop TimeDefense runs will immediately
--      auto-sync here and appear live in analytics.html + tools/analyze_telemetry.mjs!
-- ============================================================================

-- 1. Main Playtest Runs Table (idempotent upsert by run_id)
CREATE TABLE IF NOT EXISTS public.timedefense_runs (
  run_id TEXT PRIMARY KEY,
  balance_version TEXT NOT NULL DEFAULT 'v1.2-cloud-telemetry',
  player_id TEXT NOT NULL DEFAULT 'anon',
  platform TEXT NOT NULL DEFAULT 'web',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ,
  level INT NOT NULL DEFAULT 1 CHECK (level BETWEEN 1 AND 5),
  level_name TEXT NOT NULL DEFAULT 'Level 1',
  difficulty TEXT NOT NULL DEFAULT 'standard',
  is_sandbox BOOLEAN NOT NULL DEFAULT FALSE,
  outcome TEXT NOT NULL DEFAULT 'in_progress',
  end_reason TEXT NOT NULL DEFAULT '',
  max_wave_reached INT NOT NULL DEFAULT 1,
  waves_started INT NOT NULL DEFAULT 0,
  waves_completed INT NOT NULL DEFAULT 0,
  endless_reached BOOLEAN NOT NULL DEFAULT FALSE,
  duration_sim_sec NUMERIC(10, 1) NOT NULL DEFAULT 0,
  build_phase_sec NUMERIC(10, 1) NOT NULL DEFAULT 0,
  lives_remaining INT NOT NULL DEFAULT 20,
  lives_lost_total INT NOT NULL DEFAULT 0,
  enemy_base_hp_remaining INT NOT NULL DEFAULT 500,
  charges_fired INT NOT NULL DEFAULT 0,
  surges_suffered INT NOT NULL DEFAULT 0,
  refineries_owned INT NOT NULL DEFAULT 0,
  manipulator_level INT NOT NULL DEFAULT 1,
  early_calls INT NOT NULL DEFAULT 0,
  money_earned INT NOT NULL DEFAULT 0,
  money_unspent_end INT NOT NULL DEFAULT 0,
  avg_unspent_cash NUMERIC(10, 1) NOT NULL DEFAULT 0,
  max_enemy_progress_pct NUMERIC(5, 1) NOT NULL DEFAULT 0,
  avg_kill_progress_pct NUMERIC(5, 1) NOT NULL DEFAULT 0,
  max_boss_progress_pct NUMERIC(5, 1) NOT NULL DEFAULT 0,
  challenge_score INT NOT NULL DEFAULT 0 CHECK (challenge_score BETWEEN 0 AND 100),
  avg_game_speed NUMERIC(4, 2) NOT NULL DEFAULT 1.0,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_td_runs_started_at ON public.timedefense_runs (started_at DESC);
CREATE INDEX IF NOT EXISTS idx_td_runs_version ON public.timedefense_runs (balance_version, is_sandbox);
CREATE INDEX IF NOT EXISTS idx_td_runs_level_diff ON public.timedefense_runs (level, difficulty, outcome);
CREATE INDEX IF NOT EXISTS idx_td_runs_player ON public.timedefense_runs (player_id, started_at DESC);

-- 2. Balance Patch Changelog Table (tracks Before vs After patch comparisons)
CREATE TABLE IF NOT EXISTS public.timedefense_patches (
  balance_version TEXT PRIMARY KEY,
  released_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  summary TEXT NOT NULL DEFAULT '',
  notes TEXT NOT NULL DEFAULT ''
);

INSERT INTO public.timedefense_patches (balance_version, summary, notes)
VALUES (
  'v1.2-cloud-telemetry',
  'Rebalance Pass 1 + Pass 2 + Cloud Feedback Loop Baseline',
  'Tower-cost-scaled upgrades, 21-combo tuning, Wave 16+ Colossus siege boss, path penetration & player behavior telemetry.'
)
ON CONFLICT (balance_version) DO NOTHING;

-- ============================================================================
-- 3. Row Level Security (RLS) — Strictly isolated to TimeDefense tables only
--    * anon can INSERT / UPDATE runs (for silent auto-upsert by run_id)
--    * anon can SELECT runs & patches (for analytics.html & CLI analyzer)
--    * anon CANNOT DELETE runs (prevents accidental/malicious wipe)
-- ============================================================================
ALTER TABLE public.timedefense_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timedefense_patches ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "TimeDefense anon select runs" ON public.timedefense_runs;
DROP POLICY IF EXISTS "TimeDefense anon insert runs" ON public.timedefense_runs;
DROP POLICY IF EXISTS "TimeDefense anon update runs" ON public.timedefense_runs;
DROP POLICY IF EXISTS "TimeDefense anon select patches" ON public.timedefense_patches;

CREATE POLICY "TimeDefense anon select runs"
  ON public.timedefense_runs FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "TimeDefense anon insert runs"
  ON public.timedefense_runs FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    length(run_id) >= 6
    AND length(run_id) <= 96
    AND level BETWEEN 1 AND 5
    AND challenge_score BETWEEN 0 AND 100
  );

CREATE POLICY "TimeDefense anon update runs"
  ON public.timedefense_runs FOR UPDATE
  TO anon, authenticated
  USING (length(run_id) >= 6)
  WITH CHECK (
    length(run_id) >= 6
    AND length(run_id) <= 96
    AND level BETWEEN 1 AND 5
    AND challenge_score BETWEEN 0 AND 100
  );

CREATE POLICY "TimeDefense anon select patches"
  ON public.timedefense_patches FOR SELECT
  TO anon, authenticated
  USING (true);
