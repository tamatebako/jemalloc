#include "test/jemalloc_test.h"

/*
 * Override malloc_conf to test MSVC weak symbol emulation.
 * On Unix, this uses weak attributes. On MSVC, this uses /alternatename.
 * This simulates a library overriding configuration, which is the exact
 * use case that was broken on MSVC before PR #2689.
 */
const char *je_malloc_conf = "narenas:1,tcache:false";

TEST_BEGIN(test_malloc_conf_override) {
	unsigned narenas;
	size_t sz = sizeof(narenas);

	/* Verify narenas was set to 1 by our override */
	expect_d_eq(mallctl("opt.narenas", &narenas, &sz, NULL, 0), 0,
	    "Failed to read opt.narenas");
	expect_u_eq(narenas, 1, "malloc_conf override should set narenas to 1");

	/* Verify tcache was disabled by our override */
	bool tcache;
	sz = sizeof(tcache);
	expect_d_eq(mallctl("opt.tcache", &tcache, &sz, NULL, 0), 0,
	    "Failed to read opt.tcache");
	expect_false(tcache, "malloc_conf override should disable tcache");
}
TEST_END

int
main(void) {
	return test(test_malloc_conf_override);
}
