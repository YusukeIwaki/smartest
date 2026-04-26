# frozen_string_literal: true

module Smartest
  class ParameterExtractor
    POSITIONAL_PARAMETER_TYPES = %i[req opt rest].freeze

    class << self
      def required_keyword_names(block, usage:)
        raise ArgumentError, "block is required" unless block

        parameters = block.parameters
        positional = parameters.select { |type, _name| POSITIONAL_PARAMETER_TYPES.include?(type) }

        raise InvalidFixtureParameterError, positional_parameter_message(usage) if positional.any?

        parameters.filter_map do |type, name|
          name if type == :keyreq
        end
      end

      private

      def positional_parameter_message(usage)
        case usage
        when :test
          <<~MESSAGE.chomp
            Positional fixture parameters are not supported.

            Use keyword fixture injection:

              test("bad") do |user:|
                ...
              end
          MESSAGE
        when :fixture
          <<~MESSAGE.chomp
            Positional fixture dependencies are not supported.

            Use keyword fixture dependencies:

              fixture :client do |server:|
                ...
              end
          MESSAGE
        else
          "Positional fixture parameters are not supported."
        end
      end
    end
  end
end
