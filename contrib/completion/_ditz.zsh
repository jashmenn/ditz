#compdef ditz

ME=ditz
COMMANDS=--commands
OPTIONS='<options>'

if (($CURRENT == 2)); then
  # We're completing the first word after the tool: the command.
  _wanted command expl "$ME command" \
    compadd -- $( "$ME" "$COMMANDS" )
else
  # Find the options/files/URL/etc. for the current command by using the tool itself.
      case "${words[$CURRENT]}"; in
        -*)
          _wanted args expl "Arguments for $ME ${words[2]}" \
             compadd -- $( "$ME" "${words[2]}" "$OPTIONS" ; _files )
            ;;
        ht*|ft*)
            _arguments '*:URL:_urls'
            ;;
        /*|./*|\~*|../*)
            _arguments '*:file:_files'
            ;;
        *)
          _wanted args expl "Arguments for $ME ${words[2]}" \
             compadd -- $( "$ME" "${words[2]}" "$OPTIONS" )
          ;;
      esac
fi
