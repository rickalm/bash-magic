test_stdin() { cat >.test_stdin; }
test_expect() { echo $@ >.test_expected; }

test_case() {
  expected_result=$1; shift
  touch .test_stdin

  echo Running Test case: $@
  cat .test_stdin | eval $@ >.test_results
  returned_code=$?

  [[ ${expected_result^^} == SUCCESS && ${returned_code} -ne 0 ]] && echo Return code ${returned_code} should have been 0
  [[ ${expected_result} -ne ${returned_code} ]] && echo Return code ${returned_code} should have been ${expected_result}

  if ! diff -bEB .test_expected .test_results &>/dev/null; then
    echo Results not as expected
  fi

  echo Expected $(cat .test_expected)
  echo got $(cat .test_results)
  echo

  rm .test_expected .test_results
}
