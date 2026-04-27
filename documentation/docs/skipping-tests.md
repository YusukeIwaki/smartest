---
title: Skipping Tests
description: Skip unsupported tests and mark known failures as pending.
---

# Skipping Tests

Smartest supports `skip` and `pending` inside test bodies and `around_test`
hooks. It does not support RSpec-style `skip` or `pending` metadata on `test`
definitions.

## Skip a Test

Use `skip` when a test should not run under the current condition:

```ruby
test("PDF export") do |browser:|
  skip "firefox is not supported" if browser.firefox?

  export_pdf(browser)
  expect(File.exist?("report.pdf")).to eq(true)
end
```

`skip` stops the test immediately. The remaining test body is not executed, the
test is reported as skipped, and the run still exits with status `0` if there
are no failures.

```text
- PDF export (skipped: firefox is not supported)

1 test, 0 passed, 0 failed, 1 skipped
```

Fixture keyword arguments are resolved before the test body starts. If the skip
condition uses a fixture, that fixture has already been created. Any cleanup
registered by created fixtures still runs.

## Mark a Test as Pending

Use `pending` when the rest of the test should run but is expected to fail:

```ruby
test("PDF export") do |browser:|
  pending "Not supported by WebDriver BiDi yet" if browser.bidi?

  export_pdf(browser)
  expect(File.exist?("report.pdf")).to eq(true)
end
```

`pending` does not stop execution. If the test fails after `pending`, Smartest
reports it as pending and the run still exits with status `0` if there are no
other failures.

```text
* PDF export (pending: Not supported by WebDriver BiDi yet)

1 test, 0 passed, 0 failed, 1 pending
```

If a pending test passes, Smartest fails the test because the expected failure is
now fixed:

```text
expected pending test to fail, but it passed: Not supported by WebDriver BiDi yet
```

## Use From `around_test`

`skip` and `pending` are also available inside `around_test` hooks:

```ruby
around_test do |test|
  skip "requires chrome" unless ENV["BROWSER"] == "chrome"

  test.run
end
```

A skipped hook may stop before `test.run`. A pending hook must still call
`test.run` exactly once because `pending` records an expected failure but does
not stop execution:

```ruby
around_test do |test|
  pending "driver bug" if ENV["BROWSER"] == "webkit"

  test.run
end
```

`skip` and `pending` are not top-level DSL methods, and they are not available
inside fixture definitions or `around_suite` hooks.
