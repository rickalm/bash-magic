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
