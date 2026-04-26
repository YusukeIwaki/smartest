# frozen_string_literal: true

module Smartest
  class TestRegistry
    include Enumerable

    def initialize
      @tests = []
    end

    def add(test_case)
      @tests << test_case
    end

    def each(&block)
      @tests.each(&block)
    end

    def count
      @tests.count
    end

    alias size count
  end
end
