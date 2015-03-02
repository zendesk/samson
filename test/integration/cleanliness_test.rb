require_relative '../test_helper'

# kitchen sink for 1-off tests
describe "cleanliness" do
  it "does not have boolean limit 1 in schema since this breaks mysql" do
    File.read("db/schema.rb").wont_match /\st\.boolean.*limit: 1/
  end
end
