# Changelog

## 0.1.0 - Unreleased

- Add the initial Smartest test runner.
- Support top-level `test` definitions.
- Support class-based fixtures through `Smartest::Fixture`.
- Support required keyword-argument fixture injection and fixture dependencies.
- Support per-test fixture caching and cleanup.
- Support suite-scoped fixtures through `suite_fixture`.
- Support `eq`, `include`, `start_with`, `end_with`, `be_nil`, `raise_error`, and `change` matchers.
- Support custom matcher modules through `use_matcher`.
- Generate an opt-in `PredicateMatcher` custom matcher for `be_<predicate>` calls.
- Add the `smartest` CLI.
- Add `--help` and `--version` CLI options.
- Use `smartest/**/*_test.rb` as the default CLI glob so Smartest can coexist with Minitest files under `test/`.
- Add gem packaging metadata and release tasks.
- Add Docusaurus documentation.
- Add `smartest --init-browser` with a Playwright init scaffold, fixture setup, matcher generation, and dependency installation.
