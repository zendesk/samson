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
  end
end
