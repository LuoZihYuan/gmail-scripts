_gmail_scripts_make() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local words="${COMP_WORDS[*]}"
  local scripts
  scripts=$(ls -d scripts/*/ 2>/dev/null | xargs -I{} basename {})

  if [[ "$cur" == s=* ]]; then
    local prefix="${cur#s=}"
    COMPREPLY=($(compgen -W "$scripts" -P "s=" -- "$prefix"))
  elif [[ "$cur" == t=* ]]; then
    COMPREPLY=("$cur")
  elif [[ "$words" == *"s="* && "$words" != *"t="* && ("$words" == *" new "* || "$words" == *" init "*) ]]; then
    COMPREPLY=($(compgen -W "t=" -- "$cur"))
  elif [[ "$words" == *" new "* || "$words" == *" init "* || "$words" == *" deploy "* || "$words" == *" publish "* || "$words" == *" open "* ]]; then
    COMPREPLY=($(compgen -W "s=" -- "$cur"))
  else
    COMPREPLY=($(compgen -W "new init deploy publish open help" -- "$cur"))
  fi
}

complete -F _gmail_scripts_make make