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

    it "rejects invalid direct PostgreSQL batch sizes before opening a cursor" do
      expect(ActiveRecord::Base).not_to receive(:connection)

      expect do
        builder.stream_each_postgres("100") { |_record| }
      end.to raise_error(ArgumentError, "stream_each batch_size must be a positive Integer")
    end

    it "rolls back if declaring the cursor fails" do
      expect(conn).to receive(:exec).with("BEGIN").ordered
      expect(conn).to receive(:exec).with(/DECLARE simple_query_cursor_\d+ NO SCROLL CURSOR FOR SELECT \* FROM users/)
                                    .ordered.and_raise("Boom!")
      expect(conn).to receive(:exec).with("ROLLBACK")

      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)

      expect do
        builder.stream_each_postgres(100) { |_record| }
      end.to raise_error("Boom!")
    end

    it "rolls back if fetching from the cursor fails" do
      expect(conn).to receive(:exec).with("BEGIN").ordered
      expect(conn).to receive(:exec)
        .with("DECLARE simple_query_cursor_#{builder.object_id} NO SCROLL CURSOR FOR SELECT * FROM users")
        .ordered
      expect(conn).to receive(:exec).with("FETCH 100 FROM simple_query_cursor_#{builder.object_id}")
                                    .and_raise("fetch failed")
      expect(conn).not_to receive(:exec).with("CLOSE simple_query_cursor_#{builder.object_id}")
      expect(conn).not_to receive(:exec).with("COMMIT")
      expect(conn).to receive(:exec).with("ROLLBACK")

      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)

      expect do
        builder.stream_each_postgres(100) { |_record| }
      end.to raise_error("fetch failed")
    end

    it "rolls back and preserves the original error if row processing fails" do
      expect(conn).to receive(:exec).with("BEGIN").ordered
      expect(conn).to receive(:exec)
        .with("DECLARE simple_query_cursor_#{builder.object_id} NO SCROLL CURSOR FOR SELECT * FROM users")
        .ordered

      fetch_result = double("PGResult", ntuples: 1)
      allow(fetch_result).to receive(:each).and_yield("row1")

      expect(conn).to receive(:exec).with("FETCH 100 FROM simple_query_cursor_#{builder.object_id}")
                                    .and_return(fetch_result)
      expect(conn).not_to receive(:exec).with("CLOSE simple_query_cursor_#{builder.object_id}")
      expect(conn).not_to receive(:exec).with("COMMIT")
      expect(conn).to receive(:exec).with("ROLLBACK")

      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)

      expect do
        builder.stream_each_postgres(100) { |_record| raise "consumer failed" }
      end.to raise_error("consumer failed")
    end
  end
end
