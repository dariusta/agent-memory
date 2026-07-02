---
title: >-
    Stratton Ecom — Per-Store Multi-Tenant Isolation
category: concepts
tags: [domain/infra, domain/web, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Shopify-grade "nothing shared" isolation for 50–100 operator stores: Medusa schema-per-tenant + a proven leak test, plus operator↔store membership + RLS killing the service-role/cookie bypass.
provenance:
  extracted: 0.6
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.63
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T00:15:52Z
---

# Stratton Ecom — Per-Store Multi-Tenant Isolation

The hardest and highest-priority requirement of the [[ecom-platform-architecture|Stratton ecom OS]]: **"Shopify-grade — every store is its own tenant, nothing shared, ever."** No shared customers, orders, products, inventory, or agent context across 50–100 operators. This page is the isolation architecture and the leak map it fixed. The reusable pattern lives in [[schema-per-tenant-isolation]].

## What was deployed at the start — and why it was NOT isolated

The initial audit found **application-layer, cookie-based** scoping with confirmed holes: ^[extracted]

- **No operator↔store membership table.** The active store came from an httpOnly `active_brand_id` cookie with **no server-side check that the operator owns that brand** — any authenticated operator could set the cookie to any store.
- **RLS was effectively off.** Policies existed but tenant reads used the **Supabase service-role key, which bypasses RLS** — the scoping was just `WHERE brand_id = X` filters at the BFF layer, easy to forget.
- **Medusa ran one shared `public` schema** behind a single superuser admin token; only **products and draft-orders** were sales-channel-scoped. Customers, orders, inventory, promotions were an admitted **shared pool**.
- Some observability tables (`agent_runs`, `get_finance_snapshot`) **lacked a store_id column entirely** → cross-store leak when unfiltered.

Because of this, the team **deliberately did NOT seed a real store** into the shared-schema Medusa — that would have baked in the shared-pool mistake.

## Target architecture (committed, all layers)

Isolation cannot depend on any single layer. Four planes:

1. **Commerce data-plane (Medusa) — schema-per-tenant.** One Medusa deployment; **each store gets its own Postgres schema** (its own products/orders/customers). A request carries `x-tenant-schema` / `active_store` → **AsyncLocalStorage** → every query runs in that store's schema. The scaffold (`services/medusa/src/lib/tenant-context.ts`, `middlewares.ts`, `tenant-provision.ts`) was built for this but was an **unproven spike** flagged for silent raw-SQL-path leaks. The delivered patch: **`getFreshManager` ALS-fork + per-connection `search_path`** to close the raw-SQL leak.
2. **Control plane.** A tenants/companies registry (`companies.medusa_schema`) + a `createStore`/`provisionStore` workflow (`CREATE SCHEMA` → migrate → seed region/channel/product) so operators self-serve isolated stores.
3. **App + Supabase layer.** An **`operator_store_members`** membership table (migration 190) + an **`is_store_member` RLS** helper + a server-side **`requireStoreMember`** so the active-store cookie can *never* reach a store you're not a member of. `agent_runs` got a `store_id` (migration 191). **No service-role reads for tenant data on the operator path** — that bypass was the leak.
4. **Agents.** `x-brand-id` / `x-tenant` is **verified against membership**, not trusted. Every agent tool (`get_orders`, `get_products`, finance, brand-overview) is bound to the caller's store schema only, so an agent physically cannot query another store or hold cross-store context.

Plus **per-store custom-domain → tenant resolution** on the storefront.

## The non-negotiable gate: an automated cross-tenant leak test

Because schema-per-tenant enforces isolation via a **Medusa ORM patch**, it must be *proven*, not trusted. The gate: provision store A + store B with distinct products, then assert A's admin token can **never** read B's products/orders/customers — across **ORM and raw-SQL paths, sequentially and under concurrency**. The delivered test passed with **40 concurrent interleaved requests, zero cross-tenant leak.** This gate must pass before any real operator is onboarded.

## Known residual risk

Redis-backed **cache/event singletons in Medusa are process-global** — a real cross-tenant risk in production that the leak test stresses (distinct products per tenant, concurrent reads). If it surfaces, key the cache per tenant or disable shared caching. ^[inferred]

## The isolation-model decision

- **(A) Schema-per-tenant on one Medusa (chosen):** hundreds of isolated schemas in one deployment, cheap to scale to 100 operators — *contingent on the leak test passing*.
- **(B) Instance-per-tenant:** a separate Medusa+DB per store — zero patch risk but 100+ Railway services and much higher cost.

Chose **A**. The general trade-off write-up is [[schema-per-tenant-isolation]].
