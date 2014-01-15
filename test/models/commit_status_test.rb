require_relative '../test_helper'

describe CommitStatus do
  let(:repo) { 'test/test' }
  let(:sha) { 'master' }

  subject { CommitStatus.new(repo, sha) }

  before do
    CommitStatus.token = '123'
  end

  describe 'with a proper sha' do
    before do
      stub_github_api('repos/' + repo + '/statuses/' + sha, statuses)
    end

    describe 'with multiple statuses' do
      let(:statuses) {[
        { :state => 'success' },
        { :state => 'pending' }
      ]}

      it 'is the first status' do
        subject.status.must_equal('success')
      end
    end

    describe 'with no statuses' do
      let(:statuses) {[]}

      it 'is nil' do
        subject.status.must_be_nil
      end
    end
  end

  describe 'when API cannot find the sha' do
    before do
      stub_github_api('repos/' + repo + '/statuses/' + sha, nil, 404)
    end

    it 'is nil' do
      subject.status.must_be_nil
    end
  end
end
