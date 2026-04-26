# frozen_string_literal: true

module Smartest
  module Expectations
    def expect(actual = nil, &block)
      ExpectationTarget.new(block || actual)
    end
  end
end
