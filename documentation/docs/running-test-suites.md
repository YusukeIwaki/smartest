---
sidebar_position: 4
title: Running Test Suites
description: Run Smartest tests through autorun or the CLI.
---

# Running Test Suites

Smartest has two entry points:

- `smartest/autorun` for single-file execution
- `exe/smartest` for loading one or more test files from the command line

## Autorun

Use `smartest/autorun` when a file should run itself:

```ruby title="test/example_test.rb"
require "smartest/autorun"

test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end
```

Run it:

```bash
ruby -Ilib test/example_test.rb
```

## CLI

Initialize a new test scaffold:

```bash
bundle exec smartest --init
```

The init command creates `test/test_helper.rb` and `test/example_test.rb`. It does not overwrite existing files.

From this repository, run the CLI directly:

```bash
ruby -Ilib exe/smartest test/**/*_test.rb
```

After installing the gem, use the executable directly:

```bash
smartest test/**/*_test.rb
```

If no paths are passed, the CLI looks for:

```text
test/**/*_test.rb
```

You can pass a single file:

```bash
ruby -Ilib exe/smartest test/user_test.rb
```

Or a shell glob:

```bash
ruby -Ilib exe/smartest test/**/*_test.rb
```

Show CLI help:

```bash
smartest --help
```

Show the installed Smartest version:

```bash
smartest --version
```

## Exit Status

Smartest returns:

- `0` when every test passes
- `1` when any test fails
- `1` when a test file cannot be loaded

This makes the CLI suitable for CI jobs:

```bash
ruby -Ilib exe/smartest test/**/*_test.rb
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

## Autorun and CLI Together

Test files may require `smartest/autorun` and still be loaded by the CLI. The CLI disables autorun before loading files so the suite is not run twice.
