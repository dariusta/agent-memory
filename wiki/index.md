---
title: >-
    Wiki Index
category: meta
summary: >-
    Master index of every page in this knowledge wiki, grouped by category. Updated by wiki-update / wiki-capture on every sync.
updated: 2026-07-01T08:31:02Z
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
- [[build-agent-prompt-references]] — stratton-internal: the build agent authors prompts from a per-model guide (gpt-image / seedance-2 / happy-horse) injected by model prefix in `canvas-build/route.ts`; guides are prose-editable (drift test doesn't pin content); each model wants a *different* discipline, and the Happy Horse guide had wrongly inherited Seedance's role-only rule.
- [[social-app-automation-mechanics]] — 2026 IG/TikTok automation specifics: TikTok two-tap account switcher, pause the playing feed before nav (opening a profile from a moving feed defeats even the agent), IG Reels has no follow/favorite rail, IG insights need a Professional account, deterministic --media_index camera-roll picker + the 2026 IG camera-first bottom-drawer composer grid coords (4-col, yf 0.696, cell 0 = camera), analytics no-content acceptor, the replace_text field-edit primitive, count-based warmup, keyword→niche search, smart-comment.
- [[voice-scrape-isolation-pipeline]] — stratton-internal's "Scrape & find voice": TikTok-only harvest (Scrape Creators) → RunPod isolation (Demucs/DeepFilterNet3/pyannote/Whisper) → a strict solo-speech acceptance gate. The yield bottleneck is the gate-vs-source (not the scraper or models); the gate was already loosened in prod, so the source is the limit and a YouTube long-form audio path is the real lever. Rejection-reason taxonomy + the fallback-path diagnostic gap.

### entities

- [[trigger-dev]] — background-job platform; env chosen by `TRIGGER_SECRET_KEY` prefix, code changes need a worker redeploy — a merged fix stays inert until `trigger deploy` (compare deployed worker date vs commit date; web redeploy ≠ worker deploy).
- [[scrape-creators]] — third-party IG/TikTok scraping API used by stratton-internal; single-item fetch endpoints are GET `?url=` (a POST to one returns a bare 404), account/feed scrapes need a handle.

### skills

- [[trigger-dev-environment-routing]] — "TTL (10m) expired" = job routed to the dev env (no persistent worker); diagnose by env/key, don't reach for a `ttl` knob.
- [[ffmpeg-filter-version-compatibility]] — version-gated filter options (e.g. `curves interp=pchip`, ffmpeg 5.1+) fail the whole graph on older binaries; validate against the prod ffmpeg.
- [[scrape-creators-get-endpoints]] — a bare "Scrape Creators returned 404: Not Found" usually means a GET-only `?url=` endpoint was hit with POST+JSON; when migrating a vendor client's call convention, grep every callsite for the old shape (one straggler `getInstagramPost` 404'd all IG "Mark posted" paths). The *same* 404 also recurs when the fix is merged but the Trigger.dev worker still runs pre-fix POST code (deploy lag); the 404 **body** distinguishes them — JSON `Post not found` = real missing post, plain-text `Not Found` = wrong method/stale deploy.
- [[ios-permission-review-prompts]] — native iOS rating (SKStoreReview) and notification-permission dialogs are suppressed in dev/simulator or after first install; branch on real permission state with a Settings deep-link fallback.
- [[macos-vision-ocr-models-missing]] — macOS 26 (Darwin 27) dropped the on-device Vision text models (`Found bundles : { }`); both legacy and modern Vision APIs fail. Swap to a self-contained engine like RapidOCR.
- [[dvt-launch-does-not-wake-display]] — `pymobiledevice3 dvt launch` starts the app but doesn't wake the screen; DVT capture reads a black frame and flows time out. Wake first; disable Auto-Lock.
- [[ios26-scene-lifecycle-launch-crash]] — building against the iOS 26/27 SDK hard-crashes at launch (SIGTRAP, `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`) if Info.plist declares a SceneManifest but the app never adopts UIScene (stock Expo SDK 54 / RN 0.81). Fix: add a real SceneDelegate.
- [[icloud-synced-repo-breaks-codesign]] — building an Xcode project inside iCloud-synced `~/Documents` makes codesign reject `.appex` ("FinderInfo … detritus not allowed"); iCloud re-stamps mid-build so stripping fails. Point derivedDataPath at `~/Library`.
- [[ui-automation-matcher-cascade]] — robust UI tapping cascade `template → region → OCR → LLM agent`, deterministic-first; a *wrong* CV template (or guessed coordinate) is worse than none; mark fragile taps optional; the whole cascade (agent included) assumes a static frame — a moving target needs a pause, not more escalation; give the escalation agent enough steps and a test-runner cap ≥ ~500s (both low caps masquerade as matching failures) + a safety-filter-clean guard prompt, and prefer a deterministic primitive (replace_text, --media_index) over the agent for rote sequences.
- [[opencode-transcript-storage]] — opencode 1.17.x keeps all session messages in a SQLite DB (`opencode.db`), not per-session JSON files, and has no export CLI; reconstruct a transcript by joining `message` + `part` on `session_id`. Plus the plugin-loads-from-a-different-config-dir gotcha.
- [[claude-headless-p-hooks-dont-fire]] — a headless `claude -p` run did not fire the claude-obsidian plugin's PostToolUse auto-commit hook; wrap-script must perform any needed side effect (commit/format) itself and verify the end-state directly.
- [[deployed-env-overrides-code-defaults]] — a running service's live env vars silently override git-tracked config defaults (e.g. an `os.getenv(..., default)` read at import); verify the actual deployed config before tuning code, or you'll guess against a value that isn't running (stratton's voice-isolation gate was already relaxed in prod).
- [[instrument-before-tuning-a-gate]] — when a strict quality/acceptance gate keeps rejecting inputs, log the rejection-reason distribution before loosening thresholds — make gate-vs-source a number, not a guess, and check the graceful fallback path isn't silently dropping that signal.
- [[ai-video-model-prompt-discipline]] — generative video models reward opposite prompt shapes: reference-token models (Seedance `@image1`) want role-only refs + short split cuts; image-to-video models (Happy Horse) want full descriptive prose+dialogue over a wired start frame. Bake exact-detail into the start frame; VO ≈2.5 words/sec; duration/aspect are node params, not prose.

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
