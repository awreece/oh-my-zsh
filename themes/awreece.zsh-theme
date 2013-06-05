# Print time from last command iff it took longer than threshold seconds.
ZSH_THEME_COMMAND_TIME_THRESHOLD=0.0
ZSH_THEME_COMMAND_TIME_PREFIX=""
ZSH_THEME_COMMAND_TIME_SUFFIX=""

ZSH_THEME_SSH_HOST_PREFIX=""
ZSH_THEME_SSH_HOST_SUFFIX=" "

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
      printf "%.3fs" $last_run_time
    elif (( $last_run_time < (60 * 60) )); then
      printf "%.3fm" $(( last_run_time / 60 ))
    elif (( $last_run_time < (60 * 60 * 24) )); then
      printf "%.3fh" $(( last_run_time / (60*60) ))
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
    echo -n "%n@%m"
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

# Success color colors the text green if the previous command succeeded and
# red otherwise.
function sc() {
  echo -n "%(?.%{$fg[green]%}.%{$fg[red]%})$argv%{$reset_color%}"
}

# Prompt will look like:

# Developer%                                       ~/Developer alex@cmu 2.001s
# ^        ^                                       ^           ^        ^
# |        |                                       |           |        |
# |        +-> A '#' if root shell, colored green  |           |        |
# |            if last command was successful and  |           |        |
# |            red otherwise.                      |           |        |
# |                                                |           |        |
# +----------> Last part in current path.          |           |        |
#                                                  |           |        |
#              Full path to cwd (if full path is <-+           |        |
#              longer than 1 segment).                         |        |
#                                                              |        |
#              ssh user@hostname (if connected   <-------------+        |
#              via ssh).                                                |
#                                                                       |
#              Duration of last command.            <-------------------+
PROMPT='$(c blue "%1~")$(c magenta "%#") '
RPROMPT='%(2~.$(c blue "%~") .)$(c cyan "$(ssh_host)")$(sc "$(command_time)")'
