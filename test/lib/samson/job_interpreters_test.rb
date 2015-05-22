require_relative '../../test_helper'

describe Samson::JobInterpreters do
  subject { Samson::JobInterpreters.instance }
  before { Samson::JobInterpreters.instance_variable_set(:@singleton__instance__, nil) }

  describe '#initialize' do
    it 'is a singleton' do
      subject.wont_be_nil
    end

    it 'registers bash interpreter by default' do
      subject.interpreters.must_equal [ Samson::JobShellScript ]
    end
  end

  describe '#register' do
    it 'can register classes that implement self.name' do
      class MyFakeScripter
        def self.display_name
          'Fake Script'
        end
      end
      subject.register MyFakeScripter
      subject.interpreters.must_equal(
        [ Samson::JobShellScript, MyFakeScripter ])
    end

    it 'cannot register classes that do not implement self.name' do
      class MyFakeBadScripter; end
      assert_raises RuntimeError do
        subject.register(MyFakeBadScripter)
      end
      subject.interpreters.must_equal [ Samson::JobShellScript ]
    end
  end

  describe '#select_options' do
    it 'gets arrays for passing to select_tag' do
      subject.select_options.must_equal [['Bash Script', Samson::JobShellScript]]
    end

    it 'gets arrays for passing to select_tag with custom interpreter' do
      class MyFakeScripter
        def self.display_name
          'Fake Script'
        end
      end
      subject.register MyFakeScripter
      subject.select_options.must_equal [['Bash Script', Samson::JobShellScript], ['Fake Script', MyFakeScripter]]
    end
  end
end
