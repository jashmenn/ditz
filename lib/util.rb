class Object
  def returning o; yield o; o end # k-combinator
end

module Enumerable
  def count_of(&b); select(&b).size end
  def max_of(&b); map(&b).max end
  def min_of(&b); map(&b).min end
end

module Enumerable
  def map_with_index # sigh...
    ret = []
    each_with_index { |e, i| ret << yield(e, i) }
    ret
  end

  def argfind
    each { |e| x = yield(e); return x if x }
    nil
  end
end

class Array
  def first_duplicate
    sa = sort
    (1 .. sa.length).argfind { |i| (sa[i] == sa[i - 1]) && sa[i] }
  end

  def to_h
    Hash[*flatten]
  end
end
