# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Models on a secondary database" do
  before do
    Widget.delete_all
    Widget.create!(name: "gear")
    Widget.create!(name: "bolt")
  end

  it "reads through the model's connection" do
    expect(Widget.simple_query.select(:name).where(name: ["gear"]).execute.map(&:name)).to eq(["gear"])
    expect(Widget.simple_query.select(:name).lazy_execute.map(&:name)).to contain_exactly("gear", "bolt")
  end

  it "updates through the model's connection" do
    Widget.simple_query.where(name: "bolt").bulk_update(set: { name: "nut" })

    expect(Widget.order(:name).pluck(:name)).to eq(["gear", "nut"])
  end

  it "streams through the model's connection", if: Widget.connection.adapter_name.match?(/postg|mysql/i) do
    names = []
    Widget.simple_query.select(:name).stream_each { |row| names << row.name }

    expect(names).to contain_exactly("gear", "bolt")
  end

  it "sanitizes placeholder conditions with the model's connection" do
    allow(Widget.connection).to receive(:quote).and_call_original
    expect(ActiveRecord::Base.connection).not_to receive(:quote)

    result = Widget.simple_query.select(:name).where(["name = ?", "gear"]).execute

    expect(result.map(&:name)).to eq(["gear"])
    expect(Widget.connection).to have_received(:quote).with("gear")
  end

  context "when the model's adapter differs from ActiveRecord::Base's" do
    let(:postgres_primary) { ActiveRecord::Base.connection.adapter_name.match?(/postg/i) }

    before do
      allow(Widget.connection).to receive(:adapter_name).and_return(postgres_primary ? "Mysql2" : "PostgreSQL")
    end

    it "picks the group_concat dialect from the model's adapter" do
      sql = Widget.simple_query.group_concat(:name).build_query.to_sql

      expect(sql).to include(postgres_primary ? "SEPARATOR" : "STRING_AGG")
    end

    it "picks the stream_each implementation from the model's adapter" do
      builder = Widget.simple_query
      streamer = postgres_primary ? :stream_each_mysql : :stream_each_postgres
      allow(builder).to receive(streamer)

      builder.stream_each { |_row| }

      expect(builder).to have_received(streamer)
    end
  end
end
