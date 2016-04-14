require_relative "../test_helper"

SingleCov.not_covered!

describe SingleCov do
  let(:existing_file) { 'app/models/stage.rb' }

  around do |test|
    begin
      old = SingleCov::COVERAGES.dup
      SingleCov::COVERAGES.replace([])
      test.call
    ensure
      SingleCov::COVERAGES.replace(old)
    end
  end

  describe ".covered!" do
    it "adds found files into COVERAGES" do
      File.expects(:exist?).with("lib/single_cov.rb").returns true
      SingleCov.covered!
      SingleCov::COVERAGES.must_equal [["lib/single_cov.rb", 0]]
    end

    it "shows help for unfound guessed files" do
      e = assert_raises RuntimeError do
        SingleCov.covered!
      end
      e.message.must_include "guess covered file"
      e.message.must_include "file:"
    end

    it "shows help for unfound files" do
      e = assert_raises RuntimeError do
        SingleCov.covered! file: 'xxx.rb'
      end
      e.message.must_equal "xxx.rb does not exist and cannot be covered."
    end

    it "warns about files that would fail on other peoples machines" do
      e = assert_raises RuntimeError do
        SingleCov.covered! file: "#{Rails.root}/#{existing_file}"
      end
      e.message.must_include "relative"
    end
  end

  describe ".verify!" do
    # make sure we don't call exit by accident and make the test just stop
    before do
      SingleCov.expects(:exit).never
      SingleCov.expects(:warn).never
    end

    it "does nothing when nothing was covered" do
      SingleCov.verify!({})
    end

    it "does nothing when coverage is perfect" do
      SingleCov.covered! file: existing_file
      SingleCov.verify!(File.expand_path(existing_file) => [])
      SingleCov.verify!(File.expand_path(existing_file) => [1, nil, 1, nil])
      SingleCov.verify!(File.expand_path(existing_file) => [1, 1, 1, 1])
    end

    it "does nothing when coverage matches expected level" do
      SingleCov.covered! file: existing_file, uncovered: 3
      SingleCov.verify!(File.expand_path(existing_file) => [0,0,0])
      SingleCov.verify!(File.expand_path(existing_file) => [1, 0, 1, nil, 0, 0])
    end

    it "warns about files that were already loaded" do
      file = 'test/test_helper.rb'
      SingleCov.covered! file: file
      SingleCov.expects(:warn).with(["#{file} was expected to be covered, but already loaded before tests started."])
      SingleCov.expects(:exit).with(1)
      SingleCov.verify!({})
    end

    it "warns about files that were never loaded" do
      file = 'db/seeds.rb'
      SingleCov.covered! file: file
      SingleCov.expects(:warn).with(["#{file} was expected to be covered, but never loaded."])
      SingleCov.expects(:exit).with(1)
      SingleCov.verify!({})
    end

    it "does not spam when to many things failed" do
      max = 40
      SingleCov.covered! file: existing_file
      SingleCov.expects(:warn).with { |list| list.join("\n").count("\n").must_be :==, max; true }
      SingleCov.expects(:exit).with(1)
      SingleCov.verify!({File.expand_path(existing_file) => Array.new(100) { 0 }})
    end
  end

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
