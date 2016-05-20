class CsvExport < ActiveRecord::Base
  belongs_to :user
  serialize :filters, JSON
  STATUS_VALUES = ['pending', 'started', 'finished', 'downloaded', 'failed', 'deleted'].freeze

  before_destroy :delete_file

  validates :status, inclusion: { in: STATUS_VALUES }
  delegate :email, to: :user, allow_nil: true

  scope :old, lambda {
    end_date = Rails.application.config.samson.export_job.downloaded_age.seconds.ago
    timeout_date = Rails.application.config.samson.export_job.max_age.seconds.ago
    where("(status = 'downloaded' AND updated_at <= :end_date) OR created_at <= :timeout_date",
      end_date: end_date, timeout_date: timeout_date)
  }

  def status?(state)
    'ready' == state.to_s ? ['downloaded', 'finished'].include?(status) : status == state.to_s
  end

  def download_name
    "deploys_#{created_at.to_s(:number)}.csv"
  end

  def path_file
    "#{Rails.root}/export/#{id}"
  end

  def filters
    filter = super.clone
    if filter['deploys.created_at']
      dates = filter['deploys.created_at'].scan(/-?\d+-\d+-\d+/)
      filter['deploys.created_at'] = (Date.parse(dates[0])..Date.parse(dates[1]))
    end
    filter
  end

  def status!(status)
    update_attributes!(status: status)
  end

  def delete_file
    File.delete(path_file) if File.exist?(path_file)
  end
end
