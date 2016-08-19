# frozen_string_literal: true
class VersionsController < ApplicationController
  def index
    @versions = PaperTrail::Version.where(
      item_id: params.require(:item_id),
      item_type: params.require(:item_type)
    ).order('created_at desc')
  end
end
