---
title: >-
    Wiki Index
category: meta
summary: >-
    Master index of every page in this knowledge wiki, grouped by category. Updated by wiki-update / wiki-capture on every sync.
updated: 2026-07-02T00:15:52Z
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
- [[social-app-automation-mechanics]] — 2026 IG/TikTok automation specifics: TikTok two-tap account switcher, pause the playing feed before nav (opening a profile from a moving feed defeats even the agent), IG Reels has no follow/favorite rail, IG insights need a Professional account, deterministic --media_index camera-roll picker + the 2026 IG camera-first bottom-drawer composer grid coords (4-col, yf 0.696, cell 0 = camera), analytics no-content acceptor, the replace_text field-edit primitive, count-based warmup, keyword→niche search (IG Search = nav slot 3 not 1), smart-comment, deterministic 3-pass popup dismisser, permissive OCR handle ladder.
- [[automated-login-2fa]] — iphone-control's login/2FA subsystem: the old "never log in" rule reversed into operator-opt-in gating (`FLOW_ALLOW_PASSWORD_LOGIN`), execution-time (not build-time) TOTP + email-OTP resolution, async `build()`, IMAP OTP fetch with a recency filter, IG's chained new-device email gate + the "code sent once, never resent" trap, and `add_account` mode.
- [[voice-scrape-isolation-pipeline]] — stratton-internal's "Scrape & find voice": TikTok-only harvest (Scrape Creators) → RunPod isolation (Demucs/DeepFilterNet3/pyannote/Whisper) → a strict solo-speech acceptance gate. The yield bottleneck is the gate-vs-source (not the scraper or models); the gate was already loosened in prod, so the source is the limit and a YouTube long-form audio path is the real lever. Rejection-reason taxonomy + the fallback-path diagnostic gap.
- [[voice-isolation-pipeline]] — stratton-internal: the *output-cleaning* half of the voice worker. It was deliberately tuned to KEEP room noise for "iPhone authenticity" (Demucs locates the window, the common path outputs raw audio, DeepFilterNet denoise `off` by default). 2026-07-01: routed both paths through DeepFilterNet + flipped `VI_ENHANCE_MODE off→full` for "just her voice"; the raw-path denoise needs an image rebuild, not just the env flip.
- [[voice-scraping-pipeline]] — stratton-internal: the *selection layer* on top of voice isolation — rank banked clips (`rankHarvestedVoices`, `%fit`+rationale), auto-stamp #1, persist the top 3 to `voice_candidates` for instant switching, and a learning loop (`voice_candidate_feedback` + `loadVoiceLessons`) that replays operator overrides into the ranker prompt; migration 186 applied to prod; the ~10-min slowness was RunPod cold starts, not GPU.
- [[model-catalog-fanout]] — stratton-internal: adding/removing one generation-model id fans out across ~15 sites; `model-catalog.ts` is the typed source of truth, but the Canvas node menu comes from MuAPI's live `/node-schemas` (~400 models), so `model-allowlist.ts` is what actually restricts it; a `skills-drift.test.ts` enforces consistency.
- [[ecom-platform-architecture]] — stratton-internal's *second* surface: a multi-tenant Shopify/Amboras-competitor ecom OS (Medusa v2 strangler migration off `@stockton/commerce`, `/ecom` admin + `/storefront`, a 50+-agent runtime) where AI agents run 50–100 operators' isolated brands. "Finish + extend," not greenfield; deployed to Railway `ecom+apps`; 127 tests, migrations 188–196.
- [[multi-tenant-store-isolation]] — stratton-internal ecom: "Shopify-grade, nothing shared" isolation — Medusa **schema-per-tenant** (ALS-fork + per-connection `search_path`) proven by a live cross-tenant leak test (ORM+raw-SQL, 40 concurrent, zero leak), plus `operator_store_members` membership + `is_store_member` RLS + `requireStoreMember` killing the cookie/service-role bypass; agent tools store-scoped.
- [[ecom-schema-drift-commerce-vs-public]] — stratton-internal ecom: the codebase references a `commerce.*` Postgres schema that does NOT exist in the live DB (`zrfisjbedcwjxzxxorfm`) — every real table is in `public`; pervasive pre-existing drift. Ground-truth table + column reconciliation map (`brand_campaigns`→`ad_campaigns`, `utm_medium`→`utm_channel`, etc.).
- [[ecom-store-connections]] — stratton-internal ecom: each store configures its own integrations (Stripe/3PL/ads/email/MuAPI) from Settings → Connections; a typed `CONNECTIONS` registry, values in `brand_config("connections")` (no migration), AES-256-GCM write-only secrets (API returns has-secret booleans only), platform infra (Supabase/Medusa) shown env-only read-only.

### entities

- [[muapi]] — stratton-internal's primary generation-model provider; its live ~400-model `/node-schemas` drives the Canvas node menu; per-model metadata via `GET /api/v1/models/<id>` (x-api-key); video `duration` is validated server-side but NOT exposed in `input_schema`.
- [[trigger-dev]] — background-job platform; env chosen by `TRIGGER_SECRET_KEY` prefix, code changes need a worker redeploy — a merged fix stays inert until `trigger deploy` (compare deployed worker date vs commit date; web redeploy ≠ worker deploy).
- [[scrape-creators]] — third-party IG/TikTok scraping API used by stratton-internal; single-item fetch endpoints are GET `?url=` (a POST to one returns a bare 404), account/feed scrapes need a handle.
- [[runpod]] — serverless GPU host for stratton-internal's ML workers (voice-isolation, comfy-realism, qc-inference, phone-relay); one endpoint per service, config split between live endpoint env vars and a pinned Docker image tag.
- [[railway]] — the PaaS hosting all of Stratton (web apps, Medusa + Postgres/Redis, workers); deploys per git-branch × environment (ecom app = branch `ecom/app`, env `ecom+apps`); verify the target environment before provisioning billed infra; MCP/CLI tokens expire mid-session; a stale "deployed & LIVE" note ≠ live infra.

### skills

- [[trigger-dev-environment-routing]] — "TTL (10m) expired" = job routed to the dev env (no persistent worker); diagnose by env/key, don't reach for a `ttl` knob.
- [[ffmpeg-filter-version-compatibility]] — version-gated filter options (e.g. `curves interp=pchip`, ffmpeg 5.1+) fail the whole graph on older binaries; validate against the prod ffmpeg.
- [[scrape-creators-get-endpoints]] — a bare "Scrape Creators returned 404: Not Found" usually means a GET-only `?url=` endpoint was hit with POST+JSON; when migrating a vendor client's call convention, grep every callsite for the old shape (one straggler `getInstagramPost` 404'd all IG "Mark posted" paths). The *same* 404 also recurs when the fix is merged but the Trigger.dev worker still runs pre-fix POST code (deploy lag); the 404 **body** distinguishes them — JSON `Post not found` = real missing post, plain-text `Not Found` = wrong method/stale deploy.
- [[html-page-where-json-expected]] — a fetch that returns the framework's HTML 404/error page instead of JSON means the URL matched no route (not a broken handler) — usually a base-path/mount-prefix mismatch after an app is folded under a sub-path; look at the raw body + content-type, and sweep *every* client call site. (Stratton ecom: `ecom/lib/api.ts` fetched `/api` while routes moved to `/api/ecom` → "Failed to load connections".)
- [[ios-permission-review-prompts]] — native iOS rating (SKStoreReview) and notification-permission dialogs are suppressed in dev/simulator or after first install; branch on real permission state with a Settings deep-link fallback.
- [[macos-vision-ocr-models-missing]] — macOS 26 (Darwin 27) dropped the on-device Vision text models (`Found bundles : { }`); both legacy and modern Vision APIs fail. Swap to a self-contained engine like RapidOCR.
- [[dvt-launch-does-not-wake-display]] — `pymobiledevice3 dvt launch` starts the app but doesn't wake the screen; DVT capture reads a black frame and flows time out. Wake first; disable Auto-Lock.
- [[ios26-scene-lifecycle-launch-crash]] — building against the iOS 26/27 SDK hard-crashes at launch (SIGTRAP, `_UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`) if Info.plist declares a SceneManifest but the app never adopts UIScene (stock Expo SDK 54 / RN 0.81). Fix: add a real SceneDelegate.
- [[icloud-synced-repo-breaks-codesign]] — building an Xcode project inside iCloud-synced `~/Documents` makes codesign reject `.appex` ("FinderInfo … detritus not allowed"); iCloud re-stamps mid-build so stripping fails. Point derivedDataPath at `~/Library`.
- [[ui-automation-matcher-cascade]] — robust UI tapping cascade `template → region → OCR → LLM agent`, deterministic-first; a *wrong* CV template (or guessed coordinate) is worse than none; mark fragile taps optional; the whole cascade (agent included) assumes a static frame — a moving target needs a pause, not more escalation; give the escalation agent enough steps and a test-runner cap ≥ ~500s (both low caps masquerade as matching failures) + a safety-filter-clean guard prompt, and prefer a deterministic primitive (replace_text, --media_index) over the agent for rote sequences.
- [[automating-2fa-code-entry]] — two failure modes for any bot entering a 2FA code: resolve rotating TOTP/OTP codes at execution time (a code baked into a plan/prompt is stale by entry → "correct secret, rejected code"), and recency-filter any OTP scraped from an inbox (else an old 6-digit string gets typed). Use IMAP for private catch-all inboxes disposable-mail APIs can't reach.
- [[opencode-transcript-storage]] — opencode 1.17.x keeps all session messages in a SQLite DB (`opencode.db`), not per-session JSON files, and has no export CLI; reconstruct a transcript by joining `message` + `part` on `session_id`. Plus the plugin-loads-from-a-different-config-dir gotcha.
- [[claude-headless-p-hooks-dont-fire]] — a headless `claude -p` run did not fire the claude-obsidian plugin's PostToolUse auto-commit hook; wrap-script must perform any needed side effect (commit/format) itself and verify the end-state directly.
- [[deployed-env-overrides-code-defaults]] — a running service's live env vars silently override git-tracked config defaults (e.g. an `os.getenv(..., default)` read at import); verify the actual deployed config before tuning code, or you'll guess against a value that isn't running (stratton's voice-isolation gate was already relaxed in prod).
- [[instrument-before-tuning-a-gate]] — when a strict quality/acceptance gate keeps rejecting inputs, log the rejection-reason distribution before loosening thresholds — make gate-vs-source a number, not a guess, and check the graceful fallback path isn't silently dropping that signal.
- [[runpod-serverless-env-vs-image]] — on a RunPod serverless endpoint, an env-var change is live on the next cold start but the worker runs a PINNED Docker image — a source change doesn't ship until you rebuild+push and repoint. Check the endpoint's image tag before claiming a code fix is live; big CUDA images can't be built in a lightweight agent sandbox.
- [[runpod-serverless-cold-start-latency]] — when a serverless-GPU feature feels slow (minutes) but the compute is sub-second, the wall-clock is cold-starts × sequential calls, not the GPU; fix by warming the endpoint (`idleTimeout` spanning a whole run, `min=0` = no idle cost, raise `max`), running a parallel worker pool, and baking model weights into the image. Read worker logs to confirm; config is a live change, no deploy.
- [[ai-video-model-prompt-discipline]] — generative video models reward opposite prompt shapes: reference-token models (Seedance `@image1`) want role-only refs + short split cuts; image-to-video models (Happy Horse) want full descriptive prose+dialogue over a wired start frame. Bake exact-detail into the start frame; VO ≈2.5 words/sec; duration/aspect are node params, not prose.
- [[single-candidate-bypasses-quality-gate]] — two traps in any "search → filter → link" flow: (1) a matcher that only runs with 2+ candidates lets a lone candidate through blind and silently ships a mismatch — keep the acceptability gate on for N=1; (2) when a structured filter attribute is missing, backfill it from the richest media you hold (vision on a reference face) rather than free-text tags, with explicit/operator values always winning. Surfaced by stratton's wrong-gender voice cast.
- [[vitest-stale-worktree-pollution]] — running vitest from a repo root also collects test files under stale `.claude/worktrees/*` siblings, which fail with unrelated `@/` alias-resolution errors that aren't your change; scope with `--root <app>`. Any git worktree nested under the repo pollutes root-level test/lint/glob runs.
- [[schema-per-tenant-isolation]] — hard multi-tenancy without N deployments: one app, one Postgres schema per tenant, request → verified membership → AsyncLocalStorage → per-connection `search_path`/ORM-manager fork (closes the raw-SQL leak). Enforce with an automated cross-tenant leak test (ORM+raw-SQL, concurrent), not trust; watch process-global caches (Redis) that leak even when the DB doesn't.
- [[parallel-agents-amplify-schema-drift]] — fan-out agents faithfully copy the same wrong precedent, so a latent inconsistency (a `commerce.*` schema that doesn't exist) gets multiplied across every migration at once. Pin ground truth (DB/contract/deploy target) before fanning out; budget the reconciliation tax; audit the staged diff for secrets (`.env.bak`) + junk before agent-authored commits; the deploy host is the authoritative build.

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
