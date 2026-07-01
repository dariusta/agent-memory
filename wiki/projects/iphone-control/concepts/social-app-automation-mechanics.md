---
title: >-
    Instagram & TikTok automation mechanics (2026 app UIs)
category: concepts
tags: [instagram, tiktok, ios, automation, computer-vision, ocr, domain/tooling, type/howto]
sources: [projects/iphone-control]
summary: >-
    App-version-specific mechanics learned by driving live IG/TikTok on iOS 26.5 — TikTok's two-tap account switcher, pausing the playing feed before any nav, the moving-feed avatar-tap that even the agent can't recover, IG Reels having no follow/favorite rail, IG insights needing a Professional account, the deterministic --media_index camera-roll picker + the 2026 IG camera-first bottom-drawer composer grid coords, the analytics no-content acceptor, the replace_text field-edit primitive, the count-based probabilistic warmup, keyword→niche search, and smart-comment generation.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.64
lifecycle: draft
lifecycle_changed: 2026-06-30
created: 2026-06-30T02:05:24Z
updated: 2026-07-01T02:44:30Z
---

# Instagram & TikTok automation mechanics (2026 app UIs)

Hard-won, app-version-specific facts from driving live Instagram/TikTok on Austin-hal (iOS 26.5, June 2026). These change as the apps update — treat as dated. Part of [[iphone-control]].

## Pause the playing feed before navigating (TikTok)

The TikTok For You feed (and IG Reels) is a **playing video**. The rig's closed-loop pointer can't lock against motion, so any nav tap (Profile, Search) **drifts** and lands wrong. **Fix: tap screen-center once to pause the video first**, freezing the frame; then every subsequent tap lands. This is a generic preamble for any "navigate away from a playing feed" flow. ^[extracted]

The worst case is **opening the author's profile from the feed** (the avatar/`+` on the right rail): the target is the *moving video element itself*, and in a live wave the `tiktok-follow`, `tiktok-view-profile`, and `instagram-view-profile` flows all failed here — **even the LLM-agent fallback couldn't recover**, because there's no static frame for it to reason over. The fix isn't more agent escalation; it's **pause-first + a CV avatar landmark**. Lesson: the matcher cascade (incl. its agent) assumes a roughly-static frame — see the cascade limit note in [[ui-automation-matcher-cascade]]. ^[extracted]

## TikTok account switch is a two-tap sequence

`tiktok-switch-account`, validated end-to-end (switched `@degenmaster2` → `@user9804916780728`): ^[extracted]

- Path: **pause video → Profile tab → name+chevron pill → "Switch account" → target row → settle.**
- The **Profile tab** = rightmost bottom-nav slot, resolved by layered CV: optional avatar template → `circle{region:'bottom-nav', pick:'rightmost'}` → `navtab{index:4}` → OCR "Profile". (The avatar photo is account-specific, so circle detection is the robust primary, not a static template.)
- The switcher is **two taps, not one**: tap the centred name+chevron **pill** (`region:{xf:0.5, yf:0.21}`) → a small menu appears → tap **"Switch account"** → the account-list sheet → tap the target handle. The old flow tapped `top-center` (too high) and skipped the intermediate "Switch account" tap. The username text lower at ~`yf 0.24` only *copies* the handle — don't aim there.

## Instagram account switcher (nav verified, switch untested with 1 account)

IG profile-tab nav + switcher-open work (single centre-top username tap → bottom sheet). The flow's old `account_switcher` OCR signature was **outdated** — the live 2026 sheet reads **"Add Instagram account" / "Go to Accounts Center"** (not the old "add account" / "log out"), now matched. Actual switching is untestable until a 2nd account is added (manual login only — see the password rule in [[iphone-control]]). ^[extracted]

## IG Reels rail has no follow/favorite

A real trap: on **Instagram Reels** the right rail is like / comment / share / **…** / audio — there is **no follow button and no bookmark/favorite on the rail**. IG "save" lives under the **…** menu and follow is contextual. So generic `follow`/`favorite` rail anchors copied from TikTok will **mis-tap** on IG Reels. TikTok *does* have real rail follow (`+`) and favorite (bookmark) icons. ^[extracted]

## IG insights/analytics require a Professional (Creator) account

Instagram's analytics flows (`analytics-post` / `-overview` / `-audience`) and pro posting features are **gated behind a Professional account** — a personal account simply has no insights surface to read. So a new **`instagram-switch-professional`** flow was built to flip the account first: **Profile → ☰ (top-right) → Settings → "Account type and tools" → "Switch to professional account" → Creator → pick a category**, with the [[ui-automation-matcher-cascade|agent fallback]] driving the multi-step wizard (it's fuzzy Settings navigation, not a fixed rail). Brings the registry to 31 flows. Run the conversion before any analytics flow. ^[extracted]

## Posting flows need pre-existing camera-roll media

`post` / `story` / `reel` can't fabricate content — the composer has to **pick an existing photo/video from the camera roll**. If the device has no media, these flows stall regardless of how good the automation is; that's an environment prerequisite, not an automation bug. Seed the camera roll before testing posting. ^[extracted]

**2026 IG composer nav:** create is the **top-left `+`** (not a bottom-nav slot), and the composer now **defaults to STORY** (camera-first) — the post/reel flows do a deterministic POST/Studio-tab tap to switch off the story default. A `--dry_run=true` var discards the draft instead of publishing, so the in-app editor + music path can be verified without posting real content. Opening `wait_for_screen` accept-lists also had to add a `feed_loading` state — the feed sometimes opens still-loading (reel/ad-topped) and the old strict `home_feed`-only check misfired. ^[extracted]

**The camera-roll thumbnail picker was the remaining brittle step — made deterministic via `--media_index=N` (Session 7).** Even with media seeded, the [[ui-automation-matcher-cascade|LLM agent]] can't reliably tap the *right* thumbnail by description — the grid is a wall of near-identical crops with no stable label. `--media_index=N` hard-codes the Nth grid cell (computed tap coords) + a "Next" tap as deterministic pre-steps, so the agent's escalation goal **drops media selection entirely** and only handles editor/music/caption/share — much cheaper and more reliable. Same deterministic-over-agent move as [[#Replacing a field's contents (not just focusing it)|replace_text]]; wired into `instagram-post`/`-reel`/`-story` + `tiktok-post`. ^[extracted]

**The 2026 IG composer is camera-first with the gallery as a *bottom drawer*, and the grid coordinates are non-obvious.** The first `--media_index` cut *guessed* a 3-column full-screen Recents grid (`yf_start 0.43`) and silently mis-tapped into the camera preview area — burning **~$90 of escalation** before anyone noticed. A *guessed* coordinate is worse than none (the coordinate-space twin of the "wrong CV template" rule in [[ui-automation-matcher-cascade]]). Recalibrated live against a screenshot, the real layout is: **4 columns** (`col = idx%4`, `xf = (col*2+1)/8`), first row at **`yf ≈ 0.696`**, row pitch **`≈ 0.116`**, "Next" at **`yf ≈ 0.079`**, and **grid cell 0 is the camera tile** — the first *real* media item is index **1**. Verified live: `instagram-post --media_index=1 --dry_run` deterministically selects the safe blank clip and lands in the in-app editor (screenshot-confirmed toolbar with the music path). Reel/story share the identical composer + coords; TikTok's grid differs (`--media_index_xf`/`--media_index_yf` override coords if the layout shifts). The publish/discard *tail* after media selection is still LLM-driven and remains the brittle part. ^[extracted]

**Analytics/insights flows need a "no content" success-acceptor.** `instagram-analytics-post` fails on an account with **no published posts** ("You'll see insights here once they become available") — the flow navigates correctly, there's simply nothing to open. This is the same shape the `-audience` flow already handles with an `audience_unavailable` acceptor; post-insights wants an equivalent `no_content` success case so an empty-but-correct run isn't scored as a failure. ^[extracted]

## Count-based probabilistic warmup model

Warmups were rewritten from time-based (`minutes` + fixed `like_every`) to **count-based + fully randomized**, matching a "Feed Warmr" panel design: ^[extracted]

- `videos_min`/`videos_max` → session length = random video count in range (varies every run).
- `watch_min`/`watch_max` → a new **`watch` step** sleeps a uniform-random time per reel (re-rolled each video).
- `like_rate` / `follow_rate` / `favorite_rate` / `comment_rate` → independent per-video coin-flips at each %.
- The session orchestrator ties watch range to the account's dwell personality and like-rate to `sessionLikeRate`. Old `minutes`/`like_every` callers still work (fallback preserved).

## Keyword → niche search prelude

A `keyword`/`keywords` var swaps the generic feed for a search-to-niche prelude: **pause → open Search (CV) → focus the search BAR by position → type keyword → submit (`press` Enter) → land on the niche results → run the engagement loop there**. Validated live on TikTok ("home workout" → niche fitness results). **Key fix:** the field needed the search *bar* tapped by position to focus it — an OCR match on the word "Search" does **not** focus the input. IG mirrors this. ^[extracted]

## Replacing a field's contents (not just focusing it)

Focusing a field is one problem (tap the *bar* by position, above); **replacing its existing text is a separate, harder one**. A plain `type` appends, and handing "clear this field then type X" to the LLM agent failed repeatedly — iOS's contextual "Select All / Cut / Paste" menu is timing- and gesture-dependent, so the agent couldn't reliably surface and use it. Session 6 added a deterministic **`replace_text` harness step** (a new `FlowStep` kind + `AxLike` `tap`/`hold`) that does it natively: ^[extracted]

```
tap field → long-press ~700ms (surfaces the iOS edit menu) → OCR-scan for "Select All"
  → tap it if found, else brute-force backspace ×30 → type the new value
```

- Each action is awaited so the screen settles between steps; the pointer never has to track a cursor afterward.
- The **30 backspaces** are a deliberate over-shoot — IG name/bio fields cap around ~80 chars and 30 covers any realistic current content when "Select All" isn't OCR-visible.
- `describe`/`label` are for logs only; `x`/`y` is the field, `text` the replacement.

This is the [[ui-automation-matcher-cascade|deterministic-over-agent]] principle applied to *editing* rather than *locating*: a fiddly mechanical sequence the LLM keeps flubbing becomes a single reliable primitive. Validated live — `instagram-edit-profile` and `tiktok-edit-profile` both PASS (name + bio edited and saved) using `replace_text` + `successOptional: true`. ^[extracted]

## Thread-aware "smart comment"

`smart-comment.ts` / a `smart_comment` warmup step: open comments (CV: template → rail-region `{0.92, 0.62}` → OCR, since the bare OCR tap "won't find it") → **scrape the existing comments** via OCR → ask Claude (haiku, cheap) for **one reply matching their length/tone/slang/emoji** → type it slowly per-char with typo-correction → send → close. It filters out scraped chrome (Like/Follow/@user/timestamps) and rejects spam/link/@-mention output. No-ops safely without `ANTHROPIC_API_KEY`. Validated live: posted varied, in-style comments on home-workout videos (e.g. "nah 30 mins is crazy 😭", "how long does this actually take"). ^[extracted]

## Reliability scaffolding shared by all flows

- Every fragile tap uses [[ui-automation-matcher-cascade]] (`template → region → OCR → agent`).
- `successOptional` flag — engagement flows (warmup, like-feed) that complete all steps but end on a reel/ad are no longer falsely marked failed (the old success heuristic looked for a specific anchor screen like "Your story" and failed even when the work was done). Confirmation flows (switch-account) keep strict checking. ^[extracted]
