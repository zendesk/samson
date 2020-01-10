# frozen_string_literal: true

# Make Activerecord readonly by blocking write requests
# NOTE: not perfect and can be circumvented with multiline sql statements or `;`
module Samson
  module ReadonlyDb
    module ReadonlyEnforcer
      # mysql, sqlite, postgres
      [:execute, :exec_query, :execute_and_clear].each do |method|
        eval <<~RUBY, nil, __FILE__, __LINE__ + 1 # rubocop:disable Security/Eval
          def #{method}(sql, *)
            Samson::ReadonlyDb.check_sql(sql)
            super
          end
        RUBY
      end
    end

    ALLOWED = ["SELECT ", "SHOW ", "SET  @@SESSION.", "SET NAMES", "EXPLAIN ", "PRAGMA "].freeze
    PROMPT_CHANGE = ["(", "(readonly "].freeze
    PROMPTS = [:PROMPT_I, :PROMPT_N].freeze

    class << self
      def enable
        return if @enabled

        if @enabled.nil? # only add patch on first enable
          ActiveRecord::Base.connection.class.prepend(ReadonlyEnforcer)
        end

        @enabled = true
        update_prompt
      end

      def disable
        @enabled = false
        update_prompt
      end

      def check_sql(sql)
        return if !@enabled || sql.lstrip.start_with?(*ALLOWED)
        raise ActiveRecord::ReadOnlyRecord, <<~MSG
          Database is in readonly mode, cannot execute query
          Switch off readonly with Samson::ReadonlyDb.disable
          #{sql}
        MSG
      end

      private

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
