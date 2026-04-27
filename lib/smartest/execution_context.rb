# frozen_string_literal: true

module Smartest
  class ExecutionContext
    include Expectations
    include Matchers

    def initialize(run_state: TestRunState.new)
      @run_state = run_state
    end

    private

    def skip(reason = nil)
      raise Skipped, reason
    end

    def pending(reason = nil)
      @run_state.pending(reason)
    end
  end
end
