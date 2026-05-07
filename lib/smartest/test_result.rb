# frozen_string_literal: true

module Smartest
  class TestResult
    attr_reader :test_case, :status, :error, :duration, :teardown_errors, :reason

    def self.passed(test_case:, duration:, teardown_errors: [])
      new(
        test_case: test_case,
        status: :passed,
        error: nil,
        reason: nil,
        duration: duration,
        teardown_errors: teardown_errors
      )
    end

    def self.failed(test_case:, error:, duration:, teardown_errors: [])
      new(
        test_case: test_case,
        status: :failed,
        error: error,
        reason: nil,
        duration: duration,
        teardown_errors: teardown_errors
      )
    end

    def self.skipped(test_case:, reason:, duration:, teardown_errors: [])
      new(
        test_case: test_case,
        status: :skipped,
        error: nil,
        reason: reason,
        duration: duration,
        teardown_errors: teardown_errors
      )
    end

    def self.pending(test_case:, reason:, duration:, teardown_errors: [])
      new(
        test_case: test_case,
        status: :pending,
        error: nil,
        reason: reason,
        duration: duration,
        teardown_errors: teardown_errors
      )
    end

    def initialize(test_case:, status:, error:, reason:, duration:, teardown_errors:)
      @test_case = test_case
      @status = status
      @error = error
      @reason = reason
      @duration = duration
      @teardown_errors = teardown_errors
    end

    def passed?
      status == :passed
    end

    def failed?
      status == :failed
    end

    def skipped?
      status == :skipped
    end

    def pending?
      status == :pending
    end
  end
end
