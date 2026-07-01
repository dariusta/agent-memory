---
title: >-
    Automating 2FA code entry (TOTP & email OTP)
category: skills
tags: [2fa, totp, otp, imap, automation, login, type/gotcha, domain/tooling]
sources: [projects/iphone-control]
summary: >-
    Two failure modes that bite any bot entering a 2FA code: (1) a rotating code (TOTP/email OTP) resolved at plan/build/prompt-compose time is already stale by the time the UI needs it — resolve it at execution time; (2) an OTP scraped from an inbox needs a recency filter or an old 6-digit string gets typed as the code. Plus: use IMAP for private catch-all inboxes that disposable-mail HTTP APIs can't reach.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.62
lifecycle: draft
lifecycle_changed: 2026-07-01
created: 2026-07-01T08:31:02Z
updated: 2026-07-01T08:31:02Z
---

# Automating 2FA code entry (TOTP & email OTP)

Generalized from the iphone-control login work ([[automated-login-2fa]]), but applies to any login automation — browser bots, headless test harnesses, agent flows.

## Resolve rotating codes at execution time, not build/plan time

A 2FA code is only valid for a short, moving window:

- **TOTP** rotates every ~30s (RFC 6238).
- An **email/SMS OTP** is only valid *after* it's been requested, and often only briefly.

So a code that's computed when you **compose the plan / build the flow / write the LLM prompt** is frequently **stale by the time navigation reaches the 2FA field** (seconds-to-minutes later). The tell is maddening: **"correct secret, rejected code"** — the shared secret is right, the login still fails, and it looks like a wrong password.

**Fix:** make code resolution a *late-bound step* that runs at the moment of entry, not an input baked in earlier. On the iphone-control rig this meant new step kinds (`enter_totp`, `enter_email_otp`) and making the flow's `build()` **async** so the OTP is fetched immediately before use (and before the escalation prompt is composed), not at registration. ^[extracted]

The same rule kills a subtler bug: don't hand a live 2FA code to a slow downstream consumer (an LLM reasoner, a queued job). By the time it acts, the code is dead. Keep the resolve→type gap as small as possible, and add a **one-shot retry** that recomputes on rejection (covers the case where you computed on a rotation boundary). ^[inferred]

## OTP scraped from an inbox needs a recency filter

If you read the code out of a mailbox, a naive "find a 6-digit number" regex will happily return an **old order confirmation, a marketing blast, or a previous login's code**. It types a wrong code and you blame the matcher. ^[extracted]

**Gate every match on recency** — message date / arrival strictly after you triggered the send. Verified failure this prevents: an inbox whose only 6-digit string was `141823` inside an October marketing email — the recency filter returned `null` (fail clean) instead of typing the stale number. Failing clean beats typing garbage. ^[extracted]

## Use IMAP for private catch-all inboxes

Disposable-mail HTTP APIs (mail.tm and friends) only cover *their* domains. Purchased or bulk accounts often use **private catch-all domains** (e.g. `*.firstmail.ltd`) reachable only over **IMAP**. A dependency-free `imaplib` poll of `INBOX` + `Junk` (Python is usually already on the box) reaches them; keep the HTTP disposable-inbox path as a fallback for the domains it does cover. ^[extracted]

## Related

- [[automated-login-2fa]] — the concrete iphone-control implementation (opt-in gating, IG's chained email new-device gate, the "code sent once, never resent" trap).
- [[ui-automation-matcher-cascade]] — the broader "prefer a deterministic primitive over the LLM for a rote sequence" principle this is an instance of.
