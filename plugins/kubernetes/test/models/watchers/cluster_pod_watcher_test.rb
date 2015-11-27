require_relative '../../test_helper'
require 'celluloid/current'
require 'kubeclient'

class DummyClient
  def initialize(stream)
    @stream = stream
  end

  def watch_pods
    @stream
  end
end

class NoticeSubscriber
  include Celluloid
  include Celluloid::Notifications

  attr_accessor :notices

  def initialize(rc_name)
    @notices = []
    subscribe(rc_name, :handle_notice)
  end

  def handle_notice(_topic, data)
    @notices << data
  end
end

class ConditionedWatchStream
  include Celluloid

  finalizer :finish
  attr_accessor :running, :waiting

  def initialize
    @condition = Celluloid::Condition.new
    @running = false
    @waiting = false
  end

  def each
    @running = true
    while @running do
      @waiting = true
      message = @condition.wait
      @waiting = false
      yield message if message
    end
  end

  def finish
    @running = false
    @condition.signal if @waiting
  end

  def notice(message)
    @condition.signal message
  end
end

class BrokenNotice
  class BrokenNoticeError < StandardError
  end

  def method_missing(method_id)
    raise BrokenNoticeError.new method_id.id2name
  end
end

describe Watchers::ClusterPodWatcher do
  describe 'using actors' do
    let(:rc_name) { 'test' }
    before do
      Celluloid.shutdown # it's started by default after requiring the gem
      Celluloid.boot

      Celluloid::Actor[:subscriber] = NoticeSubscriber.new(rc_name)
      Celluloid::Actor[:stream] = ConditionedWatchStream.new
    end
    after do
      # because of dependencies between actors we need to maintain a shutdown order
      actor(:stream).terminate
      actor(:subscriber).terminate

      Celluloid.shutdown
    end

    describe 'without supervision' do
      before do
        Celluloid::Actor[:watcher] = Watchers::ClusterPodWatcher.new DummyClient.new(Celluloid::Actor[:stream])
      end
      after do
        actor(:watcher).terminate if actor(:watcher).alive?
      end

      it 'publishes notices' do
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 1)
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 2)
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 3)
      end

      it 'ignores error notices' do
        send_notice(actor(:stream), rc_name, 'ERROR')
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 1)
        refute_equal('ERROR', actor(:subscriber).notices.first.type)
      end

      it 'tolerates restarts' do
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 1)

        actor(:watcher).async.stop_watching
        wait_for { !actor(:stream).waiting } # wait until the stream actually shuts down
        actor(:watcher).async.start_watching

        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 2)
      end

      it 'terminates cleanly if exceptions occur' do
        assert actor(:watcher).alive?
        wait_for { actor(:stream).running }
        send_broken_notice(actor(:stream))
        wait_for { !actor(:watcher).alive? }
        refute actor(:stream).running
      end
    end

    describe 'with supervision' do
      before do
        Watchers::ClusterPodWatcher.supervise as: :watcher, args: [DummyClient.new(Celluloid::Actor[:stream])]
      end
      after do
        actor(:watcher).terminate
      end

      it 'gets restarted after a crash' do
        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 1)

        id_before = actor(:watcher).wrapped_object.object_id
        send_broken_notice(actor(:stream))

        send_notice(actor(:stream), rc_name)
        wait_for_notice_count(actor(:subscriber), 2)
        refute_equal(id_before, actor(:watcher).wrapped_object.object_id)
      end
    end

    describe 'managing watchers' do
      before do
        Kubernetes::Cluster.any_instance.stubs(:client).returns(DummyClient.new(Celluloid::Actor[:stream]))
      end
      after do
        actor(:cluster_pod_watcher_1).terminate
      end

      it 'starts a watcher for a given cluster' do
        Watchers::ClusterPodWatcher::start_watcher(kubernetes_clusters(:test_cluster))
        assert actor(:cluster_pod_watcher_1).alive?
      end

      it 'restarts a watcher for a given cluster' do
        Watchers::ClusterPodWatcher::start_watcher(kubernetes_clusters(:test_cluster))
        assert actor(:cluster_pod_watcher_1).alive?
        id_before = actor(:cluster_pod_watcher_1).wrapped_object.object_id
        Watchers::ClusterPodWatcher::restart_watcher(kubernetes_clusters(:test_cluster))
        assert actor(:cluster_pod_watcher_1).alive?
        refute_equal(id_before, actor(:cluster_pod_watcher_1).wrapped_object.object_id)
      end
    end
  end

  describe 'as a class' do
    it 'builds a correct pod watcher name' do
      assert_equal(:cluster_pod_watcher_1,
                   Watchers::ClusterPodWatcher.pod_watcher_symbol(kubernetes_clusters(:test_cluster)))
    end
  end

  private

  def build_notice(rc_name, type)
    notice_str = %[{"type": "#{type}", "object": {"metadata": {"labels": {"replication_controller": "#{rc_name}"}}}}]
    Kubeclient::Common::WatchNotice.new(JSON.parse(notice_str))
  end

  def send_notice(stream, topic, type = 'MODIFIED')
    send_to_stream(stream, build_notice(topic, type))
  end

  def send_broken_notice(stream)
    send_to_stream(stream, BrokenNotice.new)
  end

  def send_to_stream(stream, message)
    wait_for { stream.waiting }
    stream.async.notice(message)
  end

  def wait_for_notice_count(subscriber, count)
    wait_for { subscriber.notices.count == count }
  end

  def wait_for
    until yield do
      # check again
    end
  end

  def actor(name)
    Celluloid::Actor[name]
  end
end
