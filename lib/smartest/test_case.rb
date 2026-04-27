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

    def includes_line?(line)
      includes_line_range?(line..line)
    end

    def includes_line_range?(range)
      return false unless location

      current_range = line_range
      current_range.begin <= range.end && range.begin <= current_range.end
    end

    private

    def line_range
      location.lineno..end_lineno
    end

    def end_lineno
      @end_lineno ||= inferred_end_lineno
    end

    def inferred_end_lineno
      code_location = instruction_sequence_metadata[:code_location]
      return code_location[2] if code_location&.length == 4

      instruction_sequence_line_numbers.max || location.lineno
    rescue StandardError
      location.lineno
    end

    def instruction_sequence_metadata
      return {} unless defined?(RubyVM::InstructionSequence)

      sequence = RubyVM::InstructionSequence.of(block)
      metadata = sequence&.to_a&.[](4)
      metadata.is_a?(Hash) ? metadata : {}
    end

    def instruction_sequence_line_numbers
      return [] unless defined?(RubyVM::InstructionSequence)

      sequence = RubyVM::InstructionSequence.of(block)
      body = sequence&.to_a&.last
      body.is_a?(Array) ? body.select { |entry| entry.is_a?(Integer) } : []
    end
  end
end
