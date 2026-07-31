# frozen_string_literal: true

module Smartest
  class TeardownErrorAggregator
    attr_reader :teardown_errors

    def initialize
      @teardown_errors = []
    end

    def collect(source)
      @teardown_errors.concat(source.teardown_errors)
      self
    end
  end
end
