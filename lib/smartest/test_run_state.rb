# frozen_string_literal: true

module Smartest
  class TestRunState
    attr_reader :pending_reason

    def pending(reason = nil)
      @pending_reason = StatusReason.normalize(reason)
      nil
    end

    def pending?
      !@pending_reason.nil?
    end
  end
end
