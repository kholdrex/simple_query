# frozen_string_literal: true

module SimpleQuery
  module Stream
    module MysqlStream
      def stream_each_mysql(&block)
        select_sql = cached_sql

        raw_conn = ActiveRecord::Base.connection.raw_connection

        result = raw_conn.query(select_sql, stream: true, cache_rows: false, as: :hash)
        result.each do |mysql_row|
          record = build_row_object_mysql(mysql_row)
          block.call(record)
        end
      end

      private

      def build_row_object_mysql(mysql_row)
        if @read_model_class
          obj = @read_model_class.allocate
          @read_model_class.attributes.each do |attr_name, col_name|
            obj.instance_variable_set(:"@#{attr_name}", mysql_row[col_name])
          end
          obj
        else
          columns = mysql_row.keys
          values = columns.map { |k| mysql_row[k] }
          struct = result_struct(columns)
          struct.new(*values)
        end
      end
    end
  end
end
