---
title: >-
    Stratton Ecom — `commerce.*` vs `public` Schema Drift
category: concepts
tags: [domain/infra, type/gotcha, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    The ecom codebase references a `commerce` schema that does NOT exist in the live DB — everything is in `public`. Pervasive pre-existing drift; here's the ground truth + the reconciliation map.
provenance:
  extracted: 0.8
  inferred: 0.15
  ambiguous: 0.05
base_confidence: 0.77
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T00:15:52Z
---

# Stratton Ecom — `commerce.*` vs `public` Schema Drift

A foundational gotcha in the [[ecom-platform-architecture|Stratton ecom OS]] that blocked an entire wave of work and cost real reconciliation cycles.

## The finding

The ecom **codebase** — the pre-existing `/api/ecom/brands` route and everything modeled on it — references a **`commerce` schema**: `commerce.companies`, `commerce.brand_campaigns`, `commerce.brand_creators`, `tracked_links`. But the live ecom DB (**`zrfisjbedcwjxzxxorfm`, "mimic-ecom"**) has **no `commerce` schema at all** — every real table lives in **`public`**. ^[extracted]

So the *existing* brands route (`insert into commerce.companies`) was already misaligned with its own DB — **the drift predates this session's work.** When five parallel build agents faithfully followed the code's `commerce.*` convention, their migrations (192/193/194) targeted a non-existent schema and their DB reads/writes would have failed as-is. The reusable lesson: [[parallel-agents-amplify-schema-drift]].

## Ground truth (verified against the live DB)

Real tables, all in `public`:
- `public.companies` (PK `company_id`) — the store/brand tenant entity, already has a `medusa_schema` column. Holds real brands (Glyka, Cleared). **Not** `commerce.companies`.
- `public.campaigns` (`campaign_id, company_id, name, client_monthly_budget_cents`) — **structurally different** from the code's assumed `commerce.brand_campaigns`.
- `public.real_ugc_creators` (`creator_id, handle, platform, payout_cents`) — the code assumed `commerce.brand_creators`.
- `store_orders` (`brand_id`, `total` bigint, `utm_source/utm_campaign/utm_channel`). Note it's `utm_channel`, **not** `utm_medium`.
- `operators`, `operator_store_members`, `brand_domains`, `agent_runs` — all present in `public`.
- **Absent entirely:** `brand_ad_accounts`, `ad_campaigns`, `brand_affiliates`, `affiliate_links`, `tracked_links`, `tracking_domains` — these had to be *created* in `public` via migrations.

`public.companies` (PK `company_id`) is the **store** table; a separate `public.companies`-shaped agency-clients table (PK `id`) exists in the *agency* DB — a genuinely different entity. Don't conflate them.

## Resolution: reconcile code to `public` (do not fabricate `commerce`)

Because all real data provably lives in `public`, `public` is authoritative and `commerce.*` is the drift. Reconciliation was **not** a mechanical find-replace (`campaigns` ≠ `brand_campaigns` structurally; `tracked_links` didn't exist), so it needed the real schema shapes:

| Code reference (drift) | Reconciled to (`public`) |
|---|---|
| `commerce.companies` | `public.companies` (PK `company_id`) |
| `commerce.brand_ad_accounts` | `public.brand_ad_accounts` (new) |
| `commerce.brand_campaigns` (ad rows, `channel='meta_ads'`, `meta.platform`/`meta.campaign_id`) | `public.ad_campaigns` (new; `platform` + `remote_id` first-class columns, `spend_cents`; dropped the `channel` filter) |
| `commerce.brand_affiliates` / `commerce.affiliate_links` | `public.brand_affiliates` / `public.affiliate_links` (new) |
| `commerce.brand_creators` | `public.real_ugc_creators` |
| `utm_medium` | `utm_channel` |
| `tracked_links` / `tracking_domains` | created new in `public` |

The UGC surface (`ugc/repo.ts`) expected `brand_campaigns`/`brand_creators`/`brand_creator_content`/`brand_creator_social_accounts` + a `companies.agency_company_id` — those tables were created in `public` (migration 196) rather than reconciled away, since they had no live equivalent. Migrations **188–196** were applied to the ecom DB; a FK bug (`companies(id)` → should be `company_id`) in the email migration was also caught and fixed.

## Why this mattered

Applying the agents' `commerce.*` migrations blindly would have created a **phantom parallel schema** in production that the app doesn't read, silently breaking every reconciled feature. The correct move was to **verify the live DB is even the one the app's `.env` points at** before applying anything — see [[parallel-agents-amplify-schema-drift]] and [[deployed-env-overrides-code-defaults]].
