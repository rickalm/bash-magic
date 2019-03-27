
# Module functions/args.sh
#

# Functions to parse command line options from argument list
# based on posix arg parser, but implemented in bash because of variations in getopts on linux/mac
#

# Options descriptor is like getopts
# one character representing each option, optional descriptor : or ? after the option to indicate if a value is passed in the args
#
#  ab:c:defg   - options abcdefg are supported, b and c expect a value, ? returned for b or c if unspecified
#  :ab:c:defg  - options abcdefg are supported, b and c expect a value, : returned for b or c if unspecified (first char is :)
#

get_opts() { get_opt_value all_opts $@; }
strip_opts() { get_opt_value no_opts $@; }

get_opt_value() {
  local return_what=${1}; shift
  local opts=${1}; shift
  local is_opt=""
  local not_opt=""

  local no_value="?"
  [ "${opts:0:1}" == ":" ] && no_value=":"

  while [ -n "${1}" ]; do
    local this_opt=${1:1:1}

    # if last pass found the target opt, return it
    [[ "${is_opt:0:2}" == "${return_what}" ]] && echo ${is_opt:3:99999} && return 0

    # If we are not collecting all opts, start fresh
    [[ "${return_what}" != "all_opts" ]] && is_opt=""

    # If we encounter a double dash "--", then the rest of the command line is not for us and we are done
    [[ "${1}" == "--" ]] && shift && break

    # If option expects arg and is followed by an = then its "self contained"
    [[ "${opts}" == *"${this_opt}:"* && "${1}" == -${this_opt}=* ]] && is_opt="${is_opt}${is_opt:+ }-${this_opt} ${1#*=}" && shift 1 && continue

    # If option expects arg and next arg is another option (starts with -) then return option & no_value
    [[ "${opts}" == *"${this_opt}:"* && "${2:0:1}" == "-" ]] && is_opt="${is_opt}${is_opt:+ }-${this_opt} ${no_value}" && shift 1 && continue

    # Otherwise If option expects arg return arg and next value
    [[ "${opts}" == *"${this_opt}:"* ]] && is_opt="${is_opt}${is_opt:+ }-${this_opt} ${2}" && shift 2 && continue

    [[ "${opts}" == *"${this_opt}"* ]] && is_opt="${is_opt}${is_opt:+ }-${this_opt}" && shift 1 && continue

    # otherwise its not one of ours
    not_opt="${not_opt}${not_opt+ }${1}"
    shift 1
  done

  # If we were asked for no_opts then return what we found, plus anything left on stack (double dash)
  #
  [ "${return_what}" == "no_opts" ] && echo ${not_opt} $@ && return

  # Otherwise return the option (or options)
  echo ${is_opt}
}

# Module functions/arrays.sh
#

exists() { [ "$2" != in ] && return $(false); eval '[ ${'$3'['$1']+somestring} ]'; }
not_exists() { exists $@ && return 1; return 0; }

sort_args() {
  echo " " " " $@ | sort_list
}

sort_list() {
  local isep=${1:- }; isep="${isep:0:1}"
  local osep=${2:-${isep}}; osep="${osep:0:1}"
  tr "${isep}" "\n" | sort -u | tr "\n" "${osep}" | sed -e "s/^${osep}*//" -e "s/${osep}*$//"
}

in_list() {
  local target=$1; shift
  for next in $(echo $@ | sort_list , " "); do
    [ "${target}" == "${next}" ] && return 0
  done
  return 1
}

dump_assoc_arrays () {
  for var in "$@"; do
    read debug < <(declare -p $var)
    say "${debug#declare -A }"
  done
}

# Module functions/cache.sh
#

# if our internal variables are not configured properly then change them
#
[ "$(declare -p _cache_data 2>/dev/null | cut -d\    -f2)" != "-A" ] && unset _cache_data && declare -A _cache_data
[ "$(declare -p _cache_code 2>/dev/null | cut -d\    -f2)" != "-A" ] && unset _cache_code && declare -A _cache_code

# Figure out the correct syntax for binaries we rely on
#
[ "$(echo test | base64 2>/dev/null)" == "dGVzdAo=" ] && _cache_b64encode() { base64; }
[ "$(echo dGVzdAo= | base64 -d 2>/dev/null)" == "test" ] && _cache_b64decode() { base64 -d; }
[ "$(echo dGVzdAo= | base64 -D 2>/dev/null)" == "test" ] && _cache_b64decode() { base64 -D; }

if [ "$(echo test | shasum | cut -d\    -f1)" == "4e1243bd22c66e76c2ba9eddc1f91394e57f9f83" ]; then
  _cache_hashgen() { echo $@ | shasum | cut -d\    -f1; }
fi

cache_filestore_enable() { _cache_dir=${TMPDIR}/_cache_data; mkdir -p ${_cache_dir} 2>/dev/null; }
cache_filestore_disable() { unset _cache_dir; }

_cache_backingstore() { [ ${_cache_dir+_} ] && return 0; return 1; }
_cache_disabled() { [ ${DISABLE_CACHE+_} ] && return 0; return 1; }
_cache_keygen() { echo $@ | tr '*/ :-' '_____' ; }

flush_cache() {
  local _cache_key=$(_cache_hashgen $@)
  unset _cache_data[${_cache_key}]
  unset _cache_code[${_cache_key}]
  _cache_backingstore && rm ${_cache_dir}/${_cache_key} 2>/dev/null
}

cache_it() {
  if _cache_disabled; then
    $@; return $?
  fi

  local _cache_key=$(_cache_hashgen $@)
  entering ${_cache_key} $@

  # If cache entries do not exist, then call underlying command
  #
  if ! _cache_load_entry ${_cache_key}; then
    _cache_data[${_cache_key}]=$(_cache_return_base64 ${@} )
    _cache_code[${_cache_key}]=$?  
    _cache_save_entry ${_cache_key}
  fi

  echo ${_cache_data[${_cache_key}]} | _cache_b64decode
  return ${_cache_code[${_cache_key}]}
}

_cache_return_base64() {
  local tf=$(mktemp)
  $@ >${tf}
  local rcode=$?
  _cache_b64encode <${tf}
  rm ${tf} >/dev/null 2>&1
  return ${rcode}
}

_cache_load_entry() {
  local _cache_key=$1
  entering ${_cache_key}

  # If the cache has a value then nothing to do
  #
  exists ${_cache_key} in _cache_code && exists ${_cache_key} in _cache_data && return 0

  # see if we can load from backingstore
  #
  if _cache_backingstore && [ -f ${_cache_dir}/${_cache_key} ]; then
    _cache_code[${_cache_key}]=$(cat ${_cache_dir}/${_cache_key} | cut -d\     -f1)
    _cache_data[${_cache_key}]=$(cat ${_cache_dir}/${_cache_key} | cut -d\     -f2-)
    return 0
  fi

  # Otherwise we failed loading from the cache
  #
  return 1
}
  
_cache_save_entry() {
  local _cache_key=$1

  # If backingstore is not enabled, then do nothing
  _cache_backingstore || return 0

  # If the _cache_key does not exist in memory then do nothing
  #
  if not_exists ${_cache_key} in _cache_code || not_exists ${_cache_key} in _cache_data; then
    return 0
  fi

  # remove any existing file then attempt to write
  #
  rm ${_cache_dir}/${_cache_key} 2>/dev/null
  echo ${_cache_code[${_cache_key}]} ${_cache_data[${_cache_key}]} >${_cache_dir}/${_cache_key} 2>/dev/null && return 0

  # If we did not succed writing to the file then make sure we delete it
  #
  rm ${_cache_dir}/${_cache_key} 2>/dev/null
  return 1
}
  



# Module functions/exhibitor.sh
#

exhibitor_get_node_str() { _exhibitor_get_node $@ | _exhibitor_jq_node_str; }
exhibitor_get_node_bytes() { _exhibitor_get_node $@ | _exhibitor_jq_node_bytes; }
exhibitor_get_node_stats() { _exhibitor_get_node $@ | _exhibitor_jq_node_stats_json; }
exhibitor_get_tree_titles() { _exhibitor_get_tree $@ | _exhibitor_jq_tree_titles; }
exhibitor_get_tree_keys() { _exhibitor_get_tree $@ | _exhibitor_jq_tree_keys; }

# Write a new entry into ZK
# Payload for entry is expected from STDIN
#
exhibitor_put_node() {
  local url=$1; shift
  local znode=/${1#/}; shift
  local payload=$(string_to_hex "$@")
  expose url znode payload

  if [[ -z "${znode}" || "${znode}" == "/" ]]; then
    _exhibitor_rest_failure Znode was blank or root, refusing to make change
    return 1
  fi
  _exhibitor_put_node ${url} ${znode} "${payload}"
}

# Delete an entry from ZK
# todo, prevent delete if children present :)
#
exhibitor_delete_node() {
  local url=$1; shift
  local znode=/${1#/}; shift
  expose url znode 

  if [[ -z "${znode}" || "${znode}" == "/" ]]; then
    _exhibitor_rest_failure Znode was blank or root, refusing to make change
    return 1
  fi

  _exhibitor_delete_node ${url} ${znode}
}

# Get an entry from ZK, including its stats
#
exhibitor_get_node() {
  local json=$(_exhibitor_get_node $@)
  local str=$(echo ${json} | _exhibitor_jq_node_str)
  local path=$(echo ${json} | _exhibitor_jq_node_path)
  local bytes=$(echo ${json} | _exhibitor_jq_node_bytes)
  expose json str path bytes

  echo ${json} | _exhibitor_jq_node_stats_json \
    | jq -c ".str=\"${str}\" | .bytes=\"${bytes}\" | .path=\"${path}\""
}




# Internal methods, calling sequence not guaranteed
#
_exhibitor_put_node() {
  local url=$1; shift
  local znode=/${1#/}; shift
  expose url znode

  curl ${TEST_CURL_OPTS} -sSL -XPUT \
    -H "Content-Type: application/json" \
    --data-ascii "${@}" \
    ${url}/exhibitor/v1/explorer/znode/${znode:1}
}

_exhibitor_delete_node() {
  local url=$1; shift
  local znode=/${1#/}; shift
  expose url znode

  curl ${TEST_CURL_OPTS} -sSL -XDELETE \
    ${url}/exhibitor/v1/explorer/znode/${znode:1}
}

_exhibitor_get_node() {
  local url=$1; shift
  local znode=/${1#/}; shift
  local key=$(urlencode ${znode})
  expose url znode key

  curl ${TEST_CURL_OPTS} -sSL -XGET \
    ${url}/exhibitor/v1/explorer/node-data/?key=${key} \
    | jq -c ".path=\"${znode}\""
}

_exhibitor_get_tree() {
  local url=$1; shift
  local znode=/${1#/}; shift
  local key=$(urlencode ${znode})
  expose url znode key

  curl ${TEST_CURL_OPTS} -sSL -XGET \
    ${url}/exhibitor/v1/explorer/node/?key=${key}
}

_exhibitor_jq_success() { jq -r '.succeeded // false'; }
_exhibitor_jq_message() { jq -r '.message // empty'; }
_exhibitor_jq_node_path() { jq -r .path; }
_exhibitor_jq_node_str() { jq -r .str; }
_exhibitor_jq_node_bytes() { jq -r .bytes; }
_exhibitor_jq_node_stats_json() { echo '{' $(jq -r '.stat') '}' | sed -Ee 's/ ([a-zA-Z]+):/ "\1":/g'; }
_exhibitor_jq_tree_titles() { jq -c '[ .[].title ]'; }
_exhibitor_jq_tree_keys() { jq -c '[ .[].key ]'; }

_exhibitor_rest_failure() { echo "{ \"succeeded\":\"false\", \"message\": \"$@\" }"; }


# Module functions/mutex.sh
#

mutex_set_provider() {
  local temp
  local result_file=$(mk_temp_file)

  #
  # Passed in should be
  #   <protocol>://<host>[:<port>]/<namespace for operations>
  #
  mutex_uri=${1}

  # Lets get the protocol
  #
  mutex_protocol=${mutex_uri%%://*}

  # Extract the protocol from the uri so we can start cracking the rest of the uri
  #
  temp=${mutex_uri#${mutex_protocol}://}/
  export mutex_host_port=${temp%%/*}

  temp=${temp#*/}
  temp=${temp%/}
  temp=${temp:-/mutex}
  export mutex_namespace=/${temp#/}

  expose mutex_uri mutex_protocol temp mutex_host_port mutex_namespace

  if [ "${mutex_protocol}" == "exhibitor" ]; then
    exhibitor_put_node http://${mutex_host_port} ${mutex_namespace} "mutex_set_provider $@" >${result_file}

    if [ "$(_exhibitor_jq_success <${result_file})" == true ]; then
      echo OK ${mutex_namespace}
      return 0
    fi

    echo FAILED $(_exhibitor_jq_message <${result_file})
    return 1
  fi

  echo UNSUPPORTED_PROTOCOL
  return 1
}

_mutex_put_key() {
  local result_file=$(mk_temp_file)

  local mutex_path=${1%/}; shift
  local mutex_key=$1; shift
  local mutex_path=${mutex_path:-mutex}
  expose mutex_uri mutex_protocol mutex_host_port mutex_namespace

  if [ "${mutex_protocol}" == "exhibitor" ]; then
    exhibitor_put_node http://${mutex_host_port} ${mutex_namespace}/${mutex_path}/lock-${mutex_key} >${result_file}
 
    if [ "$(_exhibitor_jq_success <${result_file})" == true ]; then
      echo OK
      return 0
    fi

    echo FAILED $(_exhibitor_jq_message <${result_file})
    return 1
  fi
}

mutex_check_lock() {
  mutex_path=${1%/}
  mutex_path=${mutex_path:-mutex}

  request=$( echo '[{}]' \
    | jq .[0].path=\"${mutex_namespace}/${mutex_path}\" \
    | jq .[0].max=1 \
    | jq -c .)

  curl -vsSL -XGET -H "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8" \
    http://${mutex_host_port}/exhibitor/v1/explorer/analyze?request=$(urlencode ${request})
}

mutex_get_lock() {
  mutex_path=${1%/}
  mutex_path=${mutex_path#/}
  mutex_path=${mutex_path:-mutex}

  mutex_key=${mutex_key:-$(date +%s)-$(local_ip_list | head -1).$$}
  expose mutex_uri mutex_protocol mutex_host_port mutex_namespace mutex_key

  _mutex_put_key ${mutex_path} ${mutex_key} &>/dev/null || { echo FAILED && return 1; }
  echo OK
  return 0
  mutex_check_lock ${mutex_path}
}

# Module functions/other.sh
#

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

# Module functions/say.sh
#

# say, say_pipe and its variants
#
# strips its arguments from $@, uses the remaining contents as what to append to the line
# say_pipe prepends SAY (and its headers) to every line from STDIN
#
# both say and say_pipe supply _debug, _info, _warn, _error, _fail versions to set verbose level
# making sure the verbosity level is the last option in the list
#
# other options are
#   -e
#   -a              Always output even if verbosity level would filter
#   -l <level>      what verbosity level to output at DEBUG,INFO,CHANGE,WARN,ERROR,FAIL
#   -h <heading>    Set to FunctionName unless supplied
#   -p <prefix>     Optional user supplied prefix to add to every output/line
#
# Output of say is:
#
# $0 <calling_function_name> [<level>] <heading> <prefix> $@
#

# Set say_verbose_level if unset
#
export say_verbose_level=${say_verbose_level:-2}

say_pipe() { while read line; do say $@ $line; done; }

say_debug() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l DEBUG $(strip_get_opts $@); }
say_info() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l INFO $(strip_get_opts $@); }
say_change() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l CHANGE $(strip_get_opts $@); }
say_warn() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l WARN $(strip_get_opts $@); }
say_error() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l ERROR $(strip_get_opts $@); }
say_fail() { say -h ${FUNCNAME[1]} $(say_get_opts $@) -l FAIL $(strip_get_opts $@); }
say_pipe_debug() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l DEBUG $(strip_get_opts $@); }
say_pipe_info() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l INFO $(strip_get_opts $@); }
say_pipe_change() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l CHANGE $(strip_get_opts $@); }
say_pipe_warn() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l WARN $(strip_get_opts $@); }
say_pipe_error() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l ERROR $(strip_get_opts $@); }
say_pipe_fail() { say_pipe -h ${FUNCNAME[1]} $(say_get_opts $@) -l FAIL $(strip_get_opts $@); }

say_strip_opts() { strip_opts "ea:p:l:h" $@; }
say_get_opts() { get_opts "ea:p:l:h" $@; }
say_get_opt_value() { get_opts "ea:p:l:h" $@; }

# Convert a log level tag to the numeric value
#
say_level_to_number() {
  # numbers are included in case we are passed a number
  local say_levels=([FATAL]=0 [ERROR]=1 [WARN]=2 [CHANGE]=3 [INFO]=4 [DEBUG]=5 [0]=0 [1]=1 [2]=2 [3]=3 [4]=4 [5]=5)
  return ${say_levels[${1^^}]}
}

# Convert log level numeric value to tag
#
say_level_to_tag() {
  # tags are included incase we are passed as tag
  local say_tags=([0]="FATAL" [1]="ERROR" [2]="WARN" [3]="CHANGE" [4]="INFO" [5]="DEBUG" [FATAL]="FATAL" [ERROR]="ERROR" [WARN]="WARN" [CHANGE]="CHANGE" [INFO]="INFO" [DEBUG]="DEBUG")
  return ${say_tags[${1^^}]}
}

say_set_verbose() {
  export say_verbose_level=$(say_level_to_number $1)
}

say() {
  local my_opts=$(say_get_opts $@)
  local always heading prefix this_level=4 this_file=${0}

  always=$(say_get_opt_value a ${my_opts})
  prefix=$(say_get_opt_value p ${my_opts})
  this_level=$(say_level_to_number $(say_get_opt_value l ${my_opts}))

  heading=$(say_get_opt_value h ${my_opts})
  heading=${heading:-${FUNCNAME[1]}}

  # Check if we should be saying this or skipping
  [ -z "${always}" -a "${this_level}" -gt "${say_verbose_level}" ] && return

  echo -n ${this_file} \[$(say_level_to_tag ${this_level})\]${heading}${prefix} $(say_strip_opts $@) >&2
}

expose() {
  while [ -n "$1" ]; do
    local next_var=$1; shift
    echo ${FUNCNAME[1]} Var ${next_var} is ..${!next_var}.. >&2
  done
}

# Module functions/tmp_files.sh
#

# MK_temp Functions. uses system mktemp to choose target path
# Record tmp file in _tmp_files array for delete on exit
# Setup EXIT handler to clean up files on exit from script
#

declare -a _tmp_files

rm_tmp_files() {
  for ((i=0; i < ${#_tmp_files[@]}; i++)); do
    mute rm -rf ${_tmp_files[$i]}
  done
}

mk_temp_dir() {
  trap rm_tmp_files EXIT
  _tmp_files+=($(mktemp -d -t ${FUNCNAME[1]}))
  echo ${_tmp_files[-1]}
}

mk_temp_file() {
  trap rm_tmp_files EXIT
  _tmp_files+=($(mktemp -t ${FUNCNAME[1]}))
  echo ${_tmp_files[-1]}
}

# There is no easy way to make a tmp fifo,
# so grab a tmp file, and use its descriptor
# to make a fifo
mk_temp_fifo() {
  local fn=$(mk_temp_file)
  mute rm ${fn}
  mkfifo ${fn}
  echo ${fn}
}

# Module functions/transform.sh
#

urlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      [-_.~a-zA-Z0-9] ) o="${c}" ;;
      * ) printf -v o '%%%02x' "'$c" ;;
    esac
    encoded+="${o}"
  done
  echo "${encoded}"
}

urldecode() {
  local string="${1}"
  local strlen=${#string}
  local decoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    case "$c" in
      % ) o=$(echo "0x${string:$(($pos+1)):2}" | xxd -r); pos=$(($pos + 2)) ;;
      * ) o="${c}" ;;
    esac
    decoded+="${o}"
  done
  echo "${decoded}"
}

string_to_hex() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
    c=${string:$pos:1}
    printf -v o '%2x ' "'$c"
    encoded+="${o}"
  done
  echo "${encoded}"
}

