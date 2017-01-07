# frozen_string_literal: true
class PrivatizeAllVaultSecrets < ActiveRecord::Migration[5.0]
  def change
    if SecretStorage.backend == Samson::Secrets::HashicorpVaultBackend
      SecretStorage.keys.each do |key|
        begin
          old = SecretStorage.read(key, include_value: true) # lots of random values
          new = {
            user_id: old[:updater_id],
            visible: ActiveRecord::Type::Boolean.new.cast(old[:visible]),
            comment: old[:comment],
            value: old.fetch(:value)
          }
          SecretStorage.write(key, new)
        rescue
          puts "Error re-writing key #{key}, fix manually #{$!}"
        end
      end
    end
  end
end
