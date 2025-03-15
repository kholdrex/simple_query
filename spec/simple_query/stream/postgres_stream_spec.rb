# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::Stream::PostgresStream do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  class MockBuilderPostgres
    include SimpleQuery::Stream::PostgresStream

    def cached_sql
      "SELECT * FROM users"
    end

    def result_struct(columns)
      @result_struct ||= Struct.new(*columns.map(&:to_sym))
    end

    attr_accessor :read_model_class

    def build_row_object(row)
      { "mocked" => row }
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  let(:builder) { MockBuilderPostgres.new }
  let(:conn)    { double("raw_connection") }

  describe "#stream_each_postgres" do
    it "declares a cursor, fetches rows in batches, and calls the block" do
      expect(conn).to receive(:exec).with("BEGIN").ordered
      expect(conn).to receive(:exec)
        .with("DECLARE simple_query_cursor_#{builder.object_id} NO SCROLL CURSOR FOR SELECT * FROM users")
        .ordered

      fetch_result1 = double("PGResult", ntuples: 2)
      allow(fetch_result1).to receive(:each).and_yield("row1").and_yield("row2")

      fetch_result2 = double("PGResult", ntuples: 0)

      expect(conn).to receive(:exec).with("FETCH 100 FROM simple_query_cursor_#{builder.object_id}")
                                    .and_return(fetch_result1, fetch_result2).twice

      expect(conn).to receive(:exec).with("CLOSE simple_query_cursor_#{builder.object_id}")
      expect(conn).to receive(:exec).with("COMMIT")

      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)

      rows = []
      builder.stream_each_postgres(100) do |record|
        rows << record
      end

      expect(rows).to eq([{ "mocked" => "row1" }, { "mocked" => "row2" }])
    end

    it "rolls back if an error occurs" do
      expect(conn).to receive(:exec).with("BEGIN").ordered
      expect(conn).to receive(:exec).with(/DECLARE simple_query_cursor_\d+ NO SCROLL CURSOR FOR SELECT \* FROM users/)
                                    .ordered.and_raise("Boom!")
      expect(conn).to receive(:exec).with("ROLLBACK")

      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)

      expect do
        builder.stream_each_postgres(100) { |r| }
      end.to raise_error("Boom!")
    end
  end
end
