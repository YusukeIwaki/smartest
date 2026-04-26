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
      return self unless matcher.matches?(@actual)

      raise AssertionFailed, matcher.negated_failure_message
    end
  end
end
