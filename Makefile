
tests/%.test:
	bash tools/test.sh $<

extended_test: test tests/exhibitor.test tests/mutex.test 

test: tests/args.test tests/transform.test tests/cache.test

.PHONY: test extended_test
.DEFAULT: text
