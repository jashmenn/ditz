module Ditz

class View
  def self.add_to_view type, &block
    @views ||= {}
    @views[type] ||= []
    @views[type] << block
  end

  def self.view_additions_for type
    @views ||= {}
    @views[type] || []
  end
end

end
