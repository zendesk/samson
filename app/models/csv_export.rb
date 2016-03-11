class CsvExport < ActiveRecord::Base
  include Searchable

  has_soft_deletion default_scope: true

  belongs_to :user

  def pending?
    return  status == 'pending'
  end

  def started?
    return  status == 'started'
  end

  def finished?
    return  status == 'finished'
  end

  def downloaded?
    return  status == 'downloaded'
  end

  def failed?
    return  status == 'failed'
  end

  def deleted?
    return  status == 'deleted'
  end

  def email
    if user.nil?
      nil
    else
      user.email
    end
  end
  
  def filename
    super || generate_csv_filename
  end
  
  def pending!
    status!("pending")
  end
  
  def started!
    status!("started")
  end
  
  def finished!
    status!("finished")
  end
  
  def failed!
    status!("failed")
  end
  
  def downloaded!
    status!("downloaded")
  end
  
  def deleted!
    status!("deleted")
  end
  
  private

  def generate_csv_filename
    datetime = Time.now.strftime "%Y%m%d_%H%M%S"
    filename = "#{self.content}_#{datetime}.csv"
    update_attribute(:filename, filename)
    filename
  end
  
  def status!(status)
    update_attribute(:status, status)
  end
end
