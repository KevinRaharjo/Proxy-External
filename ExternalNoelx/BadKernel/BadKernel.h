//
//  BadKernel.h
//  External Nixx — BadKernel public interface
//
//  Real implementation is provided by setup_badkernel.sh at build time.
//  Keep in sync with BadKernel.m if the upstream changes.
//

#ifndef BadKernel_h
#define BadKernel_h

#import <Foundation/Foundation.h>
#import <stdint.h>
#import <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

// Log callback used by BadKernelInitWithLog.
typedef void (*bk_log_func_t)(const char *message);

// ═══════════════════════════════════════════════════════════════
// MARK: - Lifecycle
// ═══════════════════════════════════════════════════════════════

int      BadKernelInit(void);
int      BadKernelInitWithLog(bk_log_func_t log_func);
int      BadKernelDeinit(void);
bool     BadKernelIsReady(void);
uint64_t BadKernelGetBase(void);
uint64_t BadKernelGetSlide(void);

// ═══════════════════════════════════════════════════════════════
// MARK: - Kernel R/W
// ═══════════════════════════════════════════════════════════════

int BadKernelKRead(uint64_t kaddr, void *out, size_t len);
int BadKernelKWrite(uint64_t kaddr, const void *in, size_t len);

uint32_t BadKernelKRead32(uint64_t addr);
uint64_t BadKernelKRead64(uint64_t addr);

int BadKernelKWrite32(uint64_t kaddr, uint32_t val);
int BadKernelKWrite64(uint64_t kaddr, uint64_t val);

// ═══════════════════════════════════════════════════════════════
// MARK: - Sandbox escape
// ═══════════════════════════════════════════════════════════════

int64_t BadKernelSandboxEscape(const char *path);
void    BadKernelSandboxRelease(int64_t handle);

NS_ASSUME_NONNULL_END

#endif /* BadKernel_h */
