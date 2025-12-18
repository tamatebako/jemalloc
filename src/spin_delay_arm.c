#include "jemalloc/internal/jemalloc_preamble.h"

/*
 * ARMv9 Speculation Barrier (SB) instruction support for ARM64.
 *
 * Performance: ~30% faster spin delays on ARMv9 hardware vs ISB.
 * Platforms: Linux, macOS, Windows (all ARM64)
 * Detection: Runtime via platform-specific APIs
 * Fallback: Uses ISB on ARMv8 and older
 *
 * Original PR: https://github.com/jemalloc/jemalloc/pull/2843
 * Author: @salvatoredipietro
 * Cross-platform support: Extended for macOS and Windows
 */

#if (defined(__aarch64__) || defined(__arm64__) || defined(_M_ARM64)) && \
    (defined(__GNUC__) || defined(__clang__) || defined(_MSC_VER))

#include "jemalloc/internal/spin_delay_arm.h"

/* Platform-specific headers for SB detection */
#if defined(__linux__)
#include <sys/auxv.h>  /* Linux: getauxval */
#elif defined(__APPLE__)
#include <sys/sysctl.h>  /* macOS: sysctlbyname */
#elif defined(_WIN32)
#include <windows.h>  /* Windows: Registry API */
#endif

/* Define HWCAP_SB for Linux if not in system headers */
#if defined(__linux__) && !defined(HWCAP_SB)
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
 * Platform-specific SB detection functions
 */

#if defined(__linux__)
/*
 * Linux: Detect SB via getauxval(AT_HWCAP) & HWCAP_SB
 * Works on: All ARMv9 Linux systems (AWS Graviton 3/4, ARM Neoverse, etc.)
 */
static int detect_sb_linux(void) {
	return (getauxval(AT_HWCAP) & HWCAP_SB) ? 1 : 0;
}
#endif

#if defined(__APPLE__)
/*
 * macOS: Detect SB via sysctl hw.optional.arm.FEAT_SB
 * Works on: All Apple Silicon (M1/M2/M3/M4 - ARMv8.5-A+)
 * Returns: 1 if supported, 0 on error or unsupported
 */
static int detect_sb_macos(void) {
	int value = 0;
	size_t length = sizeof(value);
	if (sysctlbyname("hw.optional.arm.FEAT_SB", &value, &length, NULL, 0) != 0) {
		return 0;  /* Error or not available */
	}
	return value;
}
#endif

#if defined(_WIN32)
/*
 * Windows: Detect SB via registry ID_AA64ISAR1_EL1 (CP 4031)
 * Works on: Windows 11 ARM64 (Snapdragon X Elite/Plus, future ARM64 devices)
 * Returns: 1 if supported, 0 on error or unsupported
 *
 * Reads undocumented registry key to access ARM system register.
 * SB field is bits 11:8 of ID_AA64ISAR1_EL1.
 */
static int detect_sb_windows(void) {
	HKEY hkey;
	LONG result;
	ULONGLONG value = 0;
	DWORD size = sizeof(value);
	unsigned int sb_field;

	/* Open registry key for CPU 0 (assumes homogeneous cores) */
	result = RegOpenKeyExA(HKEY_LOCAL_MACHINE,
	                       "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
	                       0,
	                       KEY_READ,
	                       &hkey);
	if (result != ERROR_SUCCESS) {
		return 0;
	}

	/* Query ID_AA64ISAR1_EL1 register value (stored as "CP 4031") */
	result = RegQueryValueExA(hkey,
	                         "CP 4031",
	                         NULL,
	                         NULL,
	                         (BYTE*)&value,
	                         &size);
	RegCloseKey(hkey);

	if (result != ERROR_SUCCESS) {
		return 0;
	}

	/* Extract SB field (bits 11:8) - nonzero means supported */
	sb_field = (value >> 8) & 0xF;
	return (sb_field != 0) ? 1 : 0;
}
#endif

/*
 * Constructor function - runs at library load time.
 * Only in .c file to avoid multiple copies per translation unit.
 *
 * Detects SB support using platform-specific method.
 */
#if defined(__GNUC__) || defined(__clang__)
__attribute__((constructor))
#elif defined(_MSC_VER)
#pragma section(".CRT$XCU", read)
__declspec(allocate(".CRT$XCU"))
static void (*_detect_arm_sb_init)(void) = detect_arm_sb_support;
#endif
static void detect_arm_sb_support(void) {
#if defined(__linux__)
	arm_has_sb_instruction = detect_sb_linux();
#elif defined(__APPLE__)
	arm_has_sb_instruction = detect_sb_macos();
#elif defined(_WIN32)
	arm_has_sb_instruction = detect_sb_windows();
#else
	/* Unknown platform - assume no SB support */
	arm_has_sb_instruction = 0;
#endif
}

#endif /* ARM64 && (GCC || Clang || MSVC) */