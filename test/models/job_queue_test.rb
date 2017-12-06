# frozen_string_literal: true
require_relative '../test_helper'

JobQueue.clear

SingleCov.covered!

describe JobQueue do
  # JobExecution is slow/complicated ... so we stub it out
  fake_execution = Class.new do
    attr_reader :id
    attr_writer :thread
    def initialize(id)
      @id = id
    end

    # when expectations fail we need to know what failed
    def inspect
      "job-#{id}"
    end
  end

  def wait_for_jobs_to_finish
    sleep 0.01 until subject.debug == [{}, {}]
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

  def locked
    locks = [active_lock, queued_lock]
    locks.each(&:lock) # stall jobs

    yield

    # let jobs finish
    locks.each { |l| l.unlock if l.locked? }
    wait_for_jobs_to_finish
  end

  let(:subject) { JobQueue }
  let(:job_execution) { fake_execution.new(:active) }
  let(:queued_job_execution) { fake_execution.new(:queued) }
  let(:active_lock) { Mutex.new }
  let(:queued_lock) { Mutex.new }
  let(:queue_name) { :my_queue }

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

    it 'reports queue length' do
      states = [
        [1, 0], # add active
        [1, 1], # add queued
        [1, 0], # done active ... enqueue queued
        [0, 0], # done queued
      ]
      states.each do |t, q|
        ActiveSupport::Notifications.expects(:instrument).with("job_queue.samson", threads: t, queued: q)
      end
      with_a_queued_job {} # noop
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
          subject.debug.each(&:clear)
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

  describe "#clear" do
    it "clears" do
      subject.debug.each { |q| q[:x] = 1 }
      subject.clear
      subject.debug.must_equal [{}, {}]
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

  describe "#kill" do
    it "kills the job" do
      with_job_execution do
        called = false
        time = Benchmark.realtime do
          job_execution.stubs(:perform).with do # cannot use expect since it is killed
            called = true
            sleep 0.1
          end
          subject.perform_later(job_execution)
          sleep 0.05
          subject.kill(job_execution.id)
        end
        time.must_be :<, 0.1
        assert called
      end
    end

    it "does nothing when job is dead" do
      subject.kill(123)
    end
  end
end
