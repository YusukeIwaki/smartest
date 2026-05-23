# frozen_string_literal: true

module Smartest
  # Top-level Smartest test definition DSL.
  #
  # Smartest installs this module into Kernel when `smartest/autorun` is
  # required. The module intentionally overrides Ruby's built-in `Kernel#test`
  # file-test helper while Smartest tests are being loaded.
  module DSL
    # Define a named Smartest test.
    #
    # Test fixtures are requested with required keyword block parameters:
    #
    #   test("opens the home page") do |page:|
    #     page.goto("/")
    #   end
    #
    # @param name [String, Symbol] human-readable test name
    # @param metadata [Hash] optional metadata kept with the test case
    # @yield test body; required keyword parameters request fixtures
    # @return [void]
    def test(name, **metadata, &block)
      location = caller_locations(1, 1).first

      Smartest.suite.tests.add(
        TestCase.new(
          name: name,
          metadata: metadata,
          block: block,
          location: location,
          around_test_hooks: Smartest.suite.around_test_hooks_for(location)
        )
      )
    end

    # Register a hook that wraps the whole suite.
    #
    # The block receives a `Smartest::SuiteRun` object and must call
    # `suite.run` exactly once.
    #
    # @yieldparam suite [Smartest::SuiteRun] suite run target
    # @return [void]
    def around_suite(&block)
      raise ArgumentError, "around_suite block is required" unless block

      Smartest.suite.around_suite_hooks << block
    end

    # Register a hook that wraps tests declared after this hook in the same file.
    #
    # The block receives a `Smartest::TestRun` object and must call `test.run`
    # exactly once. The hook wraps fixture setup, the test body, and fixture
    # teardown.
    #
    # @yieldparam test [Smartest::TestRun] test run target
    # @return [void]
    def around_test(&block)
      raise ArgumentError, "around_test block is required" unless block

      Smartest.suite.add_around_test_hook(caller_locations(1, 1).first, block)
    end

    private :test, :around_suite, :around_test
  end
end

module Kernel
  # @!method test(name, **metadata, &block)
  #   Define a named Smartest test.
  #
  #   Fixture values are requested with required keyword block parameters:
  #
  #     test("opens the home page") do |page:|
  #       page.goto("/")
  #     end
  #
  #   Smartest installs this method by prepending `Smartest::DSL` into Kernel,
  #   so it overrides Ruby's built-in `Kernel#test` file-test helper while
  #   Smartest tests are being loaded.
  #
  #   @param name [String, Symbol] human-readable test name
  #   @param metadata [Hash] optional metadata kept with the test case
  #   @yield test body; required keyword parameters request fixtures
  #   @return [void]
  #
  # @!method around_suite(&block)
  #   Register a hook that wraps the whole suite.
  #
  #   The block receives a `Smartest::SuiteRun` object and must call
  #   `suite.run` exactly once.
  #
  #   @yieldparam suite [Smartest::SuiteRun] suite run target
  #   @return [void]
  #
  # @!method around_test(&block)
  #   Register a hook that wraps tests declared after this hook in the same file.
  #
  #   The block receives a `Smartest::TestRun` object and must call `test.run`
  #   exactly once. The hook wraps fixture setup, the test body, and fixture
  #   teardown.
  #
  #   @yieldparam test [Smartest::TestRun] test run target
  #   @return [void]
end
