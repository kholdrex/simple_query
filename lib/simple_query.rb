# frozen_string_literal: true

require "active_record"
require "simple_query/builder"
require "simple_query/where_clause"
require "simple_query/read_model"

module SimpleQuery
  extend ActiveSupport::Concern

  included do
    def self.simple_query
      SimpleQuery::Builder.new(self)
    end
  end
end

ActiveRecord::Base.include SimpleQuery
