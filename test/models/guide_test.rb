require_relative '../test_helper'

describe Guide do
  let(:guide) { guides(:test) }

  it "requires a project_id" do
    guide = Guide.create(body: "foo")
    guide.errors.messages.must_equal project_id: ["can't be blank"]
  end
end
