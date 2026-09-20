//
//  KRWBackend.m
//  External Nixx — dual-backend KRW routing
//

#import "BadKernelBridge.h"
#import "KRWBackend.h"

extern uint64_t early_kread64(uint64_t where);
extern void early_kwrite64(uint64_t where, uint64_t what);

static int32_t gKRWBackend = 0;

void krw_set_backend(int32_t type) {
    gKRWBackend = type;
    const char *name = "none";
    if (type == 1) name = "opa334";
    else if (type == 2) name = "BadKernel";
    NSLog(@"[KRW] backend = %s", name);
}

int32_t krw_current_backend(void) { return gKRWBackend; }

uint64_t krw_backend_kread64(uint64_t addr) {
    if (gKRWBackend == 2) return BadKernelKRead64(addr);
    return early_kread64(addr);
}

void krw_backend_kwrite64(uint64_t addr, uint64_t val) {
    if (gKRWBackend == 2) {
        BadKernelKWrite64(addr, val);
        return;
    }
    early_kwrite64(addr, val);
}
