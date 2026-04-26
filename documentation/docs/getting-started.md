---
sidebar_position: 2
title: Getting Started
description: Install Smartest, write a first test, and run it.
---

# Getting Started

This guide creates one test file and runs it with Smartest.

## Requirements

Smartest is a Ruby test runner. The current development version is tested with Ruby 3.3.

If you are working from this repository, run examples with the local `lib/` directory on Ruby's load path:

```bash
ruby -Ilib test/example_test.rb
```

When Smartest is packaged as a gem, applications can require it normally through Bundler.

## Create a Test File

Create `test/example_test.rb`:

```ruby
require "smartest/autorun"

test("factorial") do
  expect(1 * 2 * 3).to eq(6)
end
```

`smartest/autorun` does two things:

- makes the top-level `test` and `use_fixture` DSL available
- runs the registered tests when Ruby exits

## Run the Test

From this repository:

```bash
ruby -Ilib test/example_test.rb
```

Expected output:

```text
Running 1 test

✓ factorial

1 test, 1 passed, 0 failed
```

## Next Steps

Continue with [Writing Tests](./writing-tests.md) to learn how to structure tests and assertions, then read [Fixtures](./fixtures.md) when a test needs setup data or external resources.
