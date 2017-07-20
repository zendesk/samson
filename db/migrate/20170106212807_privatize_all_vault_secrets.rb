# frozen_string_literal: true
class PrivatizeAllVaultSecrets < ActiveRecord::Migration[5.0]
  def change
    if SecretStorage.backend == Samson::Secrets::HashicorpVaultBackend
      SecretStorage.ids.each do |id|
        begin
          old = SecretStorage.read(id, include_value: true) # lots of random values
          new = {
            user_id: old[:updater_id],
            visible: ActiveRecord::Type::Boolean.new.cast(old[:visible]),
            comment: old[:comment],
            value: old.fetch(:value)
          }
          SecretStorage.write(id, new)
        rescue
          write "Error re-writing id #{id}, fix manually #{$!}"
        end
      end
    end
  end
end
