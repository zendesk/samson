# Monkey patch the Hash class to add the #to_kuber_selector method, which
# makes it easy to generate the "Selectors" that Kubernetes uses to get
# objects that given criteria.
#
# see http://kubernetes.io/v1.0/docs/user-guide/labels.html

class Hash
  def to_kuber_selector
    clauses = []

    each do |key,value|
      next if key == :not

      if value.is_a?(Array)
        clauses << "#{key} in (#{value.join(',')})"
      elsif value.is_a?(TrueClass)
        clauses << key
      else
        clauses << "#{key}=#{value}"
      end
    end

    fetch(:not, {}).each do |key, value|
      if value.is_a?(Array)
        clauses << "#{key} notin (#{value.join(',')})"
      else
        clauses << "#{key}!=#{value}"
      end
    end

    clauses.join(',')
  end
end
