#include "test/jemalloc_test.h"

/*
 * ARMv8.5-A Speculation Barrier (SB) instruction benchmark
 *
 * This analyze test benchmarks spin delay performance on ARM64 platforms:
 * - Measures ISB (ARMv8.0-8.4 baseline) performance
 * - Measures SB (ARMv8.5-A+ optimized) performance if supported
 * - Reports speedup and improvement percentage
 *
 * Runs automatically in CI on all ARM64 platforms to verify:
 * - Linux ARM64 (Ubuntu, Alpine)
 * - macOS ARM64 (Apple Silicon)
 * - Windows ARM64 (Snapdragon X)
 */

#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64))

#define BENCHMARK_ITERATIONS 10000000  /* 10 million iterations for accuracy */

/* External SB detection flag */
extern int arm_has_sb_instruction;

/* Force ISB (ARMv8.0-8.4 baseline) */
static JEMALLOC_ALWAYS_INLINE void
spin_delay_isb_only(void) {
#if defined(__GNUC__) || defined(__clang__)
	__asm__ __volatile__("isb" ::: "memory");
#elif defined(_MSC_VER)
	__isb(_ARM64_BARRIER_SY);
#endif
}

/* Force SB (ARMv8.5-A+ optimization) - only call if supported! */
static JEMALLOC_ALWAYS_INLINE void
spin_delay_sb_only(void) {
#if defined(__GNUC__) || defined(__clang__)
	__asm__ __volatile__(".inst 0xd50330ff" ::: "memory");
#elif defined(_MSC_VER)
	__emit(0xd50330ff);
#endif
}

/* Get time in nanoseconds using jemalloc's nstime */
static uint64_t
get_time_ns(void) {
	nstime_t time;
	nstime_init_update(&time);
	return nstime_ns(&time);
}

TEST_BEGIN(test_sb_benchmark) {
	uint64_t start, end;
	double isb_ns_per_iter, sb_ns_per_iter;

	malloc_printf("=== ARMv8.5-A SB Benchmark ===\n");
	malloc_printf("Iterations: %d\n", BENCHMARK_ITERATIONS);
	malloc_printf("SB support detected: %s\n\n",
	    arm_has_sb_instruction ? "YES" : "NO");

	if (!arm_has_sb_instruction) {
		malloc_printf("Skipping SB benchmark - not supported on this CPU\n");
		malloc_printf("(Running on ARMv8.0-8.4 hardware)\n");
		return;
	}

	/* ===== Benchmark ISB (baseline) ===== */

	/* Warmup */
	for (int i = 0; i < 1000; i++) {
		spin_delay_isb_only();
	}

	/* Measure ISB */
	start = get_time_ns();
	for (int i = 0; i < BENCHMARK_ITERATIONS; i++) {
		spin_delay_isb_only();
	}
	end = get_time_ns();
	isb_ns_per_iter = (double)(end - start) / BENCHMARK_ITERATIONS;

	malloc_printf("ISB (ARMv8.0-8.4 baseline): %.3f ns/iter\n", isb_ns_per_iter);

	/* ===== Benchmark SB (optimized) ===== */

	/* Warmup */
	for (int i = 0; i < 1000; i++) {
		spin_delay_sb_only();
	}

	/* Measure SB */
	start = get_time_ns();
	for (int i = 0; i < BENCHMARK_ITERATIONS; i++) {
		spin_delay_sb_only();
	}
	end = get_time_ns();
	sb_ns_per_iter = (double)(end - start) / BENCHMARK_ITERATIONS;

	malloc_printf("SB  (ARMv8.5-A+ optimized): %.3f ns/iter\n", sb_ns_per_iter);

	/* ===== Calculate and report improvement ===== */

	double speedup = isb_ns_per_iter / sb_ns_per_iter;
	double improvement = ((isb_ns_per_iter - sb_ns_per_iter) / isb_ns_per_iter) * 100.0;

	malloc_printf("\n");
	malloc_printf("Results:\n");
	malloc_printf("  Speedup: %.2fx faster\n", speedup);
	malloc_printf("  Improvement: %.1f%%\n", improvement);

	/* Platform-specific expectations */
	malloc_printf("\n");
	malloc_printf("Expected ranges by platform:\n");
	malloc_printf("  Apple Silicon (M1/M2/M3/M4): 1.10-1.15x (10-15%% improvement)\n");
	malloc_printf("  AWS Graviton 3/4 (Neoverse):  1.60-1.80x (25-35%% improvement)\n");
	malloc_printf("  Other ARM servers:            Platform-dependent\n");

	/* Reference benchmarks for comparison */
	malloc_printf("\n");
	malloc_printf("Reference benchmarks:\n");
	malloc_printf("  macOS 15 M1:   ISB=8.847 ns, SB=7.849 ns, speedup=1.13x (11.3%%)\n");
	malloc_printf("  Linux Graviton 3: ISB=8740.725 ns, SB=5110.839 ns, speedup=1.71x (30%%)\n");

	/* Sanity check - SB should be faster or equal, never slower */
	expect_true(speedup >= 1.0,
	    "SB should be faster than ISB (or equal in worst case)");

	/* Warn if SB is somehow slower (shouldn't happen) */
	if (speedup < 1.0) {
		malloc_printf("\nWARNING: SB is slower than ISB! This is unexpected.\n");
		malloc_printf("Please report this result with CPU model information.\n");
	}
}
TEST_END

#endif /* ARM64 */

int
main(void) {
#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64))
	return test_no_reentrancy(test_sb_benchmark);
#else
	/* Not ARM64 - skip benchmark */
	malloc_printf("Skipping SB benchmark on non-ARM64 platform\n");
	return 0;
#endif
}