# frozen_string_literal: true
require_relative '../test_helper'

SingleCov.covered!

describe ChangelogsController do
  let(:project) { projects(:test) }

  as_a_viewer do
    describe "#show" do
      it "renders recent logs by default" do
        today = Date.parse('2016-03-01')
        Date.stubs(:today).returns(today)
        Changeset.expects(:new).with(
          'bar/foo',
          'master@{2016-02-26}',
          'master@{2016-03-01}'
        ).returns(stub(pull_requests: []))
        get :show, project_id: project
        assert_template :show
      end

      it "renders requested dates" do
        Changeset.expects(:new).with(
          'bar/foo',
          'master@{2016-01-01}',
          'master@{2016-02-01}'
        ).returns(stub(pull_requests: []))
        get :show, project_id: project, start_date: '2016-01-01', end_date: '2016-02-01'
        assert_template :show
      end
    end
  end
end
