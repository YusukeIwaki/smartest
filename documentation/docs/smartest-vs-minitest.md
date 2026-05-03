---
title: Smartest vs Minitest
description: Compare Smartest's keyword fixture injection with Minitest setup, teardown, assertions, and test file layout.
---

# Smartest vs Minitest

Minitest is a familiar Ruby testing framework for xUnit-style tests. It works
well when setup is simple, class-based test organization is preferred, and the
suite already uses Minitest conventions.

Smartest is focused on pytest-style fixture injection. It is designed for tests
where dependencies should be requested explicitly and fixture cleanup should sit
beside the resource setup.

## At a Glance

| Concern | Minitest | Smartest |
| --- | --- | --- |
| Test shape | Test classes with `test_` methods | Top-level `test("name")` blocks |
| Setup | `setup` methods and instance variables | Class-based fixtures |
| Dependency visibility | Test methods read `@instance_variables` | Tests request keyword arguments |
| Teardown | `teardown` methods | `cleanup` inside fixtures |
| Assertions | `assert_equal`, `refute`, and related assertions | `expect(actual).to matcher` |
| Default file path | Often `test/` | `smartest/**/*_test.rb` |

## `setup` Compared With Fixtures

A Minitest test often shares setup through instance variables:

```ruby title="Minitest"
class UserRepositoryTest < Minitest::Test
  def setup
    @database = TestDatabase.create
    @repository = UserRepository.new(@database)
  end

  def teardown
    @database.drop
  end

  def test_finds_user
    @database.insert_user(name: "Alice")
    assert_equal "Alice", @repository.find("Alice").name
  end
end
```

In Smartest, setup values are fixtures and tests name the fixtures they need:

```ruby title="Smartest"
class RepositoryFixture < Smartest::Fixture
  fixture :database do
    database = TestDatabase.create
    cleanup { database.drop }
    database
  end

  fixture :repository do |database:|
    UserRepository.new(database)
  end
end

around_suite do |suite|
  use_fixture RepositoryFixture
  suite.run
end

test("finds user") do |database:, repository:|
  database.insert_user(name: "Alice")
  expect(repository.find("Alice").name).to eq("Alice")
end
```

The Smartest test signature documents the setup values used by this test. The
`repository` fixture documents that it depends on `database`.

## Lazy Fixture Resolution

Minitest `setup` runs before each test method in the class. Smartest resolves
only the fixtures requested by the current test, plus the fixtures they depend
on.

```ruby title="Smartest"
test("uses only the database") do |database:|
  expect(database.connected?).to eq(true)
end

test("uses a repository") do |repository:|
  expect(repository.count).to eq(0)
end
```

The first test does not create `repository`. The second test creates
`repository` and its `database` dependency.

## Coexisting With Minitest

Smartest looks for this glob when no paths are passed:

```text
smartest/**/*_test.rb
```

It does not load `test/` by default, so a project can keep Minitest tests under
`test/` while adding Smartest tests under `smartest/`:

```text
test/
  user_repository_test.rb
smartest/
  test_helper.rb
  fixtures/
    repository_fixture.rb
  user_repository_test.rb
```

## When Smartest Is a Good Fit

Smartest is worth considering when:

- test dependencies are easier to read as named keyword arguments than as
  instance variables
- setup values depend on other setup values
- resource cleanup should be attached to the fixture that acquired the resource
- you want pytest-style fixture injection in Ruby

Minitest may be a better fit when:

- the project already follows Minitest class and assertion conventions
- setup is simple enough that `setup` and `teardown` stay clear
- existing framework integrations assume Minitest tests under `test/`
