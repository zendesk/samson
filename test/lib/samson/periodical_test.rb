# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered! uncovered: (ENV["TRAVIS"] ? 2 : 1)

describe Samson::Periodical do
  def with_registered
    registered = Samson::Periodical.send(:registered)
    old = registered[:periodical_deploy].dup
    registered[:periodical_deploy].merge!(execution_interval: 86400, active: true)
    yield
  ensure
    registered[:periodical_deploy].replace old
  end
  let(:custom_error) { Class.new(StandardError) }

  after { maxitest_kill_extra_threads } # concurrent leaves a bunch of threads running

  around do |test|
    begin
      Samson::Periodical.enabled = true
      test.call
    ensure
      Samson::Periodical.enabled = false
    end
  end

  around do |test|
    begin
      old_registered = Samson::Periodical.instance_variable_get(:@registered).deep_dup
      Samson::Periodical.instance_variable_set(:@env_settings, nil)
      test.call
    ensure
      Samson::Periodical.instance_variable_set(:@registered, old_registered)
      Samson::Periodical.instance_variable_set(:@env_settings, nil)
    end
  end

  describe ".register" do
    it "adds a hook" do
      x = 2
      Samson::Periodical.register(:foo, 'bar') { x = 1 }
      Samson::Periodical.run_once(:foo)
      x.must_equal 1
    end
  end

  describe ".overdue?" do
    with_env PERIODICAL: 'bar:10'

    before do
      Samson::Periodical.register(:foo, 'bar') { 111 }
      Samson::Periodical.register(:bar, 'bar') { 111 }
    end

    it "is overdue when it missed 2 intervals" do
      assert Samson::Periodical.overdue?(:foo, 2.minutes.ago - 2)
    end

    it "is overdue when it missed 1 intervals" do
      refute Samson::Periodical.overdue?(:foo, 2.minutes.ago + 2)
    end

    it "is overdue when it missed 2 custom intervals" do
      assert Samson::Periodical.overdue?(:bar, 25.seconds.ago)
    end

    it "fails on unknown" do
      assert_raises(KeyError) { Samson::Periodical.overdue?(:baz, 25.seconds.ago) }
    end
  end

  describe ".run_once" do
    it "runs" do
      Lock.expects(:remove_expired_locks)
      Samson::Periodical.run_once(:remove_expired_locks)
    end

    it "sends errors to error notifier" do
      Lock.expects(:remove_expired_locks).raises custom_error
      ErrorNotifier.expects(:notify).
        with(instance_of(custom_error), error_message: "Samson::Periodical remove_expired_locks failed")
      Samson::Periodical.run_once(:remove_expired_locks)
    end
  end

  # starts background threads and should always shut them down
  describe ".run" do
    with_env PERIODICAL: 'foo'

    it "runs active tasks" do
      x = 2
      Samson::Periodical.register(:foo, 'bar') { x = 1 }
      tasks = Samson::Periodical.run
      sleep 0.05 # let task execute
      tasks.first.shutdown
      x.must_equal 1
    end

    it "does not run inactive tasks" do
      Samson::Periodical.register(:bar, 'bar') {}
      Samson::Periodical.run.must_equal []
    end

    it 'does not run tasks when disabled' do
      Samson::Periodical.enabled = false

      Samson::Periodical.register(:bar, 'bar') {}
      Samson::Periodical.run.must_equal []
    end

    it "sends errors to error notifier" do
      ErrorNotifier.expects(:notify).with(instance_of(ArgumentError), error_message: "Samson::Periodical foo failed")
      Samson::Periodical.register(:foo, 'bar', now: true) { raise ArgumentError }
      tasks = Samson::Periodical.run
      sleep 0.05 # let task execute
      tasks.first.shutdown
    end

    it "does not block server boot when initial run is inline and fails" do
      ErrorNotifier.expects(:notify).with(instance_of(ArgumentError), error_message: "Samson::Periodical foo failed")
      Samson::Periodical.register(:foo, 'bar') { raise ArgumentError }
      tasks = Samson::Periodical.run
      tasks.first.shutdown
    end
  end

  describe ".configs_from_string" do
    def call(*args)
      Samson::Periodical.send(:configs_from_string, *args)
    end

    it "is empty for nil" do
      call(nil).must_equal({})
    end

    it "is empty for empty" do
      call('').must_equal({})
    end

    it "can configure by name" do
      call('foo').must_equal(foo: {active: true})
    end

    it "can configure with muliple names" do
      call('foo,bar').must_equal(foo: {active: true}, bar: {active: true})
    end

    it "can configure interval with :" do
      call('foo:123').must_equal(foo: {active: true, execution_interval: 123})
    end

    it "supports spaces around ," do
      call('foo ,bar , baz').must_equal(foo: {active: true}, bar: {active: true}, baz: {active: true})
    end

    it "does not accept unknown arguments" do
      assert_raises(ArgumentError) { call('foo:123:123') }
    end

    it "fails with non-int" do
      assert_raises(ArgumentError) { call('foo:123a') }
    end
  end

  describe ".interval" do
    it "returns interval when a task is active" do
      with_registered do
        Samson::Periodical.interval(:periodical_deploy).must_equal 86400
      end
    end

    it "is disabled when a flag is not set" do
      refute Samson::Periodical.interval(:periodical_deploy)
    end
  end

  describe '.running_task_count' do
    it 'counts running tasks, starting at 0' do
      Samson::Periodical.instance_variable_set(:@running_tasks_count, nil)
      Samson::Periodical.running_task_count.must_equal 0
    end

    it 'counts running tasks' do
      skip if ENV['TRAVIS'] # TODO: this fails on travis :(
      mutex = Mutex.new.lock
      Samson::Periodical.register(:foo, 'bar', active: true, now: true) { mutex.lock }
      tasks = Samson::Periodical.run
      sleep 0.01 # Allow task to start

      Samson::Periodical.running_task_count.must_equal 1
      mutex.unlock
      sleep 0.01 # Allow task to finish

      Samson::Periodical.running_task_count.must_equal 0
      tasks.first.shutdown
    end

    it 'correctly counts down when task raised' do
      ErrorNotifier.expects(:notify)
      Samson::Periodical.register(:foo, 'bar', active: true, now: true) { raise }
      tasks = Samson::Periodical.run
      sleep 0.01 # Allow task to finish

      Samson::Periodical.running_task_count.must_equal 0
      tasks.first.shutdown
    end
  end

  it "lists all example periodical tasks in the .env.example" do
    configureable = File.read('config/initializers/periodical.rb').scan(/\.register.*?:([a-z\d_]+)/).flatten
    mentioned = File.read('.env.example')[/## Periodical tasks .*^PERIODICAL=/m].scan(/# ([a-z\d_]+):\d+/).flatten
    configureable.sort.must_equal mentioned.sort
  end

  it "runs everything" do
    stub_request(:get, "https://www.githubstatus.com/api/v2/status.json")
    Samson::Periodical.send(:registered).each_key do |task|
      Samson::Periodical.run_once task
    end
  end

  it "executes consistent_start_time tasks on interval" do
    with_registered do
      now = Time.parse("2017-08-08 14:00:00")
      Time.stubs(:now).returns(now)
      Concurrent::ScheduledTask.expects(:execute).with(10.hours) # periodical_deploy
      Samson::Periodical.run
    end
  end
end
