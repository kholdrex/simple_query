# frozen_string_literal: true

require "active_support/concern"
require "active_record"

require_relative "simple_query/stream/mysql_stream"
require_relative "simple_query/stream/postgres_stream"
require_relative "simple_query/builder"
require_relative "simple_query/read_model"
require_relative "simple_query/clauses/where_clause"
require_relative "simple_query/clauses/join_clause"
require_relative "simple_query/clauses/order_clause"
require_relative "simple_query/clauses/distinct_clause"
require_relative "simple_query/clauses/limit_offset_clause"
require_relative "simple_query/clauses/group_having_clause"
require_relative "simple_query/clauses/set_clause"

module SimpleQuery
  extend ActiveSupport::Concern

  class Configuration
    attr_accessor :auto_include_ar

    def initialize
      @auto_include_ar = false
    end
  end

  def self.configure
    yield config
    auto_include! if config.auto_include_ar
  end

  def self.config
    @config ||= Configuration.new
  end

  def self.auto_include!
    ActiveRecord::Base.include(SimpleQuery)
  end

  class_methods do
    def _simple_scopes
      @_simple_scopes ||= {}
    end

    def simple_scope(name, body = nil, &block)
      raise ArgumentError, "Pass either a proc/lambda or a block, not both" if body && block_given?

      scope_body = body || block
      raise ArgumentError, "You must provide a block or a proc" unless scope_body

      _simple_scopes[name.to_sym] = scope_body
    end
  end

  included do
    def self.simple_query
      Builder.new(self)
    end
  end
end
