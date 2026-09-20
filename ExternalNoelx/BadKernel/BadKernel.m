//
//  BadKernel.m
//  External Nixx — BadKernel stub
//
//  Real implementation is provided by setup_badkernel.sh at build time.
//  This stub prevents link errors if the clone step fails.
//

#import "BadKernel.h"

// If BADKERNEL_REAL is defined (real sources were cloned), skip these stubs.
#ifndef BADKERNEL_REAL

void BadKernelInit(void) {}
void BadKernelDeinit(void) {}
bool BadKernelIsReady(void) { return false; }
uint64_t BadKernelGetBase(void) { return 0; }
uint64_t BadKernelGetSlide(void) { return 0; }

bool BadKernelKRead(uint64_t addr, void *out, size_t len) { return false; }
uint32_t BadKernelKRead32(uint64_t addr) { return 0; }
uint64_t BadKernelKRead64(uint64_t addr) { return 0; }

bool BadKernelKWrite(uint64_t addr, const void *in, size_t len) { return false; }
bool BadKernelKWrite32(uint64_t addr, uint32_t val) { return false; }
bool BadKernelKWrite64(uint64_t addr, uint64_t val) { return false; }

int64_t BadKernelSandboxEscape(const char *path) { return -1; }
void BadKernelSandboxRelease(int64_t handle) {}

#endif
