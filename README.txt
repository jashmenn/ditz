== ditz

by William Morgan <wmorgan-ditz at the masanjin dot nets>

http://ditz.rubyforge.org

== DESCRIPTION

Ditz is a simple, light-weight distributed issue tracker designed to work with
distributed version control systems like git, darcs, Mercurial, and Bazaar. It
can also be used with centralized systems like SVN.

Ditz maintains an issue database directory on disk, with files written in a
line-based and human-editable format. This directory can be kept under version
control, alongside project code.

There are several different ways to use ditz:

1. Treat issue change the same as code change: include it as part of commits,
   and merge it with changes from other developers, resolving conflicts in the
   usual manner.
2. Keep the issue database in the repository but in a separate branch. Issue
   changes can be managed by your VCS, but is not tied directly to code
   commits.
3. Keep the issue database separate and not under VCS at all.

Ditz provides a simple, console-based interface for creating and updating the
issue database file, and some rudimentary static HTML generation capabilities
for producing world-readable status pages (for a demo, see the ditz ditz page).
It currently offers no central public method of bug submission. 

== SYNOPSIS

# set up project. creates the bugs.yaml file.
1. ditz init
2. ditz add-release

# add an issue
3. ditz add

# where am i?
4. ditz status
5. ditz todo (or simply "ditz")

# do work
6. write code
7. ditz close <issue-id>
8. commit
9. goto 3

# finished!
10. ditz release <release-name>

== THE DITZ DATA MODEL

Ditz includes the bare minimum set of features necessary for open-source
development. Features like time spent, priority, assignment of tasks to
developers, due dates, etc. are purposely excluded.

A ditz project consists of issues, releases and components.

Issues:
  Issues are the fundamental currency of issue tracking. A ditz issue is either
  a feature or a bug, but this distinction doesn't affect anything other than
  how they're displayed.

  Each issue belongs to exactly one component, and is part of zero or one
  releases.

  Each issues has an exportable id, in the form of 40 random hex characters.
  This id is "guaranteed" to be unique across all possible issues and
  developers, present and future. Issue ids are typically not exposed to the
  user.

  Issues also have a non-exportable name, which is short and human-readable.
  All ditz commands use issue names instead of issue ids. Issue ids may change
  in certain circumstances, specifically after a "ditz drop" command.

Components:
  There is always one "general" component, named after the project itself. In
  the simplest case, this is the only component, and the user is never bothered
  with the question of which component to assign an issue to.

  Components simply provide a way of organizing issues, and have no real
  functionality. Issues are assigned names derived form the component they're
  assigned to.

Releases:
  A release is the primary grouping mechanism for issues. Status commands like
  "ditz status" and "ditz todo" always group issues by release. When a release
  is 100% complete, it can be marked as released, in which case the associated
  issues will cease appearing in ditz status and todo messages.

== FUTURE WORK

In future releases, Ditz will have a plugin architecture to allow tighter
integration with specific SCMs and developer communication channels. (See
http://ditz.rubyforge.org/ditz/issue-0704dafe4aef96279364013aba177a0971d425cb.html)

== LEARNING MORE

* ditz help
* find $DITZ_INSTALL_DIR -type f | xargs cat

== REQUIREMENTS

* trollop >= 1.8.2

== INSTALLATION

Download tarballs from http://rubyforge.org/projects/ditz/, or command your
computer to "gem install ditz".

== LICENSE

Copyright (c) 2008 William Morgan.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

