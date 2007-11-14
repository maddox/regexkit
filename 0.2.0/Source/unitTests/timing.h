//
//  RegexKit-timing.h
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
static unsigned int startAutoreleasedObjects = 0, iterations = 0;

static RKCPUTime testStartCPUTime;
static RKCPUTime testEndCPUTime;
static RKCPUTime testElapsedCPUTime;

static NSString *leakEnvString = nil;
static NSString *debugEnvString = nil;
static NSString *timingEnvString = nil;

static NSMutableArray *timingResultsArray = nil;

@interface timing : SenTestCase {
}

@end
