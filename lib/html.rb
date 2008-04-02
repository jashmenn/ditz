require 'erb'

module Ditz

## pass through any variables needed for template generation, and add a bunch
## of HTML formatting utility methods.
class ErbHtml
  def initialize template_dir, template_name, links, mapping={}
    @template_name = template_name
    @template_dir = template_dir
    @links = links
    @mapping = mapping

    @@erbs ||= {}
    @@erbs[template_name] ||= ERB.new(IO.readlines(File.join(template_dir, "#{template_name}.rhtml")).join)
  end

  def h o; o.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;") end
  def p o; "<p>" + h(o.to_s).gsub("\n\n", "</p><p>") + "</p>" end
  def obscured_email e; h e.gsub(/@.*?(>|$)/, "@...\\1") end
  def link_to o, name
    dest = @links[o]
    dest = o if dest.nil? && o.is_a?(String)
    raise ArgumentError, "no link for #{o.inspect}" unless dest
    "<a href=\"#{dest}\">#{name}</a>"
  end

  def render template_name, morevars={}
    ErbHtml.new(@template_dir, template_name, @links, @mapping.merge(morevars)).to_s
  end

  def method_missing meth, *a
    @mapping.member?(meth) ? @mapping[meth] : super
  end

  def to_s
    @@erbs[@template_name].result binding
  end
end

end
