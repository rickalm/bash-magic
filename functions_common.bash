get_opts() {
  local opts=${1}; shift
  local return=""

  while [ "${1:0:1}" == "-" ]; do
    [[ "${opts}" == *":${1:1:1}"* ]] && return="${return} -${1:1:1} ${2}" && shift
    [[ "${opts}" == *"${1:1:1}"* ]] && return="${return} -${1:1:1}"
    shift
  done

  echo ${return}
}

strip_opts() {
  local opts=${1}; shift
  while [ "${1:0:1}" == "-" ]; do
    [[ "${opts}" == *":${1:1:1}"* ]] && shift; # If arg expects var then make sure we shift it out as well
    shift
  done
  echo $@
}

say_strip_opts() { strip_opts "ea:p:l:h" $@; }
say_get_opts() { get_opts "ea:p:l:h" $@; }

say_debug() { say $(say_get_opts $@) -l DEBUG $(strip_get_opts $@); }
say_info() { say $(say_get_opts $@) -l INFO $(strip_get_opts $@); }
say_warn() { say $(say_get_opts $@) -l WARN $(strip_get_opts $@); }
say_error() { say $(say_get_opts $@) -l ERROR $(strip_get_opts $@); }
say_fail() { say $(say_get_opts $@) -l FAIL $(strip_get_opts $@); }

say() {
  local my_opts=$(say_get_opts $@)
  echo ${0} ${FUNCNAME[1]} $(say_strip_opts $@) >&2
}

say_pipe() { while read line; do say $@ $line; done; }

# Check if commands are available or return a failure
#
need() {
  while [ -n "$1" ]; do
    which $1 || say_error Cannot find $1 && return 1
  done
}

local_ip_list() {
  need grep cut || return 1

  case $(want ip ifconfig) in
    ip) fetch_cmd="ip addr show";;
    ifconfig) fetch_cmd="ifconfig -a";;
    *) say_error Could not find a way to check IP; return 1
  esac

  $fetch_cmd | tr ' ' '\n' | grep -P '\d+\.\d+\.\d+\.\d+/\d+' | grep -Pv '^(127\.|172.17)' | cut -d/ -f1
}

sort_list() {
  echo $@ $(cat | tr '\n' ' ') | tr ' ' '\n' | sort -u | tr '\n' ' '
}
