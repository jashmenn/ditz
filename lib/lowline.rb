require 'util'

class Numeric
  def to_pretty_s
    if self < 20
      %w(no one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen)[self]
    else
      to_s
    end
  end
end

class String
  def ucfirst; self[0..0].upcase + self[1..-1] end
  def dcfirst; self[0..0].downcase + self[1..-1] end
  def blank?; self =~ /\A\s*\z/ end
  def underline; self + "\n" + ("-" * self.length) end
  def multiline prefix=""; blank? ? "" : "\n" + self.gsub(/^/, prefix) end
  def pluralize n; n.to_pretty_s + " " + (n == 1 ? self : self + "s") end # oh yeah
end

class Array
  def listify prefix=""
    return "" if empty?
    "\n" +
      map_with_index { |x, i| x.to_s.gsub(/^/, "#{prefix}#{i + 1}. ") }.
        join("\n")
  end
end

class Time
  def pretty; strftime "%c" end
  def pretty_date; strftime "%Y-%m-%d" end
  def ago
    diff = (Time.now - self).to_i.abs
    if diff < 60
      "second".pluralize diff
    elsif diff < 60*60*3
      "minute".pluralize(diff / 60)
    elsif diff < 60*60*24*3
      "hour".pluralize(diff / (60*60))
    elsif diff < 60*60*24*7*2
      "day".pluralize(diff / (60*60*24))
    elsif diff < 60*60*24*7*8
      "week".pluralize(diff / (60*60*24*7))
    elsif diff < 60*60*24*7*52
      "month".pluralize(diff / (60*60*24*7*4))
    else
      "year".pluralize(diff / (60*60*24*7*52))
    end
  end
end

module Lowline
  def ask q, opts={}
    default_s = case opts[:default]
      when nil; nil
      when ""; " (enter for none)"
      else; " (enter for #{opts[:default].inspect})"
    end

    tail = case q
      when /[:?]$/; " "
      when /[:?]\s+$/; ""
      else; ": "
    end

    while true
      print [q, default_s, tail].compact.join
      ans = gets.strip
      if opts[:default]
        ans = opts[:default] if ans.blank?
      else
        next if ans.blank? && !opts[:empty_ok]
      end
      break ans unless (opts[:restrict] && ans !~ opts[:restrict])
    end
  end

  def ask_multiline q
    puts "#{q} (ctrl-d or . by itself to stop):"
    ans = ""
    while true
      print "> "
      line = gets
      break if line =~ /^\.$/ || line.nil?
      ans << line.strip + "\n"
    end
    ans.sub(/\n+$/, "")
  end

  def ask_yon q
    while true
      print "#{q} (y/n): "
      a = gets.strip
      break a if a =~ /^[yn]$/i
    end =~ /y/i
  end

  def ask_for_many plural_name, name=nil
    name ||= plural_name.gsub(/s$/, "")
    stuff = []

    while true
      puts
      puts "Current #{plural_name}:"
      if stuff.empty?
        puts "None!"
      else
        stuff.each_with_index { |c, i| puts "  #{i + 1}) #{c}" }
      end
      puts
      ans = ask "(A)dd #{name}, (r)emove #{name}, or (d)one"
      case ans
      when "a", "A"
        ans = ask "#{name.ucfirst} name", ""
        stuff << ans unless ans =~ /^\s*$/
      when "r", "R"
        ans = ask "Remove which component? (1--#{stuff.size})"
        stuff.delete_at(ans.to_i - 1) if ans
      when "d", "D"
        break
      end
    end
    stuff
  end

  def ask_for_selection stuff, name, to_string=:to_s
    puts "Choose a #{name}:"
    stuff.each_with_index do |c, i|
      pretty = case to_string
      when Symbol
        c.send to_string
      when Proc
        to_string.call c
      else
        raise ArgumentError, "unknown to_string argument type; expecting Proc or Symbol"
      end
      puts "  #{i + 1}) #{pretty}"
    end

    j = while true
      i = ask "#{name.ucfirst} (1--#{stuff.size})"
      break i.to_i if i && (1 .. stuff.size).member?(i.to_i)
    end

    stuff[j - 1]
  end
end

