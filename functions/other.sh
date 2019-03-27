# Check if commands are available or return a failure
#
need() {
  while [ -n "$1" ]; do
    if ! mute which $1; then say_error Cannot find $1; return 1; fi
    shift
  done
}

# Check if commands are available or return a failure
#
want() {
  while [ -n "$1" ]; do
    if mute which $1; then echo $1; return 0; fi
    shift
  done
  return 1
}

mute() {
  eval $@ &>/dev/null && return 0
  return $?
}

entering() {
  echo ${FUNCNAME[1]} entering $@ >&2
}

local_ip_list() {
  need grep cut || return 1

  case $(want ip ifconfig) in
    ip) fetch_cmd="ip addr show";;
    ifconfig) fetch_cmd="ifconfig -a";;
    *) say_error Could not find a way to check IP; return 1
  esac

  $fetch_cmd | tr ' ' '\n' | grep -E '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)*' | grep -Ev '^(127\.|172.17)' | cut -d/ -f1
}

function unregex {
   # This is a function because dealing with quotes is a pain.
   # http://stackoverflow.com/a/2705678/120999
   sed -e 's/[]\/()$*.^|[]/\\&/g' <<< "$1"
}
