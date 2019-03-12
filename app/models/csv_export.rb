# frozen_string_literal: true
class CsvExport < ActiveRecord::Base
  belongs_to :user
  serialize :filters, JSON
  STATUS_VALUES = ['pending', 'started', 'finished', 'downloaded', 'failed', 'deleted'].freeze

  before_destroy :delete_file

  validates :status, inclusion: {in: STATUS_VALUES}
  delegate :email, to: :user, allow_nil: true

  scope :old, -> {
    end_date = Rails.application.config.samson.export_job.downloaded_age.seconds.ago
    timeout_date = Rails.application.config.samson.export_job.max_age.seconds.ago
    where(
      "(status = 'downloaded' AND updated_at <= :end_date) OR created_at <= :timeout_date",
      end_date: end_date, timeout_date: timeout_date
    )
  }

  def status?(state)
    state.to_s == 'ready' ? ['downloaded', 'finished'].include?(status) : status == state.to_s
  end

  def download_name
    "deploys_#{filters_project}#{created_at.to_s(:number)}.csv"
  end

  def path_file
    "#{Rails.root}/export/#{id}"
  end

  def filters
    filter = super.clone
    if filter['deploys.created_at']
      dates = filter['deploys.created_at'].scan(/-?\d+-\d+-\d+/)
      filter['deploys.created_at'] = (Time.parse(dates[0] + "T00:00:00Z")..Time.parse(dates[1] + "T23:59:59Z"))
    end
    filter
  end

  def filters_project
    if id = filters['stages.project_id']
      proj = Project.with_deleted { Project.where(id: id).first&.permalink }
      proj + '_' if proj
    end
  end

  def status!(status)
    update_attributes!(status: status)
  end

  def delete_file
    File.delete(path_file) if File.exist?(path_file)
  end
end
