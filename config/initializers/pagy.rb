# frozen_string_literal: true
require 'pagy/extras/array'
require 'pagy/extras/bootstrap'

# https://github.com/ddnexus/pagy/issues/68
Pagy::Backend.prepend(
  Module.new do
    private

    def pagy(*args)
      super
    rescue Pagy::OutOfRangeError => e
      e.pagy.instance_variable_set(:@page, e.pagy.last)
      [e.pagy, []]
    end
  end
)
