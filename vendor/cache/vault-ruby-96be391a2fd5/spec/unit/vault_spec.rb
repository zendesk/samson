require "spec_helper"

describe Vault do
  it "sets the default values" do
    Vault::Configurable.keys.each do |key|
      value = Vault::Defaults.send(key)
      expect(Vault.client.instance_variable_get(:"@#{key}")).to eq(value)
    end
  end

  describe ".client" do
    it "returns the Vault::Client" do
      expect(Vault.client).to be_a(Vault::Client)
    end
  end

  describe ".configure" do
    Vault::Configurable.keys.each do |key|
      it "sets the client's #{key.to_s.gsub("_", " ")}" do
        Vault.configure do |config|
          config.send("#{key}=", key)
        end

        expect(Vault.client.instance_variable_get(:"@#{key}")).to eq(key)
      end
    end
  end

  describe ".method_missing" do
    context "when the client responds to the method" do
      let(:client) { double(:client) }
      before { Vault.instance_variable_set(:@client, client) }

      it "delegates the method to the client" do
        allow(client).to receive(:bacon).and_return("awesome")
        expect { Vault.bacon }.to_not raise_error
      end
    end

    context "when the client does not respond to the method" do
      it "calls super" do
        expect { Vault.bacon }.to raise_error(NoMethodError)
      end
    end
  end

  describe ".respond_to_missing?" do
    let(:client) { double(:client) }
    before { allow(Vault).to receive(:client).and_return(client) }

    it "delegates to the client" do
      expect { Vault.respond_to_missing?(:foo) }.to_not raise_error
    end
  end
end
