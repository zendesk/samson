# Monkey patch the Hash class to add the #to_kuber_selector method, which
# makes it easy to generate the "Selectors" that Kubernetes uses to get
# objects that given criteria.
#
# see http://kubernetes.io/v1.0/docs/user-guide/labels.html

class Hash
  def to_kuber_selector
    clauses = []

    each do |key, value|
      next if key == :not

      clauses <<
        if value.is_a?(Array)
          "#{key} in (#{value.join(',')})"
        elsif value.is_a?(TrueClass)
          key
        else
          "#{key}=#{value}"
        end
    end

    fetch(:not, {}).each do |key, value|
      clauses <<
        if value.is_a?(Array)
          "#{key} notin (#{value.join(',')})"
        else
          "#{key}!=#{value}"
        end
    end

    clauses.join(',')
  end
end
