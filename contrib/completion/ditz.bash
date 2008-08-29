# ditz bash completion
#
# author: Christian Garbs
#
# based on bzr.simple by Martin Pool

_ditz() 
{
    local cur=${COMP_WORDS[COMP_CWORD]}

    if [ $COMP_CWORD -eq 1 ]; then
	# no command yet, show all commands
	COMPREPLY=( $( compgen -W "$(ditz --commands)" -- $cur ) )

    else
	unset COMP_WORDS[COMP_CWORD]  # remove last
	unset COMP_WORDS[0]           # remove first
	
	# add options if applicable...
	local options
	if [ "${cur:0:1}" = '-' ]; then
	    # ...but only if at least a dash is given
	    case "${COMP_WORDS[1]}" in
		add|add_reference|add_release|assign|close|comment|release|set_component|start|stop|unassign)
		    options="--comment --no-comment"
		    ;;
		edit)
		    options="--comment --no-comment --silent"
		    ;;
	    esac
	fi
	
	# let ditz parse the commandline and print available completions, then append the options form above
	COMPREPLY=( $( compgen -W "$(ditz "${COMP_WORDS[@]}" '<options>' 2>/dev/null) $options" -- $cur ) )
    fi 
}

complete -F _ditz -o default ditz
