require_relative '../../test_helper'
require 'celluloid/current'
require 'kubeclient'

SingleCov.covered! uncovered: 1

describe Watchers::ClusterPodWatcher do
  describe 'using actors' do
    let(:project) { projects(:test) }

    before do
      Celluloid.shutdown # it's started by default after requiring the gem
      Celluloid.boot

      Celluloid::Actor[:subscriber] = NoticeSubscriber.new(Watchers::TopicSubscription.pod_updates_topic(project.id))
      Celluloid::Actor[:stream] = ConditionedWatchStream.new
    end

    after do
      # because of dependencies between actors we need to maintain a shutdown order
      actor(:stream).terminate
      actor(:subscriber).terminate

      Celluloid.shutdown
    end

    describe 'without supervision' do
      let(:cluster) { kubernetes_clusters(:test_cluster) }

      before do
        Kubernetes::Cluster.any_instance.stubs(:client).returns(DummyClient.new(Celluloid::Actor[:stream]))
        Celluloid::Actor[:watcher] = Watchers::ClusterPodWatcher.new(cluster)
      end
      after do
        actor(:watcher).terminate if actor(:watcher).alive?
      end

      it 'publishes notices' do
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 1)
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 2)
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 3)
      end

      it 'ignores error notices' do
        send_notice(actor(:stream), 'ERROR')
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 1)
        refute_equal('ERROR', actor(:subscriber).notices.first.type)
      end

      it 'tolerates restarts' do
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 1)

        actor(:watcher).async.stop_watching
        wait_for { !actor(:stream).waiting } # wait until the stream actually shuts down
        actor(:watcher).async.start_watching

        send_notice(actor(:stream))
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
      let(:cluster) { kubernetes_clusters(:test_cluster) }
      let(:watcher_name) { Watchers::ClusterPodWatcher.watcher_symbol(cluster) }

      before do
        Kubernetes::Cluster.any_instance.stubs(:client).returns(DummyClient.new(Celluloid::Actor[:stream]))
        Watchers::ClusterPodWatcher.start_watcher(cluster)
      end
      after do
        actor(watcher_name).terminate
      end

      it 'gets restarted after a crash' do
        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 1)

        id_before = actor(watcher_name).wrapped_object.object_id
        send_broken_notice(actor(:stream))

        send_notice(actor(:stream))
        wait_for_notice_count(actor(:subscriber), 2)
        refute_equal(id_before, actor(watcher_name).wrapped_object.object_id)
      end
    end

    describe 'managing watchers' do
      let(:cluster) { kubernetes_clusters(:test_cluster) }

      before do
        Kubernetes::Cluster.any_instance.stubs(:client).returns(DummyClient.new(Celluloid::Actor[:stream]))
      end
      after do
        actor(cluster_name(cluster)).terminate
      end

      it 'starts a watcher for a given cluster' do
        Watchers::ClusterPodWatcher.start_watcher(cluster)
        assert actor(cluster_name(cluster)).alive?
      end

      it 'restarts a watcher for a given cluster' do
        Watchers::ClusterPodWatcher.start_watcher(cluster)
        assert actor(cluster_name(cluster)).alive?
        id_before = actor(cluster_name(cluster)).wrapped_object.object_id
        Watchers::ClusterPodWatcher.restart_watcher(cluster)
        assert actor(cluster_name(cluster)).alive?
        refute_equal(id_before, actor(cluster_name(cluster)).wrapped_object.object_id)
      end
    end
  end

  describe 'as a class' do
    let(:cluster) { kubernetes_clusters(:test_cluster) }

    it 'builds a correct ClusterPodWatcher name' do
      assert_equal(cluster_name(cluster).to_sym, Watchers::ClusterPodWatcher.watcher_symbol(cluster))
    end

    it 'builds a correct ClusterPodErrorWatcher watcher name' do
      assert_equal(cluster_name(cluster).to_sym, Watchers::ClusterPodWatcher.watcher_symbol(cluster))
    end
  end

  private

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

    def initialize(topic)
      @notices = []
      subscribe(topic, :handle_notice)
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
      while @running
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
      raise BrokenNoticeError, method_id.id2name
    end
  end

  def build_notice(type)
    Kubeclient::Common::WatchNotice.new(create_msg(type: type).to_h)
  end

  def send_notice(stream, type = 'MODIFIED')
    send_to_stream(stream, build_notice(type))
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
    until yield
      # check again
    end
  end

  def actor(name)
    Celluloid::Actor[name]
  end

  def create_msg(type: 'ADDED')
    {
      type: type,
      object: {
        kind: 'Pod',
        metadata: {
          labels: {
            project_id: project.id
          }
        }
      }
    }
  end

  def cluster_name(cluster)
    "cluster_pod_watcher_#{cluster.id}"
  end
end
