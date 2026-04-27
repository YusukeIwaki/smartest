# frozen_string_literal: true

module Smartest
  module Matchers
    def eq(expected)
      EqMatcher.new(expected)
    end

    def include(expected)
      IncludeMatcher.new(expected)
    end

    def start_with(*prefixes)
      StartWithMatcher.new(*prefixes)
    end

    def end_with(*suffixes)
      EndWithMatcher.new(*suffixes)
    end

    def be_nil
      BeNilMatcher.new
    end

    def raise_error(expected_error = StandardError)
      RaiseErrorMatcher.new(expected_error)
    end

    def change(*args, &block)
      raise ArgumentError, "change does not support arguments; use change { ... }" if args.any?
      raise ArgumentError, "change requires a block" unless block

      ChangeMatcher.new(block)
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

  class StartWithMatcher
    def initialize(*prefixes)
      @prefixes = prefixes
    end

    def matches?(actual)
      @actual = actual
      actual.start_with?(*@prefixes)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to start with #{expected_description}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to start with #{expected_description}"
    end

    private

    def expected_description
      return "no prefixes" if @prefixes.empty?

      @prefixes.map(&:inspect).join(" or ")
    end
  end

  class EndWithMatcher
    def initialize(*suffixes)
      @suffixes = suffixes
    end

    def matches?(actual)
      @actual = actual
      actual.end_with?(*@suffixes)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to end with #{expected_description}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to end with #{expected_description}"
    end

    private

    def expected_description
      return "no suffixes" if @suffixes.empty?

      @suffixes.map(&:inspect).join(" or ")
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

  class ChangeMatcher
    UNSET = Object.new

    def initialize(value_block)
      @value_block = value_block
      @expected_from = UNSET
      @expected_to = UNSET
      @expected_delta = UNSET
      reset_result
    end

    def from(expected)
      @expected_from = expected
      self
    end

    def to(expected)
      @expected_to = expected
      self
    end

    def by(expected_delta)
      @expected_delta = expected_delta
      self
    end

    def matches?(actual)
      run_change(actual)
      return false unless @callable

      positive_failures.empty?
    end

    def does_not_match?(actual)
      run_change(actual)
      return false unless @callable

      negated_failures.empty?
    end

    def failure_message
      return "expected a block to change value" unless @callable

      "expected value to #{expected_description}, but #{observed_description}#{failed_modifier_description}"
    end

    def negated_failure_message
      return "expected a block not to change value" unless @callable

      "expected value not to change, but #{observed_description}"
    end

    private

    def reset_result
      @callable = true
      @before_value = nil
      @after_value = nil
      @actual_delta = UNSET
      @failed_modifiers = []
    end

    def run_change(actual)
      reset_result
      @callable = actual.respond_to?(:call)
      return unless @callable

      @before_value = @value_block.call
      actual.call
      @after_value = @value_block.call
      calculate_delta if delta_expected?
    end

    def positive_failures
      @failed_modifiers = []
      @failed_modifiers << "change" if !delta_expected? && @before_value == @after_value
      @failed_modifiers << "from(#{@expected_from.inspect})" if from_expected? && @before_value != @expected_from
      @failed_modifiers << "to(#{@expected_to.inspect})" if to_expected? && @after_value != @expected_to
      @failed_modifiers << "by(#{@expected_delta.inspect})" if delta_expected? && @actual_delta != @expected_delta
      @failed_modifiers
    end

    def negated_failures
      @failed_modifiers = []
      @failed_modifiers << "change" unless @before_value == @after_value
      @failed_modifiers
    end

    def expected_description
      parts = ["change"]
      parts << "from #{@expected_from.inspect}" if from_expected?
      parts << "to #{@expected_to.inspect}" if to_expected?
      parts << "by #{@expected_delta.inspect}" if delta_expected?
      parts.join(" ")
    end

    def observed_description
      if delta_expected?
        delta_description = if @actual_delta.equal?(UNSET)
                              "could not calculate a numeric difference"
                            else
                              "changed by #{@actual_delta.inspect}"
                            end

        "#{delta_description} from #{@before_value.inspect} before to #{@after_value.inspect} after"
      else
        "was #{@before_value.inspect} before and #{@after_value.inspect} after"
      end
    end

    def failed_modifier_description
      failures = positive_failures
      return "" if failures.empty?

      "; failed modifiers: #{failures.join(', ')}"
    end

    def calculate_delta
      @actual_delta = @after_value - @before_value
    rescue NoMethodError, TypeError
      @actual_delta = UNSET
    end

    def from_expected?
      !@expected_from.equal?(UNSET)
    end

    def to_expected?
      !@expected_to.equal?(UNSET)
    end

    def delta_expected?
      !@expected_delta.equal?(UNSET)
    end
  end
end
