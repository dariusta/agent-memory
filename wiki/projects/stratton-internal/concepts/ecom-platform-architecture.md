---
title: >-
    Stratton Ecom OS — Multi-Tenant Store Platform
category: concepts
tags: [domain/web, domain/infra, domain/ai, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Stratton's second major surface: a Shopify/Amboras-competitor multi-tenant ecom OS on Medusa v2 + Supabase where AI agents run brands. "Finish + extend," not greenfield.
provenance:
  extracted: 0.65
  inferred: 0.3
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T06:03:38Z
---

# Stratton Ecom OS — Multi-Tenant Store Platform

A second, largely separate initiative living in the **same `stratton-internal` monorepo** as the AI-UGC-video pipeline ([[stratton-internal]]): a **multi-tenant e-commerce operating system** — the goal is an internal Shopify/Amboras competitor where **50–100 operators each run their own isolated store** and **AI agents autonomously run the brand** while the human makes high-level calls.

The single most important audit finding: **this is "finish + extend," not greenfield.** ^[extracted] A large store OS already exists mid-migration, so the off-the-shelf agent frameworks the user floated (AutoGPT, LangFlow, CrewAI, Letta, MetaGPT) were **not needed** — the repo already has its own agent runtime.

## What already exists (the inventory)

- **`/ecom` admin app** — Next.js, ~26 pages organized Build/Sell/Market/Operate/Settings. Home/Orders/Finance/Agents-chat/Comms are fully real; most catalog/customer pages are **read-only Medusa proxies with honest empty states** (a strangler read-path). **Settings → Connections** (`/ecom/setup`) is now a real **per-store** integration-config surface (Stripe/3PL/ads/email/etc. stored in `brand_config`, encrypted write-only secrets) — see [[ecom-store-connections]]. ^[extracted]
- **`/storefront`** — separate customer-facing Next.js app (cart → Stripe checkout → order, A/B + PostHog). ^[extracted]
- **`services/medusa`** — a complete, deployable **Medusa v2.17.1** scaffold (Railway config, `medusa-config.js`, migrate+seed scripts, **plus schema-per-tenant machinery**). This is the commerce backend the strangler migrates *onto*. ^[extracted]
- **`packages/commerce`** (`@stockton/commerce`, ~1,900 LOC) — the **legacy** commerce layer: ~17 `store_*` tables in Supabase (`store_orders`, `store_products`, `store_customers`, `store_carts`, `store_payments`…) accessed via raw Postgres. Still active read-side during the transition. ^[extracted]
- **`packages/agents`** (`@stockton/agents`) — **50+ autonomous business agents** (supply chain, content, QC, ad-deployment, inventory) on a Hono runtime with budget/approval/queue. Plus a Canvas DAG workflow executor and 66 Trigger.dev jobs. This *is* the agent harness. ^[extracted]
- **`@stockton/integrations`** — Klaviyo, 3PL, Keepa, etc.

## The strangler migration (`@stockton/commerce` → Medusa v2)

The store is mid-**strangler migration** from Supabase-backed `@stockton/commerce` onto headless **Medusa v2**. ^[extracted]

- Read-path: pages proxy through `/api/ecom/medusa/[resource]` + `medusa-resources.ts` (a **catalog-driven** generic proxy).
- Write-path (built this session): a **single generic Medusa write proxy** mirrors the read side — `MUTABLE_RESOURCES` allowlist + `isMutableResource()` in `medusa-resources.ts`, and `POST`/`DELETE` on the `[resource]` routes behind a shared `guardMutation()` (operator-gated, allowlist-gated, store-scoped). `medusaAdmin<T>(path, init)` is the one Medusa Admin API caller. One proxy serves every resource (products, collections, categories, price-lists, promotions, customers).
- Live catalog CRUD was tested against the deployed Medusa and caught a real bug: **product create requires a `prices` array on the variant.** ^[extracted]

## Data-model ground truth (important)

The ecom app's live Supabase project is **`zrfisjbedcwjxzxxorfm` ("mimic-ecom")** — it holds `store_orders`, `companies` (the real brands: Glyka, Cleared…), `operators`, `agent_runs`, `campaigns`, `real_ugc_creators`. A *different* project (`qoobz…`) is the **agency dashboard** (37 users), and `qoobzhuqmfnkfzoytodd` is the video-pipeline prod DB — **don't confuse them.** ^[extracted]

The store/brand tenant entity is **`public.companies` (PK `company_id`)** — *not* a `commerce` schema. The codebase is riddled with references to a **`commerce.*` schema that does not exist** in the live DB; this is pervasive pre-existing drift that blocked a whole wave of work. See [[ecom-schema-drift-commerce-vs-public]] and the reusable lesson [[parallel-agents-amplify-schema-drift]].

## Multi-tenancy (the #1 requirement)

"Shopify-grade: every store is its own tenant, nothing shared, ever." What was deployed at session start was *not* that (cookie-brand filtering, shared Medusa `public` schema, no operator↔store membership). The target and the hardening built are in [[multi-tenant-store-isolation]].

## Deploy topology

- Everything is on **[[railway]]**. The ecom stack lives in the **`ecom+apps`** environment (project `mimic-ecom`), NOT `production` — Medusa + its own Postgres + Redis + the `staging-ecom` web service. The app auto-deploys on push to the **`ecom/app`** git branch. ^[extracted]
- Medusa is live at `medusa-ecomapps.up.railway.app` (the exact URL the app defaults to, so it connects with zero code changes). Admin user `test@test.com` / `test1234` is created by a pre-deploy hook matching the code's staging defaults.
- Auth: the dashboard is behind Supabase auth (Google-OAuth-primary; **email/password sign-in is disabled**), so the *inside* of the authed dashboard can't be browser-tested without either enabling email auth or driving a Google login. A test operator `test-op@mimic.ai` (owner of Glyka) exists for when email auth is on.

## Status snapshot (2026-07-02)

Built + deployed + tested to staging: multi-tenant isolation (proven via live leak test), store write-path (catalog/orders/emails), growth surfaces (Meta/TikTok ads UI, affiliates, tracking, attribution), UGC surface. **127 ecom unit tests pass; migrations 188–196 applied** to the ecom DB. Remaining blockers all need external inputs: live ad launch (Meta/TikTok tokens + `AD_TOKEN_ENC_KEY`), authed browser test (enable email auth), and a UGC AI-campaign branch that expects agency-spine columns. The session cost **~$758** — see the cost/parallelism caveat in [[parallel-agents-amplify-schema-drift]].
