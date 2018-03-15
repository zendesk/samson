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
    deploys = production_stages.map do |stage|
      stage.deploys.where(created_at: (1.year.ago...Time.zone.local.new(2018, 3, 16))).select(&:succeeded?).first
    end

    deploys.each { |deploy| SamsonGcloud::ImageTagger.tag(deploy) }
  end
end
