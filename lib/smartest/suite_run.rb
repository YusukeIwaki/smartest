# frozen_string_literal: true

module Smartest
  class SuiteRun
    attr_reader :result

    def initialize(&block)
      @block = block
      @ran = false
      @result = nil
    end

    def run
      raise AroundSuiteRunError, "around_suite hook called suite.run more than once" if ran?

      @ran = true
      @result = @block.call
    end

    def ran?
      @ran
    end
  end
end
