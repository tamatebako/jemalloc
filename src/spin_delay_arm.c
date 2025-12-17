#include "jemalloc/internal/jemalloc_preamble.h"

/*
 * ARMv9 Speculation Barrier (SB) instruction support for ARM64 Linux.
 *
 * Performance: ~30% faster spin delays on ARMv9 hardware vs ISB.
 * Detection: Runtime via getauxval(AT_HWCAP) and HWCAP_SB flag.
 * Fallback: Uses ISB on ARMv8 and older.
 *
 * Original PR: https://github.com/jemalloc/jemalloc/pull/2843
 * Author: @salvatoredipietro
 */

#if defined(__linux__) && (defined(__aarch64__) || defined(__arm64__)) && \
    (defined(__GNUC__) || defined(__clang__))

#include "jemalloc/internal/spin_delay_arm.h"
#include <sys/auxv.h>  /* Linux only - guarded above */

/* Define HWCAP_SB if not in system headers */
#ifndef HWCAP_SB
#define HWCAP_SB (1ULL << 56)  /* ULL for 32-bit ARM compatibility */
#endif

/*
 * Global variable tracking SB instruction support.
 *
 * Normal int (not _Atomic) per review feedback:
 * - Constructor runs before any threads exist (no race condition)
 * - Atomic loads would cause performance regression
 * - Value never changes after initialization
 */
int arm_has_sb_instruction = 0;

/*
 * Constructor function - runs at library load time.
 * Only in .c file to avoid multiple copies per translation unit.
 *
 * GCC/Clang attribute already guarded by outer #if condition.
 */
__attribute__((constructor))
static void detect_arm_sb_support(void) {
	arm_has_sb_instruction = (getauxval(AT_HWCAP) & HWCAP_SB) ? 1 : 0;
}

#endif /* __linux__ && __aarch64__ && (GCC || Clang) */