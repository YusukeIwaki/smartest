# frozen_string_literal: true

module Smartest
  class AroundSuiteContext
    def initialize(suite)
      @suite = suite
    end

    def call(hook, suite_run)
      @suite.around_suite_hook do
        instance_exec(suite_run, &hook)
      end
    end

    private

    def use_fixture(klass)
      @suite.fixture_classes.add(klass)
    end

    def use_matcher(matcher_module)
      @suite.matcher_modules.add(matcher_module)
    end

    def around_test(&block)
      raise ArgumentError, "around_test block is required" unless block

      @suite.add_around_test_hook(caller_locations(1, 1).first, block)
    end
  end

  class AroundTestContext
    def initialize(test_run, run_state:)
      @test_run = test_run
      @run_state = run_state
    end

    def call(hook, run_target = @test_run)
      instance_exec(run_target, &hook)
    end

    private

    def use_fixture(klass)
      @test_run.add_fixture_class(klass)
    end

    def use_matcher(matcher_module)
      @test_run.add_matcher_module(matcher_module)
    end

    def use_helper(helper_module)
      @test_run.add_helper_module(helper_module)
    end

    def skip(reason = nil)
      raise Skipped, reason
    end

    def pending(reason = nil)
      @run_state.pending(reason)
    end
  end
end
