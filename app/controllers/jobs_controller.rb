class JobsController < ApplicationController
  def enabled
    if JobExecution.enabled
      head :no_content
    else
      head :accepted
    end
  end
end
