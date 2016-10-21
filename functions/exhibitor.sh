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

