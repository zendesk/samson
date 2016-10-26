# frozen_string_literal: true
class VersionsController < ApplicationController
  def index
    versions = PaperTrail::Version.where(
      item_id: params.require(:item_id),
      item_type: params.require(:item_type)
    ).order('created_at desc')
    @versions = versions_with_diff(versions)
  end

  private

  # version holds the previous state of the object
  # for each version calculate the diff to the previous version
  # or to the current state for the first version
  def versions_with_diff(versions)
    begin
      item = versions[0]&.item
    rescue NameError
      nil
    end
    current = (item ? item.send(:object_attrs_for_paper_trail, item.attributes) : {})

    versions.map do |v|
      previous = YAML.load(v.object || {}.to_yaml) # version from `create` has no object
      diff = hash_diff(current, previous)
      current = previous
      [v, diff]
    end
  end

  # {a: 1}, {a:2, b:3} -> [[:a, 1, 2], [:b, nil, 3]]
  def hash_diff(a, b)
    (b.keys + a.keys).uniq.map { |k| [k, b[k], a[k]] }.select { |_, p, c| p != c }
  end
end
