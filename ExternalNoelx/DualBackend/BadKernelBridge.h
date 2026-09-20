//
//  BadKernelBridge.h
//  External Nixx — dual backend bridge
//

#ifndef BadKernelBridge_h
#define BadKernelBridge_h

#import <Foundation/Foundation.h>
#import <stdint.h>
#import <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

// ═══════════════════════════════════════════════════════════════
// MARK: - BadKernel C API
// ═══════════════════════════════════════════════════════════════

void BadKernelInit(void);
void BadKernelDeinit(void);
bool BadKernelIsReady(void);
uint64_t BadKernelGetBase(void);
uint64_t BadKernelGetSlide(void);

bool BadKernelKRead(uint64_t addr, void *out, size_t len);
uint32_t BadKernelKRead32(uint64_t addr);
uint64_t BadKernelKRead64(uint64_t addr);

bool BadKernelKWrite(uint64_t addr, const void *in, size_t len);
bool BadKernelKWrite32(uint64_t addr, uint32_t val);
bool BadKernelKWrite64(uint64_t addr, uint64_t val);

int64_t BadKernelSandboxEscape(const char *path);
void BadKernelSandboxRelease(int64_t handle);

// ═══════════════════════════════════════════════════════════════
// MARK: - KRW backend routing
// ═══════════════════════════════════════════════════════════════
//
// Use int32_t instead of NS_ENUM because Swift does not reliably
// expose nested ObjC enums through the bridging header.
// Values: 0 = none, 1 = opa334, 2 = BadKernel
//

void krw_set_backend(int32_t type);
int32_t krw_current_backend(void);

uint64_t krw_backend_kread64(uint64_t addr);
void krw_backend_kwrite64(uint64_t addr, uint64_t val);

NS_ASSUME_NONNULL_END

#endif /* BadKernelBridge_h */
