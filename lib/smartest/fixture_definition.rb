# frozen_string_literal: true

module Smartest
  class FixtureDefinition
    VALID_SCOPES = %i[test suite].freeze

    attr_reader :name, :block, :dependencies, :location, :scope

    def initialize(name:, block:, location:, scope: :test)
      raise ArgumentError, "fixture name is required" if name.nil? || name.to_s.empty?
      raise ArgumentError, "fixture block is required" unless block

      @name = name.to_sym
      @block = block
      @location = location
      @scope = normalize_scope(scope)
      @dependencies = ParameterExtractor.required_keyword_names(block, usage: :fixture)
    end

    private

    def normalize_scope(scope)
      symbol_scope = scope.to_sym
      return symbol_scope if VALID_SCOPES.include?(symbol_scope)

      raise InvalidFixtureScopeError, scope
    rescue NoMethodError
      raise InvalidFixtureScopeError, scope
    end
  end
end
