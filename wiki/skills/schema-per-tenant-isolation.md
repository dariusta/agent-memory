---
title: >-
    Schema-Per-Tenant Isolation (one app, one Postgres schema per tenant)
category: skills
tags: [domain/infra, domain/web, type/pattern, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    Hard multi-tenancy without N deployments: one app, one Postgres schema per tenant, request → ALS → per-connection search_path. Enforce via an automated cross-tenant leak test, not trust.
provenance:
  extracted: 0.5
  inferred: 0.45
  ambiguous: 0.05
base_confidence: 0.58
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T00:15:52Z
---

# Schema-Per-Tenant Isolation

When you need **hard** multi-tenancy ("nothing shared, ever") for many tenants (dozens–hundreds) but a separate deployment/database per tenant is too much infra and cost, **schema-per-tenant** is the middle path: **one application process, one Postgres schema per tenant.** Surfaced building Stratton's [[multi-tenant-store-isolation|per-store ecom isolation]] on Medusa v2, but the shape is framework-agnostic.

## The mechanism

- Each tenant gets its own Postgres **schema** (its own copy of every table).
- A request carries a tenant selector (e.g. an `x-tenant-schema` header / resolved `active_store`).
- Resolve it **server-side from verified membership**, never from a raw client cookie/header — then push it into **AsyncLocalStorage** (ALS) for the request's lifetime.
- Every DB query runs inside that tenant's schema via a **per-connection `search_path`** (or an ORM manager forked per request — e.g. Medusa's `getFreshManager` ALS-fork). The fork is what closes the **raw-SQL leak**: ORM-level scoping alone misses hand-written SQL and non-transactional reads.
- Provision on tenant creation: a control-plane registry (`tenants(schema_name, …)`) + a `createTenant` workflow that does `CREATE SCHEMA` → run migrations → seed defaults.

## The isolation-model decision

| | Schema-per-tenant | Instance/DB-per-tenant |
|---|---|---|
| Isolation | Hard *if the patch is proven* | Bulletproof (no shared process) |
| Cost / infra | One deployment, cheap to scale | N services + N databases |
| Risk | Enforced by an ORM/`search_path` patch → must be tested | Zero patch risk |

Schema-per-tenant wins on cost at 50–100 tenants **only because** the leak test below de-risks the patch.

## Enforce with a leak test, don't trust

Because isolation rides on a patch, treat it as **unproven until an automated cross-tenant leak test passes** — and gate onboarding on it:

1. Provision tenant A and tenant B with **distinct** data.
2. Assert A's credential can **never** read B's data — across **ORM paths AND raw-SQL paths**.
3. Run it **sequentially and under concurrency** (e.g. 40 interleaved requests) — concurrency is where ALS/connection-pool bugs surface.

## Watch-outs

- **Process-global singletons leak.** Redis-backed caches, event buses, and other process-level singletons are shared across tenants even when the DB isn't. Key them per tenant or disable shared caching. This is the classic gap schema isolation misses.
- **Isolation is multi-layer.** The commerce DB is only one plane. Any *other* store of tenant data (your app's own Supabase tables, observability/`agent_runs`, agent tool context) needs its own enforcement — see the membership+RLS half in [[multi-tenant-store-isolation]]. A service-role key that **bypasses RLS** silently defeats the whole thing.
- **Verify, then seed.** Don't seed real tenants into a single-shared-schema deployment "for now" — it bakes in the shared-pool mistake you're trying to kill.

Related: [[multi-tenant-store-isolation]] (the concrete Stratton build), [[railway]] (where it's deployed).
