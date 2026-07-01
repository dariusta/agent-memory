---
title: >-
    Wiki Index
category: meta
summary: >-
    Master index of every page in this knowledge wiki, grouped by category. Updated by wiki-update / wiki-capture on every sync.
updated: 2026-07-01T04:22:28Z
---

# Wiki Index

Compiled knowledge distilled from projects and conversations. This index lists every page by category so retrieval can filter cheaply before reading any page body.

## Categories

- **concepts/** — general ideas, architectures, mental models
- **entities/** — tools, services, people, organizations
- **skills/** — reusable patterns, techniques, how-tos
- **references/** — source summaries and external material
- **synthesis/** — cross-project analysis and connections
- **projects/** — project-specific knowledge (`projects/<name>/<name>.md` is each project's anchor)
- **journal/** — dated notes and running logs

## Pages

### concepts

- [[kori-navigation-architecture]] — Kori mixes Expo Router file routes (full-screen pages) with an `activeTab` React state in `Home.tsx` for the 5 home tabs; open a home tab with `setActiveTab`, not a router push.
- [[kori-ios-build-run]] — install Kori on a physical iPhone when Xcode-beta has no Simulator (xcodebuild Release + devicectl, ECID vs CoreDevice UUID); the iOS 26+ scene-lifecycle SIGTRAP + SceneDelegate fix; iCloud-derivedDataPath codesign trap; NODE_BINARY symlink; plus the Debug dev-client keyWindow crash and sim-automation walls.
- [[behavioral-realism-anti-detection]] — emulating a human across a device fleet: the biggest tell is every device behaving identically + shared egress IP, not swipe geometry; prioritize per-account identity, scheduling, action-mix, aging.
- [[iphone-control-architecture]] — the esp32farm rig stack (ESP32 BLE-HID → DVT capture → RapidOCR/OpenCV → Flask panel → tsx flow engine), from-scratch runtime setup, and the per-account humanization module map.
- [[video-url-resolution]] — stratton-internal: a produced video usually lives in the `video_assets` table, not `video_tasks.final_video_url`; resolve any task's playable cut through the canonical `lib/final-video.ts` (single + batch), never a single column.
- [[social-app-automation-mechanics]] — 2026 IG/TikTok automation specifics: TikTok two-tap account switcher, pause the playing feed before nav (opening a profile from a moving feed defeats even the agent), IG Reels has no follow/favorite rail, IG insights need a Professional account, deterministic --media_index camera-roll picker + the 2026 IG camera-first bottom-drawer composer grid coords (4-col, yf 0.696, cell 0 = camera), analytics no-content acceptor, the replace_text field-edit primitive, count-based warmup, keyword→niche search, smart-comment.

### entities

- [[trigger-dev]] — background-job platform; env chosen by `TRIGGER_SECRET_KEY` prefix, code changes need a worker redeploy.

### skills

- [[trigger-dev-environment-routing]] — "TTL (10m) expired" = job routed to the dev env (no persistent worker); diagnose by env/key, don't reach for a `ttl` knob.
- [[ffmpeg-filter-version-compatibility]] — version-gated filter options (e.g. `curves interp=pchip`, ffmpeg 5.1+) fail the whole graph on older binaries; validate against the prod ffmpeg.
- [[ios-permission-review-prompts]] — native iOS rating (SKStoreReview) and notification-permission dialogs are suppressed in dev/simulator or after first install; branch on real permission state with a Settings deep-link fallback.
- [[macos-vision-ocr-models-missing]] — macOS 26 (Darwin 27) dropped the on-device Vision text models (`Found bundles : { }`); both legacy and modern Vision APIs fail. Swap to a self-contained engine like RapidOCR.
- [[dvt-launch-does-not-wake-display]] — `pymobiledevice3 dvt launch` starts the app but doesn't wake the screen; DVT capture reads a black frame and flows time out. Wake first; disable Auto-Lock.
- [[ios26-scene-lifecycle-launch-crash]] — building against the iOS 26/27 SDK hard-crashes at launch (SIGTRAP, `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`) if Info.plist declares a SceneManifest but the app never adopts UIScene (stock Expo SDK 54 / RN 0.81). Fix: add a real SceneDelegate.
- [[icloud-synced-repo-breaks-codesign]] — building an Xcode project inside iCloud-synced `~/Documents` makes codesign reject `.appex` ("FinderInfo … detritus not allowed"); iCloud re-stamps mid-build so stripping fails. Point derivedDataPath at `~/Library`.
- [[ui-automation-matcher-cascade]] — robust UI tapping cascade `template → region → OCR → LLM agent`, deterministic-first; a *wrong* CV template (or guessed coordinate) is worse than none; mark fragile taps optional; the whole cascade (agent included) assumes a static frame — a moving target needs a pause, not more escalation; give the escalation agent enough steps and a test-runner cap ≥ ~500s (both low caps masquerade as matching failures) + a safety-filter-clean guard prompt, and prefer a deterministic primitive (replace_text, --media_index) over the agent for rote sequences.
- [[opencode-transcript-storage]] — opencode 1.17.x keeps all session messages in a SQLite DB (`opencode.db`), not per-session JSON files, and has no export CLI; reconstruct a transcript by joining `message` + `part` on `session_id`. Plus the plugin-loads-from-a-different-config-dir gotcha.
- [[claude-headless-p-hooks-dont-fire]] — a headless `claude -p` run did not fire the claude-obsidian plugin's PostToolUse auto-commit hook; wrap-script must perform any needed side effect (commit/format) itself and verify the end-state directly.

### references

_(none yet)_

### synthesis

_(none yet)_

### projects

- [[agent-memory-wiki]] — this repo: the cross-agent auto-distill memory system; every coding agent (Claude/Codex/opencode/pi/Gemini) funnels ending/compacting sessions through `bin/wiki-distill.sh` → headless `claude -p` → `wiki-update` skill → self-commit. Design reasoning + gotchas; wiring in `docs/agent-hooks.md`.
- [[stratton-internal]] — Next.js 15 / Railway app generating AI UGC video ads; Trigger.dev background jobs; staging shares the prod Supabase DB.
- [[kori]] — React Native / Expo iOS app for learning Korean ("Korean Passport"); Firebase + Superwall; hybrid Expo Router + in-component tab navigation. Sibling Stratton project.
- [[iphone-control]] — physical-iPhone automation farm (esp32farm): ESP32 BLE-HID + DVT capture + RapidOCR/CV vision, running humanized Instagram/TikTok warmup flows with deterministic-first interactions and an LLM agent fallback.

### journal

_(none yet)_
