# frozen_string_literal: true

# Make Activerecord readonly by blocking write requests
module Samson
  module ReadonlyDb
    PROMPT_CHANGE = ["(", "(readonly "].freeze
    PROMPTS = [:PROMPT_I, :PROMPT_N].freeze

    module ErrorInformer
      def initialize(message)
        message += "\nSwitch off readonly with Samson::ReadonlyDb.disable" if Samson::ReadonlyDb.enabled?
        super
      end
    end

    class << self
      def enable
        ActiveRecord::ReadOnlyError.prepend ErrorInformer if @enabled.nil?
        toggle true
      end

      def disable
        toggle false
      end

      def enabled?
        @enabled
      end

      private

      def toggle(to)
        return if !!@enabled == to
        @enabled = to
        # what .connected_to does under the hood, but without block
        stack = ActiveRecord::Base.connected_to_stack
        if @enabled
          stack << {role: :writing, prevent_writes: true, klasses: [ActiveRecord::Base]}
        else
          stack.pop
        end
        update_prompt
      end

      # TODO: modify normal prompt when marco-polo is not enabled
      # TODO: pry support
      def update_prompt
        return unless defined?(IRB) # uncovered
        return unless prompt = IRB.conf.dig(:PROMPT, :RAILS_ENV)

        PROMPTS.each do |prompt_key|
          value = prompt.fetch(prompt_key) # change marco-polo prompt
          change = (@enabled ? PROMPT_CHANGE : PROMPT_CHANGE.reverse)
          value.sub!(*change) || raise("Unable to change prompt #{prompt_key} #{value.inspect}")
        end
        nil
      end
    end
  end
end
