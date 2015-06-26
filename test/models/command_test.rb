require_relative '../test_helper'

describe Command do
  describe 'name' do
    it 'returns whole command as name' do
      command = commands(:echo)
      command.name.must_equal "echo hello"
    end

    it 'returns first line as name if strt with comment' do
      command = commands(:namecmd)
      command.name.must_equal "name cmd"
    end
  end
end
