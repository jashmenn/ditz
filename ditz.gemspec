Gem::Specification.new do |s|
  s.name = %q{ditz}
  s.version = "0.5"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["William Morgan"]
  s.date = %q{2008-09-05}
  s.default_executable = %q{ditz}
  s.description = %q{Ditz is a simple, light-weight distributed issue tracker designed to work with distributed version control systems like git, darcs, Mercurial, and Bazaar. It can also be used with centralized systems like SVN.  Ditz maintains an issue database directory on disk, with files written in a line-based and human-editable format. This directory can be kept under version control, alongside project code.  Ditz provides a simple, console-based interface for creating and updating the issue database files, and some basic static HTML generation capabilities for producing world-readable status pages (for a demo, see the ditz ditz page).  Ditz includes a robust plugin system for adding commands, model fields, and modifying output. See PLUGINS.txt for documentation on the pre-shipped plugins.  Ditz currently offers no central public method of bug submission.   == USING DITZ  There are several different ways to use Ditz:  1. Treat issue change the same as code change: include it as part of commits, and merge it with changes from other developers, resolving conflicts in the usual manner. 2. Keep the issue database in the repository but in a separate branch. Issue changes can be managed by your VCS, but is not tied directly to code commits. 3. Keep the issue database separate and not under VCS at all.}
  s.email = %q{wmorgan-ditz@masanjin.net}
  s.executables = ["ditz"]
  s.extra_rdoc_files = ["Manifest.txt", "PLUGINS.txt", "README.txt"]
  s.files = ["Changelog", "INSTALL", "LICENSE", "Manifest.txt", "PLUGINS.txt", "README.txt", "Rakefile", "ReleaseNotes", "bin/ditz", "contrib/completion/_ditz.zsh", "contrib/completion/ditz.bash", "lib/ditz.rb", "lib/ditz/file-storage.rb", "lib/ditz/hook.rb", "lib/ditz/html.rb", "lib/ditz/lowline.rb", "lib/ditz/model-objects.rb", "lib/ditz/model.rb", "lib/ditz/operator.rb", "lib/ditz/plugins/git-sync.rb", "lib/ditz/plugins/git.rb", "lib/ditz/plugins/issue-claiming.rb", "lib/ditz/plugins/issue-labeling.rb", "lib/ditz/util.rb", "lib/ditz/view.rb", "lib/ditz/views.rb", "share/ditz/index.rhtml", "share/ditz/issue.rhtml", "share/ditz/issue_table.rhtml", "share/ditz/release.rhtml", "share/ditz/unassigned.rhtml", "share/ditz/component.rhtml", "share/ditz/style.css", "share/ditz/blue-check.png", "share/ditz/green-bar.png", "share/ditz/green-check.png", "share/ditz/red-check.png", "share/ditz/yellow-bar.png", "man/man1/ditz.1", "setup.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://ditz.rubyforge.org}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{ditz}
  s.rubygems_version = %q{1.2.0}
  s.summary = %q{A simple issue tracker designed to integrate well with distributed version control systems like git and darcs. State is saved to a YAML file kept under version control, allowing issues to be closed/added/modified as part of a commit.}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if current_version >= 3 then
      s.add_runtime_dependency(%q<trollop>, [">= 1.9"])
      s.add_runtime_dependency(%q<yaml_waml>, [">= 0.3"])
    else
      s.add_dependency(%q<trollop>, [">= 1.9"])
      s.add_dependency(%q<yaml_waml>, [">= 0.3"])
    end
  else
    s.add_dependency(%q<trollop>, [">= 1.9"])
    s.add_dependency(%q<yaml_waml>, [">= 0.3"])
  end
end
