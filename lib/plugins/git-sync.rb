module Ditz
class Operator
  operation :sync, "Sync the repo containing ditz via git"
  def sync project, config, issue, maybe_string
    Dir.chdir $project_root
    sh "git commit -m 'issue updates'"
    sh "git pull"
    sh "git push"
  end

  private

  def sh s
    puts "+ #{s}"
    unless system s
      $stderr.puts "can't execute: #{s}"
      exit(-1)
    end
  end
end

end
