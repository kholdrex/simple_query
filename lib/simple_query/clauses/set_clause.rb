# frozen_string_literal: true

module SimpleQuery
  class SetClause
    def initialize(set_hash)
      @set_hash = set_hash
    end

    def to_sql
      @set_hash.map do |col, val|
        "#{quote_column(col)} = #{quote_value(val)}"
      end.join(", ")
    end

    private

    def quote_column(col)
      ActiveRecord::Base.connection.quote_column_name(col)
    end

    def quote_value(val)
      ActiveRecord::Base.connection.quote(val)
    end
  end
end
