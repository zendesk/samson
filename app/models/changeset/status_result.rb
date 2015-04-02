class Changeset::StatusResult < Struct.new(:state, :error)
  def self.null_result
    new(nil, nil)
  end
end
