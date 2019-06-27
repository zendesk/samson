# frozen_string_literal: true
require_relative '../test_helper'

JobQueue.clear

SingleCov.covered!

describe JobQueue do
  fake_job = Class.new do
    attr_reader :deploy
    def initialize(deploy)
      @deploy = deploy
    end
  end

  # JobExecution is slow/complicated ... so we stub it out
  fake_execution = Class.new do
    attr_reader :id, :job
    attr_writer :thread
    def initialize(id, job)
      @id = id
      @job = job
    end

    # when expectations fail we need to know what failed
    def inspect
      "job-#{id}"
    end
  end

  def with_executing_job
    job_execution.expects(:perform).with { active_lock.synchronize { true } }

    with_job_execution do
      locked do
        subject.perform_later(job_execution)
        yield
      end
    end
  end

  def with_a_queued_job
    # keep executing until unlocked
    job_execution.expects(:perform).with { active_lock.synchronize { true } }
    queued_job_execution.expects(:perform).with { queued_lock.synchronize { true } }

    with_job_execution do
      locked do
        subject.perform_later(job_execution, queue: queue_name)
        subject.perform_later(queued_job_execution, queue: queue_name)
        yield
      end
    end
  end

  def with_two_executing_jobs_and_a_queued_job
    job_execution.expects(:perform).with { active_lock.synchronize { true } }
    queued_job_execution.expects(:perform).with { queued_lock.synchronize { true } }
    another_job_execution.expects(:perform).with { another_lock.synchronize { true } }
    with_job_execution do
      locked do
        subject.perform_later(job_execution, queue: queue_name)
        subject.perform_later(queued_job_execution, queue: queue_name)
        subject.perform_later(another_job_execution, queue: another_queue_name)
        yield
      end
    end
  end

  def locked
    locks = [active_lock, queued_lock, another_lock]
    locks.each(&:lock) # stall jobs

    yield

    # let jobs finish
    locks.each { |l| l.unlock if l.locked? }
    wait_for_jobs_to_finish
  end

  let(:subject) { JobQueue }
  let(:instance) { JobQueue.instance }
  let(:job) { fake_job.new(nil) }
  let(:job_execution) { fake_execution.new(:active, job) }
  let(:queued_job_execution) { fake_execution.new(:queued, job) }
  let(:another_job_execution) { fake_execution.new(:another, job) }
  let(:active_lock) { Mutex.new }
  let(:queued_lock) { Mutex.new }
  let(:another_lock) { Mutex.new }
  let(:queue_name) { :my_queue }
  let(:another_queue_name) { :another_queue }

  before do
    JobQueue.stubs(:new).returns(job_execution).returns(queued_job_execution)
  end

  describe "#perform_later" do
    it 'immediately performs a job when executing is empty' do
      with_executing_job do
        assert subject.executing?(:active)
        refute subject.queued?(:active)
        subject.find_by_id(:active).must_equal(job_execution)
      end
    end

    it 'performs parallel jobs when they are in different queues' do
      with_job_execution do
        locked do
          [job_execution, queued_job_execution].each do |job|
            job.expects(:perform).with { active_lock.synchronize { true } }

            subject.perform_later(job)

            assert subject.executing?(job.id)
          end
        end
      end
    end

    it 'queues a job if max concurrent jobs is hit' do
      with_env MAX_CONCURRENT_JOBS: '1' do
        with_job_execution do
          locked do
            job_execution.expects(:perform).with { active_lock.synchronize { true } }
            queued_job_execution.expects(:perform).with { queued_lock.synchronize { true } }

            subject.perform_later(job_execution)
            subject.perform_later(queued_job_execution)

            assert subject.executing?(:active)
            refute subject.executing?(:queued)
          end
        end
      end
    end

    it 'does not perform a job if job execution is disabled' do
      JobQueue.enabled = false
      job_execution.expects(:perform).never

      subject.perform_later(job_execution)

      refute subject.executing?(:active)
      refute subject.queued?(:active)
      refute subject.find_by_id(:active)
    end

    it 'does not queue a job if job execution is disabled' do
      with_executing_job do
        JobQueue.enabled = false
        subject.perform_later(queued_job_execution, queue: queue_name)

        refute subject.executing?(:queued)
        refute subject.queued?(:queued)
        refute subject.find_by_id(:queued)
      end
    end

    it 'reports to airbrake when executing jobs were in an unexpected state' do
      with_job_execution do
        subject.instance.instance_variable_get(:@executing)[queue_name] = job_execution

        e = assert_raises RuntimeError do
          subject.instance.send(:delete_and_enqueue_next, queued_job_execution, queue_name)
        end
        e.message.must_equal 'Unexpected executing job found in queue my_queue: expected queued got active'
      end
    end

    describe 'queue length' do
      def assert_queue_length_notifications
        states = [
          [1, 0], # add active
          [1, 1], # add queued
          [1, 0], # done active ... enqueue queued
          [0, 0], # done queued
        ]
        states.each do |t, q|
          yield(t, q)
        end
        with_a_queued_job {} # noop
      end

      it 'reports queue length' do
        assert_queue_length_notifications do |t, q|
          ActiveSupport::Notifications.expects(:instrument).with(
            "job_queue.samson",
            jobs: {executing: t, queued: q,},
            deploys: {executing: 0, queued: 0}
          )
        end
      end

      describe 'with deploys' do
        let(:job) { fake_job.new(mock) }

        it 'reports deploy queue lengths' do
          assert_queue_length_notifications do |t, q|
            ActiveSupport::Notifications.expects(:instrument).with(
              "job_queue.samson",
              jobs: {executing: t, queued: q},
              deploys: {executing: t, queued: q}
            )
          end
        end
      end
    end

    describe 'with queued job' do
      it 'has a queued job' do
        with_a_queued_job do
          refute subject.executing?(:queued)
          assert subject.queued?(:queued)
          subject.find_by_id(:queued).must_equal(queued_job_execution)
        end
      end

      it 'performs then next job when executing job completes' do
        with_a_queued_job do
          active_lock.unlock
          sleep 0.01 while subject.executing?(:active)

          refute subject.find_by_id(:active)
          assert subject.executing?(:queued)
          refute subject.queued?(:queued)
        end
      end

      it 'does not perform a job from an executing queue when another job completes' do
        with_two_executing_jobs_and_a_queued_job do
          another_lock.unlock
          sleep 0.01 while subject.executing?(:another)

          refute subject.executing?(:queued)
        end
      end

      it 'does not perform the next job when job execution is disabled' do
        with_a_queued_job do
          JobQueue.enabled = false

          queued_job_execution.unstub(:perform)
          queued_job_execution.expects(:perform).never

          active_lock.unlock
          sleep 0.01 while subject.executing?(:active)

          refute subject.find_by_id(:active)
          refute subject.executing?(:queued)
          assert subject.queued?(:queued)
          subject.clear
        end
      end

      it 'does not fail when queue is empty' do
        with_a_queued_job do
          active_lock.unlock
          queued_lock.unlock
          wait_for_jobs_to_finish

          refute subject.find_by_id(:active)
          refute subject.find_by_id(:queued)

          # make sure we cleaned up nicely
          subject.debug.must_equal([{}, {}])
        end
      end
    end
  end

  describe 'staggered jobs' do
    def with_staggering_enabled(stagger_interval: 1.second, &block)
      JobQueue.any_instance.expects(:stagger_interval).returns(stagger_interval)
      with_env SERVER_MODE: 'true', &block
    end

    describe '#initialize' do
      it 'starts staggered job deque task if staggering is enabled' do
        JobQueue.any_instance.expects(:start_staggered_job_dequeuer)
        with_staggering_enabled do
          JobQueue.unstub(:new)
          JobQueue.send(:new)
        end
      end
    end

    describe '#debug' do
      it 'includes staggered jobs if enabled' do
        with_staggering_enabled do
          subject.debug.must_equal [{}, {}, {}]
        end
      end
    end

    describe '#stagger_job_or_execute' do
      it 'pushes job to staggered queue if queue is enabled' do
        with_staggering_enabled do
          instance.instance_variable_get(:@stagger_queue).must_equal []

          instance.send(:stagger_job_or_execute, job_execution, '')

          instance.instance_variable_get(:@stagger_queue).must_equal [{job_execution: job_execution, queue: ''}]
          subject.clear
        end
      end

      it 'performs job if staggering is not enabled' do
        instance.expects(:perform_job).with(job_execution, '')
        instance.instance_variable_get(:@stagger_queue).must_equal []

        instance.send(:stagger_job_or_execute, job_execution, '')

        instance.instance_variable_get(:@stagger_queue).must_equal []
      end
    end

    describe '#dequeue_staggered_job' do
      it 'performs dequeued job' do
        instance.expects(:perform_job).with(job_execution, queue_name)
        instance.instance_variable_set(:@stagger_queue, [{job_execution: job_execution, queue: queue_name}])

        instance.send(:dequeue_staggered_job)
        subject.clear
      end

      it 'does not call perform_job if queue is empty' do
        instance.expects(:perform_job).never

        instance.send(:dequeue_staggered_job)
      end
    end

    describe '#start_staggered_job_dequeuer' do
      it 'creates new timer task and starts it' do
        mock_timer_task = mock(execute: true)
        expected_task_params = {now: true, timeout_interval: 10, execution_interval: 1.second}
        instance.expects(:dequeue_staggered_job)
        Concurrent::TimerTask.expects(:new).with(expected_task_params).yields.returns(mock_timer_task)

        with_staggering_enabled do
          instance.send(:start_staggered_job_dequeuer)
        end
        subject.clear
      end
    end

    describe '#staggering_enabled?' do
      it 'returns true if in server mode and stagger interval is set' do
        with_staggering_enabled do
          assert instance.send(:staggering_enabled?)
        end
      end

      it 'returns false if not in server mode' do
        refute instance.send(:staggering_enabled?)
      end

      it 'returns false if stagger interval is not set' do
        with_env SERVER_MODE: 'true' do
          refute instance.send(:staggering_enabled?)
        end
      end
    end

    describe "#stagger_interval" do
      it 'gets the stagger interval constant' do
        instance.send(:stagger_interval).must_equal 0.seconds
      end
    end
  end

  describe "#dequeue" do
    it "removes a job from the queue" do
      with_a_queued_job do
        queued_job_execution.unstub(:perform)
        assert subject.dequeue(queued_job_execution.id)
        refute subject.queued?(queued_job_execution.id)
      end
    end

    it "does not remove a job when it is not queued" do
      with_a_queued_job do
        refute subject.dequeue(job_execution.id)
        refute subject.queued?(job_execution.id)
      end
    end
  end

  describe "#debug" do
    it "returns executing and queued" do
      subject.debug.must_equal([{}, {}])
    end
  end

  describe '#debug_hash_from_queue' do
    it 'returns the expected debug hash from a queue' do
      queue = [{queue: queue_name, job_execution: job_execution}]
      instance.send(:debug_hash_from_queue, queue).must_equal "#{queue_name}": [job_execution]
    end
  end

  describe "#clear" do
    it "clears" do
      subject.debug.each { |q| q[:x] = 1 }
      subject.clear
      subject.debug.must_equal [{}, {}]
    end

    it "kills hanging threads directly so user sees what was hanging" do
      e = nil
      t =
        Thread.new do
          sleep 1
        rescue RuntimeError
          sleep 0.1 # make sure it waits
          e = $!
        end
      subject.instance.instance_variable_get(:@threads)[1] = t
      subject.clear
      maxitest_wait_for_extra_threads
      e.class.must_equal RuntimeError
    end

    it "does not raise on dead threads" do
      t = Thread.new {}
      subject.instance.instance_variable_get(:@threads)[1] = t
      sleep 0.1
      subject.clear
    end

    it "raises when used outside of test" do
      Rails.env.expects(:test?).returns(false)
      assert_raises(RuntimeError) { subject.clear }
    end
  end

  describe "#wait" do
    it "waits" do
      with_job_execution do
        time = Benchmark.realtime do
          job_execution.expects(:perform).with { sleep 0.1 }
          subject.perform_later(job_execution)
          assert subject.wait(job_execution.id) # blocks until thread unlocks
        end
        time.must_be :>, 0.1
      end
    end

    it "waits a limited amount" do
      with_job_execution do
        time = Benchmark.realtime do
          job_execution.expects(:perform).with { sleep 0.1 }
          subject.perform_later(job_execution)
          refute subject.wait(job_execution.id, 0.05) # blocks until thread unlocks
        end
        wait_for_jobs_to_finish
        maxitest_wait_for_extra_threads
        (0.05..0.1).must_include time
      end
    end

    it "does not wait when job is dead" do
      with_job_execution do
        time = Benchmark.realtime { refute subject.wait(123) }
        time.must_be :<, 0.1
      end
    end
  end

  describe "#cancel" do
    it "stops a running thread" do
      with_job_execution do
        called = false
        job_sleep = 0.2
        time = Benchmark.realtime do
          job_execution.stubs(:perform).with do # cannot use expect since it is killed
            called = true
            sleep job_sleep
          end
          subject.perform_later(job_execution)
          sleep job_sleep / 4
          subject.cancel(job_execution.id)
          sleep job_sleep / 4
        end
        time.must_be :<, job_sleep
        assert called
      end
    end

    it "waits for thread to stop so redirected user sees cancellation outcome" do
      with_job_execution do
        job_execution.stubs(:perform).with do # cannot use expect since it is killed
          sleep 0.1
        rescue JobQueue::Cancel
          sleep 0.01 # pretend to do slow cleanup
          raise
        end
        subject.perform_later(job_execution)
        sleep 0.01 # let thread start

        thread = subject.instance.instance_variable_get(:@threads)[job_execution.id]
        assert thread.alive?
        subject.cancel(job_execution.id)
        refute thread.alive?
      end
    end

    it "closes AR connection to make sure a bad connection is not returned to the pool" do
      with_job_execution do
        job_execution.stubs(:perform).with { sleep 0.1 }
        subject.perform_later(job_execution)

        Rails.env.expects(:test?).times(2).returns(false, true)
        ActiveRecord::Base.connection.expects(:close)

        sleep 0.01 # random errors happen without this
        subject.cancel(job_execution.id)
        maxitest_wait_for_extra_threads
      end
    end

    it "does nothing when thread is dead" do
      subject.cancel(job_execution.id)
    end
  end

  describe '#is_deploy?' do
    before { JobQueue.unstub(:new) }

    def deploy?(job_execution)
      JobQueue.send(:new).send(:deploy?, job_execution)
    end

    it 'returns true if job execution is a deploy' do
      assert deploy?(mock(job: mock(deploy: mock)))
    end

    it 'returns false if job execution does not respond to job' do
      refute deploy?(mock)
    end

    it 'returns false if job execution job does not have a deploy' do
      refute deploy?(mock(job: mock(deploy: nil)))
    end
  end
end
