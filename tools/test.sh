test_mute() { eval "$@" &>/dev/null; return $?; }

test_new() {
  test_mute rm .test_*;
  touch .test_stdin;
  [ -n "$1" ] && test_stdin $@
}

test_stdin() {
  [ -n "$1" ] && echo $@ >.test_stdin && return
  non_block_cat >.test_stdin
}

non_block_cat() {
  cat
  return

  cat >/tmp/holding &
  local pid_cat=$!
  sleep 5
  kill ${pid_cat} &>/dev/null
  cat /tmp/holding
}

test_expect() {
  [ -n "$1" ] && echo "$@" >.test_expected && return
  cat >.test_expected
}

test_result() {
  export expected_result=$1; shift
  [ -n "$1" ] && test_expect $@
}

test_failed() {
  test_mute touch .test_expected .test_results .test_failed
  test_results_failed=$((${test_results_failed} + 1))

  echo Test FAILED: $@
  echo Expected ..$(cat .test_expected)..
  echo got ..$(cat .test_results)..
  echo
  [ -n "${test_fail_exit}" ] && exit 1
}

test_passed() {
  test_mute touch .test_expected .test_results .test_failed
  test_results_passed=$((${test_results_passed} + 1))

  echo Test passed: $@
  echo Expected ..$(cat .test_expected)..
  echo got ..$(cat .test_results)..
  echo
}

test_case() {
  test_mute rm .test_results

  # if stdin was not already setup, then create from any input we have
  #
  #if [ ! -f .test_stdin ]; then
    #non_block_cat >.test_stdin
  #fi

  echo Running Test case: $@
  eval $@ <.test_stdin >.test_results
  returned_code=$?

  if [[ ${expected_result} -ne ${returned_code} ]]; then
    test_failed Return code ${returned_code} should have been ${expected_result}
    return 1
  fi

  touch .test_expected .test_results
  if ! test_mute diff -bEB .test_expected .test_results; then
    test_failed Results not as expected
    return 1
  fi

  test_passed
  return 0
}

#TEST_CURL_OPTS=-v
test_target=$1;shift
test_results_passed=0
test_results_failed=0
test_fail_exit=true

test_target=$(basename $test_target .test)

for module in $(ls functions/*.sh | grep -v ${test_target}.sh); do
  . ${module}
done

echo All Modules loaded, starting tests
echo

. functions/${test_target}.sh
. tests/${test_target}.test

echo Tests Run: $(( ${test_results_passed} + ${test_results_failed} ))
echo Tests Passed: ${test_results_passed}
echo Tests Failed: ${test_results_failed}

unset TEST_CURL_OPTS
