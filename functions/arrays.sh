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
