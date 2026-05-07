---
title: Pytest-style Fixtures for Ruby
description: Map pytest fixture concepts to Smartest's class-based fixtures, keyword injection, fixture dependencies, and teardown.
---

# Pytest-style Fixtures for Ruby

Smartest brings pytest-style fixture injection to Ruby without copying Python's
decorator syntax.

In pytest, a test asks for a fixture by naming a function parameter. In Smartest,
a test asks for a fixture by naming a required Ruby keyword argument:

```python title="pytest"
import pytest

@pytest.fixture
def user():
    return User(name="Alice")

def test_user(user):
    assert user.name == "Alice"
```

```ruby title="Smartest"
class AppFixture < Smartest::Fixture
  fixture :user do
    User.new(name: "Alice")
  end
end

around_suite do |suite|
  use_fixture AppFixture
  suite.run
end

test("user") do |user:|
  expect(user.name).to eq("Alice")
end
```

`fixture` and `suite_fixture` are class macros inside `Smartest::Fixture`
subclasses. They are not top-level APIs in test files.

## Fixture Dependencies

Pytest fixtures can depend on other fixtures by naming them as function
parameters:

```python title="pytest"
@pytest.fixture
def client(server):
    return Client(base_url=server.url)
```

Smartest uses required keyword arguments for the same idea:

```ruby title="Smartest"
class WebFixture < Smartest::Fixture
  suite_fixture :server do
    TestServer.start
  end

  fixture :client do |server:|
    Client.new(base_url: server.url)
  end
end
```

When a test requests `client`, Smartest resolves `server` first. The dependency
graph stays visible in fixture signatures instead of being hidden in test body
calls.

## Teardown

Pytest often uses `yield` fixtures or finalizers for teardown:

```python title="pytest"
@pytest.fixture
def server():
    server = TestServer.start()
    yield server
    server.stop()
```

Smartest keeps teardown near the resource setup with `on_teardown`:

```ruby title="Smartest"
class WebFixture < Smartest::Fixture
  fixture :server do
    server = TestServer.start
    on_teardown { server.stop }
    server
  end
end
```

Teardown runs even if a later setup step or the test body fails. Regular fixture
teardown runs after the test. `suite_fixture` teardown runs after the suite.

## Concept Map

| Pytest concept | Smartest equivalent | Notes |
| --- | --- | --- |
| `@pytest.fixture` | `fixture` inside `class < Smartest::Fixture` | Smartest fixtures are grouped in Ruby classes. |
| Test function parameter | Required keyword argument | `test("name") do |user:|` requests `fixture :user`. |
| Fixture parameter | Fixture block keyword argument | `fixture :client do |server:|` depends on `server`. |
| `scope="session"` | `suite_fixture` | Created lazily and reused for the suite. |
| `yield` teardown or finalizer | `on_teardown` | Register teardown immediately after acquiring the resource. |
| `conftest.py` discovery | `require` fixture files and `use_fixture` | Smartest registers fixture classes explicitly. |

## How This Differs From Ruby Fixtures

In Ruby projects, "fixtures" often means Rails database records, FactoryBot
factories, or helper methods hidden behind a test framework DSL. Smartest uses a
narrower meaning:

- a fixture is a named setup value
- tests declare fixture usage in their keyword arguments
- fixtures declare dependencies in their keyword arguments
- teardown belongs next to the resource setup

This makes Smartest useful when you want pytest-style dependency injection for
Ruby tests while keeping fixture ownership explicit.
