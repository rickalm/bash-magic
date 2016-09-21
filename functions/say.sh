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
