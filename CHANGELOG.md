# Changelog

## 0.5.0 - Unreleased

### Breaking Changes

- Rename the fixture teardown registration API from `cleanup` to
  `on_teardown`. The old `cleanup` method is no longer available.
- Rename teardown failure output from cleanup terminology to teardown
  terminology.

## 0.4.0

### New Features

- Add fixture-scoped method stub helpers: `simple_stub_any_instance_of` and
  `simple_stub`.
- Add `with_stub_const` for block-scoped constant stubbing in test bodies,
  `around_test`, and `around_suite`.
- Support Ruby 2.7 and newer.

## 0.1.0 - 0.3.2

- Initial release.
