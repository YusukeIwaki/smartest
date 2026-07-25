# frozen_string_literal: true

module Smartest
  class AroundSuiteHookChain
    attr_reader :teardown_errors

    def initialize(suite:, hooks:)
      @suite = suite
      @hooks = hooks
      @teardown_error_aggregator = TeardownErrorAggregator.new
      @teardown_errors = @teardown_error_aggregator.teardown_errors
    end

    def run(&suite_body)
      run_hook(0, &suite_body)
    end

    private

    def run_hook(index, &suite_body)
      return yield if index >= @hooks.length

      hook = @hooks[index]
      suite_run = SuiteRun.new { run_hook(index + 1, &suite_body) }
      context = AroundSuiteContext.new(@suite)

      begin
        context.call(hook, suite_run)
      ensure
        context.close
        @teardown_error_aggregator.collect(context)
      end

      raise AroundSuiteRunError, "around_suite hook did not call suite.run" unless suite_run.ran?

      suite_run.result
    end
  end

  class AroundTestHookChain
    attr_reader :teardown_errors

    def initialize(hooks:, test_run:, run_state:)
      @hooks = hooks
      @test_run = test_run
      @run_state = run_state
      @teardown_error_aggregator = TeardownErrorAggregator.new
      @teardown_errors = @teardown_error_aggregator.teardown_errors
    end

    def run
      run_hook(0)
    end

    private

    def run_hook(index)
      return @test_run.run if index >= @hooks.length

      hook = @hooks[index]
      next_run = TestRun.new(
        fixture_classes: [],
        matcher_modules: []
      ) do |**_keywords|
        run_hook(index + 1)
      end
      context = AroundTestContext.new(@test_run, run_state: @run_state)

      begin
        context.call(hook, next_run)
      ensure
        context.close
        @teardown_error_aggregator.collect(context)
      end

      raise AroundTestRunError, "around_test hook did not call test.run" unless next_run.ran?

      next_run.result
    end
  end
end
