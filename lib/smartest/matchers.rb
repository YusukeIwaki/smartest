# frozen_string_literal: true

module Smartest
  module Matchers
    def eq(expected)
      EqMatcher.new(expected)
    end

    def include(expected)
      IncludeMatcher.new(expected)
    end

    def be_nil
      BeNilMatcher.new
    end

    def raise_error(expected_error = StandardError)
      RaiseErrorMatcher.new(expected_error)
    end
  end

  class EqMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual == @expected
    end

    def failure_message
      "expected #{@actual.inspect} to eq #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to eq #{@expected.inspect}"
    end
  end

  class IncludeMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual.include?(@expected)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to include #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to include #{@expected.inspect}"
    end
  end

  class BeNilMatcher
    def matches?(actual)
      @actual = actual
      actual.nil?
    end

    def failure_message
      "expected #{@actual.inspect} to be nil"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to be nil"
    end
  end

  class RaiseErrorMatcher
    def initialize(expected_error)
      @expected_error = expected_error
      @actual_error = nil
      @callable = true
    end

    def matches?(actual)
      @actual_error = nil
      @callable = actual.respond_to?(:call)
      return false unless @callable

      actual.call
      false
    rescue Exception => error
      raise if Smartest.fatal_exception?(error)

      @actual_error = error
      error.is_a?(@expected_error)
    end

    def failure_message
      return "expected a block to raise #{@expected_error}" unless @callable
      return "expected block to raise #{@expected_error}, but nothing was raised" unless @actual_error

      "expected block to raise #{@expected_error}, but raised #{@actual_error.class}: #{@actual_error.message}"
    end

    def negated_failure_message
      "expected block not to raise #{@expected_error}, but raised #{@actual_error.class}: #{@actual_error.message}"
    end
  end
end
