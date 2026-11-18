# TimeDefense

Godot `4.7.2` 2D Tower Defense prototype built around time manipulation (`Rewind`, `Pause`, `Haste`), permanent mission-level alien mutations, the 5-wave `Surge` countdown, rogue-like persistent meta-research, and the `Hive Destroyer` base-attack race.

## Play on Mobile or Desktop (Auto-Updated on Push)
- **Live Web URL:** `https://toxicw8st.github.io/time-defense/`
- On **iPhone (Safari)** or **Android (Chrome)**: open the link in landscape mode (you can also use **Add to Home Screen** for a full-screen app icon; reload the page after pushing updates to load the latest build).
- **In-Game Controls:**
  - **Build / Upgrade:** Tap or click a build pad (`P1–P14`) then tap a tower (`Blaster $90`, `Mortar $110`, `Laser $100`), or tap a tower button first then tap any open pad.
  - **Mobile / Touch Details:** Tap any button (even disabled ones) to view its stats in the info box. Use **Top Bar** buttons (`|| / 1x / 2x / 3x`, `Levels / Lab`, `Menu`, `Dbg`, `Full`) without needing a keyboard.

## Automated CI/CD (`.github/workflows/deploy.yml`)
Every `git push` to `master` or `main`:
1. Installs & caches Godot `4.7.2-stable` headless + export templates.
2. Runs all 9 automated test suites (`tests/test_step0.tscn`–`tests/test_step8.tscn`).
3. Exports a single-threaded WebAssembly (`Web`) build (compatible with both iOS Safari and Android Chrome without COOP/COEP headers) and deploys it to GitHub Pages.
