module Ditz

class Config
  field :git_sync_local_branch, :prompt => "Local bugs branch name for ditz sync", :default => "bugs"
  field :git_sync_remote_branch, :prompt => "Remote bugs branch name for ditz sync", :default => "bugs"
  field :git_sync_remote_repo, :prompt => "Remote bugs repo name for ditz sync", :default => "origin"
end

class Operator
  operation :sync, "Sync the repo containing ditz via git" do
    opt :dry_run, "Dry run: print the commants, but don't execute them", :short => "n"
  end
  def sync project, config, opts
    unless config.git_sync_local_branch
      $stderr.puts "Please run ditz reconfigure and set the local and remote branch names"
      return
    end

    Dir.chdir $project_root
    puts "[in #{$project_root}]"
    sh "git add *.yaml", :force => true, :fake => opts[:dry_run]
    sh "git commit -m 'issue updates'", :force => true, :fake => opts[:dry_run]
    sh "git pull", :fake => opts[:dry_run]
    sh "git push #{config.git_sync_remote_repo} #{config.git_sync_local_branch}:#{config.git_sync_remote_branch}", :fake => opts[:dry_run]
    puts
    puts "Ditz issue state synchronized."
  end

  private

  def sh s, opts={}
    puts "+ #{s}"
    return if opts[:fake]
    unless system(s) || opts[:force]
      $stderr.puts "non-zero (#{$?.exitstatus}) exit code: #{s}"
      exit(-1)
    end
  end
end

end
