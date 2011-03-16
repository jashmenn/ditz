## sha-names ditz plugin
## 
## This world's-smallest-ditz-plugin uses the initial 5 characters of
## the SHA id instead of an identifier like "ditz-999".  Installing
## this plugin will cause all references of the form 'ditz-123' and
## 'engine-57' to change to '1a2bc', 'f33d0' and similarly memorable
## IDs.  If you are comfortable working with them (your clients may
## not be...)  these make all issue IDs unique across the project, so
## long as you do not get a collision between two 5-hex-char IDs.
##
## Without this plugin, the standard ID for an issue will be of the
## form 'design-123'. Whilst this is easier to remember, it is also
## liable to change - for example, if two ditz trees are merged
## together, or if an issue is re-assigned from one component to
## another. This plugin provides a canonical, immutable ID from the
## time of issue creation.
##
## Usage: 
##   1. add a line "- sha-names" to the .ditz-plugins file in the
##   project root

module Ditz

class Project

  SHA_NAME_LENGTH = 5

  def assign_issue_names!
    issues.sort_by { |i| i.creation_time }.each do |i|
      i.name = i.id.slice(0,SHA_NAME_LENGTH)
    end
  end

end
end
