---
title: Stubs
description: Stub Ruby methods from Smartest fixtures with automatic cleanup.
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

The stub is automatically reset when the fixture is cleaned up.

## Instance Method Stubs

Use `simple_stub_any_instance_of` for instance methods:

```ruby
simple_stub_any_instance_of(PaymentGateway, :charge) { :approved }
```

The stub affects existing instances and new instances of the target class in
the current Fiber until cleanup resets it. Other Fibers and Threads continue to
see the original method unless they apply their own stub.

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

## How Cleanup Works

You do not need to call `reset!` manually when using stub helpers inside
fixtures. The helper internally:

1. creates a `Smartest::SimpleStub`
2. applies it
3. registers cleanup to reset it

Conceptually, this:

```ruby
simple_stub_any_instance_of(ApplicationController, :current_user) { user }
```

behaves like:

```ruby
stub = Smartest::SimpleStub.new(ApplicationController, :current_user) { user }
stub.apply!
cleanup { stub.reset }
```

Cleanup is tied to the fixture lifecycle:

- `fixture` stubs reset after each test.
- `suite_fixture` stubs reset after the suite fixture scope ends.

In most cases, prefer the fixture helpers so stub lifetime is automatically tied
to the fixture lifecycle.

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

Both helpers return the `Smartest::SimpleStub` object. They are available inside
`Smartest::Fixture` fixture blocks, including `fixture` and `suite_fixture`,
because they need `cleanup` to keep the stub lifetime tied to the fixture scope.

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
already active in the current Fiber. `reset!` raises
`Smartest::SimpleStub::NotAppliedError` when the stub is not active in the
current Fiber.

`Smartest::SimpleStub` stores the active stub in Fiber-local storage keyed by
the target class and method name. That means setup and cleanup can use separate
stub instances in the same Fiber:

```ruby
Smartest::SimpleStub.new(User, :name) { "Test User" }.apply

# Later:
Smartest::SimpleStub.new(User, :name).reset
```

## Fiber and Thread Scope

`Smartest::SimpleStub` installs a process-wide dispatcher method, but the active
stub implementation is looked up from Fiber-local storage. Applying a stub in
one Fiber does not change behavior in another Fiber or Thread:

```ruby
stub = Smartest::SimpleStub.new(User, :name) { "Stubbed" }
stub.apply!

User.new.name
# => "Stubbed"

Fiber.new do
  User.new.name
  # Calls the original method.
end.resume

stub.reset!
```

Different Threads can apply different stubs for the same class and method at
the same time. Cleanup still matters, so prefer the fixture helpers when the
stub belongs to test setup.
