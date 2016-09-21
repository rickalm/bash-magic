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

test_new
test_result 0
test_expect -a -c one -b two
test_case get_opts ab:c:defg -z -a -c one -b two -- -e fred barney

test_new
test_result 0
test_expect -a -c one -b two
test_case get_opts ab:c:defg -z -a -c one -b=two -- -e fred barney

test_new
test_result 0
test_expect -z -e fred barney
test_case strip_opts ab:c:defg -z -a -c one -b=two -- -e fred barney

test_new
test_result 0
test_expect -a -c ? -b two
test_case get_opts ab:c:defg -z -a -c -b=two -- -e fred barney

test_new
test_result 0
test_expect two
test_case get_opt_value -b ab:c:defg -z -a -c -b=two -- -e fred barney

