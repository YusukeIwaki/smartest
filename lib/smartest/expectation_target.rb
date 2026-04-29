# frozen_string_literal: true

module Smartest
  class ExpectationTarget
    def initialize(actual)
      @actual = actual
    end

    def to(matcher)
      return self if matcher.matches?(@actual)

      raise AssertionFailed, matcher.failure_message
    end

    def not_to(matcher)
      if matcher.respond_to?(:supports_negated_expectation?) && !matcher.supports_negated_expectation?
        raise ArgumentError, matcher.negated_expectation_error
      end

      if matcher.respond_to?(:does_not_match?)
        return self if matcher.does_not_match?(@actual)

        raise AssertionFailed, negated_failure_message_for(matcher)
      end

      return self unless matcher.matches?(@actual)

      raise AssertionFailed, negated_failure_message_for(matcher)
    end

    private

    def negated_failure_message_for(matcher)
      return matcher.negated_failure_message if matcher.respond_to?(:negated_failure_message)
      return matcher.failure_message_when_negated if matcher.respond_to?(:failure_message_when_negated)

      description = matcher.respond_to?(:description) ? matcher.description : matcher.inspect
      "expected #{@actual.inspect} not to #{description}"
    end
  end
end
