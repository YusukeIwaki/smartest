# frozen_string_literal: true

module Smartest
  class MatcherRegistry
    include Enumerable

    def initialize
      @matcher_modules = []
    end

    def add(matcher_module)
      unless matcher_module.is_a?(Module) && !matcher_module.is_a?(Class)
        raise ArgumentError, "matcher must be a module"
      end

      @matcher_modules << matcher_module unless @matcher_modules.include?(matcher_module)
    end

    def each(&block)
      @matcher_modules.each(&block)
    end

    def to_a
      @matcher_modules.dup
    end
  end
end
