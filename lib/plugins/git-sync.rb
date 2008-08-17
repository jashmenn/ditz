## git-sync ditz plugin
## 
## This plugin is useful for when you want synchronized, non-distributed issue
## coordination with other developers, and you're using git. It allows you to
## synchronize issue updates with other developers by using the 'ditz sync'
## command, which does all the git work of sending and receiving issue change
## for you. However, you have to set things up in a very specific way for this
## to work:
##
## 1. Your ditz state must be on a separate branch. I recommend calling it
##    'bugs'. Create this branch, do a ditz init, and push it to the remote
##    repo. (This means you won't be able to mingle issue change and code
##    change in the same commits. If you care.)
## 2. Make a checkout of the bugs branch in a separate directory, but NOT in
##    your code checkout. If you're developing in a directory called "project",
##    I recommend making a ../project-bugs/ directory, cloning the repo there
##    as well, and keeping that directory checked out to the 'bugs' branch.
##    (There are various complicated things you can do to make that directory
##    share git objects with your code directory, but I wouldn't bother unless
##    you really care about disk space. Just make it an independent clone.)
## 3. Set that directory as your issue-dir in your .ditz-config file in your
##    code checkout directory. (This file should be in .gitignore, btw.)
## 4. Run 'ditz reconfigure' and fill in the local branch name, remote
##    branch name, and remote repo for the issue tracking branch.
##
## Once that's set up, 'ditz sync' will change to the bugs checkout dir, bundle
## up any changes you've made to issue status, push them to the remote repo,
## and pull any new changes in too. All ditz commands will read from your bugs
## directory, so you should be able to use ditz without caring about where
## things are anymore.
##
## This complicated setup is necessary to avoid accidentally mingling code
## change and issue change. With this setup, issue change is synchronized,
## but how you synchronize code is still up to you.

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
