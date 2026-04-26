---
title: Expectations
description: Smartest expectation methods and matchers.
---

# Expectations

Smartest exposes expectations inside test bodies:

```ruby
expect(actual).to matcher
expect(actual).not_to matcher
```

## `eq(expected)`

Passes when `actual == expected`:

```ruby
expect(1 + 2).to eq(3)
expect("hello").not_to eq("goodbye")
```

## `include(expected)`

Passes when `actual.include?(expected)` returns true:

```ruby
expect([1, 2, 3]).to include(2)
expect("smartest").to include("test")
```

## `be_nil`

Passes when `actual.nil?` is true:

```ruby
expect(nil).to be_nil
expect("value").not_to be_nil
```

## `raise_error(error_class)`

Passes when the block raises the expected error class:

```ruby
expect { Integer("x") }.to raise_error(ArgumentError)
```

Fatal process-level exceptions such as `SystemExit` and `Interrupt` are re-raised instead of being treated as assertion failures.
