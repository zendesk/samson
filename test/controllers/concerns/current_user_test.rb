require_relative '../../test_helper'

SingleCov.covered! uncovered: 2

describe "CurrentUser included in controller" do
  class CurrentUserTestController < ApplicationController
    include CurrentUser

    def whodunnit
      render text: PaperTrail.whodunnit.to_s.dup
    end

    def change
      Stage.find(params[:id]).update_attribute(:name, 'MUUUU')
      head :ok
    end
  end

  tests CurrentUserTestController
  use_test_routes

  as_a_viewer do
    around { |t| PaperTrail.with_whodunnit(nil, &t) }

    it "knows who did something" do
      get :whodunnit, test_route: true
      response.body.must_equal users(:viewer).id.to_s
    end

    it "does not assign to different users by accident" do
      before = PaperTrail.whodunnit # FIXME: this is not nil on travis ... capturing current value instead
      get :whodunnit, test_route: true
      PaperTrail.whodunnit.must_equal before
    end

    it "records changes" do
      stage = stages(:test_staging)
      PaperTrail.with_logging do
        get :change, test_route: true, id: stage.id
      end
      stage.reload.name.must_equal 'MUUUU'
      stage.versions.size.must_equal 1
    end
  end
end
