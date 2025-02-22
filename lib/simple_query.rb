# frozen_string_literal: true

require "active_record"
require "active_support/concern"

require_relative "simple_query/builder"
require_relative "simple_query/read_model"
require_relative "simple_query/clauses/where_clause"
require_relative "simple_query/clauses/join_clause"
require_relative "simple_query/clauses/order_clause"
require_relative "simple_query/clauses/distinct_clause"
require_relative "simple_query/clauses/limit_offset_clause"
require_relative "simple_query/clauses/group_having_clause"

module SimpleQuery
  extend ActiveSupport::Concern

  included do
    def self.simple_query
      Builder.new(self)
    end
  end
end

ActiveRecord::Base.include SimpleQuery
