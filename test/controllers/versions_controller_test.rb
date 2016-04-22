require_relative '../test_helper'

SingleCov.covered!

describe VersionsController do
  def create_version(id)
    PaperTrail.with_whodunnit(id) do
      PaperTrail.with_logging do
        stage.update_attribute(:name, 'Fooo')
      end
    end
  end

  let(:stage) { stages(:test_staging) }

  as_a_viewer do
    describe "#index" do
      it "renders" do
        create_version user.id
        get :index, item_id: stage.id, item_type: stage.class.name
        assert_template :index
      end

      it "renders with unfound user" do
        create_version '1211212'
        get :index, item_id: stage.id, item_type: stage.class.name
        assert_template :index
      end
    end
  end
end
