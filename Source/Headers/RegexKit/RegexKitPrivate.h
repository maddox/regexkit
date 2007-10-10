//
//  RegexKitPrivate.h
//  RegexKit
//
// NOT in RegexKit.framework/Headers
//

/*
 Copyright © 2007, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */ 


/*
 This file is intended to store various private bits for RKRegex such as:

 Runtime detection and configuration specifics (base runtime detection is from RKRegex.h)
 Compile time option configurations (ie, USE_* flags)
 Function prototypes that are for private use.
 Internal typedefs
 Preprocessor macros

 In general, this is for stuff that is compiler housekeeping (prototypes) or so simple and trivial that the specifics don't much matter (ala NSMakeRange & friends).
 The largest function currently is RKStringBufferWithString, which sort of doesn't fit here but sort of does, so it does.

 Mostly helps keep the main file cleaner looking.

 Compile unit global variables should /NOT/ be defined here.
*/

#import <Foundation/Foundation.h>
#import <RegexKit/RegexKitDefines.h>
#import <RegexKit/RegexKitTypes.h>
#import <RegexKit/RKRegex.h>

#ifdef USE_CORE_FOUNDATION
typedef CFStringEncoding RKStringBufferEncoding;
#else
typedef NSStringEncoding RKStringBufferEncoding;
#endif

typedef struct _RKStringBuffer {
  NSString *string;
  const char *characters;
  unsigned long length;
  RKStringBufferEncoding encoding;
} RKStringBuffer;


// Switches between #defines vs. RKREGEX_STATIC_INLINE functions for some things
#define _USE_DEFINES


#import <pthread.h>

#import <objc/objc.h>
#import <objc/objc-api.h>


#ifdef __MACOSX_RUNTIME__

#import <objc/objc-class.h>
#import <objc/objc-runtime.h>
#include <mach/mach_types.h>
#include <mach/mach_host.h>
#include <mach/thread_switch.h>
#include <mach/mach_init.h>

// Technically SWITCH_OPTION_DEPRESS requires determining the minimum depress time, but it's somewhat convoluted to extract and make useable globally.. :(
RKREGEX_STATIC_INLINE void RKThreadYield(void) { thread_switch(THREAD_NULL, SWITCH_OPTION_DEPRESS, 1); }
RKREGEX_STATIC_INLINE BOOL RKIsMainThread(void) { return((BOOL)pthread_main_np()); }

#include <libkern/OSAtomic.h>

#define HAVE_RKREGEX_ATOMIC_OPS

#define RKAtomicMemoryBarrier(...) OSMemoryBarrier()
#define RKAtomicIncrementInt(ptr) OSAtomicIncrement32(ptr)
#define RKAtomicDecrementInt(ptr) OSAtomicDecrement32(ptr)
#define RKAtomicCompareAndSwapInt(oldValue, newValue, ptr) OSAtomicCompareAndSwap32Barrier(oldValue, newValue, ptr)

#ifdef __LP64__
#define RKAtomicCompareAndSwapPtr(oldp, newp, ptr) OSAtomicCompareAndSwap64Barrier((int64_t)oldp, (int64_t)newp, (int64_t *)ptr)
#else
#define RKAtomicCompareAndSwapPtr(oldp, newp, ptr) OSAtomicCompareAndSwap32Barrier((int32_t)oldp, (int32_t)newp, (int32_t *)ptr)
#endif

#endif //__MACOSX_RUNTIME__

// FreeBSD 5+
#if (__FreeBSD__ >= 5)
#include <sys/types.h>
#include <machine/atomic.h>
#include <unistd.h>
#include <pthread_np.h>

/* Testing gave the impression that sched_yield().. didn't.  Massive bulk read spin increments.  Sleeping helped tremendously. */
RKREGEX_STATIC_INLINE void RKThreadYield(void) { usleep(50); sched_yield(); }
RKREGEX_STATIC_INLINE BOOL RKIsMainThread(void) { return((BOOL)pthread_main_np()); }

#define HAVE_RKREGEX_ATOMIC_OPS

RKREGEX_STATIC_INLINE void RKAtomicMemoryBarrier(void) { volatile int x = 0; atomic_cmpset_rel_int(&x, 1, 2); /* XXX force a bogus memory transaction */ }
RKREGEX_STATIC_INLINE int32_t RKAtomicIncrementInt(int32_t *ptr) { atomic_add_int(ptr, 1); return(atomic_load_acq_32(ptr)); /* XXX not 100% correct, but close enough */ }
RKREGEX_STATIC_INLINE int32_t RKAtomicDecrementInt(int32_t *ptr) { atomic_subtract_int(ptr, 1); return(atomic_load_acq_32(ptr)); /* XXX not 100% correct, but close enough */ }
RKREGEX_STATIC_INLINE BOOL RKAtomicCompareAndSwapInt(int32_t oldValue, int32_t newValue, volatile int32_t *ptr) { return(atomic_cmpset_rel_int(ptr, oldValue, newValue)); }
RKREGEX_STATIC_INLINE BOOL RKAtomicCompareAndSwapPtr(void *oldp, void *newp, volatile void *ptr) { return(atomic_cmpset_rel_ptr(ptr, oldp, newp)); }

#endif //__FreeBSD__

// Solaris
#if defined(__sun__) && defined(__svr4__)
#include <thread.h>
#include <atomic.h>

RKREGEX_STATIC_INLINE void RKThreadYield(void) { thr_yield(); }
RKREGEX_STATIC_INLINE void RKIsMainThread(void) { thr_main(); }

#define HAVE_RKREGEX_ATOMIC_OPS

RKREGEX_STATIC_INLINE void RKAtomicMemoryBarrier(void) { membar_enter(); membar_exit(); }
RKREGEX_STATIC_INLINE int32_t RKAtomicIncrementInt(int32_t *ptr) { return(atomic_inc_uint_nv((uint_t *)ptr)); }
RKREGEX_STATIC_INLINE int32_t RKAtomicDecrementInt(int32_t *ptr) { return(atomic_dec_uint_nv((uint_t *)ptr)); }
RKREGEX_STATIC_INLINE BOOL RKAtomicCompareAndSwapInt(int32_t oldValue, int32_t newValue, volatile int32_t *ptr) { return(atomic_cas_uint(ptr, (uint_t)oldValue, (uint_t)newValue) == oldValue ? YES : NO); }
RKREGEX_STATIC_INLINE BOOL RKAtomicCompareAndSwapPtr(void *oldp, void *newp, volatile void *ptr) { return(atomic_cas_ptr(ptr, oldp, newp) == oldp ? YES : NO); }

#endif // Solaris __sun__ _svr4__

// Try for GCC 4.1+ built in atomic ops and pthreads?
#if !defined(HAVE_RKREGEX_ATOMIC_OPS) && ((__GNUC__ == 4) && (__GNUC_MINOR__ >= 1))

#warning "Unable to determine platform specific atomic operations. Trying gcc 4.1+ built in atomic ops, sched_yield(), and pthread_main_np()"

#define HAVE_RKREGEX_ATOMIC_OPS

RKREGEX_STATIC_INLINE void RKThreadYield(void) { sched_yield(); }
RKREGEX_STATIC_INLINE BOOL RKIsMainThread(void) { return((BOOL)pthread_main_np()); }
#define RKAtomicMemoryBarrier(...) __sync_synchronize()
#define RKAtomicIncrementInt(ptr) __sync_add_and_fetch(ptr, 1)
#define RKAtomicDecrementInt(ptr) __sync_sub_and_fetch(ptr, 1)
#define RKAtomicCompareAndSwapInt(oldValue, newValue, ptr) __sync_bool_compare_and_swap(ptr, oldValue, newValue)
#define RKAtomicCompareAndSwapPtr(oldp, newp, ptr) __sync_bool_compare_and_swap(ptr, oldValue, newValue)

#endif // HAVE_RKREGEX_ATOMIC_OPS == NO and gcc 4.1 or greater


#ifndef HAVE_RKREGEX_ATOMIC_OPS
#error "Unable to determine atomic operations for this platform"
#endif

// End platform configuration

// Useful min/max macros that only evaluate the parameters once, and are type sensitive.

#ifdef max
#warning "max is already defined, max(a, b) may not not behave as expected."
#else
#define max(a,b) ({__typeof__(a) _a = (a); __typeof__(b) _b = (b); (_a > _b) ? _a : _b; })
#endif

#ifdef min
#warning "min is already defined, min(a, b) may not behave as expected."
#else
#define min(a,b) ({__typeof__(a) _a = (a); __typeof__(b) _b = (b); (_a < _b) ? _a : _b; })
#endif

// Returns a string in the form of '[className selector]: standardStringFormat, formatArguments'
// Dynamically looks up the class name so inherited classes will reported the new class name, and not the base class name.
// example
// NSString *prettyString = RKPrettyObjectMethodString("A simple error occurred.  Size %d is invalid", requestedSize);
// [RKRegex setSize:]: A simple error occurred.  Size 2147483647 is invalid
//
#define RKPrettyObjectMethodString(stringArg, ...) ([NSString stringWithFormat:[NSString stringWithFormat:@"%p [%@ %@]: %@", self, NSStringFromClass([(id)self class]), NSStringFromSelector(_cmd), stringArg], ##__VA_ARGS__])

// Returns human readable string of an unknown object in the form of '[className @ 0x12345678]: '[object description]'...'
// The object description is limited to 40 characters, and adds a trailing '...' if the length exceeds that.
// The objects [[obj description] UTF8String] is evaluated twice, unfortunately, to remove the possibility of a NULL pointer to '%.40s'
//
#define RKPrettyObjectDescription(prettyObject) ([NSString stringWithFormat:@"[%@ @ %p]: '%.40s'%@", [prettyObject className], prettyObject, ([[prettyObject description] UTF8String] == NULL) ? "" : [[prettyObject description] UTF8String], ([[prettyObject description] length] > 40) ? @"...":@""])


// In RKRegex.c
RKRegex *RKRegexFromStringOrRegex(id self, const SEL _cmd, id aRegex, const RKCompileOption compileOptions, const BOOL shouldAutorelease) RK_ATTRIBUTES(nonnull(3), pure, used, visibility("hidden"));
// In RKCache.c
id RKFastCacheLookup(RKCache * const aCache, const SEL _cmd RK_ATTRIBUTES(unused), const unsigned int objectHash, const BOOL shouldAutorelease) RK_ATTRIBUTES(used, visibility("hidden"));
// In RKPrivate.c
void nsprintf(NSString * const formatString, ...) RK_ATTRIBUTES(visibility("hidden"));
void vnsprintf(NSString * const formatString, va_list ap) RK_ATTRIBUTES(visibility("hidden"));
int RKRegexPCRECallout(pcre_callout_block * const callout_block) RK_ATTRIBUTES(used, visibility("hidden"));
NSArray *RKArrayOfPrettyNewlineTypes(NSString * const prefixString) RK_ATTRIBUTES(used, visibility("hidden"));


#ifdef _USE_DEFINES

#define NSMakeRange(x, y) ((NSRange){(x), (y)})
#define NSEqualRanges(range1, range2) ({NSRange _r1 = (range1), _r2 = (range2); (_r1.location == _r2.location) && (_r1.length == _r2.length); })
#define NSLocationInRange(l, r) ({ unsigned int _l = (l); NSRange _r = (r); (_l - _r.location) < _r.length; })
#define NSMaxRange(r) ({ NSRange _r = (r); _r.location + _r.length; })

#define RKYesOrNo(yesOrNo) ((yesOrNo == YES) ? @"Yes":@"No")
#define RKMakeStringBuffer(bufferString, stringBufferCharacters, stringBufferLength, stringBufferEncoding) ((RKStringBuffer){bufferString, stringBufferCharacters, stringBufferLength, stringBufferEncoding})
#define RKRangeInsideRange(insideRange, outsideRange) ((insideRange.location - outsideRange.location < outsideRange.length) && (((insideRange.location + insideRange.length) - outsideRange.location) <= outsideRange.length))

#ifdef USE_CORE_FOUNDATION
#define RKHashForStringAndCompileOption(string, option) (RK_EXPECTED(string == NULL, 0) ? option : (CFHash((CFTypeRef)string) ^ option))
#else // NextStep Foundation
#define RKHashForStringAndCompileOption(string, option) (RK_EXPECTED(string == NULL, 0) ? option : ([string hash] ^ option))
#endif //USE_CORE_FOUNDATION

#else

RKREGEX_STATIC_INLINE RKStringBuffer RKStringBufferWithString(NSString * const string) RK_ATTRIBUTES(nonnull(1), const);
RKREGEX_STATIC_INLINE NSString      *RKYesOrNo(const BOOL yesOrNo) RK_ATTRIBUTES(const);
RKREGEX_STATIC_INLINE unsigned int   RKHashForStringAndCompileOption(NSString * const string, const RKCompileOption option) RK_ATTRIBUTES(nonnull(1), pure);
RKREGEX_STATIC_INLINE RKStringBuffer RKMakeStringBuffer(NSString * const bufferString, const char * const stringBufferCharacters, const unsigned int stringBufferLength, const RKStringBufferEncoding stringBufferEncoding) RK_ATTRIBUTES(const);
RKREGEX_STATIC_INLINE BOOL           RKRangeInsideRange(const NSRange insideRange, const NSRange outsideRange) RK_ATTRIBUTES(const);

// Pretty NSString of BOOL, returns Yes or No NSString
RKREGEX_STATIC_INLINE NSString *RKYesOrNo(const BOOL yesOrNo) { return((yesOrNo == YES) ? @"Yes":@"No"); }

RKREGEX_STATIC_INLINE RKStringBuffer RKMakeStringBuffer(NSString * const bufferString, const char * const stringBufferCharacters, const unsigned int stringBufferLength, const RKStringBufferEncoding stringBufferEncoding) {
  RKStringBuffer stringBuffer;
  stringBuffer.string = bufferString;
  stringBuffer.characters = stringBufferCharacters;
  stringBuffer.length = stringBufferLength;
  stringBuffer.encoding = stringBufferEncoding;
  return(stringBuffer);
}


RKREGEX_STATIC_INLINE BOOL RKRangeInsideRange(const NSRange insideRange, const NSRange outsideRange) {
  return((NSLocationInRange(insideRange.location, outsideRange) == YES) && (((NSMaxRange(insideRange) - outsideRange.location) <= outsideRange.length) == YES));
}

RKREGEX_STATIC_INLINE unsigned int RKHashForStringAndCompileOption(NSString * const string, const RKCompileOption option) {
  if(RK_EXPECTED(string == NULL, 0)) { return(option); }
#ifdef USE_CORE_FOUNDATION
  return(CFHash((CFTypeRef)string) ^ option);
#else // NextStep Foundation
  return([string hash] ^ option);
#endif //USE_CORE_FOUNDATION
}

#endif

RKREGEX_STATIC_INLINE RKStringBuffer RKStringBufferWithString(NSString * const RK_C99(restrict) string) {
  RKStringBuffer stringBuffer = RKMakeStringBuffer(string, NULL, 0, 0);
  
#ifdef USE_CORE_FOUNDATION
  if(RK_EXPECTED(string != NULL, 1)) {
    stringBuffer.encoding = CFStringGetFastestEncoding((CFStringRef)string);
    
    if((stringBuffer.encoding == kCFStringEncodingMacRoman) || (stringBuffer.encoding == kCFStringEncodingASCII) || (stringBuffer.encoding == kCFStringEncodingUTF8)) {
      stringBuffer.characters = CFStringGetCStringPtr((CFStringRef)string, stringBuffer.encoding);
      stringBuffer.length = CFStringGetLength((CFStringRef)string);
    }
    if(RK_EXPECTED(stringBuffer.characters == NULL, 0)) {
      stringBuffer.characters = [string UTF8String];
      stringBuffer.encoding = kCFStringEncodingUTF8;
      if(RK_EXPECTED(stringBuffer.characters != NULL, 1)) { stringBuffer.length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]; }
      //NSLog(@"CF UTF8String conversion path. string = %p '%.40s' UTF8length = %u, original encoding: %d %@ length: %u", stringBuffer.characters, stringBuffer.characters, stringBuffer.length, cfStringEncoding, CFStringGetNameOfEncoding(cfStringEncoding), CFStringGetLength((CFStringRef)string));
    }
  }
#else // No Core Foundation, NextStep Foundation instead
  if(RK_EXPECTED(string != NULL, 1)) {
    stringBuffer.encoding = [string fastestEncoding];
    
    if((stringBuffer.encoding == NSMacOSRomanStringEncoding) || (stringBuffer.encoding == NSASCIIStringEncoding) || (stringBuffer.encoding == NSUTF8StringEncoding)) {
      stringBuffer.characters = [string cStringUsingEncoding:stringBuffer.encoding];
      stringBuffer.length = [string length];
    }
    if(RK_EXPECTED(stringBuffer.characters == NULL, 0)) {
      stringBuffer.characters = [string UTF8String];
      stringBuffer.encoding = NSUTF8StringEncoding;
      if(RK_EXPECTED(stringBuffer.characters != NULL, 1)) { stringBuffer.length = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]; }
      //NSLog(@"NS UTF8String conversion path. string = %p, '%.40s' UTF8length = %u, original encoding: %@ length: %u", stringBuffer.characters, stringBuffer.characters, stringBuffer.length, [NSString localizedNameOfStringEncoding:[string fastestEncoding]], [string length]);
    }
  }
#endif //USE_CORE_FOUNDATION
  return(stringBuffer);
}

typedef enum {
  RKCaptureExtractAllowConversions      = (1<<0),
  RKCaptureExtractStrictReference       = (1<<1),
  RKCaptureExtractIgnoreConversions     = (1<<2)
} RKCaptureExtractOptions;

NSString *RKStringFromReferenceString(id self, const SEL _cmd, RKRegex * const regex, const NSRange * const matchRanges, const RKStringBuffer * const matchStringBuffer, const RKStringBuffer * const referenceStringBuffer) RK_ATTRIBUTES(malloc, used, visibility("hidden"));
BOOL RKExtractCapturesFromMatchesWithKeyArguments(id self, const SEL _cmd, const RKStringBuffer * const stringBuffer, RKRegex * const regex, const NSRange * const matchRanges, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList) RK_ATTRIBUTES(used, visibility("hidden"));

unsigned int RKCaptureIndexForCaptureNameCharacters(RKRegex * const aRegex, const SEL _cmd, const char * const RK_C99(restrict) captureNameCharacters, const size_t length, const NSRange * const RK_C99(restrict) matchedRanges, const BOOL raiseExceptionOnDoesNotExist) RK_ATTRIBUTES(pure, used, visibility("hidden"));


@interface RKRegex (Private)

- (RKMatchErrorCode)getRanges:(NSRange * const RK_C99(restrict))ranges count:(const unsigned int)rangeCount withCharacters:(const void * const RK_C99(restrict))charactersBuffer length:(const unsigned int)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options;

@end


#ifdef RK_ENABLE_THREAD_LOCAL_STORAGE

/*************** Thread local data definitions ***************/

/*
 The following block contains the compile unit private definitions for implementing
 thread local data structures.  It is currently only used to create on demand a single
 NSNumberFormatter that is reused for all requested NSNumber conversions.  Apple
 documentation indicates that this object is not multithreading safe, so each thread
 gets its own NSNumberFormatter on demand.  Additionally, when the thread is exiting,
 __RKThreadIsExiting (static in RKRegex.m) gets called so we can do any clean up of allocations.
 
 RKRegex.m __attribute__((constructor)) registers our pthread key, __RKRegexThreadLocalDataKey and sets the thread exit clean up handler.
*/

extern pthread_key_t __RKRegexThreadLocalDataKey;

// Any additions here must add a deallocation section to RKRegex.m/__RKThreadIsExiting.
// Rough convention is to create a function that retrieves a specific item from the thread local data, demand populating the structure as required.


struct __RKThreadLocalData {
  NSNumberFormatter *_numberFormatter;
#ifdef HAVE_NSNUMBERFORMATTER_CONVERSIONS
  NSNumberFormatterStyle _currentFormatterStyle;
#endif
};

struct __RKThreadLocalData *__RKGetThreadLocalData(void) RK_ATTRIBUTES(pure);

#ifdef _USE_DEFINES
#define RKGetThreadLocalData() ({ struct __RKThreadLocalData * RK_C99(restrict) _tld = pthread_getspecific(__RKRegexThreadLocalDataKey); RK_EXPECTED((_tld != NULL), 1) ? _tld : __RKGetThreadLocalData(); })
#else
RKREGEX_STATIC_INLINE struct __RKThreadLocalData *RKGetThreadLocalData(void) RK_ATTRIBUTES(pure);
RKREGEX_STATIC_INLINE struct __RKThreadLocalData *RKGetThreadLocalData(void) {
  struct __RKThreadLocalData * RK_C99(restrict) tld = pthread_getspecific(__RKRegexThreadLocalDataKey);
  return(RK_EXPECTED((tld != NULL), 1) ? tld : __RKGetThreadLocalData());
}
#endif _USE_DEFINES

#ifdef HAVE_NSNUMBERFORMATTER_CONVERSIONS

NSNumberFormatter *__RKGetThreadLocalNumberFormatter(void) RK_ATTRIBUTES(pure, used);
#ifdef _USE_DEFINES
#define RKGetThreadLocalNumberFormatter() ({ struct __RKThreadLocalData * RK_C99(restrict) __tld = pthread_getspecific(__RKRegexThreadLocalDataKey); if(RK_EXPECTED(__tld == NULL, 0)) { __tld = __RKGetThreadLocalData(); } RK_EXPECTED((__tld == NULL), 0) ? NULL : RK_EXPECTED((__tld->_numberFormatter != NULL), 1) ? __tld->_numberFormatter : __RKGetThreadLocalNumberFormatter(); })
#else
RKREGEX_STATIC_INLINE NSNumberFormatter *RKGetThreadLocalNumberFormatter(void) RK_ATTRIBUTES(pure);
RKREGEX_STATIC_INLINE NSNumberFormatter *RKGetThreadLocalNumberFormatter(void) {
  struct __RKThreadLocalData * RK_C99(restrict) tld = NULL;
  if(RK_EXPECTED((tld = RKGetThreadLocalData()) == NULL, 0)) { return(NULL); }
  return(RK_EXPECTED((tld->_numberFormatter != NULL), 1) ? tld->_numberFormatter : __RKGetThreadLocalNumberFormatter());
}
#endif //_USE_DEFINES
#endif // HAVE_NSNUMBERFORMATTER_CONVERSIONS


/*************** End thread local data definitions ***************/
#endif //RK_ENABLE_THREAD_LOCAL_STORAGE

/*************** Match and replace operations ***************/

// Used in NSString to perform match and replace operations.  Kept here to keep things tidy.

#define RK_DEFAULT_STACK_INSTRUCTIONS (1024)

#define OP_STOP               0
#define OP_COPY_CAPTUREINDEX  1
#define OP_COPY_CAPTURENAME   2
#define OP_COPY_RANGE         3
#define OP_COMMENT            4


struct referenceInstruction {
  int op;
  const void * RK_C99(restrict) ptr;
  NSRange range;
};

struct copyInstruction {
  const void * RK_C99(restrict) ptr;
  size_t length;
};

typedef struct referenceInstruction RKReferenceInstruction;
typedef struct copyInstruction RKCopyInstruction;

struct referenceInstructionsBuffer {
  unsigned int length, capacity;
  RKReferenceInstruction * RK_C99(restrict) instructions;
  NSMutableData * RK_C99(restrict) mutableData;
  BOOL isValid;
};

struct copyInstructionsBuffer {
  unsigned int length, capacity;
  size_t copiedLength;
  RKCopyInstruction * RK_C99(restrict) instructions;
  NSMutableData * RK_C99(restrict) mutableData;
  BOOL isValid;
};

typedef struct referenceInstructionsBuffer RKReferenceInstructionsBuffer;
typedef struct copyInstructionsBuffer RKCopyInstructionsBuffer;

#ifdef _USE_DEFINES

#define RKMakeReferenceInstructionsBuffer(length, capacity, instructions, mutableData) ((RKReferenceInstructionsBuffer){length, capacity, instructions, mutableData, YES})
#define RKMakeCopyInstructionsBuffer(length, capacity, copiedLength, instructions, mutableData) ((RKCopyInstructionsBuffer){length, capacity, copiedLength, instructions, mutableData, YES})

#else
RKREGEX_STATIC_INLINE RKReferenceInstructionsBuffer RKMakeReferenceInstructionsBuffer(const unsigned int length, const unsigned int capacity, RKReferenceInstruction * const instructions, NSMutableData * const mutableData) {
  RKReferenceInstructionsBuffer instructionsBuffer;
  instructionsBuffer.length       = length;
  instructionsBuffer.capacity     = capacity;
  instructionsBuffer.instructions = instructions;
  instructionsBuffer.mutableData  = mutableData;
  instructionsBuffer.isValid      = YES;
  return(instructionsBuffer);
}

RKREGEX_STATIC_INLINE RKCopyInstructionsBuffer RKMakeCopyInstructionsBuffer(const unsigned int length, const unsigned int capacity, const size_t copiedLength, RKCopyInstruction * const instructions, NSMutableData *mutableData) {
  RKCopyInstructionsBuffer instructionsBuffer;
  instructionsBuffer.length       = length;
  instructionsBuffer.capacity     = capacity;
  instructionsBuffer.copiedLength = copiedLength;
  instructionsBuffer.instructions = instructions;
  instructionsBuffer.mutableData  = mutableData;
  instructionsBuffer.isValid      = YES;
  return(instructionsBuffer);
}
#endif

/*************** End match and replace operations ***************/


// These imports have dependencies on the platform configuration details

#import <RegexKit/RKAutoreleasedMemory.h>
#import <RegexKit/RKPlaceholder.h>
#import <RegexKit/RKCoder.h>

