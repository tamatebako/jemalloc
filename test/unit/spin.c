#include "test/jemalloc_test.h"

#include "jemalloc/internal/spin.h"

/* Test ARMv8.5-A Speculation Barrier detection on ARM64 platforms */
#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64))
extern int arm_has_sb_instruction;

TEST_BEGIN(test_sb_detection) {
	/* Verify detection has run (0 or 1, not uninitialized) */
	expect_true(arm_has_sb_instruction == 0 || arm_has_sb_instruction == 1,
	    "SB detection should have run at library load");

	/* Log result for CI visibility */
	if (arm_has_sb_instruction) {
		test_skip_if(false);
		malloc_printf("ARMv8.5-A SB: SUPPORTED - using SB instruction\n");
	} else {
		test_skip_if(false);
		malloc_printf("ARMv8.5-A SB: NOT SUPPORTED - using ISB fallback\n");
	}
}
TEST_END
#endif

TEST_BEGIN(test_spin) {
	spin_t spinner = SPIN_INITIALIZER;

	for (unsigned i = 0; i < 100; i++) {
		spin_adaptive(&spinner);
	}
}
TEST_END

int
main(void) {
#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64))
	return test(
	    test_sb_detection,
	    test_spin);
#else
	return test(test_spin);
#endif
}
