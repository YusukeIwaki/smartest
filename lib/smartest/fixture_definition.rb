# frozen_string_literal: true

module Smartest
  class FixtureDefinition
    attr_reader :name, :block, :dependencies, :location

    def initialize(name:, block:, location:)
      raise ArgumentError, "fixture name is required" if name.nil? || name.to_s.empty?
      raise ArgumentError, "fixture block is required" unless block

      @name = name.to_sym
      @block = block
      @location = location
      @dependencies = ParameterExtractor.required_keyword_names(block, usage: :fixture)
    end
  end
end
