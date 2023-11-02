require "spec_helper"

module Vault
  describe Authenticate do
    let(:auth) { Authenticate.new(client: nil) }
    describe "#region_from_sts_endpoint" do
      subject { auth.send(:region_from_sts_endpoint, sts_endpoint) }

      context 'with a china endpoint' do
        let(:sts_endpoint) { "https://sts.cn-north-1.amazonaws.com.cn" }
        it { is_expected.to eq 'cn-north-1' }
      end

      context 'with a GovCloud endpoint' do
        let(:sts_endpoint) { "https://sts.us-gov-west-1.amazonaws.com" }
        it { is_expected.to eq 'us-gov-west-1' }
      end

      context 'with no regional endpoint' do
        let(:sts_endpoint) { "https://sts.amazonaws.com" }
        it { is_expected.to eq 'us-east-1' }
      end

      context 'with a malformed url' do
        let(:sts_endpoint) { "https:sts.amazonaws.com" }
        it { expect { subject }.to raise_exception(StandardError, "Unable to parse STS endpoint https:sts.amazonaws.com") }
      end
    end
  end
end
