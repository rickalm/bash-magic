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
  


