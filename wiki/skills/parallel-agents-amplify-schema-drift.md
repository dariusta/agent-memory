---
title: >-
    Parallel Agents Amplify a Latent Inconsistency
category: skills
tags: [domain/ai, type/gotcha, type/pattern, visibility/public]
sources: [projects/stratton-internal]
summary: >-
    Fan-out agents faithfully copy the same wrong precedent, so a latent drift (a schema that doesn't exist) gets multiplied across every migration. Pin ground truth before fanning out; audit the staged diff.
provenance:
  extracted: 0.55
  inferred: 0.4
  ambiguous: 0.05
base_confidence: 0.6
lifecycle: draft
lifecycle_changed: 2026-07-02
created: 2026-07-02T00:15:52Z
updated: 2026-07-02T00:15:52Z
---

# Parallel Agents Amplify a Latent Inconsistency

Multi-agent fan-out is fast, but it has a specific failure mode worth pricing in before you reach for it. Learned the expensive way on Stratton's [[ecom-platform-architecture|ecom OS]] build (**~$758, 100+ files, five parallel agents**).

## The failure mode

Subagents are told to "match the existing code's conventions" — and they do, **faithfully**. If the codebase carries a **latent inconsistency**, every parallel agent copies it, so a single wrong precedent gets **multiplied** across all their output at once.

Concretely: the ecom code referenced a `commerce.*` Postgres schema that **doesn't exist** in the live DB (everything is in `public` — see [[ecom-schema-drift-commerce-vs-public]]). Five agents modeled their new tables on that convention, so **all** their migrations (192/193/194/…) targeted a phantom schema and would have failed or, worse, created a parallel schema the app never reads. Reconciling it back to `public` was **not** a mechanical find-replace (table names *and* columns differed structurally) and burned real cycles.

## The lesson

- **Pin ground truth before you fan out.** For anything the agents will build *on top of* — a DB schema, an API contract, a deploy target — verify the live/authoritative version first and hand it to every agent as a fixed input. Don't let each agent independently re-derive it from possibly-drifted code. Copying a shared wrong precedent in parallel is worse than one agent getting it wrong serially, because you discover it all at once, post-hoc.
- **Budget the reconciliation tax.** Parallelism moves fast but **creates integration debt** — the drift, build-blocking type errors from independently-authored files, duplicate spreads, casts. Factor "one agent reconciles the merge" into the plan and the cost.
- **Audit the staged diff before committing agent work.** An agent had staged a **`.env.bak` containing secrets** for commit (caught + removed), plus 272 junk drift-checker temp files. Subagents don't share your instinct about what must never be committed — review `git status`/the staged diff for secrets and junk before every agent-authored commit.
- **The deploy env is the authoritative build.** Monorepo workspace packages (`@stockton/*`) that resolve on the CI/deploy host may be **unlinked locally**, so a local build fails with `Module not found` that isn't a real error. Fix the *real* `tsc` errors and let the deploy host validate — don't chase a local-only resolution failure. (Kin to [[vitest-stale-worktree-pollution]].)

## When to still fan out

Parallelism is right when the work is genuinely **disjoint** (agents touch non-overlapping files) and the shared foundation is **already verified and stable**. It's a trap when the agents share a foundation that is itself unverified — pin the foundation first, *then* fan out.

Related: [[deployed-env-overrides-code-defaults]], [[instrument-before-tuning-a-gate]], [[ecom-schema-drift-commerce-vs-public]].
