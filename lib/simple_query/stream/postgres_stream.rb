# frozen_string_literal: true

module SimpleQuery
  module Stream
    module PostgresStream
      # rubocop:disable Metrics/MethodLength
      def stream_each_postgres(batch_size, &block)
        select_sql = cached_sql

        conn = ActiveRecord::Base.connection.raw_connection
        cursor_name = "simple_query_cursor_#{object_id}"

        begin
          conn.exec("BEGIN")
          declare_sql = "DECLARE #{cursor_name} NO SCROLL CURSOR FOR #{select_sql}"
          conn.exec(declare_sql)

          loop do
            res = conn.exec("FETCH #{batch_size} FROM #{cursor_name}")
            break if res.ntuples.zero?

            res.each do |pg_row|
              record = build_row_object(pg_row)
              block.call(record)
            end
          end

          conn.exec("CLOSE #{cursor_name}")
          conn.exec("COMMIT")
        rescue StandardError => e
          begin
            conn.exec("ROLLBACK")
          rescue StandardError
            nil
          end
          raise e
        end
      end
      # rubocop:enable Metrics/MethodLength

      private

      def build_row_object(pg_row)
        if @read_model_class
          obj = @read_model_class.allocate
          @read_model_class.attributes.each do |attr_name, col_name|
            obj.instance_variable_set(:"@#{attr_name}", pg_row[col_name])
          end
          obj
        else
          columns = pg_row.keys
          values = columns.map { |k| pg_row[k] }
          struct = result_struct(columns)
          struct.new(*values)
        end
      end
    end
  end
end
