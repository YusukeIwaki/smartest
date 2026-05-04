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

  stub.apply!

  begin
    expect(existing.name).to eq("stubbed")
    expect(SimpleStubSelfTestSubject.new("Bob").name).to eq("stubbed")
  ensure
    stub.reset
  end

  expect(existing.name).to eq("original Alice")
  expect(SimpleStubSelfTestSubject.new("Bob").name).to eq("original Bob")
end

test("simple stub can be reset from a fresh stub object") do
  Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :greeting) { |prefix| "#{prefix}, stubbed" }.apply!

  begin
    expect(SimpleStubSelfTestSubject.new("Alice").greeting("Hi")).to eq("Hi, stubbed")
  ensure
    Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :greeting).reset!
  end

  expect(SimpleStubSelfTestSubject.new("Alice").greeting("Hi")).to eq("Hi, Alice")
end

test("simple_stub_any_instance_of applies and resets from fixture cleanup") do
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

test("simple_stub applies and resets singleton methods from fixture cleanup") do
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

test("simple_stub_const applies and resets existing constants from fixture cleanup") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :stubbed_provider do
      simple_stub_const("SimpleStubSelfTestConfig::PROVIDER", :stubbed_provider)
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses constant stub fixture",
      proc do |stubbed_provider:|
        expect(stubbed_provider).to eq(:stubbed_provider)
        expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:stubbed_provider)
      end
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "sees restored constant",
      proc { expect(SimpleStubSelfTestConfig::PROVIDER).to eq(:original_provider) }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("simple_stub_const removes newly defined constants from fixture cleanup") do
  fixture_class = Class.new(Smartest::Fixture) do
    fixture :stubbed_missing_provider do
      simple_stub_const("SimpleStubSelfTestConfig::MISSING_PROVIDER", :stubbed_missing_provider)
    end
  end

  suite = Smartest::Suite.new
  suite.fixture_classes.add(fixture_class)
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "uses new constant stub fixture",
      proc do |stubbed_missing_provider:|
        expect(stubbed_missing_provider).to eq(:stubbed_missing_provider)
        expect(SimpleStubSelfTestConfig::MISSING_PROVIDER).to eq(:stubbed_missing_provider)
      end
    )
  )
  suite.tests.add(
    SimpleStubSelfTest.test_case(
      "sees removed constant",
      proc { expect(SimpleStubSelfTestConfig.const_defined?(:MISSING_PROVIDER, false)).to eq(false) }
    )
  )

  status, = SimpleStubSelfTest.run_suite(suite)

  expect(status).to eq(0)
end

test("simple stub preserves receiver self and method blocks") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :yielding_greeting) do |prefix, &block|
    block.call("#{prefix}, stubbed #{@name}")
  end

  stub.apply!

  begin
    result = subject.yielding_greeting("Hi") { |message| message.upcase }
    expect(result).to eq("HI, STUBBED ALICE")
  ensure
    stub.reset
  end

  expect(subject.yielding_greeting("Hi") { |message| message }).to eq("Hi, Alice")
end

test("simple stub is scoped to the current fiber") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed #{@name}" }

  stub.apply!

  begin
    expect(subject.name).to eq("stubbed Alice")
    Fiber.new do
      expect(subject.name).to eq("original Alice")
    end.resume
  ensure
    stub.reset
  end

  expect(subject.name).to eq("original Alice")
end

test("simple stub can differ per thread") do
  subject = SimpleStubSelfTestSubject.new("Alice")
  queue = Queue.new
  main_stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "main #{@name}" }

  main_stub.apply!

  thread = Thread.new do
    thread_stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "thread #{@name}" }
    thread_stub.apply!

    begin
      queue << subject.name
    rescue Exception => error
      queue << error
    ensure
      thread_stub.reset
    end
  end

  begin
    expect(subject.name).to eq("main Alice")

    thread_result = queue.pop
    raise thread_result if thread_result.is_a?(Exception)

    expect(thread_result).to eq("thread Alice")
    thread.join
    expect(subject.name).to eq("main Alice")
  ensure
    main_stub.reset
    thread.kill if thread.alive?
  end

  expect(subject.name).to eq("original Alice")
end

test("simple stub supports safe and strict apply reset APIs") do
  stub = Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "stubbed" }

  stub.apply
  stub.apply

  begin
    error = SimpleStubSelfTest.capture_error(Smartest::SimpleStub::AlreadyAppliedError) do
      Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name) { "other" }.apply!
    end

    expect(error.message).to eq("stub for SimpleStubSelfTestSubject#name is already applied")
  ensure
    stub.reset
  end

  stub.reset

  error = SimpleStubSelfTest.capture_error(Smartest::SimpleStub::NotAppliedError) do
    stub.reset!
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
    Smartest::SimpleStub.new(SimpleStubSelfTestSubject, :name).apply!
  end

  expect(error.message).to eq("block must be given for applying stub")
end
