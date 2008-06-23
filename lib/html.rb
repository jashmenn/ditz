require 'erb'

module Ditz

## pass through any variables needed for template generation, and add a bunch
## of HTML formatting utility methods.
class ErbHtml
  def initialize template_dir, links, binding={}
    @template_dir = template_dir
    @links = links
    @binding = binding
  end

  ## return an ErbHtml object that has the current binding plus extra_binding merged in
  def clone_for_binding extra_binding={}
    extra_binding.empty? ? self : ErbHtml.new(@template_dir, @links, @binding.merge(extra_binding))
  end

  def render_template template_name, extra_binding={}
    if extra_binding.empty?
      @@erbs ||= {}
      @@erbs[template_name] ||= ERB.new IO.read(File.join(@template_dir, "#{template_name}.rhtml"))
      @@erbs[template_name].result binding
    else
      clone_for_binding(extra_binding).render_template template_name
    end
  end

  def render_string s, extra_binding={}
    if extra_binding.empty?
      ERB.new(s).result binding
    else
      clone_for_binding(extra_binding).render_string s
    end
  end

  ###
  ### the following methods are meant to be called from the ERB itself
  ###

  def h o; o.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;") end
  def p o; "<p>" + h(o.to_s).gsub("\n\n", "</p><p>") + "</p>" end
  def obscured_email e; h e.gsub(/@.*?(>|$)/, "@...\\1") end
  def link_to o, name
    dest = @links[o]
    dest = o if dest.nil? && o.is_a?(String)
    raise ArgumentError, "no link for #{o.inspect}" unless dest
    "<a href=\"#{dest}\">#{name}</a>"
  end

  def link_issue_names project, s
    project.issues.inject(s) do |s, i|
      s.gsub(/\b#{i.name}\b/, link_to(i, i.title))
    end
  end

  ## render a nested ERB
  alias :render :render_template

  def method_missing meth, *a
    @binding.member?(meth) ? @binding[meth] : super
  end
end

end
