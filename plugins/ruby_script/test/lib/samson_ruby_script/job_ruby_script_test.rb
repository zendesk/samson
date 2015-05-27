require_relative '../../test_helper'

describe JobRubyScript do
  let(:job) { jobs(:succeeded_test) }
  let(:output) { StringIO.new }

  subject { JobRubyScript.new(job, 'master', 'cache/dir', './', output) }

  describe '#commands' do
    it 'creates the appropriate script' do
      job.update(command: 'puts "Hello World"')
      subject.commands.must_equal ["ENV['DEPLOYER']      = '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_EMAIL']= '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_NAME'] = '#{job.user.name.shellescape}'",
                                   "ENV['REVISION']      = 'master'",
                                   "ENV['TAG']           = 'staging'",
                                   "ENV['CACHE_DIR']     = 'cache/dir'",
                                   "Dir.chdir './'",
                                   'puts "Hello World"']
    end

    it 'allows for special chars' do
      script = <<-'CODE'
        class FooBar
          def initialize(foo: 123, bar: )
          end

          def malicious
            puts ';|\sudo make-sandwich'
          end
        end
      CODE
      job.update(command: script)
      subject.commands.must_equal ["ENV['DEPLOYER']      = '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_EMAIL']= '#{job.user.email.shellescape}'",
                                   "ENV['DEPLOYER_NAME'] = '#{job.user.name.shellescape}'",
                                   "ENV['REVISION']      = 'master'",
                                   "ENV['TAG']           = 'staging'",
                                   "ENV['CACHE_DIR']     = 'cache/dir'",
                                   "Dir.chdir './'",
                                   *script.split("\n")]
    end
  end

  describe '#execute' do
    it 'executes simple ruby script' do
      job.update(command: 'puts "Hello World"')
      subject.execute!
      output.string.must_equal [ "ENV['DEPLOYER']      = 'super-admin@example.com'",
                                 "ENV['DEPLOYER_EMAIL']= 'super-admin@example.com'",
                                 "ENV['DEPLOYER_NAME'] = 'Super Admin'",
                                 "ENV['REVISION']      = 'master'",
                                 "ENV['TAG']           = 'staging'",
                                 "ENV['CACHE_DIR']     = 'cache/dir'",
                                 "Dir.chdir './'",
                                 "puts \"Hello World\"",
                                 '----- Output Below -----',
                                 "Hello World\r\n",
                               ].join("\r\n")
    end

    it 'executes complex ruby script' do
      script = <<-'CODE'
        class FooBar
          def initialize(foo: 123, bar: )
            @foo, @bar = [foo, bar]
          end
          def malicious
            puts ';|\sudo make-sandwich'
            puts "bar = #{@bar}"
          end
          def gcd(a,b)
            return a if b == 0
            gcd(b, a % b)
          end
        end
        f = FooBar.new(foo: 'hello', bar: 'world')
        f.malicious
        puts f.gcd(11,15)
      CODE
      job.update(command: script)
      subject.execute!
      output.string.must_equal [ "ENV['DEPLOYER']      = 'super-admin@example.com'",
                                 "ENV['DEPLOYER_EMAIL']= 'super-admin@example.com'",
                                 "ENV['DEPLOYER_NAME'] = 'Super Admin'",
                                 "ENV['REVISION']      = 'master'",
                                 "ENV['TAG']           = 'staging'",
                                 "ENV['CACHE_DIR']     = 'cache/dir'",
                                 "Dir.chdir './'",
                                 '        class FooBar',
                                 '          def initialize(foo: 123, bar: )',
                                 '            @foo, @bar = [foo, bar]',
                                 '          end',
                                 '          def malicious',
                                 "            puts ';| udo make-sandwich'",
                                 "            puts \"bar = \"",
                                 '          end',
                                 '          def gcd(a,b)',
                                 '            return a if b == 0',
                                 '            gcd(b, a % b)',
                                 '          end',
                                 '        end',
                                 "        f = FooBar.new(foo: 'hello', bar: 'world')",
                                 '        f.malicious',
                                 '        puts f.gcd(11,15)',
                                 '----- Output Below -----',
                                 ";|\\sudo make-sandwich",
                                 'bar = world',
                                 "1\r\n",].join("\r\n")
    end
  end

  describe '.display_name!' do
    it 'has set the appropriate name for UI' do
      JobRubyScript.display_name.must_equal 'Ruby Script'
    end
  end
end
