//
//  BadKernel.h
//  External Nixx — BadKernel header
//
//  Real implementation is provided by setup_badkernel.sh at build time.
//  This placeholder exists so the bridging header can resolve the import
//  even if the clone step fails.
//

#ifndef BadKernel_h
#define BadKernel_h

#import <Foundation/Foundation.h>
#import <stdint.h>
#import <stdbool.h>

NS_ASSUME_NONNULL_BEGIN

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

NS_ASSUME_NONNULL_END

#endif /* BadKernel_h */
