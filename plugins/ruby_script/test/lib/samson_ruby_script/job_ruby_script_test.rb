require_relative '../../test_helper'

describe JobRubyScript do
  let(:job) { jobs(:succeeded_test) }
  subject { JobRubyScript.new(job, 'master', 'cache/dir', 'working/dir', StringIO.new) }

  describe '#commands' do
    it 'creates the appropriate script' do
      subject.commands.must_equal ["ENV['DEPLOYER']      = '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_EMAIL']= '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_NAME'] = '#{job.user.name.shellescape}'",
                                   "ENV['REVISION']      = 'master'",
                                   "ENV['TAG']           = 'staging'",
                                   "ENV['CACHE_DIR']     = 'cache/dir'",
                                   "Dir.chdir 'working/dir'",
                                   'cap staging deploy']
    end
  end

  describe '.display_name!' do
    it 'has set the appropriate name for UI' do
      JobRubyScript.display_name.must_equal 'Ruby Script'
    end
  end
end
