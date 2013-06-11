# Print time from last command iff it took longer than threshold seconds.
ZSH_THEME_COMMAND_TIME_THRESHOLD=0.0
ZSH_THEME_COMMAND_TIME_PREFIX=""
ZSH_THEME_COMMAND_TIME_SUFFIX=""

ZSH_THEME_SSH_HOST_PREFIX="["
ZSH_THEME_SSH_HOST_SUFFIX="] "

# Returns true if the current os is Mac OSX.
function is_mac() {
  [[ $(uname -a) =~ "Darwin" ]]
}

zmodload zsh/datetime  # For EPOCHREALTIME.

last_run_time=0
last_start_time='invalid'
last_command=''
last_status=0

if is_mac; then
  terminal_window_id=$(osascript -e 'tell application "Terminal" to ¬' \
                                 -e '  get id of front window')
fi

# Returns true if the current window has focus.
# Warning: Currently only implementd on mac.
function is_focused() {
  if is_mac; then
    focus_window_id=$(osascript -e 'tell application "System Events" to ¬' \
                                -e '  set focus_app_name to ¬' \
                                -e '    name of first application process ¬' \
                                -e '    whose frontmost is true' \
                                -e 'tell application focus_app_name to ¬' \
                                -e '  get id of front window')
  fi
  # On a not mac, this will always return true since focus_id and
  # terminal_window_id are both undefined so empty strings.
  [[ $focus_window_id == $terminal_window_id ]]
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

# Executed right before a command is exectued.
function preexec() {
  last_start_time=$EPOCHREALTIME
  last_command=$1
}

# Executed right after a command completes.
function precmd() {
  exit_status=$?
  # We do these invalid shenanigans because zsh executes precmd but not preexec
  # if an empty line is entered.
  if [[ $last_start_time != 'invalid' ]]; then
    last_status=$exit_status
    last_run_time=$((EPOCHREALTIME - last_start_time))

    if ! is_focused; then
      notify_function
    fi
   
    last_start_time='invalid'
    last_command=''
  # else
  #   # Don't print command_time when no command given.
  #   last_run_time=0
  fi
}

# Sends a notification that the last command terminated.
# Warning: currently only implemented for mac.
function notify_function() {
  message=$(printf "Command \"%s\" finished (%d) after %s" \
                   $last_command $last_status $(time_to_human $last_run_time))
  if is_mac; then
    callback="osascript -e 'tell application \"Terminal\"' \
                        -e 'activate' \
                        -e 'set index of window id $terminal_window_id to 1' \
                        -e 'end tell'"
    terminal-notifier -group zsh -message $message -execute $callback >/dev/null
  fi
}

# Converts a floating point time in seconds to a human readable string.
function time_to_human() {
    seconds=$1
    if (( seconds < 10 )); then
      printf "%6.3fs" $seconds
    elif (( seconds < 60 )); then
      printf "%6.3fs" $seconds
    elif (( seconds < (60*60) )); then
      printf "%6.3fm" $(( seconds / 60 ))
    elif (( seconds < (60*60*24) )); then
      printf "%6.3fh" $(( seconds / (60*60) ))
    else
      printf "%6.3fd" $(( seconds / (60*60*24) ))
    fi
}

# The (human readable) run time of the last command executed.
function command_time() {
  if (( last_run_time > ZSH_THEME_COMMAND_TIME_THRESHOLD ))
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
#   color <color> <text>
#
# Example:
#   color red %~
function color() {
  c=$1
  shift argv
  echo -n "%{$fg[$c]%}$argv%{$reset_color%}"
}

# Success color colors the text green if the previous command succeeded and
# red otherwise.
function success_color() {
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
# |        |                                        |           |        |
# |        |   Number of jobs if any.          --+  |           |        |
# v        v                                     v  v           v        v
###############################################################################
# Developer%                                     1& ~/Developer alex@cmu 2.001s

function prompt() {
  color blue "%1~"
  color magenta "%#"
  echo -n " "
}

function rprompt() {
  echo -n "%(1j.$(color yellow '%j&') .)"
  echo -n "%(2~.$(color blue '%~') .)"
  color cyan "$(ssh_host)"
  success_color "$(command_time)"
}

PROMPT='$(prompt)'
RPROMPT='$(rprompt)'
