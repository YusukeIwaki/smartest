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
      suite_cleanup_errors = []
      suite_errors = []
      @suite_fixture_set = nil

      @reporter.start(@tests.count)

      begin
        run_around_suite_hooks(@suite.around_suite_hooks.dup) do
          run_tests(results, suite_cleanup_errors)
        end
      rescue Exception => error
        raise if Smartest.fatal_exception?(error)

        suite_errors << error
      end

      @reporter.finish(
        results,
        suite_cleanup_errors: suite_cleanup_errors,
        suite_errors: suite_errors
      )

      results.any?(&:failed?) || suite_cleanup_errors.any? || suite_errors.any? ? 1 : 0
    end

    private

    def run_tests(results, suite_cleanup_errors)
      begin
        @tests.each do |test_case|
          result = run_one(test_case)
          results << result
          @reporter.record(result)
        end
      ensure
        suite_cleanup_errors.concat(@suite_fixture_set.run_cleanups) if @suite_fixture_set
        @suite_fixture_set = nil
      end
    end

    def run_around_suite_hooks(hooks, index = 0, &block)
      return yield if index >= hooks.length

      hook = hooks[index]
      suite_run = SuiteRun.new do
        run_around_suite_hooks(hooks, index + 1, &block)
      end

      AroundSuiteContext.new(@suite).call(hook, suite_run)
      raise AroundSuiteRunError, "around_suite hook did not call suite.run" unless suite_run.ran?

      suite_run.result
    end

    def run_one(test_case)
      started_at = now
      error = nil
      skipped = nil
      cleanup_errors = []
      run_state = TestRunState.new
      test_run = TestRun.new(
        fixture_classes: @suite.fixture_classes,
        matcher_modules: @suite.matcher_modules
      ) do |fixture_classes:, matcher_modules:, helper_modules:|
        run_test_body(test_case, fixture_classes, matcher_modules, helper_modules, run_state, cleanup_errors)
      end

      begin
        run_around_test_hooks(@suite.around_test_hooks + test_case.around_test_hooks, test_run, run_state)
      rescue Skipped => skipped_error
        skipped = skipped_error
      rescue Exception => rescued_error
        raise if Smartest.fatal_exception?(rescued_error)

        error = rescued_error
      end

      duration = now - started_at

      return TestResult.failed(test_case: test_case, error: nil, duration: duration, cleanup_errors: cleanup_errors) if skipped && cleanup_errors.any?
      return TestResult.skipped(test_case: test_case, reason: skipped.reason, duration: duration) if skipped

      if run_state.pending?
        if error && !around_test_protocol_error?(error)
          return TestResult.failed(test_case: test_case, error: nil, duration: duration, cleanup_errors: cleanup_errors) if cleanup_errors.any?

          return TestResult.pending(test_case: test_case, reason: run_state.pending_reason, duration: duration)
        end

        error ||= PendingPassedError.new(run_state.pending_reason)
      end

      if error || cleanup_errors.any?
        TestResult.failed(
          test_case: test_case,
          error: error,
          duration: duration,
          cleanup_errors: cleanup_errors
        )
      else
        TestResult.passed(test_case: test_case, duration: duration)
      end
    end

    def run_test_body(test_case, fixture_classes, matcher_modules, helper_modules, run_state, cleanup_errors)
      context = build_context(matcher_modules, run_state, helper_modules)
      fixture_set = nil

      begin
        fixture_set = FixtureSet.new(fixture_classes, context: context, parent: suite_fixture_set)
        fixtures = fixture_set.resolve_keywords(test_case.fixture_names)
        context.instance_exec(**fixtures, &test_case.block)
      ensure
        cleanup_errors.concat(fixture_set.run_cleanups) if fixture_set
      end
    end

    def run_around_test_hooks(hooks, test_run, run_state, index = 0)
      return test_run.run if index >= hooks.length

      hook = hooks[index]
      next_run = TestRun.new(
        fixture_classes: [],
        matcher_modules: []
      ) do |**_keywords|
        run_around_test_hooks(hooks, test_run, run_state, index + 1)
      end

      AroundTestContext.new(test_run, run_state: run_state).call(hook, next_run)
      raise AroundTestRunError, "around_test hook did not call test.run" unless next_run.ran?

      next_run.result
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
