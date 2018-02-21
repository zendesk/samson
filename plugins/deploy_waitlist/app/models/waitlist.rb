class Waitlist
  attr_reader :project_id, :stage_id, :deployers

  WAITLIST_KEY = 'deploy_waitlist'.freeze

  def initialize(project_id, stage_id)
    @project_id = project_id
    @stage_id = stage_id
  end

  # [{deployer: [email], added: [utc]}, ...]
  def deployers
    @deployers ||= Rails.cache.read(key) || []
  end

  def remove(index)
    current_list = deployers
    deployers = current_list unless current_list.delete_at(index).nil?
    head_since = now if (index == 0)
  end

  def deployers=(list_of_deployers)
    return unless list_of_deployers.present?
    Rails.cache.write(key, list_of_deployers)
  end

  def head_since
    @head_since ||= fetch :head_since
  end

  def head_since=(utc_date)
    update(head_since: utc_date)
  end

  def created_at
    @created_at ||= fetch :created_at
  end

  def def created_at=(utc_date)
    update(created_at: utc_date)
  end

  private

  def fetch(field)
    return nil unless metadata.present?
    metadata[field]
  end

  def update(args_harsh)
    metadata = metadata.merge(args_harsh).merge(last_updated: Time.now.utc)
  end

  def metadata
    @metadata ||= Rails.cache.read(metadata_key) || { created_at: Time.now.utc }
  end

  def metadata=(metadata_hash)
    return unless metadata_hash.present?
    Rails.cache.write(metadata_key, metadata_hash)
  end

  def key
    WAITLIST_KEY + queue_key_part
  end

  def metadata_key
    metadata_key_part + queue_key_part
  end

  def metadata_key_part
    WAITLIST_KEY + '.metadata'
  end

  def queue_key_part
    ".project-#{project_id}.stage-#{stage_id}"
  end
end
