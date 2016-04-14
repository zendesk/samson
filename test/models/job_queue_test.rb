require_relative '../test_helper'

SingleCov.covered! uncovered: 7

describe JobQueue do
  def enable_job_execution
    JobExecution.enabled = true
    yield
  ensure
    JobExecution.enabled = false
  end

  let(:subject) { JobQueue.new }
  let(:job_execution) { stub(id: 1, on_complete: nil) }
  let(:queued_job_execution) { stub(id: 2, on_complete: nil) }

  before do
    JobExecution.stubs(:new).returns(job_execution).returns(queued_job_execution)
  end

  it 'immediately starts a job when active is empty' do
    job_execution.expects(:start!)

    enable_job_execution do
      subject.add(:x, job_execution)
    end

    subject.active?(:x, 1).must_equal(true)
    subject.queued?(:x, 1).must_equal(false)
    subject.find(1).must_equal(job_execution)
  end

  it 'queues a job if there is already an active one' do
    job_execution.stubs(:start!)

    enable_job_execution do
      subject.add(:x, job_execution)
    end

    queued_job_execution.expects(:start!).never

    enable_job_execution do
      subject.add(:x, queued_job_execution)
    end

    subject.active?(:x, 2).must_equal(false)
    subject.queued?(:x, 2).must_equal(true)
    subject.find(2).must_equal(queued_job_execution)
  end

  it 'starts two different queues' do
    job_execution.expects(:start!)

    enable_job_execution do
      subject.add(:x, job_execution)
    end

    subject.active?(:x, 1).must_equal(true)

    queued_job_execution.expects(:start!)

    enable_job_execution do
      subject.add(:y, queued_job_execution)
    end

    subject.active?(:y, 2).must_equal(true)
  end

  it 'does not queue a job if job execution is disabled' do
    job_execution.expects(:start!).never

    subject.add(:x, job_execution)

    subject.active?(:x, 1).must_equal(false)
    subject.queued?(:x, 1).must_equal(false)
    subject.find(1).must_equal(job_execution)
  end

  describe 'with a queue' do
    before do
      job_execution.stubs(:start!)

      enable_job_execution do
        subject.add(:x, job_execution)
        subject.add(:x, queued_job_execution)
      end
    end

    it 'activates the first execution' do
      subject.active?(:x, 1).must_equal(true)
    end

    it 'starts a job when popping the active queue' do
      queued_job_execution.expects(:start!)

      enable_job_execution do
        subject.pop(:x, job_execution)
      end

      subject.find(1).must_equal(nil)
      subject.active?(:x, 2).must_equal(true)
      subject.queued?(:x, 2).must_equal(false)
    end

    it 'does not start a job when job execution is disabled' do
      queued_job_execution.expects(:start!).never

      subject.pop(:x, job_execution)

      subject.find(1).must_equal(nil)
      subject.active?(:x, 2).must_equal(false)
      subject.queued?(:x, 2).must_equal(true)
    end

    it 'pops the queued job execution off the stack' do
      queued_job_execution.expects(:start!).never

      subject.pop(:x, queued_job_execution)

      subject.find(1).must_equal(job_execution)
      subject.active?(:x, 1).must_equal(true)

      subject.find(2).must_equal(nil)
      subject.queued?(:x, 2).must_equal(false)
    end
  end
end
