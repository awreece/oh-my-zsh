ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}["
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg[yellow]%}]%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%}*%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN=""

# Print time from last command iff it took longer than threshold seconds.
ZSH_THEME_COMMAND_TIME_THRESHOLD=0.0
ZSH_THEME_COMMAND_TIME_PREFIX="%(?.%{$fg[green]%}.%{$fg[red]%})"
ZSH_THEME_COMMAND_TIME_SUFFIX="%{$reset_color%}"

ZSH_THEME_SSH_HOST_PREFIX="%{$fg[cyan]%}"
ZSH_THEME_SSH_HOST_SUFFIX="%{$reset_color%} "

zmodload zsh/datetime

last_run_time=0
last_start_time=$EPOCHREALTIME

function preexec() {
  last_start_time=$EPOCHREALTIME
}

function precmd() {
  # We do these invalid shenanigans because zsh executes precmd but not preexec
  # if an empty line is entered.
  if [[ $last_start_time != 'invalid' ]]
  then
    last_run_time=$((EPOCHREALTIME - last_start_time))
    last_start_time='invalid'
  fi
}

# The (human readable) run time of the last command executed.
function command_time() {
  if (( $last_run_time > $ZSH_THEME_COMMAND_TIME_THRESHOLD ))
  then
    echo -n $ZSH_THEME_COMMAND_TIME_PREFIX
    if (( $last_run_time < 10 )); then
      printf "%0.3fs" $last_run_time
    elif (( $last_run_time < 60 )); then
      printf "%.2fs" $last_run_time
    elif (( $last_run_time < (60 * 60) )); then
      printf "%.2fm" $(( last_run_time / 60 ))
    elif (( $last_run_time < (60 * 60 * 24) )); then
      printf "%.2fh" $(( last_run_time / (60*60) ))
    else
      printf "%.2fd" $(( last_run_time / (60*60*24) ))
    fi
    echo -n $ZSH_THEME_COMMAND_TIME_SUFFIX
  fi
}

# Return a zero exit status iff the current shell is controlled via ssh.
function is_ssh() {
  # http://unix.stackexchange.com/a/9607/18208
  if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ]; then
    return 0
  else
    case $(ps -o comm= -p $PPID) in
      sshd|*/sshd) return 1;;
    esac
  fi
  return 1
}

# The hostname if connected on ssh.
function ssh_host() {
  if is_ssh; then
    echo -n $ZSH_THEME_SSH_HOST_PREFIX
    echo -n "[%m]"
    echo -n $ZSH_THEME_SSH_HOST_SUFFIX
  fi
}

# Color the text with the appropriate foreground color.
# Usage:
#   c <color> <text>
#
# Example:
#   c red %~
function c() {
  color=$1
  shift argv
  echo -n "%{$fg[$color]%}$argv%{$reset_color%}"
}

PROMPT='$(c magenta "%#")%{$reset_color%} '
RPROMPT='$(c blue "%~") $(ssh_host)$(command_time)%{$reset_color%}'
