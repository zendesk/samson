require_relative "../test_helper"

SingleCov.not_covered!

describe SingleCov do
  describe ".file_under_test" do
    {
      "test/models/xyz_test.rb" => "app/models/xyz.rb",
      "test/lib/xyz_test.rb" => "lib/xyz.rb",
      "plugins/foo/test/lib/xyz_test.rb" => "plugins/foo/lib/xyz.rb",
      "plugins/foo/test/models/xyz_test.rb" => "plugins/foo/app/models/xyz.rb"
    }.each do |test, file|
      it "maps #{test} to #{file}" do
        actual = SingleCov.send(:file_under_test, "#{Rails.root}/#{test}:34:in `foobar'")
        actual.must_equal file
      end
    end
  end
end
