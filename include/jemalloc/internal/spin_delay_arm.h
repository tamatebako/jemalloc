#ifndef JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H
#define JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H

#include "jemalloc/internal/jemalloc_preamble.h"

/* MSVC ARM64 needs intrin.h for intrinsics */
#if defined(_MSC_VER) && (defined(_M_ARM64) || defined(_M_ARM64EC))
#include <intrin.h>
#endif

/*
 * ARMv9 Speculation Barrier (SB) instruction support.
 *
 * This header provides the inline spin_delay_arm() function for fast-path
 * performance. The actual detection logic is in src/spin_delay_arm.c.
 *
 * Platforms: Linux, macOS, Windows (all ARM64)
 * Detection: Runtime via platform-specific APIs (getauxval/sysctl/registry)
 */

#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))

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
#if defined(__GNUC__) || defined(__clang__)
	if (__builtin_expect(arm_has_sb_instruction == 1, 1)) {
		/* ARMv9 Speculation Barrier - faster than ISB */
		__asm__ __volatile__(".inst 0xd50330ff" ::: "memory");
	} else {
		/* ARMv8 Instruction Synchronization Barrier - fallback */
		__asm__ __volatile__("isb" ::: "memory");
	}
#elif defined(_MSC_VER)
	/* MSVC on ARM64 uses __emit() to insert raw instruction opcodes */
	if (arm_has_sb_instruction == 1) {
		/* ARMv9 Speculation Barrier (SB) - opcode 0xd50330ff */
		__emit(0xd50330ff);
	} else {
		/* ARMv8 Instruction Synchronization Barrier (ISB) - use intrinsic */
		__isb(_ARM64_BARRIER_SY);
	}
#endif
}

#endif /* ARM64 && (GCC || Clang || MSVC) */

#endif /* JEMALLOC_INTERNAL_SPIN_DELAY_ARM_H */