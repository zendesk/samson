# frozen_string_literal: true
class Waitlist
  attr_reader :project_id, :stage_id, :list, :metadata

  WAITLIST_KEY = 'deploy_waitlist'
  METADATA_KEY = '.metadata'

  def initialize(project_id, stage_id)
    @project_id = project_id
    @stage_id = stage_id
    @list = Rails.cache.read(key) || []
    @metadata = Rails.cache.read(metadata_key) || {}
  end

  def add(deployer_hash = {})
    @list << deployer_hash
    @metadata[:last_updated] = Time.now
    @metadata[:head_updated_at] = Time.now if @list.size == 1
    set
  end

  def remove(index)
    @list.delete_at(index)
    @metadata[:last_updated] = Time.now
    @metadata[:head_updated_at] = Time.now if index == 0
    set
  end

  # accessors for the view
  def created_at
    @metadata[:created_at]
  end

  def head_updated_at
    @metadata[:head_updated_at]
  end

  def head_locked?
    return false if @list.blank?
    stage = Stage.find @stage_id
    return false if stage.lock.blank?
    stage.lock.user.email == list[0][:email]
  end

  def to_json(*_args)
    {
      created_at: created_at,
      head_updated_at: head_updated_at,
      head_is_locked: head_locked?,
      list: list
    }
  end

  private

  def set
    Rails.cache.write(key, @list)
    @metadata[:created_at] = Time.now unless @metadata[:created_at]
    Rails.cache.write(metadata_key, @metadata)
  end

  def key
    WAITLIST_KEY + stage_key
  end

  def metadata_key
    "#{WAITLIST_KEY}.{METADATA_KEY}#{stage_key}"
  end

  def stage_key
    ".project-#{project_id}.stage-#{stage_id}"
  end
end
