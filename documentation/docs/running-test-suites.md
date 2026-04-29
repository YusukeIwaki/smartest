---
title: Running Test Suites
description: Run Smartest tests through autorun or the CLI.
---

# Running Test Suites

The primary Smartest workflow is:

- initialize a test scaffold with `bundle exec smartest --init`
- write tests that require `test_helper`
- run the suite with `bundle exec smartest`

## Initialize

Initialize a new test scaffold:

```bash
bundle exec smartest --init
```

The init command creates `smartest/test_helper.rb`, `smartest/fixtures/`,
`smartest/matchers/`, `smartest/matchers/predicate_matcher.rb`, and
`smartest/example_test.rb`. It does not overwrite existing files.

Generated tests require the helper by name:

```ruby
require "test_helper"

test("example") do
  expect(1 + 1).to eq(2)
end
```

The CLI adds `smartest/` to Ruby's load path before loading files, so helpers can
be required by name.

## Run Tests

Run the default suite:

```bash
bundle exec smartest
```

If no paths are passed, the CLI looks for:

```text
smartest/**/*_test.rb
```

Smartest does not load files from `test/` by default, so a project can keep
Minitest files there while using Smartest files under `smartest/`.

You can pass a single file:

```bash
bundle exec smartest smartest/user_test.rb
```

Or a shell glob:

```bash
bundle exec smartest smartest/**/*_test.rb
```

Run tests by line number. Smartest runs tests whose `test` blocks contain or
intersect the selected lines:

```bash
bundle exec smartest smartest/user_test.rb:12
bundle exec smartest smartest/user_test.rb:3-12
```

## Profile Slow Tests

The CLI prints the 5 slowest tests after each run by default. Use the separated
`--profile N` form to choose a different count:

```bash
bundle exec smartest --profile 10
bundle exec smartest --profile 3 smartest/user_test.rb
```

Show CLI help:

```bash
bundle exec smartest --help
```

Show the installed Smartest version:

```bash
bundle exec smartest --version
```

## Suite Hooks

Use `around_suite` in `smartest/test_helper.rb` when the full run must happen
inside another block:

```ruby
around_suite do |suite|
  Async do
    suite.run
  end
end
```

The hook receives a run target and must call `suite.run` exactly once. It wraps
every test, test-scoped fixture setup and cleanup, suite fixture setup, and suite
fixture cleanup.

Fixture and matcher registrations made before `suite.run` are applied to that
run:

```ruby
around_suite do |suite|
  use_fixture GlobalFixture
  suite.run
end
```

Multiple `around_suite` hooks run in registration order. The first hook is the
outermost wrapper:

```ruby
around_suite do |suite|
  with_outer_resource { suite.run }
end

around_suite do |suite|
  with_inner_resource { suite.run }
end
```

If an `around_suite` hook raises or does not call `suite.run`, Smartest reports a
suite failure and exits with status `1`.

## Test Hooks

Use `around_test` when each test needs to run inside another block:

```ruby
around_test do |test|
  SomeAutoCloseResource.new do
    test.run
  end
end
```

The hook receives a run target and must call `test.run` exactly once. It wraps
fixture setup, the test body, and fixture cleanup.

When `around_test` is written directly in a test file, it is file-scoped. Smartest
copies the current file's `around_test` hooks when each `test` is registered, so
hooks apply to tests defined later in the same file.

Define `around_test` inside `around_suite` when the hook should apply to the
whole run:

```ruby
around_suite do |suite|
  around_test do |test|
    with_some_resource do
      test.run
    end
  end

  suite.run
end
```

`around_test` can register fixture classes, helper modules, and matcher modules
for that test run:

```ruby
around_test do |test|
  use_fixture LocalFixture
  use_helper LocalHelper
  use_matcher LocalMatcher
  test.run
end
```

Fixture classes registered from `around_test` must define only test-scoped
fixtures. If a class defines `suite_fixture`, register it from `around_suite`
instead so its cache and cleanup belong to the suite lifecycle.

`use_fixture` and `use_matcher` are only available inside `around_suite` or
`around_test` blocks. `use_helper` is only available inside `around_test`. None
of them are top-level DSL methods. See [Helpers](./helpers.md) for details on
helper registration.

## Exit Status

Smartest returns:

- `0` when every test passes, is skipped, or is pending as expected
- `1` when any test fails
- `1` when a pending test unexpectedly passes
- `1` when suite fixture cleanup fails
- `1` when an `around_suite` hook fails
- `1` when an `around_test` hook fails
- `1` when a test file cannot be loaded

This makes the CLI suitable for CI jobs:

```bash
bundle exec smartest
```

## Reading Output

A passing run looks like this:

```text
Running 1 test

✓ factorial

Top 1 slowest test (0.00001 seconds, 100.0% of total time):
  factorial
    0.00001 seconds .../smartest/factorial_test.rb:3

1 test, 1 passed, 0 failed
```

A failing expectation includes failure details:

```text
Failures:

1) bad math
   expected 2 to eq 3
```

## Helper Loading

`smartest/test_helper.rb` typically requires `smartest/autorun` and loads fixture
and matcher files:

```ruby
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end

Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
  require matcher_file
end

around_suite do |suite|
  use_matcher PredicateMatcher
  suite.run
end
```

Test files require that helper:

```ruby
require "test_helper"
```

The CLI disables autorun before loading files, so requiring the helper does not
run the suite twice.

Fixture files under `smartest/fixtures/` and matcher files under
`smartest/matchers/` are required by the helper in sorted order.
