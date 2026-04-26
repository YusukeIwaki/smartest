# frozen_string_literal: true

module Smartest
  class TestResult
    attr_reader :test_case, :status, :error, :duration, :cleanup_errors

    def self.passed(test_case:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :passed,
        error: nil,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def self.failed(test_case:, error:, duration:, cleanup_errors: [])
      new(
        test_case: test_case,
        status: :failed,
        error: error,
        duration: duration,
        cleanup_errors: cleanup_errors
      )
    end

    def initialize(test_case:, status:, error:, duration:, cleanup_errors:)
      @test_case = test_case
      @status = status
      @error = error
      @duration = duration
      @cleanup_errors = cleanup_errors
    end

    def passed?
      status == :passed
    end

    def failed?
      status == :failed
    end
  end
end
