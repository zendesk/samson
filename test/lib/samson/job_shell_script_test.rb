require_relative '../../test_helper'

describe Samson::JobShellScript do
  let(:job) { jobs(:succeeded_test) }
  subject { Samson::JobShellScript.new(job, 'master', 'cache/dir', 'working/dir', StringIO.new) }

  describe '#commands' do
    it 'creates the appropriate script' do
      subject.commands.must_equal ['export DEPLOYER=super-admin@example.com',
                                   'export DEPLOYER_EMAIL=super-admin@example.com',
                                   'export DEPLOYER_NAME=Super\ Admin',
                                   'export REVISION=master',
                                   'export TAG=staging',
                                   'export CACHE_DIR=cache/dir',
                                   'cd working/dir',
                                   'cap staging deploy']
    end
  end

  describe '.display_name!' do
    it 'has set the appropriate name for UI' do
      Samson::JobShellScript.display_name.must_equal 'Bash Script'
    end
  end
end
