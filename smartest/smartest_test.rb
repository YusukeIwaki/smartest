# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "smartest/autorun"
require "fileutils"
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

class SelfTestBaseType; end
class SelfTestChildType < SelfTestBaseType; end

module SelfTestMarkerType; end

class SelfTestMarkedType
  include SelfTestMarkerType
end

around_suite do |suite|
  use_fixture SelfTestRegisteredFixture
  suite.run
end

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

test("skip marks a test as skipped and stops the body") do
  events = []
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "unsupported export",
      proc do
        events << :before_skip
        skip "firefox is not supported"
        events << :after_skip
      end
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq([:before_skip])
  expect(output).to include("- unsupported export (skipped: firefox is not supported)")
  expect(output).to include("1 test, 0 passed, 0 failed, 1 skipped")
  expect(output).not_to include("Failures:")
end

test("pending marks a failing test as pending") do
  events = []
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bidi export",
      proc do
        pending "Not supported by WebDriver BiDi yet"
        events << :after_pending
        expect("actual").to eq("expected")
        events << :after_failure
      end
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq([:after_pending])
  expect(output).to include("* bidi export (pending: Not supported by WebDriver BiDi yet)")
  expect(output).to include("1 test, 0 passed, 0 failed, 1 pending")
  expect(output).not_to include("Failures:")
end

test("pending fails when the test passes") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "fixed bidi export",
      proc do
        pending "Not supported by WebDriver BiDi yet"
        expect("actual").to eq("actual")
      end
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("expected pending test to fail, but it passed: Not supported by WebDriver BiDi yet")
  expect(output).to include("1 test, 0 passed, 1 failed")
end

test("skip and pending are not available inside fixtures") do
  %i[skip pending].each do |method_name|
    fixture_class = Class.new(Smartest::Fixture) do
      fixture :value do
        __send__(method_name, "reason")
      end
    end

    suite = Smartest::Suite.new
    suite.fixture_classes.add(fixture_class)
    suite.tests.add(SmartestSelfTest.test_case("#{method_name} fixture", proc { |value:| expect(value).to eq(:value) }))

    status, output = SmartestSelfTest.run_suite(suite)

    expect(status).to eq(1)
    expect(output).to include("NoMethodError")
    expect(output).to include(method_name.to_s)
  end
end

test("supports basic matchers") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "matchers",
      proc do
        expect([1, 2, 3]).to include(2)
        expect("about:blank").to start_with("about:")
        expect("https://cdn-b.test/assets/app.js").to start_with(
          "https://cdn-a.test",
          "https://cdn-b.test"
        )
        expect("screenshot.png").to end_with(".jpg", ".png")
        expect("https://example.test").not_to start_with("about:")
        expect("report.txt").not_to end_with(".png")
        expect(Object.new).not_to start_with("prefix")
        expect(SelfTestChildType.new).to be_a(SelfTestBaseType)
        expect(SelfTestMarkedType.new).to be_an(SelfTestMarkerType)
        expect(nil).to be_nil
        expect("value").not_to be_nil
        expect("https://example.test").to match(%r{\Ahttps://})
        expect("about:blank").not_to match(%r{\Ahttps://})
        expect(%w[request close request]).to contain_exactly("request", "request", "close")
        expect(%i[request close open]).to match_array(%i[open request close])
        expect(["foo", 42]).to contain_exactly(match(/foo/), eq(42))
        expect(["ab", "ac"]).to contain_exactly(match(/a/), "ab")
        expect([nil, false]).to contain_exactly(false, nil)
        expect([:request]).not_to contain_exactly(:request, :request)
        expect { raise ArgumentError, "bad" }.to raise_error(ArgumentError)
        expect { raise RuntimeError, "request timed out" }.to raise_error(/timed out/)
        expect { raise ArgumentError, "bad input" }.to raise_error(ArgumentError, /bad/)
        expect { raise ArgumentError, "bad" }.not_to raise_error(RuntimeError)
        expect { raise ArgumentError, "bad" }.not_to raise_error(/timed out/)
        expect { raise ArgumentError, "bad" }.not_to raise_error(ArgumentError, /timed out/)
        expect { :ok }.not_to raise_error(/timed out/)
      end
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("supports matcher composition with and and or") do
  action_calls = 0
  first_value = 0
  second_value = 10

  expect("NetworkError").to include("Network").or include("Failed to fetch")
  expect(304).to eq(200).or(eq(201)).or(eq(304))
  expect("report.txt").to start_with("report").and end_with(".txt")
  expect {
    action_calls += 1
    first_value += 1
    second_value += 1
  }.to change { first_value }.by(1).and change { second_value }.by(1)

  expect(action_calls).to eq(1)
end

test("reports matcher composition failures") do
  error = SmartestSelfTest.capture_error(Smartest::AssertionFailed) do
    expect("permission denied").to include("NetworkError").or include("Failed to fetch")
  end

  expect(error.message).to include(
    'expected "permission denied" to match any of include "NetworkError" or include "Failed to fetch"'
  )
  expect(error.message).to include('expected "permission denied" to include "NetworkError"')
  expect(error.message).to include('expected "permission denied" to include "Failed to fetch"')

  error = SmartestSelfTest.capture_error(Smartest::AssertionFailed) do
    expect("error.log").to start_with("error").and end_with(".txt")
  end

  expect(error.message).to include('expected "error.log" to match all of start with "error" and end with ".txt"')
  expect(error.message).to include('expected "error.log" to end with ".txt"')
end

test("rejects negated matcher composition") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    expect("public token").not_to include("password").or include("secret")
  end

  expect(error.message).to eq("not_to does not support matcher composition with .and or .or")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    expect("report.log").not_to start_with("report").and end_with(".txt")
  end

  expect(error.message).to eq("not_to does not support matcher composition with .and or .or")
end

test("short-circuits or matcher composition") do
  right_matcher = Class.new(Smartest::Matcher) do
    def matches?(_actual)
      raise "right matcher should not be evaluated"
    end

    def failure_message
      "right matcher failed"
    end

    def negated_failure_message
      "right matcher matched"
    end
  end.new

  expect("ok").to eq("ok").or(right_matcher)
end

test("reports be_a and match matcher failures") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad type",
      proc { expect(nil).to be_a(String) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated type",
      proc { expect(SelfTestChildType.new).not_to be_an(SelfTestBaseType) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad regex",
      proc { expect("about:blank").to match(%r{\Ahttps://}) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated regex",
      proc { expect("https://example.test").not_to match(%r{\Ahttps://}) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("expected nil to be a kind of String, but was NilClass")
  expect(output).to include("not to be a kind of SelfTestBaseType, but was SelfTestChildType")
  expect(output).to include('expected "about:blank" to match /\\Ahttps:\\/\\//')
  expect(output).to include('expected "https://example.test" not to match /\\Ahttps:\\/\\//')
end

test("reports contain_exactly and match_array matcher failures") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad collection",
      proc { expect(["foo", "baz", 2]).to contain_exactly(match(/foo/), eq(42), "bar") }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad duplicate count",
      proc { expect([:request]).to match_array(%i[request request]) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated collection",
      proc { expect(%w[b a]).not_to contain_exactly("a", "b") }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include('expected ["foo", "baz", 2] to contain exactly [match /foo/, eq 42, "bar"]')
  expect(output).to include('missing: [eq 42, "bar"]')
  expect(output).to include('extra: ["baz", 2]')
  expect(output).to include("expected [:request] to match array [:request, :request]")
  expect(output).to include("missing: [:request]")
  expect(output).to include('expected ["b", "a"] not to contain exactly ["a", "b"]')
end

test("reports raise_error matcher failures") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "nothing raised",
      proc { expect { :ok }.to raise_error(/timeout/) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad message",
      proc { expect { raise RuntimeError, "permission denied" }.to raise_error(/timeout/) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated message",
      proc { expect { raise RuntimeError, "timeout after 1s" }.not_to raise_error(/timeout/) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad class and message class",
      proc { expect { raise RuntimeError, "timeout after 1s" }.to raise_error(ArgumentError, /timeout/) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad class and message message",
      proc { expect { raise ArgumentError, "permission denied" }.to raise_error(ArgumentError, /timeout/) }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated class and message",
      proc { expect { raise ArgumentError, "timeout after 1s" }.not_to raise_error(ArgumentError, /timeout/) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("expected block to raise error with message matching /timeout/, but nothing was raised")
  expect(output).to include(
    "expected block to raise error with message matching /timeout/, but raised RuntimeError: permission denied"
  )
  expect(output).to include(
    "expected block not to raise error with message matching /timeout/, but raised RuntimeError: timeout after 1s"
  )
  expect(output).to include(
    "expected block to raise ArgumentError with message matching /timeout/, but raised RuntimeError: timeout after 1s"
  )
  expect(output).to include(
    "expected block to raise ArgumentError with message matching /timeout/, but raised ArgumentError: permission denied"
  )
  expect(output).to include(
    "expected block not to raise ArgumentError with message matching /timeout/, but raised ArgumentError: timeout after 1s"
  )
end

test("rejects unsupported raise_error argument forms") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    raise_error
  end

  expect(error.message).to eq("raise_error supports an error class, message regexp, or error class and message regexp")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    raise_error("timeout")
  end

  expect(error.message).to eq("raise_error supports an error class, message regexp, or error class and message regexp")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    raise_error(String)
  end

  expect(error.message).to eq("raise_error supports an error class, message regexp, or error class and message regexp")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    raise_error(RuntimeError, "timeout")
  end

  expect(error.message).to eq("raise_error supports an error class, message regexp, or error class and message regexp")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    raise_error(/timeout/, RuntimeError)
  end

  expect(error.message).to eq("raise_error supports an error class, message regexp, or error class and message regexp")
end

test("reports start_with and end_with matcher failures") do
  suite = Smartest::Suite.new
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad prefix",
      proc { expect("https://example.test/path").to start_with("about:") }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad suffix",
      proc { expect("asset.gif").to end_with(".jpg", ".png") }
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "bad negated suffix",
      proc { expect("screenshot.png").not_to end_with(".png") }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include('expected "https://example.test/path" to start with "about:"')
  expect(output).to include('expected "asset.gif" to end with ".jpg" or ".png"')
  expect(output).to include('expected "screenshot.png" not to end with ".png"')
end

test("supports change matcher for block expectations") do
  value = 0
  action_calls = 0

  expect {
    action_calls += 1
    value += 2
  }.to change { value }.from(0).to(2).by(2)

  expect(action_calls).to eq(1)
  expect { value }.not_to change { value }
end

test("reports change matcher failures with before and after values") do
  value = 0

  error = SmartestSelfTest.capture_error(Smartest::AssertionFailed) do
    expect { value += 1 }.to change { value }.from(0).to(2).by(2)
  end

  expect(error.message).to include("0 before")
  expect(error.message).to include("1 after")
  expect(error.message).to include("to(2)")
  expect(error.message).to include("by(2)")
end

test("fails negated change matcher when the value changes") do
  value = 0

  error = SmartestSelfTest.capture_error(Smartest::AssertionFailed) do
    expect { value += 1 }.not_to change { value }
  end

  expect(error.message).to include("expected value not to change")
  expect(error.message).to include("0 before")
  expect(error.message).to include("1 after")
end

test("requires change matcher value and action blocks") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    change
  end

  expect(error.message).to eq("change requires a block")

  error = SmartestSelfTest.capture_error(ArgumentError) do
    change(:value) { :other }
  end

  expect(error.message).to include("change does not support arguments")

  error = SmartestSelfTest.capture_error(Smartest::AssertionFailed) do
    expect(:value).to change { :other }
  end

  expect(error.message).to include("expected a block to change value")
end

test("registers matcher modules for suite execution contexts") do
  status_matcher = Class.new do
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual.status == @expected
    end

    def failure_message
      "expected #{@actual.inspect} to have status #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to have status #{@expected.inspect}"
    end
  end

  custom_matchers = Module.new do
    define_method(:have_status) do |expected|
      status_matcher.new(expected)
    end
  end

  response = Struct.new(:status).new(200)
  suite = Smartest::Suite.new
  suite.matcher_modules.add(custom_matchers)
  suite.tests.add(SmartestSelfTest.test_case("custom matcher", proc { expect(response).to have_status(200) }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("rejects non-module matcher registrations") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    Smartest::MatcherRegistry.new.add(Object.new)
  end

  expect(error.message).to include("matcher must be a module")
end

test("rejects class matcher registrations") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    Smartest::MatcherRegistry.new.add(Class.new)
  end

  expect(error.message).to include("matcher must be a module")
end

test("rejects non-module helper registrations") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    Smartest::HelperRegistry.new.add(Object.new)
  end

  expect(error.message).to include("helper must be a module")
end

test("rejects class helper registrations") do
  error = SmartestSelfTest.capture_error(ArgumentError) do
    Smartest::HelperRegistry.new.add(Class.new)
  end

  expect(error.message).to include("helper must be a module")
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

test("suite fixtures are created once and cleaned up after the suite") do
  events = []
  servers = []

  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :server do
      events << :server_setup
      server = Object.new
      cleanup { events << :server_cleanup }
      server
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("first", proc { |server:| events << :first; servers << server }))
  suite.tests.add(SmartestSelfTest.test_case("second", proc { |server:| events << :second; servers << server }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(%i[server_setup first second server_cleanup])
  expect(servers.length).to eq(2)
  expect(servers[0].object_id).to eq(servers[1].object_id)
end

test("test fixtures can depend on suite fixtures") do
  calls = []
  server_ids = []
  client_ids = []

  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :server do
      calls << :server
      Object.new
    end

    fixture :client do |server:|
      [server, Object.new]
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("first", proc { |client:| server_ids << client.first.object_id; client_ids << client.last.object_id }))
  suite.tests.add(SmartestSelfTest.test_case("second", proc { |client:| server_ids << client.first.object_id; client_ids << client.last.object_id }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(calls).to eq([:server])
  expect(server_ids.uniq.length).to eq(1)
  expect(client_ids.uniq.length).to eq(2)
end

test("suite fixtures cannot depend on test fixtures") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :user do
      :user
    end

    suite_fixture :server do |user:|
      user
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("needs server", proc { |server:| expect(server).to eq(:server) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("suite-scoped fixture server cannot depend on test-scoped fixture user")
end

test("suite fixture setup failures are cached and cleaned up once") do
  calls = 0
  events = []

  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :server do
      calls += 1
      cleanup { events << :server_cleanup }
      raise "server setup failed"
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("first", proc { |server:| expect(server).to eq(:server) }))
  suite.tests.add(SmartestSelfTest.test_case("second", proc { |server:| expect(server).to eq(:server) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(calls).to eq(1)
  expect(events).to eq([:server_cleanup])
  expect(output.scan("RuntimeError: server setup failed").length).to eq(2)
end

test("around_suite wraps tests and suite fixture cleanup") do
  events = []

  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :server do
      events << :server_setup
      cleanup { events << :server_cleanup }
      :server
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.around_suite_hooks << proc do |suite_run|
    events << :around_before
    suite_run.run
    events << :around_after
  end
  suite.tests.add(SmartestSelfTest.test_case("uses server", proc { |server:| events << :test; expect(server).to eq(:server) }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(%i[around_before server_setup test server_cleanup around_after])
end

test("around_suite hooks run in registration order") do
  events = []
  suite = Smartest::Suite.new

  suite.around_suite_hooks << proc do |suite_run|
    events << :outer_before
    suite_run.run
    events << :outer_after
  end
  suite.around_suite_hooks << proc do |suite_run|
    events << :inner_before
    suite_run.run
    events << :inner_after
  end
  suite.tests.add(SmartestSelfTest.test_case("passes", proc { events << :test }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(%i[outer_before inner_before test inner_after outer_after])
end

test("around_suite can register fixtures before running tests") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :user_name do
      "Alice"
    end
  end

  suite = Smartest::Suite.new
  suite.around_suite_hooks << proc do |suite_run|
    use_fixture fixture_class
    suite_run.run
  end
  suite.tests.add(SmartestSelfTest.test_case("uses runtime fixture", proc { |user_name:| expect(user_name).to eq("Alice") }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("around_suite can register suite-wide around_test hooks") do
  events = []
  suite = Smartest::Suite.new

  suite.around_suite_hooks << proc do |suite_run|
    around_test do |test_run|
      events << :around_test_before
      test_run.run
      events << :around_test_after
    end

    suite_run.run
  end
  suite.tests.add(SmartestSelfTest.test_case("passes", proc { events << :test }))

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(%i[around_test_before test around_test_after])
end

test("around_test wraps fixture setup, test body, and cleanup") do
  events = []

  fixture_class = Class.new(Smartest::Fixture) do
    fixture :resource do
      events << :fixture_setup
      cleanup { events << :fixture_cleanup }
      :resource
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    Smartest::TestCase.new(
      name: "uses resource",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          events << :around_test_before
          test_run.run
          events << :around_test_after
        end
      ],
      block: proc { |resource:| events << :test; expect(resource).to eq(:resource) }
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(%i[around_test_before fixture_setup test fixture_cleanup around_test_after])
end

test("around_test can register fixtures for one test run") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :local_value do
      "local"
    end
  end

  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "uses local fixture",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          use_fixture fixture_class
          test_run.run
        end
      ],
      block: proc { |local_value:| expect(local_value).to eq("local") }
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("around_test rejects fixture classes with suite fixtures") do
  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :server do
      :server
    end
  end

  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "rejects local suite fixture",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          use_fixture fixture_class
          test_run.run
        end
      ],
      block: proc { |server:| expect(server).to eq(:server) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::AroundTestFixtureScopeError")
  expect(output).to include("cannot be registered from around_test")
  expect(output).to include("suite-scoped fixtures: :server")
  expect(output).to include("Register fixture classes with suite_fixture from around_suite instead.")
end

test("around_test can register matchers for one test run") do
  matcher_module = Module.new do
    define_method(:equal_local) do |expected|
      Class.new do
        define_method(:initialize) { |value| @expected = value }
        define_method(:matches?) { |actual| actual == @expected }
        define_method(:failure_message) { "expected value to match" }
        define_method(:negated_failure_message) { "expected value not to match" }
      end.new(expected)
    end
  end

  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "uses local matcher",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          use_matcher matcher_module
          test_run.run
        end
      ],
      block: proc { expect("local").to equal_local("local") }
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("around_test can register private helpers for one test run") do
  helper_module = Module.new do
    def local_helper_value
      "local"
    end
  end

  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "uses local helper",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          use_helper helper_module
          test_run.run
        end
      ],
      block: proc do
        expect(local_helper_value).to eq("local")
        expect(private_methods).to include(:local_helper_value)
        expect(public_methods).not_to include(:local_helper_value)
      end
    )
  )
  suite.tests.add(
    SmartestSelfTest.test_case(
      "without helper",
      proc { expect(respond_to?(:local_helper_value, true)).to eq(false) }
    )
  )

  status, = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("around_test rejects helper registrations after test.run") do
  helper_module = Module.new do
    def late_helper_value
      "late"
    end
  end

  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "late helper",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          test_run.run
          use_helper helper_module
        end
      ],
      block: proc { expect(true).to eq(true) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::AroundTestRunError: use_helper must be called before test.run")
end

test("around_test must call test.run") do
  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "not reached",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [proc { |_test_run| nil }],
      block: proc { expect(true).to eq(false) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::AroundTestRunError: around_test hook did not call test.run")
end

test("around_test can skip before test.run") do
  events = []
  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "skipped by hook",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          events << :around_before
          skip "browser is not supported"
          test_run.run
          events << :around_after
        end
      ],
      block: proc { events << :test_body }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq([:around_before])
  expect(output).to include("- skipped by hook (skipped: browser is not supported)")
  expect(output).to include("1 test, 0 passed, 0 failed, 1 skipped")
end

test("around_test can mark a failing test as pending") do
  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "pending by hook",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          pending "driver bug"
          test_run.run
        end
      ],
      block: proc { expect("actual").to eq("expected") }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(output).to include("* pending by hook (pending: driver bug)")
  expect(output).to include("1 test, 0 passed, 0 failed, 1 pending")
end

test("pending around_test hooks must still call test.run") do
  suite = Smartest::Suite.new
  suite.tests.add(
    Smartest::TestCase.new(
      name: "pending hook missing run",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |_test_run|
          pending "driver bug"
        end
      ],
      block: proc { expect(true).to eq(false) }
    )
  )

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::AroundTestRunError: around_test hook did not call test.run")
  expect(output).to include("1 test, 0 passed, 1 failed")
end

test("use_fixture and use_matcher are only available inside hooks") do
  {
    "use_fixture Object" => "use_fixture",
    "use_matcher Module.new" => "use_matcher"
  }.each do |registration, method_name|
    Dir.mktmpdir do |dir|
      smartest_dir = File.join(dir, "smartest")
      FileUtils.mkdir_p(smartest_dir)
      File.write(File.join(smartest_dir, "sample_test.rb"), <<~RUBY)
        require "smartest/autorun"

        #{registration}

        test("not reached") do
          expect(true).to eq(true)
        end
      RUBY

      _stdout, stderr, status = Open3.capture3(
        { "RUBYLIB" => File.expand_path("../lib", __dir__) },
        "ruby",
        File.expand_path("../exe/smartest", __dir__),
        "smartest/sample_test.rb",
        chdir: dir
      )

      expect(status.success?).to eq(false)
      expect(stderr).to include("Error loading tests:")
      expect(stderr).to include("NoMethodError")
      expect(stderr).to include(method_name)
    end
  end
end

test("around_suite failures fail the run") do
  suite = Smartest::Suite.new
  suite.around_suite_hooks << proc { |_suite_run| raise "suite wrapper failed" }
  suite.tests.add(SmartestSelfTest.test_case("not reached", proc { expect(true).to eq(false) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Suite failures:")
  expect(output).to include("RuntimeError: suite wrapper failed")
  expect(output).to include("0 tests, 0 passed, 0 failed, 1 suite failure")
end

test("around_suite must call suite.run") do
  suite = Smartest::Suite.new
  suite.around_suite_hooks << proc { |_suite_run| nil }
  suite.tests.add(SmartestSelfTest.test_case("not reached", proc { expect(true).to eq(false) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::AroundSuiteRunError: around_suite hook did not call suite.run")
end

test("suite cleanup failures fail the run") do
  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :browser do
      cleanup { raise "browser close failed" }
      :browser
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SmartestSelfTest.test_case("uses browser", proc { |browser:| expect(browser).to eq(:browser) }))

  status, output = SmartestSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Suite cleanup failures:")
  expect(output).to include("cleanup failed: RuntimeError: browser close failed")
  expect(output).to include("1 test, 1 passed, 0 failed, 1 suite cleanup failed")
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

test("rejects invalid fixture scopes") do
  error = SmartestSelfTest.capture_error(Smartest::InvalidFixtureScopeError) do
    Class.new(Smartest::Fixture) do
      fixture(:bad, scope: :file) { nil }
    end
  end

  expect(error.message).to include("invalid fixture scope: :file")
  expect(error.message).to include("supported scopes: test, suite")
end

test("cli loads files and returns failure status") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"
    RUBY

    test_file = File.join(smartest_dir, "sample_test.rb")
    File.write(test_file, <<~RUBY)
      require "test_helper"

      test("cli failure") do
        expect("a").to eq("b")
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "smartest/sample_test.rb",
      chdir: dir
    )

    expect(status.success?).to eq(false)
    expect(stderr).to eq("")
    expect(stdout).to include("cli failure")
    expect(stdout).to include("expected \"a\" to eq \"b\"")
  end
end

test("cli loads matcher files registered in test helper") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    matchers_dir = File.join(smartest_dir, "matchers")
    FileUtils.mkdir_p(matchers_dir)
    File.write(File.join(smartest_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"

      Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each do |matcher_file|
        require matcher_file
      end

      around_suite do |suite|
        use_matcher HaveStatusMatcher
        suite.run
      end
    RUBY
    File.write(File.join(matchers_dir, "have_status_matcher.rb"), <<~RUBY)
      module HaveStatusMatcher
        class MatcherImpl < Smartest::Matcher
          def initialize(expected)
            @expected = expected
          end

          def matches?(actual)
            @actual = actual
            actual.status == @expected
          end

          def failure_message
            "expected \#{@actual.inspect} to have status \#{@expected.inspect}"
          end

          def negated_failure_message
            "expected \#{@actual.inspect} not to have status \#{@expected.inspect}"
          end

          def description
            "have status \#{@expected.inspect}"
          end
        end

        def have_status(expected)
          MatcherImpl.new(expected)
        end
      end
    RUBY

    File.write(File.join(smartest_dir, "sample_test.rb"), <<~RUBY)
      require "test_helper"

      Response = Struct.new(:status)

      test("custom matcher") do
        expect(Response.new(200)).to have_status(200)
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "smartest/sample_test.rb",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("custom matcher")
    expect(stdout).to include("1 test, 1 passed, 0 failed")
  end
end

test("cli runs tests matching a file line filter") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"
    RUBY

    test_file = File.join(smartest_dir, "sample_test.rb")
    File.write(test_file, <<~RUBY)
      require "test_helper"

      test("line one") do
        expect(1).to eq(1)
      end

      test("line two") do
        expect(2).to eq(2)
      end
    RUBY
    line_number = File.readlines(test_file).find_index { |line| line.include?("expect(2)") } + 1

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "smartest/sample_test.rb:#{line_number}",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("Running 1 test")
    expect(stdout).not_to include("line one")
    expect(stdout).to include("line two")
    expect(stdout).to include("1 test, 1 passed, 0 failed")
  end
end

test("cli runs tests intersecting a file line range filter") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"
    RUBY

    test_file = File.join(smartest_dir, "sample_test.rb")
    File.write(test_file, <<~RUBY)
      require "test_helper"

      test("range one") do
        expect(1).to eq(1)
      end

      test("range two") do
        expect(2).to eq(2)
      end

      test("range three") do
        expect(3).to eq(3)
      end
    RUBY
    lines = File.readlines(test_file)
    start_line = lines.find_index { |line| line.include?("expect(1)") } + 1
    end_line = lines.find_index { |line| line.include?("expect(2)") } + 1

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "smartest/sample_test.rb:#{start_line}-#{end_line}",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("Running 2 tests")
    expect(stdout).to include("range one")
    expect(stdout).to include("range two")
    expect(stdout).not_to include("range three")
    expect(stdout).to include("2 tests, 2 passed, 0 failed")
  end
end

test("cli default suite ignores minitest-style test directory") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"
    RUBY

    File.write(File.join(smartest_dir, "sample_test.rb"), <<~RUBY)
      require "test_helper"

      test("smartest default") do
        expect(1).to eq(1)
      end
    RUBY

    minitest_dir = File.join(dir, "test")
    FileUtils.mkdir_p(minitest_dir)
    File.write(File.join(minitest_dir, "test_helper.rb"), <<~RUBY)
      raise "loaded minitest helper"
    RUBY
    File.write(File.join(minitest_dir, "sample_test.rb"), <<~RUBY)
      raise "loaded minitest test"
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("smartest default")
    expect(stdout).to include("1 test, 1 passed, 0 failed")
  end
end

test("cli prints version") do
  stdout, stderr, status = Open3.capture3(
    { "RUBYLIB" => File.expand_path("../lib", __dir__) },
    "ruby",
    File.expand_path("../exe/smartest", __dir__),
    "--version"
  )

  expect(status.success?).to eq(true)
  expect(stderr).to eq("")
  expect(stdout).to eq("#{Smartest::VERSION}\n")
end

test("cli prints help") do
  stdout, stderr, status = Open3.capture3(
    { "RUBYLIB" => File.expand_path("../lib", __dir__) },
    "ruby",
    File.expand_path("../exe/smartest", __dir__),
    "--help"
  )

  expect(status.success?).to eq(true)
  expect(stderr).to eq("")
  expect(stdout).to include("Usage:")
  expect(stdout).to include("smartest [--profile N] [paths...]")
  expect(stdout).to include("smartest [--profile N] path/to/test_file.rb:line[-line]")
  expect(stdout).to include("smartest --init")
  expect(stdout).to include("Use --profile N")
  expect(stdout).to include("smartest/**/*_test.rb")
end

test("--profile prints the slowest tests with default count of 5") do
  output = StringIO.new
  reporter = Smartest::Reporter.new(output, profile_count: 5)

  results = [
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("alpha", proc {}), duration: 0.10),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("bravo", proc {}), duration: 0.50),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("charlie", proc {}), duration: 0.30),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("delta", proc {}), duration: 0.20),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("echo", proc {}), duration: 0.40),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("foxtrot", proc {}), duration: 0.05)
  ]

  reporter.finish(results)
  text = output.string

  expect(text).to include("Top 5 slowest tests")
  expect(text).to include("bravo")
  expect(text).to include("echo")
  expect(text).to include("charlie")
  expect(text).to include("delta")
  expect(text).to include("alpha")
  expect(text).not_to include("foxtrot\n    0")

  bravo_index = text.index("bravo")
  echo_index = text.index("echo")
  charlie_index = text.index("charlie")
  delta_index = text.index("delta")
  alpha_index = text.index("alpha")
  expect(bravo_index < echo_index).to eq(true)
  expect(echo_index < charlie_index).to eq(true)
  expect(charlie_index < delta_index).to eq(true)
  expect(delta_index < alpha_index).to eq(true)
end

test("--profile N shows top N slowest tests") do
  output = StringIO.new
  reporter = Smartest::Reporter.new(output, profile_count: 2)

  results = [
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("alpha", proc {}), duration: 0.10),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("bravo", proc {}), duration: 0.50),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("charlie", proc {}), duration: 0.30)
  ]

  reporter.finish(results)
  text = output.string

  expect(text).to include("Top 2 slowest tests")
  expect(text).to include("bravo")
  expect(text).to include("charlie")
  expect(text).not_to include("  alpha\n")
end

test("--profile does not error when fewer tests than the requested count") do
  output = StringIO.new
  reporter = Smartest::Reporter.new(output, profile_count: 5)

  results = [
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("solo", proc {}), duration: 0.01),
    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("duo", proc {}), duration: 0.02)
  ]

  reporter.finish(results)
  text = output.string

  expect(text).to include("Top 2 slowest tests")
  expect(text).to include("solo")
  expect(text).to include("duo")
end

test("--profile is not printed when profile_count is nil") do
  output = StringIO.new
  reporter = Smartest::Reporter.new(output)

  reporter.finish([
                    Smartest::TestResult.passed(test_case: SmartestSelfTest.test_case("alpha", proc {}), duration: 0.10)
                  ])

  expect(output.string).not_to include("slowest")
end

test("--profile is not printed when there are no results") do
  output = StringIO.new
  reporter = Smartest::Reporter.new(output, profile_count: 5)

  reporter.finish([])

  expect(output.string).not_to include("slowest")
end

test("CLIArguments defaults profile count and parses --profile N") do
  arguments = Smartest::CLIArguments.new([])

  expect(arguments.profile_count).to eq(5)
  expect(arguments.files).to eq(Dir["smartest/**/*_test.rb"])
  expect(Smartest::CLIArguments.new(["--profile", "3"]).profile_count).to eq(3)
end

test("CLIArguments leaves unsupported profile forms as paths") do
  equals_form = Smartest::CLIArguments.new(["--profile=7"])
  missing_count = Smartest::CLIArguments.new(["--profile"])
  path_after_profile = Smartest::CLIArguments.new(["--profile", "smartest/foo_test.rb"])

  expect(equals_form.profile_count).to eq(5)
  expect(equals_form.files).to eq(["--profile=7"])
  expect(missing_count.profile_count).to eq(5)
  expect(missing_count.files).to eq(["--profile"])
  expect(path_after_profile.profile_count).to eq(5)
  expect(path_after_profile.files).to eq(["--profile", "smartest/foo_test.rb"])
end

test("cli runs without --profile N and prints default slowest tests") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "sample_test.rb"), <<~RUBY)
      require "smartest/autorun"

      test("default first") do
        expect(1).to eq(1)
      end

      test("default second") do
        expect(1).to eq(1)
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("Top 2 slowest tests")
    expect(stdout).to include("2 tests, 2 passed, 0 failed")
  end
end

test("cli runs with --profile N and prints requested slowest tests") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    FileUtils.mkdir_p(smartest_dir)
    File.write(File.join(smartest_dir, "sample_test.rb"), <<~RUBY)
      require "smartest/autorun"

      test("first") do
        expect(1).to eq(1)
      end

      test("second") do
        expect(1).to eq(1)
      end
    RUBY

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "--profile",
      "1",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("Top 1 slowest test")
    expect(stdout).to include("2 tests, 2 passed, 0 failed")
  end
end

test("cli initializes a runnable test scaffold") do
  Dir.mktmpdir do |dir|
    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "--init",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("create  smartest")
    expect(stdout).to include("create  smartest/fixtures")
    expect(stdout).to include("create  smartest/matchers")
    expect(stdout).to include("create  smartest/test_helper.rb")
    expect(stdout).to include("create  smartest/matchers/predicate_matcher.rb")
    expect(stdout).to include("create  smartest/example_test.rb")
    helper_contents = File.read(File.join(dir, "smartest/test_helper.rb"))
    expect(helper_contents).to include('require "smartest/autorun"')
    expect(helper_contents).to include('Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each')
    expect(helper_contents).to include('Dir[File.join(__dir__, "matchers", "**", "*.rb")].sort.each')
    expect(helper_contents).to include("around_suite do |suite|")
    expect(helper_contents).to include("use_matcher PredicateMatcher")
    predicate_matcher_contents = File.read(File.join(dir, "smartest/matchers/predicate_matcher.rb"))
    expect(predicate_matcher_contents).to include("module PredicateMatcher")
    expect(predicate_matcher_contents).to include("class Matcher < Smartest::Matcher")
    expect(File.read(File.join(dir, "smartest/example_test.rb"))).to include('require "test_helper"')

    nested_fixtures_dir = File.join(dir, "smartest/fixtures/nested")
    FileUtils.mkdir_p(nested_fixtures_dir)
    File.write(File.join(nested_fixtures_dir, "auto_loaded_fixture.rb"), <<~RUBY)
      class AutoLoadedFixture < Smartest::Fixture
        fixture :auto_loaded_message do
          "loaded from smartest/fixtures"
        end
      end
    RUBY

    File.write(File.join(dir, "smartest/auto_loaded_fixture_test.rb"), <<~RUBY)
      require "test_helper"

      around_test do |test|
        use_fixture AutoLoadedFixture
        test.run
      end

      test("auto-loaded fixture") do |auto_loaded_message:|
        expect(auto_loaded_message).to eq("loaded from smartest/fixtures")
      end
    RUBY

    nested_matchers_dir = File.join(dir, "smartest/matchers/nested")
    FileUtils.mkdir_p(nested_matchers_dir)
    File.write(File.join(nested_matchers_dir, "auto_loaded_matcher.rb"), <<~RUBY)
      module AutoLoadedMatcher
        class Matcher < Smartest::Matcher
          def initialize(expected)
            @expected = expected
          end

          def matches?(actual)
            @actual = actual
            actual == @expected
          end

          def failure_message
            "expected \#{@actual.inspect} to auto-eq \#{@expected.inspect}"
          end

          def negated_failure_message
            "expected \#{@actual.inspect} not to auto-eq \#{@expected.inspect}"
          end

          def description
            "auto-eq \#{@expected.inspect}"
          end
        end

        def auto_eq(expected)
          Matcher.new(expected)
        end
      end
    RUBY

    File.write(File.join(dir, "smartest/auto_loaded_matcher_test.rb"), <<~RUBY)
      require "test_helper"

      around_test do |test|
        use_matcher AutoLoadedMatcher
        test.run
      end

      test("auto-loaded matcher") do
        expect("loaded from smartest/matchers").to auto_eq("loaded from smartest/matchers")
      end
    RUBY

    File.write(File.join(dir, "smartest/predicate_matcher_test.rb"), <<~RUBY)
      require "test_helper"

      test("generated predicate matcher") do
        expect("").to be_empty
        expect(2).to be_between(1, 3)
        expect(2).to be_odd.or be_even
      end
    RUBY

    run_stdout, run_stderr, run_status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      chdir: dir
    )

    expect(run_status.success?).to eq(true)
    expect(run_stderr).to eq("")
    expect(run_stdout).to include("example")
    expect(run_stdout).to include("auto-loaded fixture")
    expect(run_stdout).to include("auto-loaded matcher")
    expect(run_stdout).to include("generated predicate matcher")
    expect(run_stdout).to include("4 tests, 4 passed, 0 failed")
  end
end

test("cli init does not overwrite existing scaffold files") do
  Dir.mktmpdir do |dir|
    smartest_dir = File.join(dir, "smartest")
    fixture_dir = File.join(smartest_dir, "fixtures")
    matcher_dir = File.join(smartest_dir, "matchers")
    FileUtils.mkdir_p(fixture_dir)
    FileUtils.mkdir_p(matcher_dir)
    helper_path = File.join(smartest_dir, "test_helper.rb")
    example_path = File.join(smartest_dir, "example_test.rb")
    fixture_path = File.join(fixture_dir, "custom_fixture.rb")
    matcher_path = File.join(matcher_dir, "predicate_matcher.rb")
    File.write(helper_path, "# custom helper\n")
    File.write(example_path, "# custom test\n")
    File.write(fixture_path, "# custom fixture\n")
    File.write(matcher_path, "# custom matcher\n")

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "--init",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("exist   smartest")
    expect(stdout).to include("exist   smartest/fixtures")
    expect(stdout).to include("exist   smartest/matchers")
    expect(stdout).to include("exist   smartest/test_helper.rb")
    expect(stdout).to include("exist   smartest/matchers/predicate_matcher.rb")
    expect(stdout).to include("exist   smartest/example_test.rb")
    expect(File.read(helper_path)).to eq("# custom helper\n")
    expect(File.read(example_path)).to eq("# custom test\n")
    expect(File.read(fixture_path)).to eq("# custom fixture\n")
    expect(File.read(matcher_path)).to eq("# custom matcher\n")
  end
end
