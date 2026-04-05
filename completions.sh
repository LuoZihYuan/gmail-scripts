if [ -n "$ZSH_VERSION" ]; then
  _gmail_scripts_make() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$repo_root" ] || [[ "$(basename "$repo_root")" != *gmail-scripts* ]]; then
      _make "$@"
      return
    fi

    local -a scripts
    scripts=(${(f)"$(ls -d scripts/*/ 2>/dev/null | xargs -I{} basename {})"})

    case "$words" in
      *s=*)
        if [[ "$words" != *t=* && ("$words" == *" new "* || "$words" == *" init "*) ]]; then
          compadd -S '' -- "t="
        fi
        ;;
      *" new "*)
        compadd -S '' -- "s="
        ;;
      *" init "*|*" deploy "*|*" publish "*|*" open "*)
        compadd -S '' -P "s=" -- "${scripts[@]}"
        ;;
      *)
        compadd -- new init deploy publish open help
        ;;
    esac
  }

  compdef _gmail_scripts_make make

elif [ -n "$BASH_VERSION" ]; then
  _gmail_scripts_make() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$repo_root" ] || [[ "$(basename "$repo_root")" != *gmail-scripts* ]]; then
      return
    fi

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
    elif [[ "$words" == *" new "* ]]; then
      COMPREPLY=($(compgen -W "s=" -- "$cur"))
    elif [[ "$words" == *" init "* || "$words" == *" deploy "* || "$words" == *" publish "* || "$words" == *" open "* ]]; then
      COMPREPLY=($(compgen -W "s=" -- "$cur"))
    else
      COMPREPLY=($(compgen -W "new init deploy publish open help" -- "$cur"))
    fi
  }

  complete -F _gmail_scripts_make make
fi