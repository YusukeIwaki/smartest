# Changelog

## 0.1.0 - Unreleased

- Add the initial Smartest test runner.
- Support top-level `test` definitions.
- Support class-based fixtures through `Smartest::Fixture`.
- Support required keyword-argument fixture injection and fixture dependencies.
- Support per-test fixture caching and cleanup.
- Support suite-scoped fixtures through `suite_fixture`.
- Support `eq`, `include`, `be_nil`, and `raise_error` matchers.
- Add the `smartest` CLI.
- Add `--help` and `--version` CLI options.
- Use `smartest/**/*_test.rb` as the default CLI glob so Smartest can coexist with Minitest files under `test/`.
- Add gem packaging metadata and release tasks.
- Add Docusaurus documentation.
