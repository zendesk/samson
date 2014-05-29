require 'soft_deletion'
require 'digest/md5'

class User < ActiveRecord::Base
  has_soft_deletion default_scope: true

  has_many :commands
  has_many :stars
  has_many :starred_projects, through: :stars, source: :project

  validates :role_id, inclusion: { in: Role.all.map(&:id) }

  before_create :set_token

  def starred_project?(project)
    starred_projects.include?(project)
  end

  def self.create_or_update_from_hash(hash)
    user = User.where(external_id: hash[:external_id]).first
    user ||= User.where(email: hash[:email]).first
    user ||= User.new

    # attributes are always a string hash
    attributes = user.attributes.merge(hash.stringify_keys) do |key, old, new|
      if key == 'role_id'
        if !User.exists?
          Role::SUPER_ADMIN.id
        elsif new && (user.new_record? || new >= old)
          new
        else
          old
        end
      else
        old.presence || new
      end
    end

    user.attributes = attributes
    user.save
    user
  end

  def name
    super.presence || email
  end

  def name_and_email
    "#{name} (#{email})"
  end

  def avatar_url
    if Rails.application.config.samson.github.use_identicons
      identicon_url
    else
      gravatar_url
    end
  end

  def gravatar_url
    md5 = Digest::MD5.hexdigest(email)
    "https://www.gravatar.com/avatar/#{md5}"
  end

  def identicon_url
    github_username = email.split('@').first
    "https://#{Rails.application.config.samson.github.web_url}/identicons/#{github_username}.png"
  end

  Role.all.each do |role|
    define_method "is_#{role.name}?" do
      role_id >= role.id
    end
  end

  private

  def set_token
    self.token = SecureRandom.hex
  end
end
