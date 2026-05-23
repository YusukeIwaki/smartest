---
title: Running Tests
description: Run Smartest tests through autorun or the CLI.
---

# Running Tests

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

For a Playwright browser-test scaffold, use:

```bash
bundle exec smartest --init-browser
```

That command creates the normal Smartest scaffold plus Playwright fixture,
matcher, and example files. It keeps or adds `gem "smartest"` in the Gemfile,
adds `playwright-ruby-client`, and runs the dependency installation commands.

For a Rails Playwright browser-test scaffold, use:

```bash
bundle exec smartest --init-rails
```

That command creates the normal Smartest scaffold plus a Rails server fixture,
Playwright matcher, and Rails browser-test example. It also keeps or adds
`gem "smartest"` in the Gemfile before installing the browser-test
dependencies.

For a Rails app container that uses a Playwright sidecar for browsers, keep the
same command and skip browser binary installation with an environment variable:

```bash
SMARTEST_SKIP_BROWSER_DOWNLOAD=1 bundle exec smartest --init-rails
```

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

If `smartest/` does not exist yet and you do not pass explicit paths, Smartest
prints scaffold commands and exits with status `1`:

```text
No smartest/ directory found.

To create a Smartest test scaffold:
  bundle exec smartest --init

For browser tests:
  bundle exec smartest --init-browser

For Rails browser tests:
  bundle exec smartest --init-rails

See all commands:
  bundle exec smartest --help
```

You can pass a single file:

```bash
bundle exec smartest smartest/user_test.rb
```

Or a directory:

```bash
bundle exec smartest smartest/suite1/
```

A directory path is expanded to `**/*_test.rb` under that directory, so this is
equivalent to:

```bash
bundle exec smartest smartest/suite1/**/*_test.rb
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

The help output is structured around common commands:

```text
Usage:
  bundle exec smartest [options] [paths...]

Common commands:
  bundle exec smartest
      Run tests under smartest/**/*_test.rb

  bundle exec smartest smartest/suite1/
      Run test files matching smartest/suite1/**/*_test.rb

  bundle exec smartest smartest/user_test.rb
      Run one test file

  bundle exec smartest smartest/user_test.rb:12
      Run tests around line 12

  bundle exec smartest --init
      Generate a basic Smartest scaffold

  bundle exec smartest --init-browser
      Generate a Playwright browser-test scaffold

  bundle exec smartest --init-rails
      Generate a Rails Playwright browser-test scaffold
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
every test, test-scoped fixture setup and teardown, suite fixture setup, and suite
fixture teardown.

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
fixture setup, the test body, and fixture teardown.

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
instead so its cache and teardown belong to the suite lifecycle.

`use_fixture` and `use_matcher` are only available inside `around_suite` or
`around_test` blocks. `use_helper` is only available inside `around_test`. None
of them are top-level DSL methods. See [Helpers](./helpers.md) for details on
helper registration.

## Exit Status

Smartest returns:

- `0` when every test passes, is skipped, or is pending as expected
- `1` when any test fails
- `1` when a pending test unexpectedly passes
- `1` when suite fixture teardown fails
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
