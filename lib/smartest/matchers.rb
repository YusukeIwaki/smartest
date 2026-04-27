# frozen_string_literal: true

module Smartest
  module Matchers
    def eq(expected)
      EqMatcher.new(expected)
    end

    def include(expected)
      IncludeMatcher.new(expected)
    end

    def start_with(*prefixes)
      StartWithMatcher.new(*prefixes)
    end

    def end_with(*suffixes)
      EndWithMatcher.new(*suffixes)
    end

    def be_a(expected_class)
      BeAKindOfMatcher.new(expected_class)
    end

    def be_an(expected_class)
      BeAKindOfMatcher.new(expected_class)
    end

    def be_nil
      BeNilMatcher.new
    end

    def match(regexp)
      MatchMatcher.new(regexp)
    end

    def contain_exactly(*expected_items)
      ContainExactlyMatcher.new(expected_items, matcher_name: "contain exactly")
    end

    def match_array(expected_items)
      ContainExactlyMatcher.new(expected_items, matcher_name: "match array")
    end

    def raise_error(*expected_error)
      RaiseErrorMatcher.new(*expected_error)
    end

    def change(*args, &block)
      raise ArgumentError, "change does not support arguments; use change { ... }" if args.any?
      raise ArgumentError, "change requires a block" unless block

      ChangeMatcher.new(block)
    end
  end

  class EqMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual == @expected
    end

    def failure_message
      "expected #{@actual.inspect} to eq #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to eq #{@expected.inspect}"
    end

    def description
      "eq #{@expected.inspect}"
    end
  end

  class IncludeMatcher
    def initialize(expected)
      @expected = expected
    end

    def matches?(actual)
      @actual = actual
      actual.include?(@expected)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to include #{@expected.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to include #{@expected.inspect}"
    end

    def description
      "include #{@expected.inspect}"
    end
  end

  class StartWithMatcher
    def initialize(*prefixes)
      @prefixes = prefixes
    end

    def matches?(actual)
      @actual = actual
      actual.start_with?(*@prefixes)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to start with #{expected_description}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to start with #{expected_description}"
    end

    def description
      "start with #{expected_description}"
    end

    private

    def expected_description
      return "no prefixes" if @prefixes.empty?

      @prefixes.map(&:inspect).join(" or ")
    end
  end

  class EndWithMatcher
    def initialize(*suffixes)
      @suffixes = suffixes
    end

    def matches?(actual)
      @actual = actual
      actual.end_with?(*@suffixes)
    rescue NoMethodError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to end with #{expected_description}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to end with #{expected_description}"
    end

    def description
      "end with #{expected_description}"
    end

    private

    def expected_description
      return "no suffixes" if @suffixes.empty?

      @suffixes.map(&:inspect).join(" or ")
    end
  end

  class BeAKindOfMatcher
    def initialize(expected_class)
      @expected_class = expected_class
    end

    def matches?(actual)
      @actual = actual
      actual.is_a?(@expected_class)
    rescue TypeError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to be a kind of #{expected_description}, but was #{actual_class_description}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to be a kind of #{expected_description}, but was #{actual_class_description}"
    end

    def description
      "be a kind of #{expected_description}"
    end

    private

    def expected_description
      @expected_class.to_s
    end

    def actual_class_description
      @actual.class.to_s
    end
  end

  class BeNilMatcher
    def matches?(actual)
      @actual = actual
      actual.nil?
    end

    def failure_message
      "expected #{@actual.inspect} to be nil"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to be nil"
    end

    def description
      "be nil"
    end
  end

  class MatchMatcher
    def initialize(regexp)
      @regexp = regexp
    end

    def matches?(actual)
      @actual = actual
      @regexp.match?(actual)
    rescue NoMethodError, TypeError
      false
    end

    def failure_message
      "expected #{@actual.inspect} to match #{@regexp.inspect}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to match #{@regexp.inspect}"
    end

    def description
      "match #{@regexp.inspect}"
    end
  end

  class ContainExactlyMatcher
    def initialize(expected_items, matcher_name:)
      @expected_items = expected_items
      @matcher_name = matcher_name
      reset_result
    end

    def matches?(actual)
      @actual = actual
      reset_result
      return false unless actual_items?

      match_items
      @missing_items.empty? && @extra_items.empty?
    end

    def failure_message
      details = failure_details
      message = "expected #{@actual.inspect} to #{@matcher_name} #{format_expected_items(@expected_items)}"
      details.empty? ? message : "#{message}; #{details.join('; ')}"
    end

    def negated_failure_message
      "expected #{@actual.inspect} not to #{@matcher_name} #{format_expected_items(@expected_items)}"
    end

    def description
      "#{@matcher_name} #{format_expected_items(@expected_items)}"
    end

    private

    def reset_result
      @actual_items = nil
      @missing_items = @expected_items.dup
      @extra_items = []
    end

    def actual_items?
      return false unless @actual.respond_to?(:to_a)

      @actual_items = @actual.to_a
      true
    end

    def match_items
      adjacency = build_adjacency
      actual_matches = Array.new(@actual_items.length)
      expected_order(adjacency).each do |expected_index|
        assign_expected_item(expected_index, adjacency, actual_matches, [])
      end

      matched_expected_indexes = actual_matches.compact
      @missing_items = []
      @expected_items.each_with_index do |item, index|
        @missing_items << item unless matched_expected_indexes.include?(index)
      end
      @extra_items = []
      @actual_items.each_with_index do |item, index|
        @extra_items << item if actual_matches[index].nil?
      end
    end

    def build_adjacency
      @expected_items.map do |expected_item|
        @actual_items.each_index.select do |actual_index|
          expected_item_matches_actual_item?(expected_item, @actual_items[actual_index])
        end
      end
    end

    def expected_order(adjacency)
      (0...@expected_items.length).sort_by { |index| [adjacency[index].length, index] }
    end

    def assign_expected_item(expected_index, adjacency, actual_matches, seen_actual_indexes)
      adjacency[expected_index].each do |actual_index|
        next if seen_actual_indexes.include?(actual_index)

        seen_actual_indexes << actual_index
        if actual_matches[actual_index].nil? ||
           assign_expected_item(actual_matches[actual_index], adjacency, actual_matches, seen_actual_indexes)
          actual_matches[actual_index] = expected_index
          return true
        end
      end

      false
    end

    def expected_item_matches_actual_item?(expected_item, actual_item)
      if expected_item.respond_to?(:matches?)
        expected_item.matches?(actual_item)
      else
        actual_item == expected_item
      end
    end

    def failure_details
      return ["actual did not provide items"] unless @actual_items

      details = []
      details << "missing: #{format_expected_items(@missing_items)}" unless @missing_items.empty?
      details << "extra: #{format_actual_items(@extra_items)}" unless @extra_items.empty?
      details
    end

    def format_expected_items(items)
      "[#{items.map { |item| format_expected_item(item) }.join(', ')}]"
    end

    def format_actual_items(items)
      "[#{items.map(&:inspect).join(', ')}]"
    end

    def format_expected_item(item)
      return item.description if item.respond_to?(:description)

      item.inspect
    end
  end

  class RaiseErrorMatcher
    def initialize(*expected_error)
      @expected_type = expected_type_for(expected_error)
      @expected_error_class = expected_error.find { |item| error_class?(item) }
      @expected_message_regexp = expected_error.find { |item| item.is_a?(Regexp) }
      @actual_error = nil
      @callable = true
    end

    def matches?(actual)
      @actual_error = nil
      @callable = actual.respond_to?(:call)
      return false unless @callable

      actual.call
      false
    rescue Exception => error
      raise if Smartest.fatal_exception?(error)

      @actual_error = error
      expected_error_matches?(error)
    end

    def failure_message
      return "expected a block to raise #{expected_description}" unless @callable
      return "expected block to raise #{expected_description}, but nothing was raised" unless @actual_error

      "expected block to raise #{expected_description}, but raised #{actual_error_description}"
    end

    def negated_failure_message
      "expected block not to raise #{expected_description}, but raised #{actual_error_description}"
    end

    private

    def expected_type_for(expected_error)
      return :class if expected_error.length == 1 && error_class?(expected_error.first)
      return :message_regexp if expected_error.length == 1 && expected_error.first.is_a?(Regexp)
      return :class_and_message_regexp if expected_error.length == 2 &&
                                          error_class?(expected_error[0]) &&
                                          expected_error[1].is_a?(Regexp)

      raise ArgumentError, "raise_error supports an error class, message regexp, or error class and message regexp"
    end

    def error_class?(value)
      value.is_a?(Class) && value <= Exception
    end

    def expected_error_matches?(error)
      case @expected_type
      when :class
        error.is_a?(@expected_error_class)
      when :message_regexp
        @expected_message_regexp.match?(error.message)
      when :class_and_message_regexp
        error.is_a?(@expected_error_class) && @expected_message_regexp.match?(error.message)
      end
    end

    def expected_description
      case @expected_type
      when :class
        @expected_error_class.to_s
      when :message_regexp
        "error with message matching #{@expected_message_regexp.inspect}"
      when :class_and_message_regexp
        "#{@expected_error_class} with message matching #{@expected_message_regexp.inspect}"
      end
    end

    def actual_error_description
      "#{@actual_error.class}: #{@actual_error.message}"
    end
  end

  class ChangeMatcher
    UNSET = Object.new

    def initialize(value_block)
      @value_block = value_block
      @expected_from = UNSET
      @expected_to = UNSET
      @expected_delta = UNSET
      reset_result
    end

    def from(expected)
      @expected_from = expected
      self
    end

    def to(expected)
      @expected_to = expected
      self
    end

    def by(expected_delta)
      @expected_delta = expected_delta
      self
    end

    def matches?(actual)
      run_change(actual)
      return false unless @callable

      positive_failures.empty?
    end

    def does_not_match?(actual)
      run_change(actual)
      return false unless @callable

      negated_failures.empty?
    end

    def failure_message
      return "expected a block to change value" unless @callable

      "expected value to #{expected_description}, but #{observed_description}#{failed_modifier_description}"
    end

    def negated_failure_message
      return "expected a block not to change value" unless @callable

      "expected value not to change, but #{observed_description}"
    end

    private

    def reset_result
      @callable = true
      @before_value = nil
      @after_value = nil
      @actual_delta = UNSET
      @failed_modifiers = []
    end

    def run_change(actual)
      reset_result
      @callable = actual.respond_to?(:call)
      return unless @callable

      @before_value = @value_block.call
      actual.call
      @after_value = @value_block.call
      calculate_delta if delta_expected?
    end

    def positive_failures
      @failed_modifiers = []
      @failed_modifiers << "change" if !delta_expected? && @before_value == @after_value
      @failed_modifiers << "from(#{@expected_from.inspect})" if from_expected? && @before_value != @expected_from
      @failed_modifiers << "to(#{@expected_to.inspect})" if to_expected? && @after_value != @expected_to
      @failed_modifiers << "by(#{@expected_delta.inspect})" if delta_expected? && @actual_delta != @expected_delta
      @failed_modifiers
    end

    def negated_failures
      @failed_modifiers = []
      @failed_modifiers << "change" unless @before_value == @after_value
      @failed_modifiers
    end

    def expected_description
      parts = ["change"]
      parts << "from #{@expected_from.inspect}" if from_expected?
      parts << "to #{@expected_to.inspect}" if to_expected?
      parts << "by #{@expected_delta.inspect}" if delta_expected?
      parts.join(" ")
    end

    def observed_description
      if delta_expected?
        delta_description = if @actual_delta.equal?(UNSET)
                              "could not calculate a numeric difference"
                            else
                              "changed by #{@actual_delta.inspect}"
                            end

        "#{delta_description} from #{@before_value.inspect} before to #{@after_value.inspect} after"
      else
        "was #{@before_value.inspect} before and #{@after_value.inspect} after"
      end
    end

    def failed_modifier_description
      failures = positive_failures
      return "" if failures.empty?

      "; failed modifiers: #{failures.join(', ')}"
    end

    def calculate_delta
      @actual_delta = @after_value - @before_value
    rescue NoMethodError, TypeError
      @actual_delta = UNSET
    end

    def from_expected?
      !@expected_from.equal?(UNSET)
    end

    def to_expected?
      !@expected_to.equal?(UNSET)
    end

    def delta_expected?
      !@expected_delta.equal?(UNSET)
    end
  end
end
