# frozen_string_literal: true
module Samson
  module Retry
    def self.retry_when_not_unique(&block)
      with_retries [ActiveRecord::RecordNotUnique], 1, &block
    end

    def self.with_retries(errors, count, only_if: nil, wait_time: nil)
      yield
    rescue *errors
      count -= 1
      if count >= 0 && (!only_if || only_if.call($!))
        sleep(wait_time) if wait_time
        retry
      else
        raise
      end
    end

    def self.until_result(tries:, wait_time:, error:)
      loop do
        tries -= 1
        result = yield
        return result if result
        if tries == 0
          error ? raise(error) : return
        end
        sleep(wait_time)
      end
    end
  end
end
