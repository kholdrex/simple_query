# frozen_string_literal: true

module SimpleQuery
  class SetClause
    def initialize(set_hash, model = ActiveRecord::Base)
      @set_hash = set_hash
      @model = model
    end

    def to_sql
      @set_hash.map do |col, val|
        "#{quote_column(col)} = #{quote_value(val)}"
      end.join(", ")
    end

    private

    def quote_column(col)
      @model.connection.quote_column_name(col)
    end

    def quote_value(val)
      @model.connection.quote(val)
    end
  end
end
