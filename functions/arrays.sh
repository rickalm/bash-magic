exists() { [ "$2" != in ] && return $(false); eval '[ ${'$3'['$1']+somestring} ]'; }

cache_key() { 
  [ ${DISABLE_CACHE+_} ] && echo $(dd if=/dev/random bs=1 count=16 2>/dev/null | base64 | tr ' :-' '___') && return
  echo $@ | tr ' :-' '___';
}

flush_cache() {
  unset _cache[$(cache_key $@)]
  unset _cache[$(cache_key _$@)]
}

cache_it() {
  entering $@
  local _cache_key=$(cache_key $@)

  exists ${_cache_key} in _cache_code && exists ${_cache_key} in _cache \
    && echo ${_cache[${_cache_key}]} && return ${_cache_code[${_cache_key}]}

  _cache[${_cache_key}]="$($@)"
  _cache_code[${_cache_key}]=$?

  echo ${_cache[${_cache_key}]}
  return ${_cache_code[${_cache_key}]}
}

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
