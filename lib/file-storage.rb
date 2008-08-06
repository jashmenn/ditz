module Ditz

## stores ditz database on disk
class FileStorage
  PROJECT_FN = "project.yaml"
  ISSUE_FN_GLOB = "issue-*.yaml"

  def ISSUE_TO_FN i; "issue-#{i.id}.yaml" end

  def initialize base_dir
    @base_dir = base_dir
    @project_fn = File.join @base_dir, PROJECT_FN
  end

  def load
    Ditz::debug "loading project from #{@project_fn}"
    project = Project.from @project_fn

    fn = File.join @base_dir, ISSUE_FN_GLOB
    Ditz::debug "loading issues from #{fn}"
    project.issues = Dir[fn].map { |fn| Issue.from fn }
    Ditz::debug "found #{project.issues.size} issues"

    project.issues.each { |i| i.project = project }
    project
  end

  def save project
    dirty = false
    dirty = project.each_modelobject { |o| break true if o.changed? }
    if dirty
      Ditz::debug "project is dirty, saving #{@project_fn}"
      project.save! @project_fn
    end

    changed_issues = project.issues.select { |i| i.changed? }
    changed_issues.each do |i|
      fn = filename_for_issue i
      Ditz::debug "issue #{i.name} is dirty, saving #{fn}"
      i.save! fn
    end

    project.deleted_issues.each do |i|
      fn = filename_for_issue i
      Ditz::debug "issue #{i.name} has been deleted, deleting #{fn}"
      FileUtils.rm fn
    end
  end

  def filename_for_issue i; File.join @base_dir, ISSUE_TO_FN(i) end
end

end
