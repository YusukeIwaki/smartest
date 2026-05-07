---
title: Stubs
description: Stub Ruby methods from Smartest fixtures with automatic teardown.
---

# Stubs

Smartest provides small stub helpers for replacing Ruby methods during a test.
They are useful when a test depends on stubbed behavior and you want that
dependency to be visible in the test signature:

```ruby
test("checkout succeeds") do |payment_gateway_stub:|
  expect(Checkout.call).to eq(:paid)
end
```

The fixture name makes it clear that this test depends on a payment gateway
stub.

If you are familiar with RSpec, this is similar to putting a stub in `before`:

```ruby
before do
  allow_any_instance_of(PaymentGateway)
    .to receive(:charge)
    .and_return(:approved)
end
```

In Smartest, the same idea is expressed as a fixture:

```ruby
class PaymentFixture < Smartest::Fixture
  fixture :payment_gateway_stub do
    simple_stub_any_instance_of(PaymentGateway, :charge) { :approved }
  end
end
```

Register the fixture class from `around_suite` before tests request the fixture:

```ruby
around_suite do |suite|
  use_fixture PaymentFixture
  suite.run
end
```

`use_fixture` is available inside `around_suite` or `around_test` blocks, not as
a top-level method in a test file.

The stub is automatically reset when the fixture is torn down.

## Instance Method Stubs

Use `simple_stub_any_instance_of` for instance methods:

```ruby
simple_stub_any_instance_of(PaymentGateway, :charge) { :approved }
```

The stub affects existing instances and new instances of the target class in
the current fixture scope until teardown resets it. During a Smartest test run,
method stubs use a process-shared store for the current test case, so other
Fibers and Threads in the same test can see the stub.

A Rails authentication fixture might look like this:

```ruby
class EdgeCaseFixture < Smartest::Fixture
  fixture :suspended_user do
    create(:user, :suspended)
  end

  fixture :suspended_user_logged_in do |suspended_user:|
    simple_stub_any_instance_of(ApplicationController, :current_user) { suspended_user }
    suspended_user
  end
end
```

## Class Method Stubs

Use `simple_stub` for singleton methods, including class methods:

```ruby
class TimeFixture < Smartest::Fixture
  fixture :fixed_time do
    frozen_time = Time.utc(2026, 1, 1, 0, 0, 0)
    simple_stub(Time, :now) { frozen_time }
    frozen_time
  end
end
```

```ruby
test("uses fixed time") do |fixed_time:|
  expect(Time.now).to eq(fixed_time)
end
```

## Constant Stubs

Use `with_stub_const` with a block for constants. It is available in test
bodies, `around_test`, and `around_suite`, not in fixture blocks.

```ruby
test("uses fake payment provider") do
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    expect(Checkout.call).to eq(:paid)
  end
end
```

If you are coming from RSpec, use Smartest's `around_test` where you would often
think of an around example hook:

```ruby
around_test do |test|
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    test.run
  end
end
```

Use `around_suite` when the constant should stay replaced for the whole suite
run:

```ruby
around_suite do |suite|
  with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
    suite.run
  end
end
```

Constant stubs are process-global. Avoid concurrent tests that stub the same
constant.

## How Method Stub Teardown Works

You do not need to call `reset!` manually when using method stub helpers inside
fixtures. The helper internally:

1. creates the stub state
2. applies the replacement
3. registers teardown to reset it

Conceptually, this:

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

behaves like:

```ruby
stub = Smartest::SimpleStub.new(ApplicationController, :current_user) { user }
stub.apply!
on_teardown { stub.reset }
```

Teardown is tied to the fixture lifecycle:

- `fixture` method stubs reset after each test.
- `suite_fixture` method stubs reset after the suite fixture scope ends.

In most cases, prefer the fixture helpers so stub lifetime is automatically tied
to the fixture lifecycle.

## How Constant Stub Blocks Work

`with_stub_const` records the previous constant value, replaces it,
yields to the block, and restores or removes the constant with `ensure`.

Conceptually, this:

```ruby
with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
  call_api
end
```

behaves like:

```ruby
old_value = AppConfig.const_get(:PAYMENT_PROVIDER, false)
AppConfig.__send__(:remove_const, :PAYMENT_PROVIDER)
AppConfig.const_set(:PAYMENT_PROVIDER, "fake")

begin
  call_api
ensure
  AppConfig.__send__(:remove_const, :PAYMENT_PROVIDER)
  AppConfig.const_set(:PAYMENT_PROVIDER, old_value)
end
```

The real implementation uses `remove_const` and `const_set` so it can also
restore constants that did not exist before the block.

## API

`simple_stub_any_instance_of(klass, method_name) { ... }` stubs an instance
method on `klass`.

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

`simple_stub(object, method_name) { ... }` stubs a singleton method on `object`.
For class methods, pass the class object:

```ruby
simple_stub(Time, :now) { fixed_time }
```

`with_stub_const(constant_path, value) { ... }` stubs a constant for the
duration of the block. The path may be a String or Symbol:

```ruby
with_stub_const("AppConfig::PAYMENT_PROVIDER", "fake") do
  call_api
end
```

`simple_stub_any_instance_of` and `simple_stub` return the
`Smartest::SimpleStub` object. `with_stub_const` returns the block result.

`simple_stub_any_instance_of` and `simple_stub` are available inside
`Smartest::Fixture` fixture blocks, including `fixture` and `suite_fixture`,
because they need `on_teardown` to keep the stub lifetime tied to the fixture scope.
`with_stub_const` is available in test bodies, `around_test`, and
`around_suite`.

## What Stubs Are Not

Smartest stubs are not a mock framework. They do not:

- verify calls
- record arguments
- provide expectations

Use Smartest expectations for assertions.

## Low-Level API

Use `Smartest::SimpleStub` directly when you need to manage reset manually:

```ruby
stub = Smartest::SimpleStub.new(PaymentGateway, :charge) { :approved }
stub.apply!
stub.reset!
```

The first argument must be a `Class`, and the second argument must be a
`Symbol`. For singleton methods, pass the object's singleton class:

```ruby
stub = Smartest::SimpleStub.new(Time.singleton_class, :now) { fixed_time }
```

`apply` and `reset` are safe to call more than once. Use the bang methods when
repeated application or reset should fail.

`apply!` raises `Smartest::SimpleStub::AlreadyAppliedError` when the stub is
already active in the current stub store. `reset!` raises
`Smartest::SimpleStub::NotAppliedError` when the stub is not active in the
current stub store.

During a Smartest run, the runner creates a suite-level process-shared store and
a test-level process-shared store. `around_suite` stubs and `suite_fixture`
stubs are stored in the suite store. Test-scoped fixture and test body stubs are
stored in the current test store and reset by fixture teardown:

```ruby
Smartest::SimpleStub.new(User, :name) { "Test User" }.apply

# Later:
Smartest::SimpleStub.new(User, :name).reset
```

Outside a Smartest runner, direct low-level use falls back to `FiberLocalStore`
so standalone setup and teardown can still be scoped to the current Fiber.

## Scope and Concurrency

`Smartest::SimpleStub` installs a process-wide dispatcher method, but the active
stub implementation is looked up from the current Smartest stub store. In normal
Smartest tests, applying a stub in one Fiber or Thread changes behavior in other
Fibers and Threads that run inside the same test case:

```ruby
stub = Smartest::SimpleStub.new(User, :name) { "Stubbed" }
stub.apply!

User.new.name
# => "Stubbed"

Fiber.new do
  User.new.name
  # => "Stubbed"
end.resume

stub.reset!
```

If Smartest runs tests concurrently in one Ruby process in the future, tests
using the process-shared method stub store are serialized internally while their
test store is active. This avoids one test's Rails server thread reading another
test's stubs.

Constant stubs are different: Ruby constant lookup does not provide a Fiber-local
hook, so `with_stub_const` replaces the constant on the owner module. That
change is process-global until teardown runs. Avoid concurrent tests that stub
the same constant.
