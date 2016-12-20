# frozen_string_literal: true
class Setting < ActiveRecord::Base
  has_paper_trail skip: [:updated_at, :created_at, :comment]

  validates :name, presence: true, format: /\A[A-Z\d_]+\z/
end
