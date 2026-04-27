---
title: Helpers
description: Register helper modules on Smartest test contexts via around_test.
---

# Helpers

Helpers are Ruby modules that add behavior to the test execution context without
turning every method into a fixture. Use helpers when tests need reusable
methods (for example, async wrappers or browser action utilities) that do not
make sense as keyword-injected fixtures.

`use_helper` is available **only inside `around_test`**. There is no top-level
`use_helper` DSL: helper registration is opt-in per test run, not file- or
suite-wide configuration.

## Registering a Helper for a Test

Pass a module to `use_helper` inside `around_test`, then call `test.run`:

```ruby
module AsyncHelpers
  def async_promise(&block)
    Thread.new(&block)
  end

  def await_promises(*threads)
    threads.map(&:value)
  end
end

around_test do |test|
  use_helper AsyncHelpers
  test.run
end

test("waits for two async operations") do
  first = async_promise { 1 }
  second = async_promise { 2 }

  expect(await_promises(first, second)).to eq([1, 2])
end
```

Helper methods are extended onto a fresh `ExecutionContext` for that single
test and made private on it. They do not mutate `Smartest::ExecutionContext`
globally, so they do not leak into later tests that did not register the
helper.

`use_helper` must receive a module and must be called before `test.run`.
Calling it after `test.run` raises `Smartest::AroundTestRunError`. Multiple
helper modules are applied in registration order.

## Suite-Wide Helpers

To apply a helper to every test in the suite, define an `around_test` hook from
`around_suite` and call `use_helper` before `test.run`:

```ruby title="smartest/test_helper.rb"
require "smartest/autorun"

around_suite do |suite|
  around_test do |test|
    use_helper AsyncHelpers
    test.run
  end

  suite.run
end
```

`use_helper` is not callable directly inside `around_suite`. Register helpers
from `around_test` so the methods are scoped to the per-test execution context.
