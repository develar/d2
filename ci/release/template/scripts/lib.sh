#!/bin/sh

# *************
# DO NOT EDIT
#
# lib.sh was bundled together from
#
# - ./ci/sub/lib/rand.sh
# - ./ci/sub/lib/log.sh
# - ./ci/sub/lib/release.sh
#
# Generated by ./ci/release/gen_template_lib.sh.
# *************

#!/bin/sh
if [ "${LIB_RAND-}" ]; then
  return 0
fi
LIB_RAND=1

pick() {
  seed="$1"
  shift

  seed_file="$(mktemp)"

  # We add 32 more bytes to the seed file for sufficient entropy. Otherwise both Cygwin's
  # and MinGW's sort for example complains about the lack of entropy on stderr and writes
  # nothing to stdout. I'm sure there are more platforms that would too.
  #
  # We also limit to a max of 32 bytes as otherwise macOS's sort complains that the random
  # seed is too large. Probably more platforms too.
  (echo "$seed" && echo "================================") | head -c32 >"$seed_file"

  while [ $# -gt 0 ]; do
    echo "$1"
    shift
  done \
    | sort --sort=random --random-source="$seed_file" \
    | head -n1
}
#!/bin/sh
if [ "${LIB_LOG-}" ]; then
  return 0
fi
LIB_LOG=1

if [ -n "${DEBUG-}" ]; then
  set -x
fi

tput() {
  if should_color; then
    TERM=${TERM:-xterm-256color} command tput "$@"
  fi
}

should_color() {
  if [ -n "${COLOR-}" ]; then
    if [ "$COLOR" = 1 -o "$COLOR" = true ]; then
      _COLOR=1
      __COLOR=1
      return 0
    elif [ "$COLOR" = 0 -o "$COLOR" = false ]; then
      _COLOR=
      __COLOR=0
      return 1
    else
      printf '$COLOR must be 0, 1, false or true but got %s\n' "$COLOR" >&2
    fi
  fi

  if [ -t 1 -a "${TERM-}" != dumb ]; then
    _COLOR=1
    __COLOR=1
    return 0
  else
    _COLOR=
    __COLOR=0
    return 1
  fi
}

setaf() {
  tput setaf "$1"
  shift
  printf '%s' "$*"
  tput sgr0
}

_echo() {
  printf '%s\n' "$*"
}

get_rand_color() {
  if [ "${TERM_COLORS+x}" != x ]; then
    TERM_COLORS=""
    export TERM_COLORS
    ncolors=$(TERM=${TERM:-xterm-256color} command tput colors)
    if [ "$ncolors" -ge 8 ]; then
      # 1-6 are regular
      TERM_COLORS="$TERM_COLORS 1 2 3 4 5 6"
    elif [ "$ncolors" -ge 16 ]; then
      # 9-14 are bright.
      TERM_COLORS="$TERM_COLORS 9 10 11 12 13 14"
    fi
  fi
  pick "$*" $TERM_COLORS
}

echop() {
  prefix="$1"
  shift

  if [ "$#" -gt 0 ]; then
    printfp "$prefix" "%s\n" "$*"
  else
    printfp "$prefix"
    printf '\n'
  fi
}

printfp() {(
  prefix="$1"
  shift

  _FGCOLOR=${FGCOLOR:-$(get_rand_color "$prefix")}
  should_color || true
  if [ $# -eq 0 ]; then
    printf '%s' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")"
  else
    printf '%s: %s\n' "$(COLOR=$__COLOR setaf "$_FGCOLOR" "$prefix")" "$(printf "$@")"
  fi
)}

catp() {
  prefix="$1"
  shift

  should_color || true
  sed "s/^/$(COLOR=$__COLOR printfp "$prefix" '')/"
}

repeat() {
  char="$1"
  times="$2"
  seq -s "$char" "$times" | tr -d '[:digit:]'
}

strlen() {
  printf %s "$1" | wc -c
}

echoerr() {
  FGCOLOR=1 logp err "$*"
}

caterr() {
  FGCOLOR=1 logpcat err "$@"
}

printferr() {
  FGCOLOR=1 logfp err "$@"
}

logp() {
  should_color >&2 || true
  COLOR=$__COLOR echop "$@" | humanpath >&2
}

logfp() {
  should_color >&2 || true
  COLOR=$__COLOR printfp "$@" | humanpath >&2
}

logpcat() {
  should_color >&2 || true
  COLOR=$__COLOR catp "$@" | humanpath >&2
}

log() {
  FGCOLOR=5 logp log "$@"
}

logf() {
  FGCOLOR=5 logfp log "$@"
}

logcat() {
  FGCOLOR=5 logpcat log "$@"
}

warn() {
  FGCOLOR=3 logp warn "$@"
}

warnf() {
  FGCOLOR=3 logfp warn "$@"
}

warncat() {
  FGCOLOR=3 logpcat warn "$@"
}

sh_c() {
  FGCOLOR=3 logp exec "$*"
  if [ -z "${DRY_RUN-}" ]; then
    eval "$@"
  fi
}

sudo_sh_c() {
  if [ "$(id -u)" -eq 0 ]; then
    sh_c "$@"
  elif command -v doas >/dev/null; then
    sh_c "doas $*"
  elif command -v sudo >/dev/null; then
    sh_c "sudo $*"
  elif command -v su >/dev/null; then
    sh_c "su root -c '$*'"
  else
    caterr <<EOF
This script needs to run the following command as root:
  $*
Please install doas, sudo, or su.
EOF
    return 1
  fi
}

header() {
  FGCOLOR=${FGCOLOR:-4} logp "/* $1 */"
}

bigheader() {
  set -- "$(echo "$*" | sed "s/^/ * /")"
  FGCOLOR=${FGCOLOR:-3} logp "/**
$*
 **/"
}

# humanpath replaces all occurrences of " $HOME" with " ~"
# and all occurrences of '$HOME' with the literal '$HOME'.
humanpath() {
  if [ -z "${HOME-}" ]; then
    cat
  else
    sed -e "s# $HOME# ~#g" -e "s#$HOME#\$HOME#g"
  fi
}

hide() {
  out="$(mktemp)"
  set +e
  "$@" >"$out" 2>&1
  code="$?"
  set -e
  if [ "$code" -eq 0 ]; then
    return
  fi
  cat "$out" >&2
  return "$code"
}

echo_dur() {
  local dur=$1
  local h=$((dur/60/60))
  local m=$((dur/60%60))
  local s=$((dur%60))
  printf '%dh%dm%ds' "$h" "$m" "$s"
}

sponge() {
  dst="$1"
  tmp="$(mktemp)"
  cat > "$tmp"
  cat "$tmp" > "$dst"
}

stripansi() {
  # First regex gets rid of standard xterm escape sequences for controlling
  # visual attributes.
  # The second regex I'm not 100% sure, the reference says it selects the US
  # encoding but I'm not sure why that's necessary or why it always occurs
  # in tput sgr0 before the standard escape sequence.
  # See tput sgr0 | xxd
  sed -e $'s/\x1b\[[0-9;]*m//g' -e $'s/\x1b(.//g'
}

runtty() {
  case "$(uname)" in
    Darwin)
      script -q /dev/null "$@"
      ;;
    Linux)
      script -eqc "$*"
      ;;
    *)
      echoerr "runtty: unsupported OS $(uname)"
      return 1
  esac
}

capcode() {
  set +e
  "$@"
  code=$?
  set -e
}

strjoin() {
  (IFS="$1"; shift; echo "$*")
}
#!/bin/sh
if [ "${LIB_RELEASE-}" ]; then
  return 0
fi
LIB_RELEASE=1

ensure_goos() {
  if [ -n "${GOOS-}" ]; then
    return
  fi
  ensure_os
  case "$OS" in
    macos) export GOOS=darwin;;
    *) export GOOS=$1;;
  esac
}

ensure_goarch() {
  if [ -n "${GOARCH-}" ]; then
    return
  fi
  ensure_arch
  case "$ARCH" in
    *) export GOARCH=$1;;
  esac
}

ensure_os() {
  if [ -n "${OS-}" ]; then
    return
  fi
  uname=$(uname)
  case $uname in
    Linux) OS=linux;;
    Darwin) OS=macos;;
    FreeBSD) OS=freebsd;;
    CYGWIN_NT*|MINGW32_NT*) OS=windows;;
    *) OS=$uname;;
  esac
}

ensure_arch() {
  if [ -n "${ARCH-}" ]; then
    return
  fi
  uname_m=$(uname -m)
  case $uname_m in
    aarch64) ARCH=arm64;;
    x86_64) ARCH=amd64;;
    *) ARCH=$uname_m;;
  esac
}

gh_repo() {
  gh repo view --json nameWithOwner --template '{{ .nameWithOwner }}'
}

manpath() {
  if command -v manpath >/dev/null; then
    command manpath
  elif man -w 2>/dev/null; then
    man -w
  else
    echo "${MANPATH-}"
  fi
}

is_writable_dir() {
  # If it can be created, we can use it.
  sh_c "mkdir -p '$1' 2>/dev/null"
}

ensure_prefix() {
  if [ -n "${PREFIX-}" ]; then
    return
  fi
  # The reason for checking whether bin is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "/usr/local/bin"; then
    # This also handles M1 Mac's which do not allow modifications to /usr/local even
    # with sudo.
    PREFIX=$HOME/.local
  else
    PREFIX=/usr/local
  fi
}

ensure_prefix_sh_c() {
  ensure_prefix

  sh_c="sh_c"
  # The reason for checking whether bin is writable is that on macOS you have /usr/local
  # owned by root but you don't need root to write to its subdirectories which is all we
  # need to do.
  if ! is_writable_dir "$PREFIX/bin"; then
    sh_c="sudo_sh_c"
  fi
}
