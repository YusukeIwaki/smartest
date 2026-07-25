# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "smartest/autorun"
require "stringio"

module SimpleStubSelfTest
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

class SimpleStubSelfTestSubject
  def initialize(name)
    @name = name
  end

  def name
    "original #{@name}"
  end

  def greeting(prefix)
    "#{prefix}, #{@name}"
  end

  def yielding_greeting(prefix)
    yield "#{prefix}, #{@name}"
  end
end

class SimpleStubSelfTestClock
  def self.now
    :original_now
  end
end

module SimpleStubSelfTestConfig
  PROVIDER = :original_provider
end

test("simple stub stubs instance methods until reset") do
  existing = SimpleStubSelfTestSubject.new("Alice")
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed" }

  stub.apply

  begin
    expect(existing.name).to eq("stubbed")
    expect(SimpleStubSelfTestSubject.new("Bob").name).to eq("stubbed")
  ensure
    stub.reset
  end

  expect(existing.name).to eq("original Alice")
  expect(SimpleStubSelfTestSubject.new("Bob").name).to eq("original Bob")
end

test("simple stub reset requires the applied stub object") do
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :greeting) do |prefix|
    "#{prefix}, stubbed"
  end

  stub.apply

  begin
    expect(SimpleStubSelfTestSubject.new("Alice").greeting("Hi")).to eq("Hi, stubbed")

    error = SimpleStubSelfTest.capture_error(Smartest::SimpleStub::NotAppliedError) do
      Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :greeting).reset
    end

    expect(error.message).to eq("stub for SimpleStubSelfTestSubject#greeting is not applied")
  ensure
    stub.reset
  end

  expect(SimpleStubSelfTestSubject.new("Alice").greeting("Hi")).to eq("Hi, Alice")
end

test("simple_stub_any_instance_of applies and resets from fixture teardown") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :stubbed_name do
      simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "fixture #{@name}" }
      :stubbed_name
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses instance stub fixture",
      proc do |stubbed_name:|
        expect(stubbed_name).to eq(:stubbed_name)
        expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("fixture Alice")
      end
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "sees reset instance method",
      proc { expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("original Alice") }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("test-scoped method stubs restore suite-scoped method stubs") do
  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :suite_name_stub do
      simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "suite #{@name}" }
    end

    fixture :test_name_stub do |suite_name_stub:|
      expect(suite_name_stub).to be_a(Smartest::SimpleStub)
      simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "test #{@name}" }
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses test scoped override",
      proc { |test_name_stub:| expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("test Alice") }
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "sees suite scoped stub after override teardown",
      proc { |suite_name_stub:| expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("suite Alice") }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("original Alice")
end

test("simple_stub applies and resets singleton methods from fixture teardown") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :stubbed_time do
      simple_stub(SimpleStubSelfTestClock, :now) { :stubbed_now }
      :stubbed_time
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses singleton stub fixture",
      proc do |stubbed_time:|
        expect(stubbed_time).to eq(:stubbed_time)
        expect(SimpleStubSelfTestClock.now).to eq(:stubbed_now)
      end
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "sees reset singleton method",
      proc { expect(SimpleStubSelfTestClock.now).to eq(:original_now) }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("around_test method stub helpers apply only for each hook scope") do
  events = []
  suite = Smartest::Suite.new

  suite.around_test_hooks << proc do |test_run|
    events << [:before_hook, SimpleStubSelfTestSubject.new("Alice").name, SimpleStubSelfTestClock.now]

    instance_stub = simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "hook #{@name}" }
    singleton_stub = simple_stub(SimpleStubSelfTestClock, :now) { :hook_now }

    events << [
      :before_test,
      SimpleStubSelfTestSubject.new("Alice").name,
      SimpleStubSelfTestClock.now,
      instance_stub.class,
      singleton_stub.class
    ]
    test_run.run
    events << [:after_test, SimpleStubSelfTestSubject.new("Alice").name, SimpleStubSelfTestClock.now]
  end
  2.times do |index|
    suite.tests.add(
      SimpleStubSelfTest.test_case(
        "uses around_test method stubs #{index}",
        proc do
          events << [:test, SimpleStubSelfTestSubject.new("Alice").name, SimpleStubSelfTestClock.now]
        end
      )
    )
  end

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(
    [
      [:before_hook, "original Alice", :original_now],
      [:before_test, "hook Alice", :hook_now, Smartest::SimpleStub, Smartest::SimpleStub],
      [:test, "hook Alice", :hook_now],
      [:after_test, "hook Alice", :hook_now],
      [:before_hook, "original Alice", :original_now],
      [:before_test, "hook Alice", :hook_now, Smartest::SimpleStub, Smartest::SimpleStub],
      [:test, "hook Alice", :hook_now],
      [:after_test, "hook Alice", :hook_now]
    ]
  )
  expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("original Alice")
  expect(SimpleStubSelfTestClock.now).to eq(:original_now)
end

test("around_suite method stub helpers apply for the whole hook scope") do
  events = []
  suite = Smartest::Suite.new

  suite.around_suite_hooks << proc do |suite_run|
    instance_stub = simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "suite #{@name}" }
    singleton_stub = simple_stub(SimpleStubSelfTestClock, :now) { :suite_now }

    events << [
      :before_suite,
      SimpleStubSelfTestSubject.new("Alice").name,
      SimpleStubSelfTestClock.now,
      instance_stub.class,
      singleton_stub.class
    ]
    suite_run.run
    events << [:after_suite, SimpleStubSelfTestSubject.new("Alice").name, SimpleStubSelfTestClock.now]
  end
  2.times do |index|
    suite.tests.add(
      SimpleStubSelfTest.test_case(
        "uses around_suite method stubs #{index}",
        proc do
          events << [:test, SimpleStubSelfTestSubject.new("Alice").name, SimpleStubSelfTestClock.now]
        end
      )
    )
  end

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(
    [
      [:before_suite, "suite Alice", :suite_now, Smartest::SimpleStub, Smartest::SimpleStub],
      [:test, "suite Alice", :suite_now],
      [:test, "suite Alice", :suite_now],
      [:after_suite, "suite Alice", :suite_now]
    ]
  )
  expect(SimpleStubSelfTestSubject.new("Alice").name).to eq("original Alice")
  expect(SimpleStubSelfTestClock.now).to eq(:original_now)
end

test("nested around hooks restore the previous hook stub as each hook exits") do
  events = []
  subject = SimpleStubSelfTestSubject.new("Alice")
  suite = Smartest::Suite.new

  suite.around_suite_hooks << proc do |suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "outer suite #{@name}" }
    events << [:outer_suite_before, subject.name]
    suite_run.run
    events << [:outer_suite_after, subject.name]
  end
  suite.around_suite_hooks << proc do |suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "inner suite #{@name}" }
    events << [:inner_suite_before, subject.name]
    suite_run.run
    events << [:inner_suite_after, subject.name]
  end
  suite.tests.add(
    Smartest::TestCase.new(
      name: "uses nested hook stubs",
      metadata: {},
      location: caller_locations(1, 1).first,
      around_test_hooks: [
        proc do |test_run|
          simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "outer test #{@name}" }
          events << [:outer_test_before, subject.name]
          test_run.run
          events << [:outer_test_after, subject.name]
        end,
        proc do |test_run|
          simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "inner test #{@name}" }
          events << [:inner_test_before, subject.name]
          test_run.run
          events << [:inner_test_after, subject.name]
        end
      ],
      block: proc { events << [:test, subject.name] }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(
    [
      [:outer_suite_before, "outer suite Alice"],
      [:inner_suite_before, "inner suite Alice"],
      [:outer_test_before, "outer test Alice"],
      [:inner_test_before, "inner test Alice"],
      [:test, "inner test Alice"],
      [:inner_test_after, "inner test Alice"],
      [:outer_test_after, "outer test Alice"],
      [:inner_suite_after, "inner suite Alice"],
      [:outer_suite_after, "outer suite Alice"]
    ]
  )
  expect(subject.name).to eq("original Alice")
end

test("hook, test fixture, and suite fixture stubs restore the previous active stub") do
  events = []
  subject = SimpleStubSelfTestSubject.new("Alice")

  fixture_class = Class.new(Smartest::Fixture) do
    suite_fixture :suite_name_stub do
      simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "suite fixture #{@name}" }
    end

    fixture :test_name_stub do |suite_name_stub:|
      events << [:test_fixture_setup, suite_name_stub.class]
      simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "test fixture #{@name}" }
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.around_suite_hooks << proc do |suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "suite hook #{@name}" }
    events << [:suite_hook_before, subject.name]
    suite_run.run
    events << [:suite_hook_after, subject.name]
  end
  suite.around_test_hooks << proc do |test_run|
    events << [:test_hook_before_apply, subject.name]
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "test hook #{@name}" }
    events << [:test_hook_before_run, subject.name]
    test_run.run
    events << [:test_hook_after_run, subject.name]
  end
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "activates suite fixture stub",
      proc do |suite_name_stub:|
        events << [:suite_fixture_test, suite_name_stub.class, subject.name]
      end
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "temporarily overrides every outer stub",
      proc do |test_name_stub:|
        events << [:test_fixture_test, test_name_stub.class, subject.name]
      end
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(events).to eq(
    [
      [:suite_hook_before, "suite hook Alice"],
      [:test_hook_before_apply, "suite hook Alice"],
      [:test_hook_before_run, "test hook Alice"],
      [:suite_fixture_test, Smartest::SimpleStub, "suite fixture Alice"],
      [:test_hook_after_run, "suite fixture Alice"],
      [:test_hook_before_apply, "suite fixture Alice"],
      [:test_hook_before_run, "test hook Alice"],
      [:test_fixture_setup, Smartest::SimpleStub],
      [:test_fixture_test, Smartest::SimpleStub, "test fixture Alice"],
      [:test_hook_after_run, "test hook Alice"],
      [:suite_hook_after, "suite hook Alice"]
    ]
  )
  expect(subject.name).to eq("original Alice")
end

test("hook method stubs reset when tests or suite hooks fail") do
  subject = SimpleStubSelfTestSubject.new("Alice")

  test_failure_suite = Smartest::Suite.new
  test_failure_suite.around_test_hooks << proc do |test_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "failing test #{@name}" }
    test_run.run
  end
  test_failure_suite.tests.add(
    SimpleStubSelfTest.test_case(
      "fails while stubbed",
      proc do
        expect(subject.name).to eq("failing test Alice")
        raise "test failed"
      end
    )
  )

  test_status, test_output = SimpleStubSelfTest.run_suite(test_failure_suite)

  expect(test_status).to eq(1)
  expect(test_output).to include("RuntimeError: test failed")
  expect(subject.name).to eq("original Alice")

  failing_test_suite = Smartest::Suite.new
  failing_test_suite.around_suite_hooks << proc do |suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "failing suite test #{@name}" }
    suite_run.run
  end
  failing_test_suite.tests.add(
    SimpleStubSelfTest.test_case(
      "fails inside suite stub",
      proc do
        expect(subject.name).to eq("failing suite test Alice")
        raise "suite test failed"
      end
    )
  )

  failing_test_status, failing_test_output = SimpleStubSelfTest.run_suite(failing_test_suite)

  expect(failing_test_status).to eq(1)
  expect(failing_test_output).to include("RuntimeError: suite test failed")
  expect(subject.name).to eq("original Alice")

  suite_failure_suite = Smartest::Suite.new
  suite_failure_suite.around_suite_hooks << proc do |suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "failing suite #{@name}" }
    suite_run.run
    raise "suite hook failed"
  end
  suite_failure_suite.tests.add(
    SimpleStubSelfTest.test_case(
      "passes before suite hook failure",
      proc { expect(subject.name).to eq("failing suite Alice") }
    )
  )

  suite_status, suite_output = SimpleStubSelfTest.run_suite(suite_failure_suite)

  expect(suite_status).to eq(1)
  expect(suite_output).to include("RuntimeError: suite hook failed")
  expect(subject.name).to eq("original Alice")
end

test("hook method stubs reset when hooks do not call their run target") do
  subject = SimpleStubSelfTestSubject.new("Alice")

  missing_test_run_suite = Smartest::Suite.new
  missing_test_run_suite.around_test_hooks << proc do |_test_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "missing test run #{@name}" }
  end
  missing_test_run_suite.tests.add(
    SimpleStubSelfTest.test_case("not reached", proc { raise "test body should not run" })
  )

  test_status, test_output = SimpleStubSelfTest.run_suite(missing_test_run_suite)

  expect(test_status).to eq(1)
  expect(test_output).to include("around_test hook did not call test.run")
  expect(subject.name).to eq("original Alice")

  missing_suite_run_suite = Smartest::Suite.new
  missing_suite_run_suite.around_suite_hooks << proc do |_suite_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "missing suite run #{@name}" }
  end
  missing_suite_run_suite.tests.add(
    SimpleStubSelfTest.test_case("not reached", proc { raise "test body should not run" })
  )

  suite_status, suite_output = SimpleStubSelfTest.run_suite(missing_suite_run_suite)

  expect(suite_status).to eq(1)
  expect(suite_output).to include("around_suite hook did not call suite.run")
  expect(subject.name).to eq("original Alice")
end

test("around_test method stubs reset when the hook skips before test.run") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  suite = Smartest::Suite.new

  suite.around_test_hooks << proc do |_test_run|
    simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "skipped #{@name}" }
    skip "unsupported"
  end
  suite.tests.add(
    SimpleStubSelfTest.test_case("skipped while stubbed", proc { raise "test body should not run" })
  )

  status, output = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(output).to include("skipped: unsupported")
  expect(subject.name).to eq("original Alice")
end

test("hook method stub teardown resets remaining stubs when one reset fails") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  suite = Smartest::Suite.new

  suite.around_suite_hooks << proc do |suite_run|
    manually_reset_stub = simple_stub_any_instance_of(SimpleStubSelfTestSubject, :name) { "stubbed #{@name}" }
    simple_stub(SimpleStubSelfTestClock, :now) { :stubbed_now }
    manually_reset_stub.reset
    suite_run.run
  end
  suite.tests.add(
    SimpleStubSelfTest.test_case("passes before teardown failure", proc { expect(true).to eq(true) })
  )

  status, output = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("Smartest::SimpleStub::NotAppliedError")
  expect(subject.name).to eq("original Alice")
  expect(SimpleStubSelfTestClock.now).to eq(:original_now)
end

test("with_stub_const applies and resets existing constants in test body blocks") do
  result = with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :stubbed_provider) do
    expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:stubbed_provider)
    :block_result
  end

  expect(result).to eq(:block_result)
  expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider)
end

test("with_stub_const removes newly defined constants after test body blocks") do
  with_stub_const("SimpleStubSelfTestConfig::MISSING_PROVIDER", :stubbed_missing_provider) do
    expect(SimpleStubSelfTestConfig::MISSING_PROVIDER).to eq(:stubbed_missing_provider)
  end

  expect(SimpleStubSelfTestConfig.const_defined?(:MISSING_PROVIDER, false)).to eq(false)
end

test("with_stub_const restores constants when the block raises") do
  error = SimpleStubSelfTest.capture_error(RuntimeError) do
    with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :stubbed_provider) do
      expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:stubbed_provider)
      raise "stubbed block failed"
    end
  end

  expect(error.message).to eq("stubbed block failed")
  expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider)
end

test("with_stub_const requires a block") do
  error = SimpleStubSelfTest.capture_error(ArgumentError) do
    with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :stubbed_provider)
  end

  expect(error.message).to eq("with_stub_const block is required")
end

test("with_stub_const wraps around_test hooks") do
  suite = Smartest::Suite.new
  suite.around_test_hooks << proc do |test_run|
    with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :around_test_provider) do
      test_run.run
    end
  end
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses around_test constant stub",
      proc { expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:around_test_provider) }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider)
end

test("with_stub_const wraps around_suite hooks") do
  suite = Smartest::Suite.new
  suite.around_suite_hooks << proc do |suite_run|
    with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :around_suite_provider) do
      suite_run.run
    end
  end
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses around_suite constant stub",
      proc { expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:around_suite_provider) }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
  expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider)
end

test("with_stub_const is not available inside fixture blocks") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :bad_constant_stub do
      with_stub_const("SimpleStubSelfTestConfig::PROVIDER", :fixture_provider) { :fixture_provider }
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(SimpleStubSelfTest.test_case("uses bad fixture", proc { |bad_constant_stub:| bad_constant_stub }))

  status, output = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(1)
  expect(output).to include("NoMethodError")
  expect(output).to include("with_stub_const")
  expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider)
end

test("simple stub preserves receiver self and method blocks") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :yielding_greeting) do |prefix, &block|
    block.call("#{prefix}, stubbed #{@name}")
  end

  stub.apply

  begin
    result = subject.yielding_greeting("Hi") { |message| message.upcase }
    expect(result).to eq("HI, STUBBED ALICE")
  ensure
    stub.reset
  end

  expect(subject.yielding_greeting("Hi") { |message| message }).to eq("Hi, Alice")
end

test("simple stub is shared with fibers") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed #{@name}" }

  stub.apply

  begin
    expect(subject.name).to eq("stubbed Alice")
    Fiber.new do
      expect(subject.name).to eq("stubbed Alice")
    end.resume
  ensure
    stub.reset
  end

  expect(subject.name).to eq("original Alice")
end

test("simple stub is shared with threads") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  queue = Queue.new
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed #{@name}" }

  stub.apply

  thread = Thread.new do
    queue << subject.name
  rescue Exception => error
    queue << error
  end

  begin
    expect(subject.name).to eq("stubbed Alice")

    thread_result = queue.pop
    raise thread_result if thread_result.is_a?(Exception)

    expect(thread_result).to eq("stubbed Alice")
    thread.join
  ensure
    stub.reset
    thread.kill if thread.alive?
  end

  expect(subject.name).to eq("original Alice")
end

test("simple stub restores previous implementation when nested stubs reset") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  outer_stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "outer #{@name}" }
  inner_stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "inner #{@name}" }

  outer_stub.apply
  inner_stub.apply

  begin
    expect(subject.name).to eq("inner Alice")
    inner_stub.reset
    expect(subject.name).to eq("outer Alice")
  ensure
    outer_stub.reset
  end

  expect(subject.name).to eq("original Alice")
end

test("simple stub apply and reset are strict") do
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed" }

  stub.apply

  begin
    error = SimpleStubSelfTest.capture_error(Smartest::SimpleStub::AlreadyAppliedError) do
      stub.apply
    end

    expect(error.message).to eq("stub for SimpleStubSelfTestSubject#name is already applied")
  ensure
    stub.reset
  end

  error = SimpleStubSelfTest.capture_error(Smartest::SimpleStub::NotAppliedError) do
    stub.reset
  end

  expect(error.message).to eq("stub for SimpleStubSelfTestSubject#name is not applied")
end

test("simple stub validates constructor arguments and apply block") do
  error = SimpleStubSelfTest.capture_error(ArgumentError) do
    Smartest::SimpleStub.new(Object.new, :name)
  end

  expect(error.message).to eq("klass must be a Class. Object specified.")

  error = SimpleStubSelfTest.capture_error(ArgumentError) do
    Smartest::SimpleStub.new(SimpleStubSelfTestSubject, "name")
  end

  expect(error.message).to eq("method name must be a Symbol.")

  error = SimpleStubSelfTest.capture_error(ArgumentError) do
    Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name).apply
  end

  expect(error.message).to eq("block must be given for applying stub")
end
