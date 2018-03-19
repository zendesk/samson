# frozen_string_literal: true

namespace :tools do
  desc "Updates all production builds with 'production' tag"
  task tag_production_images: :environment do
    Job.prepend(Module.new do
      def append_output!(more)
        puts more
        super
      end
    end)

    production_stages = Stage.where.not(permalink: 'production').select(&:production?)

    ids = Deploy.
      reorder(nil).
      successful.
      where(stage_id: production_stages.map(&:id), created_at: (1.year.ago...Time.parse('2018-03-16'))).
      group(:stage_id).
      pluck('max(deploys.id)')

    Deploy.find(ids).each { |deploy| SamsonGcloud::ImageTagger.tag(deploy) }
  end
end
