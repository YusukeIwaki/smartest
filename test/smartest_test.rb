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
    test_dir = File.join(dir, "test")
    FileUtils.mkdir_p(test_dir)
    File.write(File.join(test_dir, "test_helper.rb"), <<~RUBY)
      require "smartest/autorun"
    RUBY

    test_file = File.join(test_dir, "sample_test.rb")
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
      "test/sample_test.rb",
      chdir: dir
    )

    expect(status.success?).to eq(false)
    expect(stderr).to eq("")
    expect(stdout).to include("cli failure")
    expect(stdout).to include("expected \"a\" to eq \"b\"")
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
  expect(stdout).to include("smartest [paths...]")
  expect(stdout).to include("smartest --init")
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
    expect(stdout).to include("create  test")
    expect(stdout).to include("create  test/fixtures")
    expect(stdout).to include("create  test/test_helper.rb")
    expect(stdout).to include("create  test/example_test.rb")
    helper_contents = File.read(File.join(dir, "test/test_helper.rb"))
    expect(helper_contents).to include('require "smartest/autorun"')
    expect(helper_contents).to include('Dir[File.join(__dir__, "fixtures", "**", "*.rb")].sort.each')
    expect(File.read(File.join(dir, "test/example_test.rb"))).to include('require "test_helper"')

    nested_fixtures_dir = File.join(dir, "test/fixtures/nested")
    FileUtils.mkdir_p(nested_fixtures_dir)
    File.write(File.join(nested_fixtures_dir, "auto_loaded_fixture.rb"), <<~RUBY)
      class AutoLoadedFixture < Smartest::Fixture
        fixture :auto_loaded_message do
          "loaded from test/fixtures"
        end
      end
    RUBY

    File.write(File.join(dir, "test/auto_loaded_fixture_test.rb"), <<~RUBY)
      require "test_helper"

      use_fixture AutoLoadedFixture

      test("auto-loaded fixture") do |auto_loaded_message:|
        expect(auto_loaded_message).to eq("loaded from test/fixtures")
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
    expect(run_stdout).to include("2 tests, 2 passed, 0 failed")
  end
end

test("cli init does not overwrite existing scaffold files") do
  Dir.mktmpdir do |dir|
    test_dir = File.join(dir, "test")
    fixture_dir = File.join(test_dir, "fixtures")
    FileUtils.mkdir_p(fixture_dir)
    helper_path = File.join(test_dir, "test_helper.rb")
    example_path = File.join(test_dir, "example_test.rb")
    fixture_path = File.join(fixture_dir, "custom_fixture.rb")
    File.write(helper_path, "# custom helper\n")
    File.write(example_path, "# custom test\n")
    File.write(fixture_path, "# custom fixture\n")

    stdout, stderr, status = Open3.capture3(
      { "RUBYLIB" => File.expand_path("../lib", __dir__) },
      "ruby",
      File.expand_path("../exe/smartest", __dir__),
      "--init",
      chdir: dir
    )

    expect(status.success?).to eq(true)
    expect(stderr).to eq("")
    expect(stdout).to include("exist   test")
    expect(stdout).to include("exist   test/fixtures")
    expect(stdout).to include("exist   test/test_helper.rb")
    expect(stdout).to include("exist   test/example_test.rb")
    expect(File.read(helper_path)).to eq("# custom helper\n")
    expect(File.read(example_path)).to eq("# custom test\n")
    expect(File.read(fixture_path)).to eq("# custom fixture\n")
  end
end
