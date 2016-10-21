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
