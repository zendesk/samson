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
      stub_github_api("repos/#{repo}/commits/#{sha}/status", statuses)
    end

    describe 'with combined status' do
      let(:statuses) { { :state => "success" }}

      it 'is the first status' do
        subject.status.must_equal('success')
      end
    end

    describe 'with no status' do
      let(:statuses) { { :state => nil } }

      it 'is nil' do
        subject.status.must_be_nil
      end
    end
  end

  describe 'when API cannot find the sha' do
    before do
      stub_github_api('repos/' + repo + '/commits/' + sha + "/status", nil, 404)
    end

    it 'is nil' do
      subject.status.must_be_nil
    end
  end
end
