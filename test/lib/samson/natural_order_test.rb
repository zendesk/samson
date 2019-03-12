# frozen_string_literal: true
require_relative '../../test_helper'

SingleCov.covered!

describe Samson::NaturalOrder do
  describe '.convert' do
    def sort(list)
      list.sort_by { |x| Samson::NaturalOrder.convert(x) }
    end

    it "sorts naturally" do
      sort(['a11', 'a1', 'a22', 'b1', 'a12', 'a9']).must_equal ['a1', 'a9', 'a11', 'a12', 'a22', 'b1']
    end

    it "sorts pure numbers" do
      sort(['11', '1', '22', '12', '9']).must_equal ['1', '9', '11', '12', '22']
    end

    it "sorts pure words" do
      sort(['bb', 'ab', 'aa', 'a', 'b']).must_equal ['a', 'aa', 'ab', 'b', 'bb']
    end
  end

  describe ".name_sortable" do
    def sort(list)
      list.sort_by { |x| Samson::NaturalOrder.name_sortable(x) }
    end

    it "generates sortable string" do
      Samson::NaturalOrder.name_sortable("abc123def5gh").must_equal "abc00123def00005gh"
    end

    it "sorts naturally" do
      sort(['a11', 'a1', 'a22', 'b1', 'a12', 'a9']).must_equal ['a1', 'a9', 'a11', 'a12', 'a22', 'b1']
    end

    it "sorts pure numbers" do
      sort(['11', '1', '22', '12', '9']).must_equal ['1', '9', '11', '12', '22']
    end

    it "sorts pure words" do
      sort(['bb', 'ab', 'aa', 'a', 'b']).must_equal ['a', 'aa', 'ab', 'b', 'bb']
    end
  end
end
