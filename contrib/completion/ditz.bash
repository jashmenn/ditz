# ditz bash completion
# 
# author: Christian Garbs
#
# based on bzr.simple by Martin Pool

_ditz() 
{
    cur=${COMP_WORDS[COMP_CWORD]}
    if [ $COMP_CWORD -eq 1 ]; then
	COMPREPLY=( $( compgen -W "$(ditz --commands)" $cur ) )
    elif [ $COMP_CWORD -eq 2 ]; then
	COMPREPLY=( $( compgen -W "$(ditz todo-full 2>/dev/null | grep '^. ' | cut -c 3- | cut -d : -f 1)" $cur ) )
    fi 
}

complete -F _ditz -o default ditz
