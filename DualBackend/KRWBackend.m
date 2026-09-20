//
//  KRWBackend.m
//  External Nixx — dual-backend KRW routing
//

#import "BadKernelBridge.h"
#import "KRWBackend.h"

// Forward-declare opa334 primitives so we don't have to import the whole header here.
extern uint64_t early_kread64(uint64_t where);
extern void early_kwrite64(uint64_t where, uint64_t what);

static KRWBackendType gKRWBackend = KRWBackendTypeNone;

void krw_set_backend(KRWBackendType type) {
    gKRWBackend = type;
    const char *name = "none";
    switch (type) {
        case KRWBackendTypeOpa334:    name = "opa334";    break;
        case KRWBackendTypeBadKernel: name = "BadKernel"; break;
        default:                       name = "none";     break;
    }
    NSLog(@"[KRW] backend = %s", name);
}

KRWBackendType krw_current_backend(void) { return gKRWBackend; }

uint64_t krw_backend_kread64(uint64_t addr) {
    switch (gKRWBackend) {
        case KRWBackendTypeBadKernel: return BadKernelKRead64(addr);
        case KRWBackendTypeOpa334:
        default:                       return early_kread64(addr);
    }
}

void krw_backend_kwrite64(uint64_t addr, uint64_t val) {
    switch (gKRWBackend) {
        case KRWBackendTypeBadKernel: BadKernelKWrite64(addr, val); return;
        case KRWBackendTypeOpa334:
        default:                       early_kwrite64(addr, val);  return;
    }
}
