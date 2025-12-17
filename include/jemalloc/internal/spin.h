#ifndef JEMALLOC_INTERNAL_SPIN_H
#define JEMALLOC_INTERNAL_SPIN_H

#include "jemalloc/internal/jemalloc_preamble.h"

/* Include ARM-specific optimizations for Linux ARM64 */
#if defined(__linux__) && (defined(__aarch64__) || defined(__arm64__)) && \
    (defined(__GNUC__) || defined(__clang__))
#include "jemalloc/internal/spin_delay_arm.h"
#endif

#define SPIN_INITIALIZER                                                       \
	{ 0U }

typedef struct {
	unsigned iteration;
} spin_t;

static inline void
spin_cpu_spinwait(void) {
#if defined(__linux__) && (defined(__aarch64__) || defined(__arm64__)) && \
    (defined(__GNUC__) || defined(__clang__))
	/* Use ARMv9 SB instruction on supported hardware, ISB fallback */
	spin_delay_arm();
#elif HAVE_CPU_SPINWAIT
	CPU_SPINWAIT;
#else
	volatile int x = 0;
	x = x;
#endif
}

static inline void
spin_adaptive(spin_t *spin) {
	volatile uint32_t i;

	if (spin->iteration < 5) {
		for (i = 0; i < (1U << spin->iteration); i++) {
			spin_cpu_spinwait();
		}
		spin->iteration++;
	} else {
#ifdef _WIN32
		SwitchToThread();
#else
		sched_yield();
#endif
	}
}

#undef SPIN_INLINE

#endif /* JEMALLOC_INTERNAL_SPIN_H */
