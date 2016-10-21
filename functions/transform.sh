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

