---
sidebar_position: 4
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

The init command creates `test/test_helper.rb`, `test/fixtures/`, and `test/example_test.rb`. It does not overwrite existing files.

Generated tests require the helper by name:

```ruby
require "test_helper"

test("example") do
  expect(1 + 1).to eq(2)
end
```

The CLI adds `test/` to Ruby's load path before loading files, so helpers can
be required by name.

## Run Tests

Run the default suite:

```bash
bundle exec smartest
```

If no paths are passed, the CLI looks for:

```text
test/**/*_test.rb
```

You can pass a single file:

```bash
bundle exec smartest test/user_test.rb
```

Or a shell glob:

```bash
bundle exec smartest test/**/*_test.rb
```

Show CLI help:

```bash
bundle exec smartest --help
```

Show the installed Smartest version:

```bash
bundle exec smartest --version
```

## Exit Status

Smartest returns:

- `0` when every test passes
- `1` when any test fails
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

1 test, 1 passed, 0 failed
```

A failing expectation includes failure details:

```text
Failures:

1) bad math
   expected 2 to eq 3
```

## Helper Loading

`test/test_helper.rb` typically requires `smartest/autorun` and loads fixture
files:

```ruby
require "smartest/autorun"

Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each do |fixture_file|
  require fixture_file
end
```

Test files require that helper:

```ruby
require "test_helper"
```

The CLI disables autorun before loading files, so requiring the helper does not
run the suite twice.

Fixture files under `test/fixtures/` are required by the helper in sorted order.
