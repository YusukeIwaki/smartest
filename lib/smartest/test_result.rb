# frozen_string_literal: true

module Smartest
  class TestResult
    attr_reader :test_case, :status, :error, :duration, :cleanup_errors, :reason

    def self.passed(test_case:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :passed,
        error: nil,
        reason: nil,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def self.failed(test_case:, error:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :failed,
        error: error,
        reason: nil,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def self.skipped(test_case:, reason:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :skipped,
        error: nil,
        reason: reason,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def self.pending(test_case:, reason:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :pending,
        error: nil,
        reason: reason,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def initialize(test_case:, status:, error:, reason:, duration:, cleanup_errors:)
      @test_case = test_case
      @status = status
      @error = error
      @reason = reason
      @duration = duration
      @cleanup_errors = cleanup_errors
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
