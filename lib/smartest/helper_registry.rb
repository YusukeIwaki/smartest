# frozen_string_literal: true

module Smartest
  class HelperRegistry
    include Enumerable

    def self.validate!(helper_module)
      unless helper_module.is_a?(Module) && !helper_module.is_a?(Class)
        raise ArgumentError, "helper must be a module"
      end
    end

    def initialize
      @helper_modules = []
    end

    def add(helper_module)
      self.class.validate!(helper_module)

      @helper_modules << helper_module unless @helper_modules.include?(helper_module)
    end

    def each(&block)
      @helper_modules.each(&block)
    end

    def to_a
      @helper_modules.dup
    end
  end
end
