//
//  ExternalNoelx-Bridging-Header.h
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "exploit/bad_query.h"
#import "exploit/mcm_bridge.h"
#import "kexploit/kexploit_opa334.h"
#import "kexploit/sandbox_escape.h"
#import "kexploit/kutils.h"
#import "helpers/AppIconHelper.h"
#import "helpers/DisplayIdentity.h"

// Dual-backend (iOS 26-27)
#import "DualBackend/BadKernelBridge.h"
#import "DualBackend/KRWBackend.h"
#import "DualBackend/DualBackendConfig.h"

// BadKernel (cloned at build time into ExternalNoelx/BadKernel/)
// HEADER_SEARCH_PATHS includes ExternalNoelx/BadKernel, so no prefix.
#import "BadKernel.h"
