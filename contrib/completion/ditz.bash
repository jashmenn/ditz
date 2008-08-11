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
    elif [ $COMP_CWORD -eq 2 ]; then
	local cmd=${COMP_WORDS[1]}
	COMPREPLY=( $( compgen -W "$(ditz "$cmd" '<options>' 2>/dev/null)" -- $cur ) )
    elif [ $COMP_CWORD -eq 3 ]; then
	local cmd=${COMP_WORDS[1]}
	local parm1=${COMP_WORDS[2]}
	COMPREPLY=( $( compgen -W "$(ditz "$cmd" "$parm1" '<options>' 2>/dev/null)" -- $cur ) )
    fi 
}

complete -F _ditz -o default ditz
