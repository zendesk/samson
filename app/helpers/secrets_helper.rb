# frozen_string_literal: true
module SecretsHelper
  SECRET_USER_VALUES = [:creator_id, :updater_id].freeze

  def render_secret_attribute(attribute, value)
    @render_secret_attribute_cache ||= Hash.new { |h, k| h[k] = User.find_by_id(k) }
    return value unless SECRET_USER_VALUES.include?(attribute)
    return "Unknown user #{value}" unless user = @render_secret_attribute_cache[value]
    link_to user.name_and_email, user
  end
end
