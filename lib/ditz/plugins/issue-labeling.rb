## issue-labeling ditz plugin
## 
## This plugin allows label issues. This can replace the issue component
## and/or issue types (bug,feature,task), by providing a more flexible
## to organize your issues.
##
## Commands added:
##   ditz new_label [label]: create a new label for the project
##   ditz label <issue> <labels>: label an issue with some labels
##   ditz unlabel <issue> [labels]: remove some label(s) of an issue
##   ditz labeled <labels> [release]: show all issues with these labels
##
## Usage:
##   1. add a line "- issue-labeling" to the .ditz-plugins file in the project
##      root
##   2. use the above commands to abandon

# TODO:
#   * extend the HTML view to have per-labels listings
#   * allow for more compact way to type them (completion, prefixes...)

module Ditz

class Label < ModelObject
  include Comparable
  field :name

  def name_prefix; @name.gsub(/\s+/, "-").downcase end

  def <=> x ; name <=> x.name end
  def == x ; name == x.name end

end # class Label

class Project
  field :labels, :multi => true, :interactive_generator => :get_labels

  def get_labels
    lab_names = ask_for_many("labels")
    ([name] + lab_names).uniq.map { |n| Label.create_interactively :with => { :name => n } }
  end

  def label_for label_name
    labels.find { |i| i.name == label_name }
  end

  def labels_for label_names
    label_names.split(/\s*,\s*/).map do |val|
      label_for(val) or raise Error, "no label with name #{val}"
    end
  end

end # class Project

class Issue
  field :labels, :multi => true, :interactive_generator => :get_labels

  def get_labels config, project
    ask_for_selection(project.labels, "label", :name, true).map {|x|x.name}
  end

  def apply_labels new_labels, who, comment
    log "issue labeled", who, comment
    new_labels.each { |l| add_label l }
  end

  def remove_labels labels_to_remove, who, comment
    log "issue unlabeled", who, comment
    if labels_to_remove.nil?
      self.labels = []
    else
      labels_to_remove.each { |l| drop_label l }
    end
  end

  def labeled? label=nil; (label.nil?)? !labels.empty? : labels.include?(label) end
  def unlabeled? label=nil; !labeled?(label) end
end

class ScreenView
  add_to_view :issue_summary do |issue, config|
    "     Labels: #{(issue.labeled?)? issue.labels.map{|l|l.name}.join(', ') : 'none'}\n"
  end
end

class HtmlView
  add_to_view :issue_summary do |issue, config|
    next if issue.unlabeled?
    [<<EOS, { :issue => issue }]
<tr>
  <td class='attrname'>Labels:</td>
  <td class='attrval'><%= h(issue.labels.map{|l|l.name}.join(', ')) %></td>
</tr>
EOS
  end
end

class Operator

  operation :new_label, "Create a new label for the project", :maybe_label
  def new_label project, config, maybe_label
    puts "Adding label #{maybe_label}." if maybe_label
    label = Label.create_interactively(:args => [project, config], :with => { :name => maybe_label }) or return
    project.add_label label
    puts "Added label #{label.name}."
  end

  operation :label, "Apply labels to an issue", :issue, :labels
  def label project, config, issue, label_names
    labels = project.labels_for label_names
    puts "Adding labels #{label_names} to issue #{issue.name}: #{issue.title}."
    comment = ask_multiline "Comments" unless $opts[:no_comment]
    issue.apply_labels labels, config.user, comment
    show_labels issue
  end

  operation :unlabel, "Remove some labels of an issue", :issue, :maybe_labels
  def unlabel project, config, issue, label_names
    labels = if label_names
               puts "Removing #{label_names} labels from issue #{issue.name}: #{issue.title}."
               project.labels_for label_names
             else
               puts "Removing labels from issue #{issue.name}: #{issue.title}."
              nil
             end
    comment = ask_multiline "Comments" unless $opts[:no_comment]
    issue.remove_labels labels, config.user, comment
    show_labels issue
  end

  def show_labels issue
    if issue.labeled?
      puts "Issue #{issue.name} is now labeled with #{issue.labels.map{|l|l.name}.join(', ')}"
    else
      puts "Issue #{issue.name} is now unlabeled"
    end
  end
  private :show_labels

  operation :labeled, "Show labeled issues", :labels, :maybe_release do
    opt :all, "Show all issues, not just open ones"
  end
  def labeled project, config, opts, labels, releases
    releases ||= project.unreleased_releases + [:unassigned]
    releases = [*releases]
    labels = project.labels_for labels

    issues = project.issues.select do |i|
      r = project.release_for(i.release) || :unassigned
      labels.all? { |l| i.labeled? l } && (opts[:all] || i.open?) && releases.member?(r)
    end

    if issues.empty?
      puts "No issues."
    else
      print_todo_list_by_release_for project, issues
    end
  end
end

end
