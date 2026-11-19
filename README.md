# TimeDefense

Godot `4.7.2` 2D Tower Defense prototype built around time manipulation (`Rewind` between waves, `Pause` 8s/10s, `Haste` +50% tower & build speed for 30s), lighter `+5%` permanent mission mutations, the 5-wave `Surge` countdown, the 4×3 Damage Matrix (`Normal`, `Piercing`, `Laser`, `Time` Decay DoT), 5 towers (with `Chrono Slow` and `Time Decay Rail Gun`), per-tower targeting (`First`, `Last`, `Strongest`, `Weakest`, `Fastest`, `Slowest`), rogue-like persistent meta-research, and the `Hive Destroyer` base-attack race.

## Play or Install on Phone & Desktop (Auto-Updated on Push)
- **Live PWA Web URL:** `https://toxicw8st.github.io/time-defense/`
- **Direct Downloads (via in-game `DL / App` Top Bar button or direct URLs):**
  - **Installable PWA:** Chrome menu -> **Install app** (Android Pixel) or Share -> **Add to Home Screen** (iPhone Safari), backed by `index.manifest.json` + `index.service.worker.js` for offline play.
  - **Android APK (debug-signed):** `https://toxicw8st.github.io/time-defense/downloads/TimeDefense.apk`
  - **Offline Web ZIP Bundle:** `https://toxicw8st.github.io/time-defense/downloads/TimeDefense-Web.zip`
- **In-Game Controls:**
  - **Build / Upgrade:** Tap or click a build pad (`P1–P14`) then tap a tower (`Blaster $90`, `Mortar $110`, `Laser $100`, `Slow $100`, `Rail $375`), or tap a tower button first then tap any open pad.
  - **Targeting & Range:** Select any built tower and tap `Target:` to cycle `First / Last / Strongest / Weakest / Fastest / Slowest` (`First` default). Range upgrades reach `2x` range (`+25% / +60% / +100%`).
  - **Mobile / Touch Details:** Tap any button (even disabled ones) to view its stats in the info box. Use **Top Bar** buttons (`|| / 1x / 2x / 3x`, `Levels / Lab`, `Menu`, `Dbg`, `Full`, `DL / App`) without needing a keyboard.

## Automated CI/CD (`.github/workflows/deploy.yml`)
Every `git push` to `master` or `main`:
1. Installs & caches Godot `4.7.2-stable` headless + export templates.
2. Runs all 9 automated test suites (`tests/test_step0.tscn`–`tests/test_step8.tscn`).
3. Exports the single-threaded Web PWA build (`index.manifest.json`, `index.service.worker.js`, `144/180/512` icons), packages `TimeDefense-Web.zip`, builds debug-signed `TimeDefense.apk`, and deploys everything to GitHub Pages.
