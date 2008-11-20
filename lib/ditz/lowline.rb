require 'tempfile'
require "ditz/util"

class Numeric
  def to_pretty_s
    %w(zero one two three four five six seven eight nine ten)[self] || to_s
  end
end

class String
  def dcfirst; self[0..0].downcase + self[1..-1] end
  def blank?; self =~ /\A\s*\z/ end
  def underline; self + "\n" + ("-" * self.length) end
  def pluralize n, b=true
    s = (n == 1 ? self : (self == 'bugfix' ? 'bugfixes' : self + "s")) # oh yeah
    b ? n.to_pretty_s + " " + s : s
  end
  def shortened_email; self =~ /<?(\S+?)@.+/ ? $1 : self end
  def multistrip; strip.gsub(/\n\n+/, "\n\n") end
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
  ## UI configuration
  @use_editor_if_possible = true
  attr_accessor :use_editor_if_possible

  class Error < StandardError; end

  def editor
    @editor ||=
      if ENV["EDITOR"] && !ENV["EDITOR"].empty?
        ENV["EDITOR"]
      else
        %w(/usr/bin/sensible-editor /usr/bin/vi).find { |e| File.exist?(e) }
      end
  end

  def run_editor
    raise Error, "no editor" unless editor

    f = Tempfile.new "ditz"
    yield f
    f.close

    cmd = "#{editor} #{f.path.inspect}"

    mtime = File.mtime f.path
    system cmd or raise Error, "cannot execute command: #{cmd.inspect}"

    File.mtime(f.path) == mtime ? nil : f.path
  end

  def ask q, opts={}
    default_s = case opts[:default]
      when nil; nil
      when ""; " (enter for none)"
      else; " (enter for #{opts[:default].to_s})"
    end

    tail = case q
      when /[:?]$/; " "
      when /[:?]\s+$/; ""
      else; ": "
    end

    while true
      prompt = [q, default_s, tail].compact.join
      if Ditz::has_readline?
        ans = Readline::readline(prompt)
      else
        print prompt
        ans = STDIN.gets.strip
      end
      if opts[:default]
        ans = opts[:default] if ans.blank?
      else
        next if ans.blank? && !opts[:empty_ok]
      end
      break ans unless (opts[:restrict] && ans !~ opts[:restrict])
    end
  end

  def ask_via_editor q, opts={}
    default = opts[:default]
    comments = opts[:comments]
    fn = run_editor do |f|
      if default
        f.puts default
      end
      f.puts
      f.puts q.gsub(/^/, "## ")
      f.puts "##"
      f.puts "## Enter your text above. Lines starting with a '#' will be ignored."
      if comments
        f.puts "##"
        f.puts comments.gsub(/^/, "## ")
      end
    end
    return unless fn
    IO.read(fn).gsub(/^#.*$/, "").multistrip
  end

  def ask_multiline q
    puts "#{q} (ctrl-d, ., or /stop to stop, /edit to edit, /reset to reset):"
    ans = ""
    while true
      if Ditz::has_readline?
        line = Readline::readline('> ')
      else
        (line = STDIN.gets) && line.strip!
      end
      if line
        if Ditz::has_readline?
          Readline::HISTORY.push(line)
        end
        case line
        when /^\.$/, "/stop"
          break
        when "/reset"
          return ask_multiline(q)
        when "/edit"
          return ask_via_editor(q, :default => ans)
        else
          ans << line + "\n"
        end
      else
        puts
        break
      end
    end
    ans.multistrip
  end

  def ask_multiline_or_editor q, opts={}
    if Lowline.use_editor_if_possible && editor
      ask_via_editor q, :comments => opts[:comments]
    else
      ask_multiline q
    end
  end

  def ask_yon q
    while true
      print "#{q} (y/n): "
      a = STDIN.gets.strip
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
        ans = ask "#{name.capitalize} name", ""
        stuff << ans unless ans =~ /^\s*$/
      when "r", "R"
        ans = ask "Remove which #{name}? (1--#{stuff.size})"
        stuff.delete_at(ans.to_i - 1) if ans
      when "d", "D"
        break
      end
    end
    stuff
  end

  def ask_for_selection stuff, name, to_string=:to_s, many=false
    if many
      return [] if stuff.empty?
      name = name.pluralize(2, false)
      puts "Choose one or more #{name} (comma separated list):"
    else
      return nil if stuff.empty?
      puts "Choose a #{name}:"
    end
    stuff.each_with_index do |c, i|
      pretty = case to_string
      when block_given? && to_string # heh
        yield c
      when Symbol
        c.send to_string
      when Proc
        to_string.call c
      else
        raise ArgumentError, "unknown to_string argument type; expecting Proc or Symbol"
      end
      puts "  #{i + 1}) #{pretty}"
    end

    js = while true
      is = ask "#{name.capitalize} (1--#{stuff.size})"
      next unless is
      is = is.strip.split(/\s*,\s*/).map { |i| i.to_i }
      break is if is.all? { |i| (1 .. stuff.size).member?(i) }
    end

    ss = js.map { |j| stuff[j - 1] }
    (many)? ss : ss.first
  end
end

