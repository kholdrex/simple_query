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
end
