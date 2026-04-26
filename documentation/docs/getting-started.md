---
sidebar_position: 2
title: Getting Started
description: Install Smartest, write a first test, and run it.
---

# Getting Started

This guide creates a small test scaffold and runs it with Smartest.

## Requirements

Smartest is a Ruby test runner. The current development version is tested with Ruby 3.3.

## Installation

Add Smartest to your application's Gemfile:

```ruby
gem "smartest"
```

Then install it:

```bash
bundle install
```

Or install it directly:

```bash
gem install smartest
```

If you are working from this repository, run examples with the local `lib/` directory on Ruby's load path:

```bash
ruby -Ilib test/example_test.rb
```

## Create a Test File

Initialize a test scaffold:

```bash
bundle exec smartest --init
```

This creates `test/test_helper.rb`:

```ruby
require "smartest/autorun"
```

It also creates `test/example_test.rb`:

```ruby
require_relative "test_helper"

test("example") do
  expect(1 + 1).to eq(2)
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

After installing the gem:

```bash
bundle exec smartest
```

Expected output:

```text
Running 1 test

✓ example

1 test, 1 passed, 0 failed
```

## Next Steps

Continue with [Writing Tests](./writing-tests.md) to learn how to structure tests and assertions, then read [Fixtures](./fixtures.md) when a test needs setup data or external resources.
