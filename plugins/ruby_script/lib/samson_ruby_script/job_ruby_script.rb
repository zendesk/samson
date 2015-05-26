require 'samson/shell_script'

class JobRubyScript < Samson::ShellScript
  def initialize(job, reference, cache_dir, working_dir, output)
    @job = job
    @reference = reference
    @cache_dir = cache_dir
    @working_dir = working_dir
    super(output, verbose: true)
  end

  def commands
    @comnands ||= [
      "ENV['DEPLOYER']      = '#{@job.user.email.shellescape}'",
      "ENV['DEPLOYER_EMAIL']= '#{@job.user.email.shellescape}'",
      "ENV['DEPLOYER_NAME'] = '#{@job.user.name.shellescape}'",
      "ENV['REVISION']      = '#{@reference.shellescape}'",
      "ENV['TAG']           = '#{(@job.tag || @job.commit).to_s.shellescape}'",
      "ENV['CACHE_DIR']     = '#{@cache_dir}'",
      "Dir.chdir '#{@working_dir}'",
      *@job.commands
    ]
  end

  def execute!
    super(commands)
  end

  private

  def create_command(commands)
    command = commands.join("\n")
    cmd = "puts <<END_SAMSON_CMD\n#{command}\n----- Output Below -----\nEND_SAMSON_CMD\n#{command}"
    %Q{ruby -e "#{cmd.gsub(/"/, '\\"')}"}
  end

  def self.display_name
    'Ruby Script'
  end
end
