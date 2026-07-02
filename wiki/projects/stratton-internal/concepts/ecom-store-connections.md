---
title: >-
    Stratton Ecom — Per-Store Connections & Integrations Config
category: concepts
tags: [domain/web, domain/infra, type/architecture, visibility/internal]
sources: [projects/stratton-internal]
summary: >-
    Each ecom store (brand) configures its own integrations from Settings → Connections; values live in brand_config("connections") with AES-256-GCM write-only secrets, and platform infra rows are env-only.
provenance:
  extracted: 0.7
  inferred: 0.25
  ambiguous: 0.05
base_confidence: 0.66
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T06:03:38Z
updated: 2026-07-02T06:03:38Z
---

# Stratton Ecom — Per-Store Connections & Integrations Config

Part of the [[ecom-platform-architecture|Stratton ecom OS]] and its
[[multi-tenant-store-isolation|"nothing shared" isolation]] story: each **store
(brand)** configures its **own** integration credentials/settings from the admin
**Settings → Connections** page (`/ecom/setup`), scoped by the active-store
switcher. This **supersedes the env-only `integrations/status.ts` registry** —
integrations are no longer a single platform-wide config. Built 2026-07-02 on
branch `ecom/app`. ^[extracted]

## The registry (`apps/web/ecom/lib/connections.ts`)

`CONNECTIONS` is the typed source of truth: each `ConnectionDef` declares an
integration, its `scope`, and its configurable `fields` (each field has a
`type` of `text | secret`, an optional platform `envVar` fallback, and
`required`/`help`). Two scopes: ^[extracted]

- **`scope: "store"` — per-store configurable** (a store can override the
  platform env default from the UI): Stripe (+ a backup processor), 3PL, Meta /
  TikTok / Google Ads, TikTok Shop, signal providers (Keepa / Kalodata), Resend
  email, PostHog, [[muapi]].
- **`scope: "platform"` — env-only infrastructure**, shown as a **read-only**
  row (not store-configurable): Supabase, Medusa.

Pure helpers `resolveConnectionState` / `mergeStoredConnection` /
`getConnectionDef` hold the merge logic (stored store value → env fallback →
status) and are unit-tested in `connections.test.ts` without touching the DB.

## Storage & secret handling

- **No new table/migration.** Per-store values are stored in the **existing
  `brand_config` table under area `"connections"`** —
  `payload.data = { [integrationId]: { settings: {…}, secrets: {…} } }`. ^[extracted]
- **Secrets are AES-256-GCM encrypted at rest** via the shared `ad-accounts`
  token helpers (`encryptToken`/`decryptToken`, key `AD_TOKEN_ENC_KEY`), stored
  as base64 blobs.
- **The API never returns secret values — only has-secret booleans.** Env
  fallbacks surface as env-var *names* + presence, never the value. This is the
  same write-only-secret discipline as the isolation work. ^[extracted]
- **Secret write semantics:** a non-empty value **sets** it, `null` **clears**
  it, and `""` (empty string) **keeps** the existing value untouched — so the UI
  can submit a form without re-sending unchanged secrets. ^[extracted]

## API & UI wiring

- **`/api/ecom/connections`** — `GET` (viewer role + `requireActiveStore`;
  falls back to env-only when there's no active store, e.g. a portfolio view)
  and `PUT` (brand-operator role). Store scope comes from the verified
  active-brand cookie, consistent with [[multi-tenant-store-isolation]] —
  membership is checked, not trusted. ^[extracted]
- **UI:** `ConnectionsPanel` inside `/ecom/setup` ("Settings" in the sidebar).
  It imports the wire types from `connections.ts` **type-only**, so the
  `server-only` lib never enters the client bundle. ^[extracted]

## Migration status / gotcha

At build time the runtime consumers **still read env vars directly** — the
per-store values are stored and shown but not yet consumed everywhere. The
accessor to migrate consumers onto per-store values is
**`getConnectionValue(storeId, integrationId, field)`** (store override →
env fallback). Until a consumer is switched to it, editing a connection in the
UI won't change that integration's behavior. ^[inferred]

The panel's original **"Failed to load connections"** error was the
`/api` → `/api/ecom` mount-prefix bug — reusable lesson:
[[html-page-where-json-expected]].
