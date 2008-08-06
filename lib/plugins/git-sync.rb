module Ditz
class Operator
  operation :sync, "Sync the repo containing ditz via git"
  def sync project, config
    Dir.chdir $project_root
    puts "[in #{$project_root}]"
    sh "git commit -a -m 'issue updates'", :force => true
    sh "git pull"
    sh "git push"
  end

  private

  def sh s, opts={}
    puts "+ #{s}"
    unless opts[:force] || system(s)
      $stderr.puts "non-zero (#{$?.exitstatus}) exit code: #{s}"
      exit(-1)
    end
  end
end

end
