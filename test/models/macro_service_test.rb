require_relative '../test_helper'

describe MacroService do
  let(:macro) { macros(:test) }
  let(:user) { users(:deployer) }
  let(:project) { projects(:test) }
  let(:service) { MacroService.new(project, user) }

  it 'creates a new job' do
    job = service.execute!(macro)
    job.persisted?.must_equal(true)
    job.command.must_equal("echo hello\nseq 1 5")
    job.user.must_equal(user)
    job.project.must_equal(project)
  end
end
