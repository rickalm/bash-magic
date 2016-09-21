test_stdin() { cat >.test_stdin; }
test_expect() { echo $@ >.test_expected; }
test_result() { export expected_result=$1; }
test_new() { test_mute rm .test_*; }
test_mute() { eval $@ &>/dev/null; return $?; }

test_failed() {
  test_mute touch .test_expected .test_results .test_failed
  echo Test FAILED: $@
  echo Expected $(cat .test_expected)
  echo got $(cat .test_results)
  echo
  test_new
}

test_passed() {
  [ -f .test_failed ] && return 1
  test_mute touch .test_results
  echo Test passed: $@
  echo got $(cat .test_results)
  echo
  test_new
}

test_case() {
  touch .test_stdin

  echo Running Test case: $@
  cat .test_stdin | eval $@ >.test_results
  returned_code=$?

  [[ ${expected_result} -ne ${returned_code} ]] \
    && test_failed Return code ${returned_code} should have been ${expected_result}

  test_mute diff -bEB .test_expected .test_results \
    || test_failed Results not as expected

  test_passed
}
