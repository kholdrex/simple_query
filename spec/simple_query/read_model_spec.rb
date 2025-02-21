# frozen_string_literal: true

require "spec_helper"

RSpec.describe SimpleQuery::ReadModel do
  describe ".attribute" do
    it "defines attribute readers (no writers)" do
      model = TestReadModel.build_from_row({})

      expect(model).to respond_to(:foo)
      expect(model).to respond_to(:bar)
      expect(model).not_to respond_to(:foo=)
      expect(model).not_to respond_to(:bar=)
    end

    it "maps custom column names to attributes" do
      row_hash = { "baz" => "SomeBarValue" }
      model = TestReadModel.build_from_row(row_hash)
      expect(model.bar).to eq("SomeBarValue")
    end
  end

  describe ".build_from_row" do
    it "sets instance variables directly from the row hash" do
      row_hash = { "foo" => "FooValue", "baz" => "BarValue" }
      model = TestReadModel.build_from_row(row_hash)
      expect(model.foo).to eq("FooValue")
      expect(model.bar).to eq("BarValue")
    end

    it "handles missing keys gracefully by leaving attributes as nil" do
      row_hash = { "foo" => "OnlyFoo" }
      model = TestReadModel.build_from_row(row_hash)
      expect(model.foo).to eq("OnlyFoo")
      expect(model.bar).to be_nil
    end
  end

  describe ".attributes" do
    it "returns a hash of defined attributes and their column mappings" do
      expected = { foo: "foo", bar: "baz" }
      expect(TestReadModel.attributes).to eq(expected)
    end
  end
end
