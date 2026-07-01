---
title: >-
    Automated login & 2FA on the iphone-control rig (operator-opt-in)
category: concepts
tags: [instagram, tiktok, ios, automation, login, 2fa, totp, otp, imap, domain/tooling, type/howto]
sources: [projects/iphone-control]
summary: >-
    The rig's old "never enter a password/2FA" hard rule was replaced with an operator-opt-in login model (FLOW_ALLOW_PASSWORD_LOGIN=1, secrets via env). Covers the deterministic instagram-login/tiktok-login flows, runtime (not build-time) TOTP + email-OTP resolution, async build() to pre-resolve the code, IMAP OTP fetch with a recency filter for private inboxes, IG's chained email new-device gate, the "code sent once, never resent" trap, and add_account mode.
provenance:
  extracted: 0.75
  inferred: 0.2
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:31:02Z
updated: 2026-07-01T08:31:02Z
---

# Automated login & 2FA on the iphone-control rig (operator-opt-in)

Part of [[iphone-control]]. This is a **reversal of the project's earlier "hard safety rule"** — the rig now *does* type passwords and enter 2FA codes, but only behind an explicit operator opt-in. The generalizable 2FA lessons are pulled out to [[automating-2fa-code-entry]]. ^[extracted]

## The opt-in gating model (replaces "never enter a password")

Earlier sessions documented an absolute rule: the rig never types a password, submits a login, or enters a 2FA code. That rule is **gone**. The new model: ^[extracted]

- Login/2FA is gated on `FLOW_ALLOW_PASSWORD_LOGIN=1`. The `instagram-login` / `tiktok-login` flows **refuse to start** without it.
- Secrets are passed via **env vars** (username/password/TOTP secret/IMAP creds), never typed into chat.
- `SKILL.md` was updated to swap the old "never enter a password" line for this operator-opt-in model.
- The credential-entry typing path deliberately **never applies the humanizer's typo/backspace jitter to secrets** (see [[iphone-control-architecture]]'s `typingPlan` — "never on secrets").

## Resolve the 2FA code at EXECUTION time, not build time

The first cut computed the **TOTP at `build()` time** and baked it into the escalation prompt. By the time nav walked to the 2FA screen (30–90s later) the 30-second code had rotated — the classic **"correct secret, rejected code."** Two new deterministic `FlowStep` kinds resolve the code when the UI actually needs it (this is the reusable core → [[automating-2fa-code-entry]]): ^[extracted]

- **`enter_totp`** — computes a fresh RFC-6238 code (zero-dep base32 + HMAC), then focus → clear → type. Submits with a **one-shot fresh-code retry** (if the first code was on a window boundary, recompute and retry once).
- **`enter_email_otp`** — polls the inbox **after** the app has sent the code, then types it. Email OTPs are only valid once requested, so this too must run at execution time.

Because `enter_email_otp` must pre-resolve the code before the escalation prompt is composed, **`Flow.build()` was made async** (`build()` may return `Promise<FlowDefinition>`); `runner.ts` and `debug-edit.ts` were updated to `await` it. IG 2FA now runs **deterministically with no reasoner** (verified: 32 deterministic steps, 0 escalations; IG accepted the fresh TOTP). ^[extracted]

## Email OTP: IMAP with a recency filter, mail.tm fallback

`enter_email_otp` reads the one-time code from a mailbox: ^[extracted]

- Prefers **IMAP** when `IMAP_HOST` is set; otherwise falls back to a **mail.tm**-style disposable HTTP inbox.
- **Why IMAP:** purchased-account inboxes live on **private catch-all domains** (e.g. `cacofkml.com` via `imap.firstmail.ltd`) that the mail.tm HTTP API can't reach. `fetchImapOtp` is a **dependency-free `imaplib` shell-out** (python3 is already present — the panel is Python) that polls `INBOX` + `Junk`.
- **Recency filter is mandatory:** a bare 6-digit regex will happily grab an old marketing/order-confirmation number. The filter rejects any code from a stale message (verified: it correctly returned `null` on an inbox whose only 6-digit string was `141823` in an October marketing mail, rather than typing a wrong code). ^[extracted]

## IG's chained new-device gate — and the "code sent once, never resent" trap

Instagram login is **multi-stage**: enter creds → `enter_totp` (app-authenticator 2FA) → a **chained "check your email" new-device gate** (`enter_email_otp`) → dismiss the Save-login / notifications interstitials. ^[extracted]

The email gate has a real trap: IG (observed) **sends the email verification code once at the start and never re-sends it**. If the automated fetch misses that first message — or the code is on a private domain the rig can't read — the flow can't proceed. Two consequences: ^[inferred]

- The flow now **detects the email gate and fails cleanly** ("reached email gate, code unreachable") instead of a generic timeout, so the failure is diagnosable.
- A live run ended here with *no new code delivered*: the phone sat on an "enter a code" popup because the single code had already been sent and consumed. Operationally: don't assume you can re-trigger the send; capture the first code, or pre-resolve it, or hand the gate to the human.

## add_account mode (add a 2nd logged-in account)

`add_account=1` reuses the login form from inside a logged-in session — **Profile → account switcher → "Add Instagram account" → "Log in to existing account"** — so a second account can be added (needed to test [[social-app-automation-mechanics|instagram-switch-account]], which needs ≥2 accounts). Nav-hardening notes worth keeping: ^[extracted]

- The **Profile tab is resolved navtab-only (slot 4)** here — the circle/avatar matcher drifted to the Activity feed instead.
- The switcher tap is **pinned to the username header**.
- The prelude runs **unconditionally** because IG often reopens onto the Activity tab, not Home.
- Flaky BLE-HID nav taps are wrapped in branch-retries + settle dwells so the prelude stays deterministic with no reasoner; each fragile tap still carries an `escalateGoal`.

See also [[ui-automation-matcher-cascade]] for the deterministic-first tap cascade these flows lean on, and the reliability scaffolding (3-pass popup dismisser, permissive OCR handle ladder) in [[social-app-automation-mechanics]].
