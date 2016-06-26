class Api::V1::ApplicationController < ActionController::Base
  include CurrentUser
  
  def login_user
    warden.authenticate(:basic) || unauthorized!
    PaperTrail.with_whodunnit(current_user.id) { yield }
  end
end
