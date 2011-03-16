module Ditz

class Issue
  alias :old_start_work :start_work
  alias :old_stop_work :stop_work
  field :time_spent, :generator => :get_time_spent
  field :mark_time, :generator => :get_mark_time
  def get_time_spent(config, project)
    time_spent || 0
  end
  def get_mark_time(config, project)
    self.mark_time || 0
  end
  def start_work(who, comment)
    self.mark_time = Time.now
    old_start_work(who, comment)
  end
  def stop_work(who, comment)
    self.time_spent += Time.now - self.mark_time
    self.mark_time = Time.now
    old_stop_work(who, comment)
  end
end

class ScreenView
  def self.modulo(seconds, quotient)
    result, remainder = seconds / quotient, seconds % quotient
  end
  def self.humanize(seconds)
    result = ""
    %w[year month day hour minute second].zip([3600*24*30*365, 3600*24*30, 3600*24, 3600, 60, 1]).inject(seconds) do |seconds, item|
      num, seconds = modulo(seconds, item[1])
      result << "#{item[0].pluralize(num)} " unless num == 0
      seconds
    end
    result
  end
  def self.get_time_spent(issue)
    if issue.status == :paused
      issue.time_spent
    elsif issue.time_spent && issue.mark_time
      issue.time_spent + (Time.now - issue.mark_time)
    else
      0
    end
  end
  add_to_view :issue_summary do |issue, config|
    " Time spent: #{humanize(get_time_spent(issue).to_i)}\n"
  end
end

end
