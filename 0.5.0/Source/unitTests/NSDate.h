#import <Cocoa/Cocoa.h>
#import <Foundation/NSDebug.h>
#import <stdint.h>
#import <sys/time.h>
#import <sys/resource.h>
#import <RegexKit/RegexKit.h>

#ifdef __MACOSX_RUNTIME__
#import <malloc/malloc.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <CoreServices/CoreServices.h>
#endif //__MACOSX_RUNTIME__

#define NSMakeRange(x, y) ((NSRange){(x), (y)})
#define NSEqualRanges(range1, range2) ({NSRange _r1 = (range1), _r2 = (range2); (_r1.location == _r2.location) && (_r1.length == _r2.length); })
#define NSLocationInRange(l, r) ({ unsigned int _l = (l); NSRange _r = (r); (_l - _r.location) < _r.length; })
#define NSMaxRange(r) ({ NSRange _r = (r); _r.location + _r.length; })

int dummyDateFunction(int dummyInt);

typedef double NSHighResTimeInterval;

typedef struct {
  NSHighResTimeInterval systemCPUTime;
  NSHighResTimeInterval userCPUTime;
  NSHighResTimeInterval CPUTime;
#ifdef __MACOSX_RUNTIME__
  malloc_statistics_t zoneStats;
  uint64_t mach_time;
  uint64_t nanoSeconds;
#endif //__MACOSX_RUNTIME__
} RKCPUTime;

@interface NSDate (CPUTimeAdditions)
+ (RKCPUTime)cpuTimeUsed;
+ (RKCPUTime)differenceOfStartingTime:(RKCPUTime)startTime endingTime:(RKCPUTime)endingTime;
+ (NSString *)stringFromCPUTime:(RKCPUTime)CPUTime;
+ (NSString *)microSecondsStringFromCPUTime:(RKCPUTime)CPUTime;
#ifdef __MACOSX_RUNTIME__
+ (NSString *)machtimeStringFromCPUTime:(RKCPUTime)CPUTime;
+ (NSString *)stringFromCPUTimeMemory:(RKCPUTime)CPUTime;
#endif //__MACOSX_RUNTIME__


@end
