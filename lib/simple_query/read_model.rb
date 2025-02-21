# frozen_string_literal: true

module SimpleQuery
  class ReadModel
    def self.attribute(attr_name, column: attr_name)
      @attributes ||= {}
      @attributes[attr_name] = column.to_s
      attr_reader attr_name
    end

    def self.attributes
      @attributes || {}
    end

    def self.build_from_row(row_hash)
      obj = allocate
      attributes.each do |attr_name, column_name|
        obj.instance_variable_set(:"@#{attr_name}", row_hash[column_name])
      end
      obj
    end

    def initialize; end
  end
end
