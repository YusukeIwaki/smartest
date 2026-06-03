# Changelog

## 0.7.0

### Breaking Changes

- Rename the Rails test server to a Rack test server. Replace
  `require "smartest/rails"` with `require "smartest/rack"` and
  `Smartest::Rails::TestServer` with `Smartest::Rack::TestServer`.

## 0.6.1

### Bug Fixes

- Fix Rails Docker scaffold friction in `smartest --init-rails` and the
  generated Playwright fixtures so the Docker-based browser test setup works
  out of the box.

### Documentation

- Document fresh Rails database preparation for browser tests, including the
  Docker-based workflow.

## 0.6.0

### New Features

- Add Rails browser-test integration with `bundle exec smartest --init-rails`,
  generated Playwright fixtures, and `Smartest::Rails::TestServer` loaded by
  explicit `require "smartest/rails"`.

### Breaking Changes

- Make method stubs process-wide across Fibers and Threads. Remove
  `Smartest::SimpleStub#apply!` and `#reset!`; `#apply` and `#reset` now raise
  when called on an already-applied or not-applied stub object.

## 0.5.0

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
