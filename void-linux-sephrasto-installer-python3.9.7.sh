#!/bin/sh
# #region[rgba(0, 255, 0, 0.05)] SOURCE-STUB
#
#----------
# Copyright (c) 2023 Kai Thöne
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#----------
#
#----------
# Set Startup Variables
ME="$0"
MYNAME=`basename "$ME"`
MYDIR=`dirname "$ME"`
MYDIR=`cd "$MYDIR"; pwd`
WD=`pwd`
SCRIPT_OPT_DEBUG=false
SCRIPT_OPT_SUDORESTART=false
#
#----------
# Library Script Functions
#
error() {
  unset ECHO_OPTION; [ "`echo -e`" = '-e' ] || ECHO_OPTION='-e'
  # red, bold
  echo $ECHO_OPTION "\033[1;31mE\033[0;1m $MYNAME: ${*}\033[0m" >&2; return 0
}

info() {
  unset ECHO_OPTION; [ "`echo -e`" = '-e' ] || ECHO_OPTION='-e'
  # cyan
  echo $ECHO_OPTION "\033[1;36mI\033[0m $MYNAME: ${*}\033[0m" >&2; return 0
}

debug() {
  [ "$SCRIPT_OPT_DEBUG" = true ] && {
    unset ECHO_OPTION; [ "`echo -e`" = '-e' ] || ECHO_OPTION='-e'
    # blue
    echo $ECHO_OPTION "\033[1;34mD\033[0m $MYNAME: ${*}\033[0m" >&2
  }; return 0
}

warn() {
  unset ECHO_OPTION; [ "`echo -e`" = '-e' ] || ECHO_OPTION='-e'
  # yellow
  echo $ECHO_OPTION "\033[1;33mW\033[0m $MYNAME: ${*}\033[0m" >&2; return 0
}

log() {
  LOGFILE="${MYNAME}.log"
  case "$1" in
    DEBUG|INFO|WARN|ERROR|CRIT) STAGE="$1"; shift;;
    *) STAGE="----";;
  esac
  STAGE="`echo "$STAGE     " | sed -e 's/^\(.\{5\}\).*$/\1/'`"
  TIMESTAMP="`date +%Y%m%d-%H:%M:%S.%N | sed -e 's/\.\([0-9]\{3\}\)[0-9]*$/.\1/'`"
  echo "${TIMESTAMP} ${STAGE} ${*}" >> "$LOGFILE"
  SIZE=`du -b "$LOGFILE" | cut -f1`
  if [ $SIZE -gt 2000000 ]; then
    INDEX=10
    while [ $INDEX -ge 1 ]; do
      INDEXPLUS=`echo "1+$INDEX" | bc`
      SUBLOGFILE="${LOGFILE}.$INDEX"
      [ -f "$SUBLOGFILE" ] && {
        if [ $INDEX -ge 10 ]; then
          rm -f "$SUBLOGFILE"
        else
          mv "$SUBLOGFILE" "${LOGFILE}.$INDEXPLUS"
        fi
      }
      INDEX=$INDEXPLUS
    done
  fi
}

cmd_exists() {
  type "$1" >/dev/null 2>&1
  return $?
}

infofile() {
  while [ -n "$1" ]; do
    [ -r "$1" -a -s "$1" ] && {
      sed 's,.*,\x1b[1;36mI\x1b[0m '"$MYNAME"': \x1b[1;32m&\x1b[0m,' "$1" >&2
    }
    shift
  done
}

check_tool() {
  while [ -n "$1" ]; do
    type "$1" >/dev/null 2>&1 || return 1
    shift
  done
  return 0
}

check_tools() {
  while [ -n "$1" ]; do
    check_tool "$1" || {
      error "Cannot find program '$1'!"
      exit 1
    }
    shift
  done
  return 0
}

getyesorno() {
  # Returns 0 for YES. Returns 1 for NO.
  # Returns 2 for abort.
  DEFAULT_ANSWER="$1"
  USER_PROMPT="$2"
  unset READ_OPTS
  echo " " | read -n 1 >/dev/null 2>&1 && READ_OPTS='-n 1'
  #--
  unset OK_FLAG
  while [ -z "$OK_FLAG" ]; do
    read -r $READ_OPTS -p "? $MYNAME: $USER_PROMPT" YNANSWER
    [ $? -ne 0 ] && return 2
    if [ -z "$YNANSWER" ]; then
      YNANSWER="$DEFAULT_ANSWER"
    else
      echo
    fi
    case "$YNANSWER" in
      [yY])
        YNANSWER=Y
        return 0
        ;;
      [nN])
        YNANSWER=N
        return 1
        ;;
    esac
  done
}  # getyesorno

read_string() {
  # Usage: read_string PROMPT VARIABLE
  # Returns 0 for YES. Returns 1 for NO.
  USER_PROMPT="$1"
  VARIABLE="$2"
  #--
  unset OK_FLAG
  while [ -z "$OK_FLAG" ]; do
    read -r -p "QUESTION -- $USER_PROMPT" $VARIABLE
    [ $? -ne 0 ] && return 1
    # VALUE=`eval echo \\\${$VARIABLE}`
    # echo "$VARIABLE=$VALUE RC=$RC"
    # [ -z "$VALUE" ] && return 1
    return 0
  done
}  # read_string

open34() {
  OPEN34_TMPFILE=`mktemp -p "$MYDIR" "$MYNAME-34-XXXXXXX"`
  exec 3>"$OPEN34_TMPFILE"
  exec 4<"$OPEN34_TMPFILE"
  rm -f "$OPEN34_TMPFILE"
}  # open34

close34() {
  exec 3>&-
  exec 4<&-
}  # close34

open56() {
  OPEN56_TMPFILE=`mktemp -p "$MYDIR" "$MYNAME-56-XXXXXXX"`
  exec 5>"$OPEN56_TMPFILE"
  exec 6<"$OPEN56_TMPFILE"
  rm -f "$OPEN56_TMPFILE"
}  # open56

close56() {
  exec 5>&-
  exec 6<&-
}  # close56

getdirectory() {
  #Usage: getdirectory [DIR ...]
  #Echoes the directory names for current or given directories.
  if [ -z "$1" ]; then
    DIR=`pwd`
    BNDIR=`basename "$DIR"`
    echo "$BNDIR"
  else
    while [ -n "$1" ]; do
      BNDIR=`basename "$1"`
      echo "$BNDIR"
      shift
    done
  fi
  return 0
}  # getdirectory

do_check_cmd() {
  echo "$*"
  "$@" || {
    error "Cannot do this! CMD='$*'"
    exit 1
  }
}

do_check_cmd_info() {
  info "$*"
  "$@" || {
    error "Cannot do this! CMD='$*'"
    exit 1
  }
}

do_check_cmd_no_echo() {
  "$@" || {
    error "Cannot do this! CMD='$*'"
    exit 1
  }
}

do_cmd() {
  echo "$*"
  "$@"
}

do_cmd_info() {
  info "$*"
  "$@" || {
    error "Cannot do this! CMD='$*'"
    return 1
  }
  return 0
}

do_check_cmd_output_only_on_error() {
  echo "$*"
  open34
  "$@" >&3 2>&1
  DO_CHECK_CMD_RC=$?
  [ $DO_CHECK_CMD_RC != 0 ] && cat <&4
  close34
  [ $DO_CHECK_CMD_RC != 0 ] && {
    error "Cannot do this! CMD='$*'"
    exit $DO_CHECK_CMD_RC
  }
  return 0
}

do_by_xterm() {
  TMPFILE_PARAM=`mktemp -p "$MYDIR" "$MYNAME-XTERM-XXXXXXX"`
  while [ -n "$1" ]; do
    echo -n "\"$1\" " >> "$TMPFILE_PARAM"
    shift
  done
  XTERM_CMD=`cat "$TMPFILE_PARAM"`
  rm -f "$TMPFILE_PARAM"; unset TMPFILE_PARAM
  TMPFILE_LOG=`mktemp -p "$MYDIR" "$MYNAME-XTERM-XXXXXXX"`
  TMPFILE_RC=`mktemp -p "$MYDIR" "$MYNAME-XTERM-XXXXXXX"`
  xterm -iconic -l -lf "$TMPFILE_LOG" -e /bin/sh -c "if $XTERM_CMD; then echo 0 > \"$TMPFILE_RC\"; else echo 1 > \"$TMPFILE_RC\"; fi"
  XTERM_RC=`cat "$TMPFILE_RC"`
  rm -f "$TMPFILE_RC"; unset TMPFILE_RC
  infofile "$TMPFILE_LOG"
  rm -f "$TMPFILE_LOG"; unset TMPFILE_LOG
  [ "$XTERM_RC" = 0 ] && return 0
  [ -n "$XTERM_RC" ] && return "$XTERM_RC"
  return 1
} # do_by_xterm

cmdpath() {
  CMD="$*"
  case "$CMD" in
    /*)
      [ -x "$CMD" ] && FOUNDPATH="$CMD"
      ;;
    */*)
      [ -x "$CMD" ] && FOUNDPATH="$CMD"
      ;;
    *)
      IFS=:
      for DIR in $PATH; do
        if [ -x "$DIR/$CMD" ]; then
          FOUNDPATH="$DIR/$CMD"
          break
        fi
      done
      unset IFS
      ;;
  esac
  if [ -n "$FOUNDPATH" ]; then
    echo "$FOUNDPATH"
  else
    return 1
  fi
}  # cmdpath

is_glibc() {
  ldd --version 2>&1 | head -1 | grep -iE '(glibc|gnu)' >/dev/null 2>&1
} # is_glibc

unset PIDFILE
unset TMPFILE
unset TMPDIR
unset OPEN34_TMPFILE
unset OPEN56_TMPFILE
at_exit() {
  [ -n "$PIDFILE" ] && [ -f "$PIDFILE" ] && rm -f "$PIDFILE"
  [ -n "$TMPFILE" ] && [ -f "$TMPFILE" ] && rm -f "$TMPFILE"
  [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
  [ -n "$OPEN34_TMPFILE" ] && [ -f "$OPEN34_TMPFILE" ] && rm "$OPEN34_TMPFILE"
  [ -n "$OPEN56_TMPFILE" ] && [ -f "$OPEN56_TMPFILE" ] && rm "$OPEN56_TMPFILE"
} # at_exit

trap at_exit EXIT HUP INT QUIT TERM
#
#----------
  #if TMPDIR=`mktemp -p . -d`; then
  #  trap at_exit EXIT HUP INT QUIT TERM && \
  #  (
  #    cd "$TMPDIR"
  #    echo "DISTRIBUTION=$DISTNAME"
  #  )
  #else
  #  echo "ERROR -- Cannot create temporary directory! CURRENT-DIR=`pwd`" >&2
  #  return 1
  #fi
# #endregion
#
#----------
# Internal Script Variables
#

#
#----------
# Internal Script Functions
#
calc() { printf "%s\n" "$@" | bc -l; }
calc_to_i() { printf "((%s)+0.5)/1\n" "$@" | bc; }
#
output_percentage() {
  PERCENT="$1"
  PPERCENT=`printf "%0.f" $PERCENT`
  [ `calc "$PPERCENT>100"` = 1 ] && PPERCENT=100
  [ "$OUTPUT_PERCENTAGE_PPERCENT" = "$PPERCENT" ] || {
    PCOUNT=`calc "$PERCENT/10"`
    PCOUNT=`calc_to_i "$PCOUNT"`
    COUNT=0
    echo -n "[ " >&2
    while [ `calc "$COUNT<$PCOUNT"` = 1 ]; do
      echo -n "#" >&2
      COUNT=`calc "$COUNT+1"`
    done
    while [ `calc "$COUNT<10"` = 1 ]; do
      echo -n " " >&2
      COUNT=`calc "$COUNT+1"`
    done
    OUTPUT_PERCENTAGE_PPERCENT=`printf "%0.f" $PERCENT`
    printf " ] %s%%\r" $OUTPUT_PERCENTAGE_PPERCENT >&2
  }
}  # output_percentage
#
output_in_cace_of_error() {
  # Usage: output_in_cace_of_error [--count [EXPECTED_LINES]]
  CMD="$1"
  unset ECHO_OPTION; [ "`echo -e`" = '-e' ] || ECHO_OPTION='-e'
  TMPFILE=`mktemp "$MYNAME-output_in_cace_of_error-XXXXXXX"`
  trap at_exit EXIT HUP INT QUIT TERM
  COUNT=0
  IS_CALCULATOR_AVAILABLE=false
  type bc >/dev/null 2>&1 && IS_CALCULATOR_AVAILABLE=true
  if [ "$CMD" = "--count" -a $IS_CALCULATOR_AVAILABLE = true ]; then
    IS_OUTPUT_AS_PERCENTAGE_BAR=false
    [ -n "$2" ] && {
      IS_OUTPUT_AS_PERCENTAGE_BAR=true
      NR_OF_EXPECTED_LINES="$2"
    }
    if [ $IS_OUTPUT_AS_PERCENTAGE_BAR = true ]; then
      NR_LINE=0
      {
        while read LINE; do
          NR_LINE=`calc "$NR_LINE+1"`
          PERCENTAGE=`calc "100.0*($NR_LINE/$NR_OF_EXPECTED_LINES)"`
          echo $LINE
          output_percentage $PERCENTAGE
          COUNT=`echo "$COUNT+1" | bc`
        done
        output_percentage 100
      } >"$TMPFILE"
    else
      while read LINE; do
        echo $LINE
        echo -n $ECHO_OPTION "$COUNT\r" >&2
        COUNT=`echo "$COUNT+1" | bc`
      done >"$TMPFILE"
    fi
    echo "" >&2
  else
    cat > "$TMPFILE"
  fi
  LINE=`tail -n 1 "$TMPFILE"`
  RC=0
  case "$LINE" in
    PIPESTATE*=*) RC=`echo "$LINE" | sed -e 's/PIPESTATE.*=//'`;;
  esac
  #echo "output_in_cace_of_error: RC=$RC" >&2
  [ "$RC" = "0" ] || { head -n -1 "$TMPFILE"; }
  rm -f "$TMPFILE"
  return $RC
}  # output_in_cace_of_error
#
sudo_install_packages() {
  # Packages to build python3:
  info "Update system ... (On a fresh system this may take a long time.)"
  { xbps-install -y -Su 2>&1; echo PIPESTATE0=$?; } | output_in_cace_of_error || { xbps-install -y -u xbps >/dev/null 2>&1; }
  { xbps-install -y -Su 2>&1; echo PIPESTATE0=$?; } | output_in_cace_of_error
  # Packages to build python
  info "Install packages to build python ..."
  { xbps-install -y base-devel binutils tar wget git xz openssl-devel zlib-devel ncurses-devel readline-devel libyaml-devel libffi-devel libxcb-devel libzstd-devel gdbm-devel liblzma-devel tk-devel libipset-devel libnsl-devel libtirpc-devel; echo PIPESTATE0=$?; } 2>&1 | output_in_cace_of_error
  # Packages to run Sephrasto
  info "Install packages to run Seprasto ..."
  { xbps-install -y qt5 libxcb libxcb-devel xcb-util-cursor xcb-imdkit xcb-util-errors xcb-util-image xcb-util-keysyms xcb-util-renderutil xcb-util-wm xcb-util-xrm; echo PIPESTATE0=$?; } 2>&1 | output_in_cace_of_error
}  # sudo_install_packages
#
do_with_sudo() {
  CMD="$1"
  [ -z "$CMD" ] && {
    error "Internal error! Missing command for do_with_sudo!"
    return 1
  }
  #
  #----------
  # Check root permissions.
  #
  unset MEUID
  MEUID=`id -u`
  [ "$MEUID" != 0 ] && {
    [ "$SCRIPT_OPT_SUDORESTART" = true ] && {
      error "Must run this script as root!" >&2
      exit 1
    }
    if type sudo >/dev/null 2>&1; then
      warn "You don't have super cow powers! Try to start commands with sudo ..."
      sudo -H "$SHELL" "$0" - "$CMD"; RC=$?
      info "|< End of sudo command sequence."
      [ "$RC" = "0" ] || exit $RC
    else
      error "Must run this commands as root! Missing tool! TOOL='sudo'"
      exit 1
    fi
  }
  unset MEUID CMD
}  # do_with_sudo
#
do_build() {
  do_with_sudo sudo_install_packages
  #
  info "Create build directories ..."
  LOCAL_PYTHON_BUILD_DIR="$HOME/.localpython/build"
  [ -d "$LOCAL_PYTHON_BUILD_DIR" ] || mkdir -p "$LOCAL_PYTHON_BUILD_DIR" || { error "Cannot create directory! DIR='$LOCAL_PYTHON_BUILD_DIR'"; exit 1; }
  LOCAL_SEPHRASTRO_DIR="$HOME/.localpython/bin"
  [ -d "$LOCAL_SEPHRASTRO_DIR" ] || mkdir -p "$LOCAL_SEPHRASTRO_DIR" || { error "Cannot create directory! DIR='$LOCAL_SEPHRASTRO_DIR'"; exit 1; }
  LOCAL_PYTHON_INSTALLATION_DIR="$HOME/.localpython/python$PYHTON_VERSION_TO_INSTALL"
  [ -d "$LOCAL_PYTHON_INSTALLATION_DIR" ] || mkdir -p "$LOCAL_PYTHON_INSTALLATION_DIR" || { error "Cannot create directory! DIR='$LOCAL_PYTHON_INSTALLATION_DIR'"; exit 1; }
  #
  # Download python.
  info "Download python source tarball ..."
  TMPFILE=`mktemp -p "$LOCAL_PYTHON_BUILD_DIR" "$MYNAME-python-src-XXXXXXX"`
  trap at_exit EXIT HUP INT QUIT TERM
  wget -q "https://www.python.org/ftp/python/$PYHTON_VERSION_TO_INSTALL/Python-$PYHTON_VERSION_TO_INSTALL.tar.xz" -O - > "$TMPFILE"
  (
    cd "$LOCAL_PYTHON_BUILD_DIR"
    tar xf "$TMPFILE"
    rm -f "$TMPFILE"
    info "Build python version=$PYHTON_VERSION_TO_INSTALL"
    cd "Python-$PYHTON_VERSION_TO_INSTALL" ||  { error "Cannot change to directory! DIR='$LOCAL_PYTHON_BUILD_DIR/Python-$PYHTON_VERSION_TO_INSTALL'"; exit 1; }
    info "Build python: ./configure ..."
    unset OUTPUT_PERCENTAGE_PPERCENT
    { ./configure --prefix="$LOCAL_PYTHON_INSTALLATION_DIR" ; echo PIPESTATE0=$?; } 2>&1 | output_in_cace_of_error --count 747
    info "Build python: make"
    unset OUTPUT_PERCENTAGE_PPERCENT
    { make; echo PIPESTATE0=$?; } 2>&1 | output_in_cace_of_error --count 753
    info "Build python: make install"
    unset OUTPUT_PERCENTAGE_PPERCENT
    { make install; echo PIPESTATE0=$?; } 2>&1 | output_in_cace_of_error --count 8096
  )
  [ -f "$TMPFILE" ] && rm -f "$TMPFILE"
  (
    cd "$LOCAL_SEPHRASTRO_DIR"
    info "Create Sephrasto python environment ..."
    "$LOCAL_PYTHON_INSTALLATION_DIR/bin/python3" -m venv "venv-seprastro-$PYHTON_VERSION_TO_INSTALL"
    (
      cd "venv-seprastro-$PYHTON_VERSION_TO_INSTALL"
      . ./bin/activate
      info "Download Sephrasto ..."
      [ -d Sephrasto ] || git clone https://github.com/Aeolitus/Sephrasto.git || { error "Cannot download Sephrasto! GIT CLONE"; exit 1; }
      info "Install Sephrasto requierements ..."
      ./bin/python3 -m pip install --upgrade pip
      ./bin/pip install -r Sephrasto/requirements.txt || { error "Cannot install Sephrasto requierements! PIP INSTALL"; exit 1; }
    )
    info "Create Sephrasto .desktop file ..."
    cat > Sephrasto.desktop <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Sephrasto
Comment=
Exec=/bin/sh "$LOCAL_SEPHRASTRO_DIR/Sephrasto.sh"
Icon=$LOCAL_SEPHRASTRO_DIR/venv-seprastro-$PYHTON_VERSION_TO_INSTALL/Sephrasto/src/Sephrasto/icon_large.png
Terminal=false
StartupNotify=true
Name[de_DE]=Sephrasto
EOF
    info "Create Sephrasto startup script ..."
    cat > Sephrasto.sh <<EOF
#!/bin/sh
cd "$LOCAL_SEPHRASTRO_DIR/venv-seprastro-$PYHTON_VERSION_TO_INSTALL"
. ./bin/activate
exec ./bin/python3 Sephrasto/src/Sephrasto/Sephrasto.py
EOF
    info "Install Sephrasto with \`$MYNAME install\`"
  )
  [ -f "$TMPFILE" ] && rm -f "$TMPFILE"
  return 0
}  # do_build
#
do_install() {
  LOCAL_SEPHRASTRO_DIR="$HOME/.localpython/bin"
  [ -d "$LOCAL_SEPHRASTRO_DIR" ] || { error "Cannot find directory! DIR='$LOCAL_SEPHRASTRO_DIR'"; exit 1; }
  for FILE in Sephrasto.desktop; do
    [ -f "$LOCAL_SEPHRASTRO_DIR/$FILE" ] || { error "Cannot find file! FILE='$LOCAL_SEPHRASTRO_DIR/$FILE'"; exit 1; }
  done
  [ -d "$HOME/.local/share/applications" ] || mkdir -p "$HOME/.local/share/applications" || { error "Cannot create directory! DIR='$HOME/.local/share/applications'"; exit 1; }
  cp "$LOCAL_SEPHRASTRO_DIR/Sephrasto.desktop" "$HOME/.local/share/applications" || { error "Cannot copy file! FROM='$LOCAL_SEPHRASTRO_DIR/Sephrasto.desktop' TO-DIR='$HOME/.local/share/applications'"; exit 1; }
  info "Installation complete."
  info "'Sephrasto.desktop' was copied to '$HOME/.local/share/applications'"
  return 0
}
#
do_clean() {
  IS_SOMETHING_TO_CLEAN=false
  for DIR in \
    "$HOME/.localpython/build/Python-$PYHTON_VERSION_TO_INSTALL" \
    "$HOME/.localpython/bin/venv-seprastro-$PYHTON_VERSION_TO_INSTALL" \
    "$HOME/.localpython/python$PYHTON_VERSION_TO_INSTALL"; do
    [ -d "$DIR" ] && { info "Directory to remove: '$DIR'"; IS_SOMETHING_TO_CLEAN=true; }
  done
  for FILE in \
    "$HOME/.localpython/bin/Sephrasto.desktop" \
    "$HOME/.localpython/bin/Sephrasto.sh" \
    "$HOME/.local/share/applications/Sephrasto.desktop"; do
    [ -f "$FILE" ] && { info "File to remove: '$FILE'"; IS_SOMETHING_TO_CLEAN=true; }
  done
  if [ "$IS_SOMETHING_TO_CLEAN" = true ]; then
    if getyesorno N "Do you want to proceed? [yN]" <&1; then
      for DIR in \
        "$HOME/.localpython/build/Python-$PYHTON_VERSION_TO_INSTALL" \
        "$HOME/.localpython/bin/venv-seprastro-$PYHTON_VERSION_TO_INSTALL" \
        "$HOME/.localpython/python$PYHTON_VERSION_TO_INSTALL"; do
        [ -d "$DIR" ] && { rm -rf "$DIR"; }
      done
      for FILE in \
        "$HOME/.localpython/bin/Sephrasto.desktop" \
        "$HOME/.localpython/bin/Sephrasto.sh" \
        "$HOME/.local/share/applications/Sephrasto.desktop"; do
        [ -f "$FILE" ] && { rm -f "$FILE"; }
      done
      info "Cleaned!"
    fi
  else
    info "Nothing to clean."
  fi
  return 0
}  # do_clean
#
usage() {
  cat >&2 <<EOF
Usage: $MYNAME [OPTIONS] COMMAND [...]
Commands:
  build           -- Download, build and prepare all packages needed by Sephrasto.
  install         -- Install .desktop file for Sephrato.
  clean           -- Remove all installed stuff.
  uninstall       -- Same as clean.
Options:
  -d, --debug     -- Output debug messages.
  -h, --help      -- Print this text.
EOF
}
#
#----------
# Check restart of this script.
#
check_tools git wget bc printf tar sed basename dirname
[ "$1" = "-" ] && { SCRIPT_OPT_SUDORESTART=true; shift; }
#
#----------
# Read options.
#
SCRIPT_ARGS_HERE=false
SCRIPT_LAST_OPT=""
SCRIPT_OPT_PARAMETER=false
SCRIPT_OPT_QUIT=false
SCRIPT_OPT_VERBOSE=false
SCRIPT_OPT_LIST_LANGS=false
SCRIPT_OPT_BASENAME=false
SCRIPT_OPT_RM_MULTIPLE_EMPTY_LINES=false
SCRIPT_OPT_LANGUAGE="$OCR_LANGUAGE"
SCRIPT_ARGS_HERE="false"
SCRIPT_OPT_PIDFN="/var/run/$MYNAE.pid"
open56
while [ "${#}" != "0" ]; do
  SCRIPT_OPTION="true"
  case "${1}" in
    --clean) info "CLEAN"; exit $?;;
    --debug) SCRIPT_OPT_DEBUG=true; shift; continue;;
    --quit) SCRIPT_OPT_QUIT=true; shift; continue;;
    --verbose) SCRIPT_OPT_VERBOSE=true; shift; continue;;
    --pid-file) if [ -n "$2" ]; then shift; SCRIPT_OPT_PIDFN="$1"; else error "Missing argument for option! OPTION='${1}'"; exit 1; fi; shift; continue;;
    --invalid)
      log "'${1}' invalid. Use ${1}=... instead"; exit 1; continue;;
    --help) usage; exit 0;;
    --*) log "invalid option '${1}'"; usage 1; exit 1;;
    # Posix getopt stops after first non-option
    -*);;
    *) echo "$1" >&5; SCRIPT_OPTION="false"; SCRIPT_ARGS_HERE="true";;  # Put normal args to tempfile.
  esac
  if [ "$SCRIPT_OPTION" = "true" ]; then
    flag="${1#?}"
    while [ -n "${flag}" ]; do
      case "${flag}" in
        h*) usage; exit 0;;
        c*) info "CLEAN"; exit $? ;;
        d*) SCRIPT_OPT_DEBUG=true;;
        l*) SCRIPT_OPT_LOCAL=true;;
        P) if [ -n "$2" ]; then shift; SCRIPT_OPT_PIDFN="$1"; else error "Missing argument for option! OPTION='-${flag}'"; exit 1; fi;;
        C*) info "BIG-CLEAN"; exit $? ;;
        q*) SCRIPT_OPT_QUIT=true;;
        Q*) exit 0;;
        *) : ;;  # log "invalid option -- '${flag%"${flag#?}"}'"; usage 1;;
      esac
      flag="${flag#?}"
    done
  fi
  shift
done
#
#----------------------------------------------------------------------
# START
#
#
#----------
# Check distribution.
# 1: /etc/*-release file method.
#
DIST_NAME=`cat /etc/*-release 2>/dev/null | sed -e 's/^NAME=\(.*\)/\1/' -e tfound -e d -e :found -e 's/^"\(.*\)"$/\1/' -e 's/^\s*\(.*\)\s*$/\1/' | head -1`
DIST_VERSION=`cat /etc/*-release 2>/dev/null | sed -e 's/^VERSION_ID=\(.*\)/\1/' -e tfound -e d -e :found -e 's/^"\(.*\)"$/\1/' -e 's/^\s*\(.*\)\s*$/\1/' | head -1`
#
# 2: lsb_release command method.
#
[ -z "$DIST_NAME" ] && {
  type lsb_release >/dev/null 2>&1 && {
    DIST_NAME=`lsb_release -a 2>/dev/null | sed -e 's/^Distributor ID:\(.*\)/\1/' -e tfound -e d -e :found -e 's/^"\(.*\)"$/\1/'  -e 's/^\s*\(.*\)\s*$/\1/' | head -1`
    DIST_VERSION=`lsb_release -a 2>/dev/null | sed -e 's/^Release:\(.*\)/\1/' -e tfound -e d -e :found -e 's/^"\(.*\)"$/\1/'  -e 's/^\s*\(.*\)\s*$/\1/' | head -1`
  }
}
#
# 3: hostnamectl command method:
#
[ -z "$DIST_NAME" ] && {
  type hostnamectl >/dev/null 2>&1 && {
    DIST_VERSION=`hostnamectl 2>/dev/null | sed -e 's/^.*Operating System:\(.*\)/\1/' -e tfound -e d -e :found -e 's/^"\(.*\)"$/\1/'  -e 's/^\s*\(.*\)\s*$/\1/' | head -1`
  }
}
[ -z "$DIST_NAME" ] && { DIST_NAME="(unknown)"; }
#
debug "DIST_NAME='$DIST_NAME' DIST_VERSION='$DIST_VERSION'"
#
#----------
# Do commands:
case "$DIST_NAME" in
  Void)
    PYHTON_VERSION_TO_INSTALL="3.9.7"
    cat <&6 | while read ARG; do
      case "$ARG" in
        build) do_build; RC=$?; [ $RC = 0 ] || exit $RC;;
        install) do_install; RC=$?; [ $RC = 0 ] || exit $RC;;
        clean|uninstall) do_clean; RC=$?; [ $RC = 0 ] || exit $RC;;
        sudo_install_packages) sudo_install_packages; RC=$?; [ $RC = 0 ] || exit $RC;;
        *) error "Unknown command! CMD='$ARG'"; exit 10;;
      esac
    done
    ;;
  *)
    error "Unknown or invalid distribution! DISTRIBUTION='$DIST_NAME'"
    exit 1
    ;;
esac
close56
#
if [ "$SCRIPT_ARGS_HERE" = false ]; then
  error "No commands given!"
  usage
fi