---
title: >-
    Stratton Ecom — Production Tab Unified onto the Agency Video Pipeline
category: concepts
tags: [domain/web, domain/ai, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    The ecom "production" tab was a dead, ported parallel video pipeline (video_tickets / v_video_ticket_board — never existed in any live DB); it was retired and rewired onto the agency video_task spine, old endpoints now 410.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.7
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T06:09:56Z
updated: 2026-07-02T06:09:56Z
---

# Stratton Ecom — Production Tab Unified onto the Agency Video Pipeline

The [[ecom-platform-architecture|Stratton ecom OS]]'s **"production" / video-creative tab** shipped as a **second, parallel video pipeline** — a port of the Stockton/Polsia implementation — living beside the battle-tested **agency** (main dashboard) video pipeline. This session (branch `ecom/app`) **retired the ported copy and unified the tab onto the agency spine.** ^[extracted]

## What the ported (now-retired) pipeline was

A self-contained clone with its own everything, wired to an external platform:

- Backing store: a **`video_tickets`** table + **`v_video_ticket_board`** read view, plus a 13-state `TicketStatus` machine (`packages/schemas/src/state-machine.ts`).
- Outbound seam: `requestVideoGeneration()` (`@stockton/integrations`) POSTing to an **external `PRODUCTION_API_URL` / `PRODUCTION_API_KEY`** platform, which echoed a `job_id` and later called back a **secret-gated webhook** (`POST /api/ecom/production/assets`, `PRODUCTION_WEBHOOK_SECRET`).
- UI: `StepBoard.tsx` (polls the board), `RequestVideoButton.tsx`, review gates (`ScriptGate`, `VariantGate`).

**The fatal fact: the backing view `v_video_ticket_board` — and the `video_tickets` table — never existed in any live DB.** The tab was **dead on arrival**: it 502'd (or rendered "Board unavailable") for anyone who opened it, because it queried objects that were never migrated. This is a specific instance of the broader [[ecom-schema-drift-commerce-vs-public|code-vs-live-DB drift]] in this repo — code modeled against a schema that isn't deployed.

## What it was unified onto (the agency `video_task` spine)

The agency pipeline is the real, exercised one — the same spine behind the UGC/video work in [[stratton-internal]]:

- **Board** (`apps/web/app/api/ecom/production/board/route.ts`) now reads real agency **`video_tasks`**, joined through **`campaigns.brand_company_id`**, **scoped to the active brand** with role + store-membership auth ([[multi-tenant-store-isolation]]).
- **Generation** (`RequestVideoButton.tsx`) queues the agency **`POST /api/generation`** flow (`generation_runs` → [[trigger-dev|Trigger.dev]] → [[muapi|MuAPI]]) against a real `video_task` — the external `PRODUCTION_API_URL` seam is gone.
- **Steps** (`ecom/lib/production-steps.ts`) are re-keyed to the canonical **`VideoTaskStatus`** machine from **`@stratton/shared`** (not the ported `TicketStatus`).

## Fail-loud deprecation: old endpoints return 410, not deletion

The old `/api/ecom/production/{generate,transition,assets}` routes were **not silently deleted** — they now return honest **410 Gone** pointing at the agency APIs. The rationale is durable: a live-but-orphaned endpoint is how a codebase **silently re-forks** a pipeline. A 410 makes any stale caller fail loudly at the seam instead of quietly driving the dead path. ^[inferred]

## Gotcha carried over: the two `companies` PKs

Rewiring onto the agency spine surfaced the **two-`companies`-tables** hazard from [[ecom-schema-drift-commerce-vs-public]]: `ugc/repo.ts` queried **`companies.company_id`**, which is the *store* DB's PK — the **agency** `companies` table uses PK **`id`**. It was fixed to `companies.id`. When code moves between the store surface and the agency spine, the `companies` primary key flips (`company_id` ↔ `id`); don't assume one.

## Related sweeps in the same session

- The **"Board unavailable" 404** was one symptom of a surface-wide **route-namespace bug** — bare `/api/*` paths from the ecom client didn't just 404, some **collided with same-named agency routes**. Full reusable lesson: [[html-page-where-json-expected]].
- A ~130-file **mock/stub audit** ran alongside and fixed the offenders it found (see [[ecom-platform-architecture]] status). The production gates (`ScriptGate`/`VariantGate`) were **retired with the ported pipeline** rather than wired up.
- Landed partly via a **parallel Claude session** editing the same `ecom/app` worktree — output was verified, not duplicated ([[parallel-agents-amplify-schema-drift]]).

**Verified state:** typecheck clean, **180/180 ecom tests green**. The remaining risk is runtime, not code: the deployed DB is missing the ecom migrations the agency spine assumes — see [[deployed-db-missing-migrations]] and [[ecom-platform-architecture]].
</content>
</invoke>
