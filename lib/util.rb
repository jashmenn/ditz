class Object
  def returning o; yield o; o end # k-combinator
end

module Enumerable
  def count_of(&b); select(&b).size end
  def max_of(&b); map(&b).max end
  def min_of(&b); map(&b).min end
end

class Array
  def uniq_by; inject({}) { |h, o| h[yield(o)] = o; h }.values end
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

  def group_by
    inject({}) do |groups, element|
      (groups[yield(element)] ||= []) << element
      groups
    end
  end if RUBY_VERSION < '1.9'

end

class Array
  def first_duplicate
    sa = sort
    (1 .. sa.length).argfind { |i| (sa[i] == sa[i - 1]) && sa[i] }
  end

  def to_h
    Hash[*flatten]
  end

  def flatten_one_level
    inject([]) do |ret, e|
      case e
      when Array
        ret + e
      else
        ret << e
      end
    end
  end
end
