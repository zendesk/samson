# frozen_string_literal: true
module StructHelper
  def create_singleton_struct(name, *fields)
    if Struct.const_defined?(name)
      Struct.const_get(name)
    else
      Struct.new(name, *fields)
    end
  end
end
