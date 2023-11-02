require "spec_helper"

#  => #<Vault::HealthStatus:0x007fab0ea2e700 @initialized=true, @sealed=false, @standby=false, @replication_performance_mode=nil, @replication_dr_mode=nil, @server_time_utc=1519776016, @version="0.6.5", @cluster_name="vault-cluster-a784b68d", @cluster_id="53f278b8-e33f-031a-60d2-11189f696b02">

module Vault
  describe Sys do
    subject { vault_test_client.sys }

    describe "#health_status" do
      it "returns server health" do
        result = subject.health_status
        expect(result).to be_a(HealthStatus)

        expect(result.initialized?).to be(true)
        expect(result.sealed?).to be(false)
        expect(result.standby?).to be(false)
        expect(result.replication_performance_mode).to be_a(String).or be(nil) # added in 0.9.2
        expect(result.replication_dr_mode).to be_a(String).or be(nil) # added in 0.9.2
        expect(result.server_time_utc).to be_a(Fixnum)
        expect(result.version).to be_a(String).or be(nil) # added in 0.6.1
        expect(result.cluster_name).to be_a(String).or be(nil)
        expect(result.cluster_id).to be_a(String).or be(nil)
      end
    end
  end
end
