# AI Agent Instructions

This repository contains Smartest, a Ruby test runner, and its Docusaurus documentation site.

## Documentation Sync Rule

When changing implementation behavior, update documentation in the same change.

Implementation behavior includes:

- public Ruby APIs such as `test`, `use_fixture`, `fixture`, `suite_fixture`, `cleanup`, and `expect`
- matcher behavior
- CLI arguments, default globs, output, and exit status
- fixture resolution, caching, cleanup, duplicate fixture detection, and circular dependency detection
- error class names and user-facing error messages
- installation, setup, and development commands

Before finishing a task:

1. Decide whether the change affects user-facing documentation.
2. Update impacted pages under `documentation/docs/`.
3. Update `README.md`, `DEVELOPMENT.md`, or `SMARTEST_DESIGN.md` if the same behavior is described there.
4. Run the Ruby test suite when implementation changed.
5. Run `npm run build` from `documentation/` when documentation changed.
6. If documentation did not need changes, explain why in the final response.

Keep documentation examples runnable and aligned with the current MVP. Do not document future APIs as available behavior.
