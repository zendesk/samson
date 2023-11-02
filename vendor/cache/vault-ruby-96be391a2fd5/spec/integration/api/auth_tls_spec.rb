require "spec_helper"

module Vault
  describe AuthTLS do
    subject { vault_test_client.auth_tls }

    before(:context) do
      vault_test_client.sys.enable_auth("cert", "cert", nil)
    end

    after(:context) do
      vault_test_client.sys.disable_auth("cert")
    end

    let(:certificate) do
      {
        display_name: "sample-cert",
        certificate:   RSpec::SampleCertificate.cert,
        policies:      "default",
        ttl:           3600,
      }
    end

    describe "#set_certificate" do
      it "sets the certificate" do
        expect(subject.set_certificate("sample", certificate)).to be(true)
        result = subject.certificate("sample")
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:display_name]).to eq(certificate[:display_name])
        expect(result.data[:certificate]).to eq(certificate[:certificate])
        expect(result.data[:ttl]).to eq(certificate[:ttl])
        expect(result.data[:policies]).to eq(certificate[:policies]).or eq([certificate[:policies]])
      end
    end

    describe "#certificate" do
      it "gets the certificate" do
        subject.set_certificate("sample", certificate)
        result = subject.certificate("sample")
        expect(result).to be_a(Vault::Secret)
        expect(result.data[:display_name]).to eq(certificate[:display_name])
        expect(result.data[:certificate]).to eq(certificate[:certificate])
        expect(result.data[:ttl]).to eq(certificate[:ttl])
        expect(result.data[:policies]).to eq(certificate[:policies]).or eq([certificate[:policies]])
      end

      it "returns nil when the certificate does not exist" do
        result = subject.certificate("nope-nope-nope")
        expect(result).to be(nil)
      end
    end

    describe "#certificates" do
      it "lists all certificates by name" do
        subject.set_certificate("sample", certificate)
        result = subject.certificates
        expect(result).to include("sample")
      end
    end

    describe "#delete_certificate" do
      it "deletes a certificate" do
        subject.set_certificate("sample", certificate)
        expect(subject.delete_certificate("sample")).to be(true)
      end

      it "does nothing if a certificate does not exist" do
        expect {
          subject.delete_certificate("nope-nope-nope")
        }.to_not raise_error
      end
    end
  end
end
