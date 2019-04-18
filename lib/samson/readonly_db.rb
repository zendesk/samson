# frozen_string_literal: true

# Make Activerecord readonly by blocking write requests
# NOTE: not perfect and can be circumvented with multiline sql statements or `;`
module Samson
  module ReadonlyDb
    ALLOWED = ["SELECT ", "SHOW ", "SET  @@SESSION.", "EXPLAIN ", "PRAGMA "].freeze
    PROMPT_CHANGE = ["(", "(readonly "].freeze
    PROMPTS = [:PROMPT_I, :PROMPT_N].freeze

    class << self
      def enable
        return if @subscriber
        @subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          sql = payload.fetch(:sql)
          next if sql.lstrip.start_with?(*ALLOWED)
          raise ActiveRecord::ReadOnlyRecord, <<~MSG
            Database is in readonly mode, cannot execute query
            Switch off readonly with #{self}.#{method(:disable).name}
            #{sql}
          MSG
        end
        update_prompt
      end

      def disable
        return unless @subscriber
        ActiveSupport::Notifications.unsubscribe @subscriber
        @subscriber = nil
        update_prompt
      end

      private

      # TODO: modify normal prompt when marco-polo is not enabled
      # TODO: pry support
      def update_prompt
        return unless defined?(IRB) # uncovered
        return unless prompt = IRB.conf.dig(:PROMPT, :RAILS_ENV)

        PROMPTS.each do |prompt_key|
          value = prompt.fetch(prompt_key) # change marco-polo prompt
          change = (@subscriber ? PROMPT_CHANGE : PROMPT_CHANGE.reverse)
          value.sub!(*change) || raise("Unable to change prompt #{prompt_key} #{value.inspect}")
        end
        nil
      end
    end
  end
end
