---
title: >-
    Railway
category: entities
tags: [domain/infra, type/tool, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    The PaaS hosting all of Stratton (web apps, Medusa, Postgres/Redis, workers). Deploys per git-branch × environment; MCP + CLI tokens expire mid-session; verify the target environment before provisioning.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T00:15:52Z
---

# Railway

The PaaS that hosts essentially all of [[stratton-internal]]: the Next.js web apps, the [[ecom-platform-architecture|ecom OS]]'s Medusa backend + its Postgres/Redis, the video-edit worker, phone-relay, and more. Projects seen: `mimic internal`, `mimic-ecom`, `brandzy`. It is **not** Coolify. ^[extracted]

## Deploy model

- A service deploys from a **git branch**, and a project has multiple **environments** (e.g. `production`, `staging`, `ecom+apps`). Push to the watched branch → auto-deploy. The ecom app watches `ecom/app` and deploys into the **`ecom+apps`** environment. ^[extracted]
- Provisioning (a service, a Postgres, a Redis) is **billed infra** — confirm before spinning it up.
- RAILPACK auto-detects the stack (e.g. Node); a **pre-deploy hook** can run migrations + seed/admin-create so the app auto-connects on boot (Medusa's `db:migrate` + admin user matching the code's staging defaults).

## Gotchas (learned building the ecom OS)

- **Verify the target environment before provisioning.** A wave of services (Medusa/Postgres/Redis) was created in `production` when they belonged in `staging`/`ecom+apps` — a costly mistake to unwind. Confirm *which environment* you're pointed at before creating anything. ^[extracted]
- **The Railway MCP `delete` tool's `confirm` param was broken** — cleanup of the wrongly-placed services had to go through the **Railway API/CLI** directly, not the MCP delete tool. ^[extracted]
- **Auth tokens expire mid-session.** Both the Railway MCP token and the CLI token died partway through a long session (the CLI later auto-refreshed from an updated config token). Deploy status can become unqueryable even though the push itself still triggers the deploy — don't treat "can't query status" as "deploy failed."
- **A stale progress note is not proof of live infra.** `PROGRESS-ecom-medusa.md` claimed "Medusa is deployed & LIVE," but the URL 404'd because **nothing was actually deployed** there. Check the live service list, not the doc, before building on top of hosted infra.
- **The deploy host is the authoritative build.** Monorepo workspace packages (`@stockton/*`) resolve on Railway but may be unlinked in a local sandbox, so a local build can fail with `Module not found` that Railway builds fine. See [[parallel-agents-amplify-schema-drift]].

Related: [[trigger-dev]] (background jobs, separate deploy), [[runpod]] (GPU workers), [[stratton-internal]].
