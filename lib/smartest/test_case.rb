# frozen_string_literal: true

module Smartest
  class TestCase
    attr_reader :name, :metadata, :block, :location, :fixture_names

    def initialize(name:, metadata:, block:, location:)
      raise ArgumentError, "test name is required" if name.nil? || name.to_s.empty?
      raise ArgumentError, "test block is required" unless block

      @name = name.to_s
      @metadata = metadata
      @block = block
      @location = location
      @fixture_names = ParameterExtractor.required_keyword_names(block, usage: :test)
    end
  end
end
