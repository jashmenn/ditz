Gem::Specification.new do |s|
  s.name = %q{ditz}
  s.version = "0.4"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["William Morgan"]
  s.date = %q{2008-08-21}
  s.default_executable = %q{ditz}
  s.description = %q{Ditz is a simple, light-weight distributed issue tracker designed to work with distributed version control systems like git, darcs, Mercurial, and Bazaar. It can also be used with centralized systems like SVN.  Ditz maintains an issue database directory on disk, with files written in a line-based and human-editable format. This directory can be kept under version control, alongside project code.  There are several different ways to use ditz:  1. Treat issue change the same as code change: include it as part of commits, and merge it with changes from other developers, resolving conflicts in the usual manner. 2. Keep the issue database in the repository but in a separate branch. Issue changes can be managed by your VCS, but is not tied directly to code commits. 3. Keep the issue database separate and not under VCS at all.  Ditz provides a simple, console-based interface for creating and updating the issue database file, and some rudimentary static HTML generation capabilities for producing world-readable status pages (for a demo, see the ditz ditz page). It currently offers no central public method of bug submission.   Synopsis:  # set up project. creates the bugs.yaml file. 1. ditz init 2. ditz add-release  # add an issue 3. ditz add}
  s.email = %q{wmorgan-ditz@masanjin.net}
  s.executables = ["ditz"]
  s.extra_rdoc_files = ["README.txt"]
  s.files = ["Changelog", "README.txt", "Rakefile", "ReleaseNotes", "bin/ditz", "lib/component.rhtml", "lib/ditz.rb", "lib/hook.rb", "lib/html.rb", "lib/index.rhtml", "lib/issue.rhtml", "lib/issue_table.rhtml", "lib/lowline.rb", "lib/model-objects.rb", "lib/model.rb", "lib/operator.rb", "lib/release.rhtml", "lib/trollop.rb", "lib/style.css", "lib/unassigned.rhtml", "lib/util.rb", "lib/view.rb", "lib/views.rb", "lib/plugins/git.rb", "lib/plugins/issue-claiming.rb", "lib/vendor/yaml_waml.rb", "contrib/completion/ditz.bash", "contrib/completion/_ditz.zsh", "man/ditz.1"]
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
      s.add_development_dependency(%q<hoe>, [">= 1.7.0"])
    else
      s.add_dependency(%q<hoe>, [">= 1.7.0"])
    end
  else
    s.add_dependency(%q<hoe>, [">= 1.7.0"])
  end
end
