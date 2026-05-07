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
