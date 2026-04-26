---
title: AI Agent Rules
description: Documentation maintenance rules for AI coding agents working on Smartest.
---

# AI Agent Rules

These rules apply to AI coding agents that change Smartest.

## Keep Documentation in Sync

When an implementation change affects user-visible behavior, update the documentation in the same change.

User-visible behavior includes:

- public Ruby APIs such as `test`, `use_fixture`, `fixture`, `cleanup`, and `expect`
- supported matcher behavior
- CLI arguments, defaults, output, or exit status
- fixture resolution, caching, cleanup, duplicate detection, or circular dependency behavior
- error class names or error messages
- installation, setup, or development commands

## Required Agent Checklist

Before finishing an implementation task:

1. Identify whether the change affects documentation.
2. Update every impacted page under `documentation/docs/`.
3. Update `README.md`, `DEVELOPMENT.md`, or `SMARTEST_DESIGN.md` when the same behavior is described there.
4. Run the Ruby test suite when implementation changed.
5. Run `npm run build` from `documentation/` when documentation changed.
6. If no documentation update is needed, state why in the final response.

## Documentation Style

Write docs as task-oriented guides:

- start with the smallest working example
- prefer runnable Ruby snippets
- call out unsupported MVP features clearly
- keep examples aligned with the current implementation
- avoid documenting future APIs as if they already exist

## Common Page Mapping

- Test definition or expectations: update `writing-tests.md` and `reference/expectations.md`.
- CLI behavior: update `running-test-suites.md`.
- Fixture behavior: update `fixtures.md` and `reference/errors.md` if errors change.
- Setup or installation behavior: update `getting-started.md`.
