# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "smartest/autorun"
require "stringio"
require "open3"
require "tmpdir"

module SmartestSelfTest
  module_function

  def test_case(name, block)
    Smartest::TestCase.new(
      name: name,
      metadata: {},
      block: block,
      location: caller_locations(1, 1).first
    )
  end

  def run_suite(suite)
    output = StringIO.new
    status = Smartest::Runner.new(suite: suite, reporter: Smartest::Reporter.new(output)).run

    [status, output.string]
  end

  def capture_error(expected_error)
    yield
  rescue Exception => error
    raise if Smartest.fatal_exception?(error)

    unless error.is_a?(expected_error)
      raise Smartest::AssertionFailed, "expected #{expected_error}, but raised #{error.class}: #{error.message}"
    end

    error
  else
    raise Smartest::AssertionFailed, "expected #{expected_error}, but nothing was raised"
  end
end

class SelfTestRegisteredFixture < Smartest::Fixture
  fixture :registered_user_name do
    "Alice"
  end
end

use_fixture SelfTestRegisteredFixture

test("registers fixture classes with use_fixture") do |registered_user_name:|
  expect(registered_user_name).to eq("Alice")
end

test("runs a registered test") do
  suite = Smartest::Suite.new
  suite.tests.add(SmartestSelfTest.test_case("factorial", proc { expect(1 * 2 * 3).to eq(6) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(output).to include("Running 1 test")
  expect(output).to include("1 test, 1 passed, 0 failed")
end

test("reports expectation failures") do
  suite = Smartest::Suite.new
  suite.tests.add(SmartestSelfTest.test_case("bad math", proc { expect(1 + 1).to eq(3) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("expected 2 to eq 3")
  expect(output).to include("1 test, 0 passed, 1 failed")
end

test("supports basic matchers") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "matchers",
      proc do
        expect([1, 2, 3]).to include(2)
        expect(nil).to be_nil
        expect("value").not_to be_nil
        expect { raise ArgumentError, "bad" }.to raise_error(ArgumentError)
      end
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("resolves keyword fixture dependencies per test") do
  calls = []

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :user do
      calls << :user
      "Alice"
    end

    fixture :greeting do |user:|
      "Hello, #{user}"
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("first", proc { |greeting:| expect(greeting).to eq("Hello, Alice") }))
  suite.tests.add(SmartestSelfTest.test_case("second", proc { |greeting:| expect(greeting).to eq("Hello, Alice") }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(calls).to eq(%i[user user])
end

test("creates fresh fixture values and fixture instances for each test") do
  markers = []
  instances = []

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :marker do
      instances << self
      Object.new
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("first", proc { |marker:| markers << marker }))
  suite.tests.add(SmartestSelfTest.test_case("second", proc { |marker:| markers << marker }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(markers.length).to eq(2)
  expect(markers[0].object_id).not_to eq(markers[1].object_id)
  expect(instances.length).to eq(2)
  expect(instances[0].object_id).not_to eq(instances[1].object_id)
end

test("caches fixture values within one test") do
  calls = 0

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :token do
      calls += 1
      Object.new
    end

    fixture :first do |token:|
      token
    end

    fixture :second do |token:|
      token
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("same object", proc { |first:, second:| expect(first.object_id).to eq(second.object_id) }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(calls).to eq(1)
end

test("runs cleanup in reverse order after failures") do
  events = []

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :server do
      cleanup { events << :server }
      :server
    end

    fixture :browser do |server:|
      cleanup { events << :browser }
      server
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("fails", proc { |browser:| expect(browser).to eq(:nope) }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(events).to eq(%i[browser server])
end

test("runs cleanup when fixture setup fails after cleanup registration") do
  events = []

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :server do
      cleanup { events << :server }
      raise "server setup failed"
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("needs server", proc { |server:| expect(server).to eq(:server) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(events).to eq([:server])
  expect(output).to include("RuntimeError: server setup failed")
end

test("duplicate fixture names fail the test") do
  first_fixture = Class.new(Smartest::Fixture) do
    fixture(:user) { "Alice" }
  end

  second_fixture = Class.new(Smartest::Fixture) do
    fixture(:user) { "Bob" }
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(first_fixture)
  suite.fixture_classes.add(second_fixture)
  suite.tests.add(SmartestSelfTest.test_case("needs user", proc { |user:| expect(user).to eq("Alice") }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("duplicate fixture: user")
end

test("allows child fixture classes to override parent fixtures") do
  parent_fixture = Class.new(Smartest::Fixture) do
    fixture(:user_name) { "Parent" }
  end

  child_fixture = Class.new(parent_fixture) do
    fixture(:user_name) { "Child" }
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(child_fixture)
  suite.tests.add(SmartestSelfTest.test_case("uses override", proc { |user_name:| expect(user_name).to eq("Child") }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("circular fixture dependencies fail the test") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture(:a) { |b:| b }
    fixture(:b) { |a:| a }
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("cycle", proc { |a:| expect(a).to eq(:a) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("circular fixture dependency: a -> b -> a")
end

test("fixture blocks can call private helper methods") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :user_name do
      build_user_name("Alice")
    end

    private

    def build_user_name(name)
      name.upcase
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("uses helper", proc { |user_name:| expect(user_name).to eq("ALICE") }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("rejects positional test parameters") do
  error = SmartestSelfTest.capture_error(Smartest::InvalidFixtureParameterError) do
    SmartestSelfTest.test_case("bad", proc { |_user| nil })
  end

  expect(error.message).to include("Positional fixture parameters are not supported.")
end

test("rejects positional fixture parameters") do
  error = SmartestSelfTest.capture_error(Smartest::InvalidFixtureParameterError) do
    Class.new(Smartest::Fixture) do
      fixture(:bad) { |_server| nil }
    end
  end

  expect(error.message).to include("Positional fixture dependencies are not supported.")
end

test("cli loads files and returns failure status") do
  Dir.mktmpdir do |dir|
    test_file = File.join(dir, "sample_test.rb")
    File.write(test_file, <<~RUBY)
      require "smartest/autorun"

      test("cli failure") do
        expect("a").to eq("b")
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      test_file
    )

    expect(status.success?).to eq(false)
    expect(stderr).to eq("")
    expect(stdout).to include("cli failure")
    expect(stdout).to include("expected \"a\" to eq \"b\"")
  end
end
