# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::Stream::MysqlStream do
  # rubocop:disable Lint/ConstantDefinitionInBlock
  class MockBuilderMySQL
    include SimpleQuery::Stream::MysqlStream

    def cached_sql
      "SELECT * FROM users"
    end

    def result_struct(columns)
      @result_struct ||= Struct.new(*columns.map(&:to_sym))
    end

    attr_accessor :read_model_class

    def build_row_object_mysql(row)
      { "mocked_mysql" => row }
    end
  end
  # rubocop:enable Lint/ConstantDefinitionInBlock

  let(:builder) { MockBuilderMySQL.new }
  let(:conn)    { double("mysql_raw_conn") }
  let(:mysql_result) { double("mysql_result") }

  describe "#stream_each_mysql" do
    it "queries with stream: true, yields each row" do
      allow(ActiveRecord::Base).to receive_message_chain(:connection, :raw_connection).and_return(conn)
      expect(conn).to receive(:query).with("SELECT * FROM users", stream: true, cache_rows: false, as: :hash)
                                     .and_return(mysql_result)

      allow(mysql_result).to receive(:each).and_yield({ "id" => 1 }).and_yield({ "id" => 2 })

      rows = []
      builder.stream_each_mysql do |r|
        rows << r
      end

      expect(rows).to eq([{ "mocked_mysql" => { "id" => 1 } }, { "mocked_mysql" => { "id" => 2 } }])
    end
  end
end
