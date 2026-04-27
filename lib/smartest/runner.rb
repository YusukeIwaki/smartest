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
      @suite_fixture_set = nil

      @reporter.start(@tests.count)

      begin
        @tests.each do |test_case|
          result = run_one(test_case)
          results << result
          @reporter.record(result)
        end
      ensure
        suite_cleanup_errors = @suite_fixture_set.run_cleanups if @suite_fixture_set
        @suite_fixture_set = nil
      end

      @reporter.finish(results, suite_cleanup_errors: suite_cleanup_errors)

      results.any?(&:failed?) || suite_cleanup_errors.any? ? 1 : 0
    end

    private

    def run_one(test_case)
      started_at = now
      context = build_context
      fixture_set = nil
      error = nil
      cleanup_errors = []

      begin
        fixture_set = FixtureSet.new(@suite.fixture_classes, context: context, parent: suite_fixture_set)
        fixtures = fixture_set.resolve_keywords(test_case.fixture_names)
        context.instance_exec(**fixtures, &test_case.block)
      rescue Exception => rescued_error
        raise if Smartest.fatal_exception?(rescued_error)

        error = rescued_error
      ensure
        cleanup_errors = fixture_set.run_cleanups if fixture_set
      end

      duration = now - started_at

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

    def suite_fixture_set
      @suite_fixture_set ||= FixtureSet.new(
        @suite.fixture_classes,
        context: build_context,
        scope: :suite
      )
    end

    def build_context
      ExecutionContext.new.tap do |context|
        @suite.matcher_modules.each { |matcher_module| context.extend(matcher_module) }
      end
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
