#!/usr/bin/env node
/**
 * TimeDefense — Closed-Loop Playtest Telemetry Analyzer
 * Pulls live runs from your Supabase public.timedefense_runs table (+ any local
 * desktop user://timedefense_analytics.json or telemetry/*.json files), compares
 * patch versions, diagnoses difficulty/economy/tower outliers, and outputs concrete
 * tuning proposals for data/balance.gd and data/waves.gd.
 *
 * Usage:
 *   node tools/analyze_telemetry.mjs
 *   node tools/analyze_telemetry.mjs --version=v1.2-cloud-telemetry
 *   node tools/analyze_telemetry.mjs --include-sandbox
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const SUPABASE_URL = "https://ojtcgdsryjylpryevurl.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9qdGNnZHNyeWp5bHByeWV2dXJsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3NDEzOTUsImV4cCI6MjEwNDMxNzM5NX0.WCTmrNwn3P2j-NemAk4Vu6ZTzVYcMIglqde5UjR3gjI";

const args = process.argv.slice(2);
const includeSandbox = args.includes("--include-sandbox");
const asJson = args.includes("--json");
const verArg = args.find(a => a.startsWith("--version="));
const versionFilter = verArg ? verArg.split("=")[1] : "";

function normalizeRow(row) {
  const p = (row && row.payload && typeof row.payload === "object") ? { ...row.payload } : {};
  return {
    ...p,
    run_id: row.run_id || p.run_id,
    balance_version: row.balance_version || p.balance_version || "v1.0",
    platform: row.platform || p.platform || "unknown",
    started_at: row.started_at || p.started_at || "",
    level: Number(row.level ?? p.level ?? 1),
    difficulty: row.difficulty || p.difficulty || "standard",
    is_sandbox: Boolean(row.is_sandbox ?? p.is_sandbox ?? false),
    outcome: row.outcome || p.outcome || "in_progress",
    max_wave_reached: Number(row.max_wave_reached ?? p.max_wave_reached ?? 1),
    lives_remaining: Number(row.lives_remaining ?? p.lives_remaining ?? 0),
    lives_lost_total: Number(row.lives_lost_total ?? p.lives_lost_total ?? 0),
    surges_suffered: Number(row.surges_suffered ?? p.surges_suffered ?? 0),
    early_calls: Number(row.early_calls ?? p.early_calls ?? 0),
    money_unspent_end: Number(row.money_unspent_end ?? p.money_unspent_end ?? 0),
    avg_unspent_cash: Number(row.avg_unspent_cash ?? p.avg_unspent_cash ?? 0),
    max_enemy_progress_pct: Number(row.max_enemy_progress_pct ?? p.max_enemy_progress_pct ?? 0),
    avg_kill_progress_pct: Number(row.avg_kill_progress_pct ?? p.avg_kill_progress_pct ?? 0),
    max_boss_progress_pct: Number(row.max_boss_progress_pct ?? p.max_boss_progress_pct ?? 0),
    challenge_score: Number(row.challenge_score ?? p.challenge_score ?? 0),
    avg_game_speed: Number(row.avg_game_speed ?? p.avg_game_speed ?? 1.0)
  };
}

async function fetchSupabaseRuns() {
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/timedefense_runs?select=*&order=started_at.desc&limit=500`, {
      headers: { apikey: SUPABASE_ANON_KEY, Authorization: `Bearer ${SUPABASE_ANON_KEY}` }
    });
    if (res.status === 404) {
      return { ok: false, status: 404, note: "Table public.timedefense_runs not created yet — run supabase/timedefense_analytics.sql in Supabase SQL Editor.", runs: [] };
    }
    if (!res.ok) return { ok: false, status: res.status, note: `Supabase HTTP ${res.status}`, runs: [] };
    const rows = await res.json();
    return { ok: true, status: 200, note: `Fetched ${rows.length} cloud run(s) from Supabase.`, runs: rows.map(normalizeRow) };
  } catch (e) {
    return { ok: false, status: 0, note: `Supabase fetch error: ${e.message}`, runs: [] };
  }
}

function loadLocalJsonFiles() {
  const found = [];
  const candidates = [];
  const appData = process.env.APPDATA || path.join(os.homedir(), ".local", "share");
  candidates.push(path.join(appData, "Godot", "app_userdata", "TimeDefense", "timedefense_analytics.json"));
  const telDir = path.join(process.cwd(), "telemetry");
  if (fs.existsSync(telDir)) {
    for (const f of fs.readdirSync(telDir)) {
      if (f.endsWith(".json")) candidates.push(path.join(telDir, f));
    }
  }
  for (const fp of candidates) {
    if (!fs.existsSync(fp)) continue;
    try {
      const parsed = JSON.parse(fs.readFileSync(fp, "utf8"));
      const arr = Array.isArray(parsed) ? parsed : (Array.isArray(parsed.runs) ? parsed.runs : []);
      for (const r of arr) found.push(normalizeRow(r));
    } catch {}
  }
  return found;
}

function analyze(allRuns) {
  const runs = allRuns.filter(r => {
    if (!includeSandbox && r.is_sandbox) return false;
    if (versionFilter && r.balance_version !== versionFilter) return false;
    return true;
  });

  const byVer = {}, waveMap = {}, towerMap = {}, zoneMap = {}, enemyLeaks = {};
  const btnPresses = {}, disabledTaps = {}, tapLand = {}, tapPort = {};
  const orientations = { landscape: 0, portrait: 0 };
  let totalTaps = 0, touchTaps = 0, totalScrolls = 0, guideDismissed = 0, guideCompleted = 0;
  const upgrades = { damage: 0, range: 0, fire_rate: 0 };
  const powers = { rewind: 0, pause: 0, haste: 0 };
  let wins = 0, losses = 0, sumCs = 0, sumKp = 0, kpCnt = 0, sumBp = 0, bpCnt = 0, sumSpd = 0, surges = 0;

  for (const r of runs) {
    if (r.outcome === "won") wins++; else if (r.outcome === "lost") losses++;
    sumCs += r.challenge_score;
    sumSpd += r.avg_game_speed;
    surges += r.surges_suffered;
    if (r.avg_kill_progress_pct > 0) { sumKp += r.avg_kill_progress_pct; kpCnt++; }
    if (r.max_boss_progress_pct > 0) { sumBp += r.max_boss_progress_pct; bpCnt++; }

    const bv = r.balance_version;
    if (!byVer[bv]) byVer[bv] = { version: bv, runs: 0, wins: 0, losses: 0, sumCs: 0, sumKp: 0, kpCnt: 0, sumWave: 0 };
    byVer[bv].runs++; if (r.outcome === "won") byVer[bv].wins++; if (r.outcome === "lost") byVer[bv].losses++;
    byVer[bv].sumCs += r.challenge_score; byVer[bv].sumWave += r.max_wave_reached;
    if (r.avg_kill_progress_pct > 0) { byVer[bv].sumKp += r.avg_kill_progress_pct; byVer[bv].kpCnt++; }

    for (const pk of ["rewind", "pause", "haste"]) powers[pk] += Number((r.powers_used || {})[pk] || 0);
    for (const uk of ["damage", "range", "fire_rate"]) upgrades[uk] += Number((r.upgrade_counts || {})[uk] || 0);
    for (const [zk, zc] of Object.entries(r.zone_builds || {})) zoneMap[zk] = (zoneMap[zk] || 0) + Number(zc || 0);
    for (const [et, ec] of Object.entries(r.leaks_by_enemy || {})) enemyLeaks[et] = (enemyLeaks[et] || 0) + Number(ec || 0);
    const ui = r.ui_telemetry || {};
    totalTaps += Number(ui.total_taps || 0);
    touchTaps += Number(ui.touch_taps || 0);
    totalScrolls += Number(ui.scroll_events || 0);
    const orient = (ui.viewport_profile && ui.viewport_profile.orientation) || "landscape";
    orientations[orient] = (orientations[orient] || 0) + 1;
    for (const [bk, bc] of Object.entries(ui.button_presses || {})) btnPresses[bk] = (btnPresses[bk] || 0) + Number(bc || 0);
    for (const [dk2, dc] of Object.entries(ui.disabled_taps || {})) disabledTaps[dk2] = (disabledTaps[dk2] || 0) + Number(dc || 0);
    for (const [ck, cc] of Object.entries(ui.tap_grid_landscape || {})) tapLand[ck] = (tapLand[ck] || 0) + Number(cc || 0);
    for (const [ck2, cc2] of Object.entries(ui.tap_grid_portrait || {})) tapPort[ck2] = (tapPort[ck2] || 0) + Number(cc2 || 0);
    if (ui.guide_stats?.dismissed_at) guideDismissed++;
    if (ui.guide_stats?.completed) guideCompleted++;

    for (const wl of (r.wave_log || [])) {
      const w = Number(wl.wave || 1);
      if (!waveMap[w]) waveMap[w] = { wave: w, plays: 0, leaks: 0, sumCash: 0, sumPen: 0, byEnemy: {} };
      waveMap[w].plays++; waveMap[w].leaks += Number(wl.lives_lost || 0);
      waveMap[w].sumCash += Number(wl.money_end || 0);
      waveMap[w].sumPen += Number(wl.max_progress_pct || 0);
      for (const [et, ec] of Object.entries(wl.leaks_by_enemy || {})) waveMap[w].byEnemy[et] = (waveMap[w].byEnemy[et] || 0) + Number(ec || 0);
    }

    for (const [tk, rec] of Object.entries(r.tower_stats || {})) {
      if (!towerMap[tk]) towerMap[tk] = { type: tk, name: rec.name || tk, is_combo: !!rec.is_combo || tk.includes("+"), built: 0, spent: 0, damage: 0, kills: 0, runs: 0, wins: 0 };
      const t = towerMap[tk];
      t.runs++; if (r.outcome === "won") t.wins++;
      t.built += Number(rec.built || 0); t.spent += Number(rec.spent || 0);
      t.damage += Number(rec.damage || 0); t.kills += Number(rec.kills || 0);
    }
  }

  const towers = Object.values(towerMap).map(t => ({
    ...t,
    dpd: t.spent > 0 ? t.damage / t.spent : 0,
    pickPct: runs.length ? (t.runs / runs.length) * 100 : 0,
    winPct: t.runs ? (t.wins / t.runs) * 100 : 0
  })).sort((a, b) => b.dpd - a.dpd);
  const dpds = towers.filter(t => t.built > 0 && t.damage > 0).map(t => t.dpd).sort((a, b) => a - b);
  const medDpd = dpds.length ? dpds[Math.floor(dpds.length / 2)] : 0;

  const waves = Object.values(waveMap).map(w => ({
    wave: w.wave, plays: w.plays, leaks: w.leaks,
    avgCash: w.plays ? w.sumCash / w.plays : 0,
    avgMaxPen: w.plays ? w.sumPen / w.plays : 0,
    topEnemy: Object.entries(w.byEnemy).sort((a, b) => b[1] - a[1])[0]?.[0] || "none"
  })).sort((a, b) => (b.leaks - a.leaks) || (b.avgMaxPen - a.avgMaxPen));

  const proposals = [];
  const avgCs = runs.length ? sumCs / runs.length : 0;
  const avgKp = kpCnt ? sumKp / kpCnt : 0;
  const avgBp = bpCnt ? sumBp / bpCnt : 0;
  const avgSpd = runs.length ? sumSpd / runs.length : 1.0;
  const fin = wins + losses;
  const wr = fin ? (wins / fin) * 100 : 0;

  if (runs.length > 0) {
    if (avgKp > 0 && avgKp < 45 && avgCs < 45) {
      proposals.push(`INCREASE EARLY/MID PRESSURE (data/waves.gd): Avg enemy dies at ${avgKp.toFixed(0)}% path (Challenge ${avgCs.toFixed(0)}/100, Speed ${avgSpd.toFixed(2)}x). Consider +8-12% wave s$ budget or +5% base enemy speed.`);
    }
    if (avgBp > 0 && avgBp < 50) {
      proposals.push(`BUFF BOSS DURABILITY (data/balance.gd): Bosses only reach ${avgBp.toFixed(0)}% of path on average — increase Juggernaut/Colossus HP by +15% or reduce Piercing boss mult slightly.`);
    }
    for (const t of towers) {
      if (medDpd > 1 && t.built >= 2 && t.dpd >= medDpd * 1.8) {
        proposals.push(`NERF OUTLIER ${t.type} (data/balance.gd): ${t.dpd.toFixed(1)} Dmg/$ (${(t.dpd / medDpd).toFixed(1)}x median ${medDpd.toFixed(1)}) across ${t.built} builds — reduce damage ~10-15% or raise merge/cost.`);
      } else if (medDpd > 1 && t.built >= 2 && t.damage > 0 && t.dpd <= medDpd * 0.45 && t.type !== "slow" && t.type !== "slow+slow") {
        proposals.push(`BUFF UNDERPERFORMER ${t.type} (data/balance.gd): ${t.dpd.toFixed(1)} Dmg/$ (${((t.dpd / medDpd) * 100).toFixed(0)}% of median) — buff damage +15-20% or lower cost.`);
      }
    }
    const totUpg = upgrades.damage + upgrades.range + upgrades.fire_rate;
    if (totUpg >= 8 && upgrades.range / totUpg < 0.12) {
      proposals.push(`REDUCE RANGE UPGRADE COST (data/balance.gd): Range is only ${((upgrades.range / totUpg) * 100).toFixed(0)}% of upgrades bought.`);
    }
    if (waves[0] && waves[0].leaks > 0) {
      proposals.push(`INSPECT CHOKE WAVE W${waves[0].wave} (data/waves.gd): ${waves[0].leaks} lives lost (top culprit: ${waves[0].topEnemy}, avg cash left $${waves[0].avgCash.toFixed(0)}).`);
    }
    const topDisabled = Object.entries(disabledTaps).sort((a, b) => b[1] - a[1])[0];
    if (topDisabled && topDisabled[1] >= 4) {
      proposals.push(`UI FRICTION (scripts/hud.gd): Disabled button "${topDisabled[0]}" tapped ${topDisabled[1]} times — clarify why it's locked or make requirement more visible.`);
    }
  }

  return {
    totalRuns: runs.length, wins, losses, winRatePct: Number(wr.toFixed(1)),
    avgChallenge: Number(avgCs.toFixed(1)), avgKillPathPct: Number(avgKp.toFixed(1)),
    avgBossPeakPct: Number(avgBp.toFixed(1)), avgGameSpeed: Number(avgSpd.toFixed(2)),
    avgSurgesPerRun: runs.length ? Number((surges / runs.length).toFixed(2)) : 0,
    medianDpd: Number(medDpd.toFixed(2)), powers, upgrades, zones: zoneMap,
    byVersion: Object.values(byVer), topWaves: waves.slice(0, 8), towers: towers.slice(0, 15),
    enemyLeaks, proposals,
    ui: {
      totalTaps, touchTaps, totalScrolls, orientations, guideDismissed, guideCompleted,
      topButtons: Object.entries(btnPresses).sort((a, b) => b[1] - a[1]).slice(0, 12),
      topDisabledTaps: Object.entries(disabledTaps).sort((a, b) => b[1] - a[1]).slice(0, 8),
      hotCellsLandscape: Object.entries(tapLand).sort((a, b) => b[1] - a[1]).slice(0, 6),
      hotCellsPortrait: Object.entries(tapPort).sort((a, b) => b[1] - a[1]).slice(0, 6)
    }
  };
}

const sb = await fetchSupabaseRuns();
const localRuns = loadLocalJsonFiles();
const mergedMap = new Map();
for (const r of localRuns) if (r.run_id) mergedMap.set(r.run_id, r);
for (const r of sb.runs) if (r.run_id) mergedMap.set(r.run_id, r);
const report = analyze(Array.from(mergedMap.values()));

if (asJson) {
  console.log(JSON.stringify({ source: { supabase: sb.note, localCount: localRuns.length, uniqueRuns: mergedMap.size }, report }, null, 2));
} else {
  console.log("=== TIMEDEFENSE CLOSED-LOOP TELEMETRY REPORT ===");
  console.log(`Source: ${sb.note} | Local Desktop/Folder runs: ${localRuns.length} | Unique merged: ${mergedMap.size}`);
  console.log(`Filtered Runs: ${report.totalRuns} (W:${report.wins} L:${report.losses} WR:${report.winRatePct}%) | Challenge: ${report.avgChallenge}/100 | KillPath: ${report.avgKillPathPct}% | BossPeak: ${report.avgBossPeakPct}% | AvgSpd: ${report.avgGameSpeed}x`);
  console.log(`Powers R:${report.powers.rewind} P:${report.powers.pause} H:${report.powers.haste} | Upgrades D:${report.upgrades.damage} R:${report.upgrades.range} S:${report.upgrades.fire_rate} | Med Dmg/$: ${report.medianDpd}`);
  console.log("\n--- Patch Comparison ---");
  for (const v of report.byVersion) console.log(`  ${v.version}: runs=${v.runs} W=${v.wins} L=${v.losses} avgCS=${(v.sumCs / v.runs).toFixed(0)}/100 avgKillPath=${v.kpCnt ? (v.sumKp / v.kpCnt).toFixed(0) : 0}%`);
  console.log("\n--- Actionable Rebalance Proposals ---");
  if (!report.proposals.length) console.log("  (Play 1+ non-sandbox runs after applying supabase/timedefense_analytics.sql to generate tuning proposals.)");
  for (const p of report.proposals) console.log("  * " + p);
  console.log("\n--- Top Towers by Dmg/$ ---");
  for (const t of report.towers.slice(0, 10)) console.log(`  ${t.name} (${t.type}): built=${t.built} spent=$${t.spent} dmg=${Math.round(t.damage)} Dmg/$=${t.dpd.toFixed(1)} pick=${t.pickPct.toFixed(0)}% WR=${t.winPct.toFixed(0)}%`);
  console.log("\n--- UI Button & Tap Heatmap Telemetry ---");
  console.log(`  Taps: ${report.ui.totalTaps} (${report.ui.touchTaps} touch) | Orientations: Landscape=${report.ui.orientations.landscape || 0} Portrait=${report.ui.orientations.portrait || 0} | Scrolls=${report.ui.totalScrolls} | Guide Vex: ${report.ui.guideCompleted} completed / ${report.ui.guideDismissed} dismissed`);
  if (report.ui.topButtons.length) console.log("  Top Buttons: " + report.ui.topButtons.map(([k, v]) => `${k}=${v}`).join(", "));
  if (report.ui.topDisabledTaps.length) console.log("  Disabled Taps (UX Friction): " + report.ui.topDisabledTaps.map(([k, v]) => `${k}=${v}`).join(", "));
  if (report.ui.hotCellsLandscape.length) console.log("  Hot Tap Cells (Landscape 16x9): " + report.ui.hotCellsLandscape.map(([k, v]) => `(${k}):${v}`).join(", "));
  if (report.ui.hotCellsPortrait.length) console.log("  Hot Tap Cells (Portrait 9x16): " + report.ui.hotCellsPortrait.map(([k, v]) => `(${k}):${v}`).join(", "));
}
