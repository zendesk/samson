# frozen_string_literal: true
require 'pagy/extras/array'
require 'pagy/extras/bootstrap'
require 'pagy/extras/overflow'

# pagination after last page renders an empty page
Pagy::Backend.prepend(Module.new do
  private

  def pagy(collection, options)
    super collection, options.merge(overflow: :empty_page)
  end
end)
