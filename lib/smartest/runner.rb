# frozen_string_literal: true

module Smartest
  class Runner
    def initialize(suite: Smartest.suite, reporter: Reporter.new)
      @suite = suite
      @reporter = reporter
    end

    def run
      results = []

      @reporter.start(@suite.tests.count)

      @suite.tests.each do |test_case|
        result = run_one(test_case)
        results << result
        @reporter.record(result)
      end

      @reporter.finish(results)

      results.any?(&:failed?) ? 1 : 0
    end

    private

    def run_one(test_case)
      started_at = now
      context = ExecutionContext.new
      fixture_set = nil
      error = nil
      cleanup_errors = []

      begin
        fixture_set = FixtureSet.new(@suite.fixture_classes, context: context)
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

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
