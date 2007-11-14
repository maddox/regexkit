//
//  collectionAdditions.h
//  RegexKit
//

#import <Cocoa/Cocoa.h>
#import <Foundation/NSDebug.h>
#import <SenTestingKit/SenTestingKit.h>
#import <RegexKit/RegexKit.h>
#import <stdint.h>
#include <sys/types.h>
#include <unistd.h>
#import "NSDate.h"

static NSAutoreleasePool *startTopPool = nil;
static NSAutoreleasePool *startLeakPool = nil;
static RKUInteger startAutoreleasedObjects = 0;

static RKCPUTime testStartCPUTime;
static RKCPUTime testEndCPUTime;
static RKCPUTime testElapsedCPUTime;

static NSString *leakEnvString = nil;
static NSString *debugEnvString = nil;
static NSString *timingEnvString = nil;


#ifndef STAssertTrue
// Used these when testing under FreeBSD and OCUnit v27

#define STAssertTrue(exeLine, ...) should(((exeLine) != 0))
#define STAssertNil(exeLine, ...) should(((exeLine) == nil))
#define STAssertNoThrow(exeLine, ...) shouldntRaise((exeLine))
#define STAssertNotNil(exeLine, ...) should(((exeLine) != nil))
#define STAssertThrows(exeLine, ...) shouldRaise((exeLine))
#define STAssertThrowsSpecificNamed(exeLine, ...) shouldRaise((exeLine))
#define STAssertFalse(exeLine, ...) should(((exeLine) == 0))

#endif


@interface extensions : SenTestCase {

}

@end
