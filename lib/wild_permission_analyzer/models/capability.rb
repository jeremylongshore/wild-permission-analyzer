# frozen_string_literal: true

module WildPermissionAnalyzer
  module Models
    class Capability
      attr_reader :name, :description, :risk_level, :prerequisites, :tags

      def initialize(name:, description: '', risk_level: 'low', prerequisites: [], tags: [])
        @name = name
        @description = description
        @risk_level = risk_level
        @prerequisites = Array(prerequisites).freeze
        @tags = Array(tags).freeze
      end

      def ==(other)
        other.is_a?(Capability) && name == other.name
      end

      alias eql? ==

      def hash
        name.hash
      end

      def to_s
        name
      end
    end
  end
end
