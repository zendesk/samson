class CsvExport < ActiveRecord::Base
  belongs_to :user
  serialize :filters, JSON
  STATUS_VALUES = [nil, 'pending', 'started', 'finished', 'downloaded', 'failed', 'deleted']

  before_create :set_defaults
  before_destroy :delete_file

  validates :status, inclusion: { in: STATUS_VALUES }
  delegate :email, to: :user, allow_nil: true


  scope :old, lambda {
    end_date = Time.now - Rails.application.config.samson.export_job.downloaded_age
    timeout_date = Time.now - Rails.application.config.samson.export_job.max_age
    where("(status = 'downloaded' AND updated_at <= :end_date) OR updated_at <= :timeout_date",
    {end_date: end_date, timeout_date: timeout_date})
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
    filter = super || {}
    if filter['deploys.created_at'].is_a?(String)
      dates = filter['deploys.created_at'].scan(/-?\d+-\d+-\d+/)
      filter['deploys.created_at'] = (Date.parse(dates[0])..Date.parse(dates[1]))
    end
    filter
  end

  def status!(status)
    update_attributes!(status: status)
  end

  def delete_file
    if File.exist?(path_file)
      File.delete(path_file)
      if File.exist?(path_file)
        Rails.logger.error "Failed to delete file #{path_file}"
      else
        Rails.logger.info "Successfully deleted file #{path_file}"
      end
    end
  end

  private

  def set_defaults
    self.status ||= :pending
    self.filters ||= {}
  end
end
