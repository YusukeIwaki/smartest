# frozen_string_literal: true

module Smartest
  class Runner
    def initialize(suite: Smartest.suite, reporter: Reporter.new, tests: nil)
      @suite = suite
      @reporter = reporter
      @tests = tests || suite.tests
    end

    def run
      results = []
      suite_errors = []
      @suite_fixture_set = nil
      hook_chain = AroundSuiteHookChain.new(
        suite: @suite,
        hooks: @suite.around_suite_hooks.dup
      )

      @reporter.start(@tests.count)

      begin
        hook_chain.run { run_tests(results) }
      rescue Exception => error
        raise if Smartest.fatal_exception?(error)

        suite_errors << error
      end

      teardown_error_aggregator = TeardownErrorAggregator.new
      teardown_error_aggregator.collect(@suite_fixture_set) if @suite_fixture_set
      teardown_error_aggregator.collect(hook_chain)
      suite_teardown_errors = teardown_error_aggregator.teardown_errors
      @suite_fixture_set = nil

      @reporter.finish(
        results,
        suite_teardown_errors: suite_teardown_errors,
        suite_errors: suite_errors
      )

      results.any?(&:failed?) || suite_teardown_errors.any? || suite_errors.any? ? 1 : 0
    end

    private

    def run_tests(results)
      begin
        @tests.each do |test_case|
          result = run_one(test_case)
          results << result
          @reporter.record(result)
        end
      ensure
        @suite_fixture_set.run_teardowns if @suite_fixture_set
      end
    end

    def run_one(test_case)
      started_at = now
      error = nil
      skipped = nil
      run_state = TestRunState.new
      fixture_set = nil
      test_run = TestRun.new(
        fixture_classes: @suite.fixture_classes,
        matcher_modules: @suite.matcher_modules
      ) do |fixture_classes:, matcher_modules:, helper_modules:|
        context = build_context(matcher_modules, run_state, helper_modules)
        fixture_set = FixtureSet.new(fixture_classes, context: context, parent: suite_fixture_set)
        run_test_body(test_case, fixture_set, context)
      end
      hook_chain = AroundTestHookChain.new(
        hooks: @suite.around_test_hooks + test_case.around_test_hooks,
        test_run: test_run,
        run_state: run_state
      )

      begin
        hook_chain.run
      rescue Skipped => skipped_error
        skipped = skipped_error
      rescue Exception => rescued_error
        raise if Smartest.fatal_exception?(rescued_error)

        error = rescued_error
      end

      teardown_error_aggregator = TeardownErrorAggregator.new
      teardown_error_aggregator.collect(fixture_set) if fixture_set
      teardown_error_aggregator.collect(hook_chain)
      teardown_errors = teardown_error_aggregator.teardown_errors
      duration = now - started_at

      return TestResult.failed(test_case: test_case, error: nil, duration: duration, teardown_errors: teardown_errors) if skipped && teardown_errors.any?
      return TestResult.skipped(test_case: test_case, reason: skipped.reason, duration: duration) if skipped

      if run_state.pending?
        if error && !around_test_protocol_error?(error)
          return TestResult.failed(test_case: test_case, error: nil, duration: duration, teardown_errors: teardown_errors) if teardown_errors.any?

          return TestResult.pending(test_case: test_case, reason: run_state.pending_reason, duration: duration)
        end

        error ||= PendingPassedError.new(run_state.pending_reason)
      end

      if error || teardown_errors.any?
        TestResult.failed(
          test_case: test_case,
          error: error,
          duration: duration,
          teardown_errors: teardown_errors
        )
      else
        TestResult.passed(test_case: test_case, duration: duration)
      end
    end

    def run_test_body(test_case, fixture_set, context)
      begin
        fixtures = fixture_set.resolve_keywords(test_case.fixture_names)
        context.instance_exec(**fixtures, &test_case.block)
      ensure
        fixture_set.run_teardowns
      end
    end

    def suite_fixture_set
      @suite_fixture_set ||= FixtureSet.new(
        @suite.fixture_classes,
        context: build_context,
        scope: :suite
      )
    end

    def build_context(matcher_modules = @suite.matcher_modules, run_state = TestRunState.new, helper_modules = [])
      ExecutionContext.new(run_state: run_state).tap do |context|
        helper_modules.each { |helper_module| extend_helper_module(context, helper_module) }
        matcher_modules.each { |matcher_module| context.extend(matcher_module) }
      end
    end

    def extend_helper_module(context, helper_module)
      context.extend(helper_module)

      helper_methods = helper_module.public_instance_methods + helper_module.protected_instance_methods
      return if helper_methods.empty?

      context.singleton_class.class_eval { private(*helper_methods) }
    end

    def around_test_protocol_error?(error)
      error.is_a?(AroundTestRunError)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
