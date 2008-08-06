module Ditz
class Operator
  operation :sync, "Sync the repo containing ditz via git"
  def sync project, config
    Dir.chdir $project_root
    puts "[in #{$project_root}]"
    sh "git add *.yaml", :force => true
    sh "git commit -m 'issue updates'", :force => true
    sh "git pull"
    sh "git push"
  end

  private

  def sh s, opts={}
    puts "+ #{s}"
    unless system(s) || opts[:force]
      $stderr.puts "non-zero (#{$?.exitstatus}) exit code: #{s}"
      exit(-1)
    end
  end
end

end
