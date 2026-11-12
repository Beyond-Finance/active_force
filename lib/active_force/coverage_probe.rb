# Probe only: intentionally unspecced code to prove the coverage gate fails. DO NOT MERGE.
module ActiveForce
  class CoverageProbe
    def initialize(values)
      @values = values
    end

    def total
      sum = 0
      @values.each do |v|
        sum += v.to_i
      end
      sum
    end

    def label
      if total > 10
        'big'
      else
        'small'
      end
    end

    def describe
      "#{label}: #{total}"
    end
  end
end
