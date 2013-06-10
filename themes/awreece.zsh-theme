# Print time from last command iff it took longer than threshold seconds.
ZSH_THEME_COMMAND_TIME_THRESHOLD=0.0
ZSH_THEME_COMMAND_TIME_PREFIX=""
ZSH_THEME_COMMAND_TIME_SUFFIX=""

# Notify if command takes longer than threshold seconds.
ZSH_THEME_NOTIFY_THRESHOLD=60.0
ZSH_THEME_NOTIFY_FUNCTION=zsh_theme_notify_function
# Don't notify for these commands.
ZSH_THEME_NOTIFY_BLACKLIST=(vim ssh less man \
                            "git commit" "git add -p" "git rebase -i")

ZSH_THEME_SSH_HOST_PREFIX="["
ZSH_THEME_SSH_HOST_SUFFIX="] "

function zsh_theme_notify_function() {
  message=$(printf "Command \"%s\" finished (%d) after %s" \
                   $last_command $last_status $(time_to_human $last_run_time))
  if ! is_ssh; then
    terminal-notifier -group zsh -message $message
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

zmodload zsh/datetime

last_run_time=0
last_start_time='invalid'
last_command=''
last_status=0

function preexec() {
  last_start_time=$EPOCHREALTIME
  last_command=$1
}

function should_notify() {
  # Check that it is not in the blacklist.
  for command in $ZSH_THEME_NOTIFY_BLACKLIST; do
    if [[ $last_command =~ $command ]]; then
      return 1
    fi
  done
  return 0

  # This bit of magic is:
  #     test that the result is the empty string
  #     |  when we look in the blacklist array
  #     |  |                            by reverse index
  #     |  |                            |  when we strip all characters
  #     |  |                            |  after the  first space.
  #     |  |                            |  |
  #  [[ -z ${ZSH_THEME_NOTIFY_BLACKLIST[(r)${last_command%% *}]} ]]
}

function precmd() {
  exit_status=$?
  # We do these invalid shenanigans because zsh executes precmd but not preexec
  # if an empty line is entered.
  if [[ $last_start_time != 'invalid' ]]; then
    last_status=$exit_status
    last_run_time=$((EPOCHREALTIME - last_start_time))

    if (( last_run_time > ZSH_THEME_NOTIFY_THRESHOLD )); then
       if should_notify; then
        $ZSH_THEME_NOTIFY_FUNCTION
      fi
    fi

    last_start_time='invalid'
    last_command=''
  # else
  #   # Don't print command_time when no command given.
  #   last_run_time=0
  fi
}

function time_to_human() {
    if (( $1 < 10 )); then
      printf "%6.3fs" $1
    elif (( $1 < 60 )); then
      printf "%6.3fs" $1
    elif (( $1 < (60 * 60) )); then
      printf "%6.3fm" $(( 1 / 60 ))
    elif (( $1 < (60 * 60 * 24) )); then
      printf "%6.3fh" $(( 1 / (60*60) ))
    else
      printf "%6.3fd" $(( 1 / (60*60*24) ))
    fi
}

# The (human readable) run time of the last command executed.
function command_time() {
  if (( $last_run_time > $ZSH_THEME_COMMAND_TIME_THRESHOLD ))
  then
    echo -n $ZSH_THEME_COMMAND_TIME_PREFIX
    time_to_human $last_run_time
    echo -n $ZSH_THEME_COMMAND_TIME_SUFFIX
  fi
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
###############################################################################
# +----------- Last part in current path.
# |
# |        +-- A '#' if root shell, colored green
# |        |   if last command was successful and
# |        |   red otherwise.
# |        |
# |        |   Duration of last command.          -----------------------+
# |        |                                                             |
# |        |   ssh user@hostname (if connected    --------------+        |
# |        |   via ssh).                                        |        |
# |        |                                                    |        |
# |        |   Full path to cwd (if full path is  --+           |        |
# |        |   longer than 1 segment).              |           |        |
# v        v                                        v           v        v
###############################################################################
# Developer%                                        ~/Developer alex@cmu 2.001s

PROMPT='$(c blue "%1~")$(c magenta "%#") '
RPROMPT='%(2~.$(c blue "%~") .)$(c cyan "$(ssh_host)")$(sc "$(command_time)")'
