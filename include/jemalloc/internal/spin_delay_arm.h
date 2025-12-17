#ifndef JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H
#define JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H

#include "jemalloc/internal/jemalloc_preamble.h"

/*
 * ARMv9 Speculation Barrier (SB) instruction support.
 *
 * This header provides the inline spin_delay_arm() function for fast-path
 * performance. The actual detection logic is in src/spin_delay_arm.c.
 */

#if defined(__linux__) && (defined(__aarch64__) || defined(__arm64__)) && \
    (defined(__GNUC__) || defined(__clang__))

/*
 * Global variable tracking SB support - defined in spin_delay_arm.c.
 * Initialized by constructor before any threads exist.
 */
extern int arm_has_sb_instruction;

/*
 * Inline function for fast path - uses SB on ARMv9, ISB on ARMv8.
 *
 * __builtin_expect optimization: SB is expected on modern hardware.
 * No atomic operations needed - value set once at startup, never changes.
 */
static inline void
spin_delay_arm(void) {
	if (__builtin_expect(arm_has_sb_instruction == 1, 1)) {
		/* ARMv9 Speculation Barrier - faster than ISB */
		__asm__ __volatile__(".inst 0xd50330ff" ::: "memory");
	} else {
		/* ARMv8 Instruction Synchronization Barrier - fallback */
		__asm__ __volatile__("isb" ::: "memory");
	}
}

#endif /* __linux__ && __aarch64__ && (GCC || Clang) */

#endif /* JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H */