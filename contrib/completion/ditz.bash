# ditz bash completion
#
# author: Christian Garbs
#
# based on bzr.simple by Martin Pool

_ditz() 
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    if [ $COMP_CWORD -eq 1 ]; then
	COMPREPLY=( $( compgen -W "$(ditz --commands)" -- $cur ) )
    else
	unset COMP_WORDS[COMP_CWORD]  # remove last
	unset COMP_WORDS[0]           # remove first
	COMPREPLY=( $( compgen -W "$(ditz "${COMP_WORDS[@]}" '<options>' 2>/dev/null)" -- $cur ) )
    fi 
}

complete -F _ditz -o default ditz
