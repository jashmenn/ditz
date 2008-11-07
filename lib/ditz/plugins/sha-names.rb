## sha-names ditz plugin
## 
## This world's-smallest-ditz-plugin uses the initial characters of the SHA id instead of
## an identifier like "ditz-999".
##
## Usage:
##   1. add a line "- sha-names" to the .ditz-plugins file in the project root

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
