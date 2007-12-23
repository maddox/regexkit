//
//  RKLock.h
//  RegexKit
//  http://regexkit.sourceforge.net/
//
//  PRIVATE HEADER -- NOT in RegexKit.framework/Headers
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

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _REGEXKIT_RKLOCK_H_
#define _REGEXKIT_RKLOCK_H_ 1

#import <Foundation/Foundation.h>
#import <RegexKit/RegexKitPrivate.h>
#import <pthread.h>
#import <unistd.h>

#define RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS 2

@interface RKLock : NSObject <NSLocking> {
  pthread_mutex_t lock;
  RKUInteger      busyCount;
  RKUInteger      spinCount;
  RKUInteger      spuriousErrorsCount;
  BOOL            debuggingEnabled;
}

+ (void)setMultithreaded:(const BOOL)enable;

- (BOOL)lock;
- (void)unlock;

- (void)setDebug:(const BOOL)enable;
- (RKUInteger)busyCount;
- (RKUInteger)spinCount;
- (void)clearCounters;

@end

BOOL RKFastLock(  RKLock * const aLock) RK_ATTRIBUTES(nonnull(1), used, visibility("hidden"));
void RKFastUnlock(RKLock * const aLock) RK_ATTRIBUTES(nonnull(1), used, visibility("hidden"));

enum {
  RKLockDidNotLock                     = -1,
  RKLockForReading                     = 0,
  RKLockForWriting                     = 1,
  RKLockTryForReading                  = 2,
  RKLockTryForWriting                  = 3,
  RKLockTryForWritingThenForReading    = 4,
  RKLockTryForWritingThenTryForReading = 5
};

typedef RKInteger RKReadWriteLockStrategy;

@interface RKReadWriteLock : NSObject <NSLocking> {
  pthread_rwlock_t readWriteLock;
  RKUInteger       readBusyCount;
  RKUInteger       readSpinCount;
  RKUInteger       readDowngradedFromWriteCount;
  RKUInteger       writeBusyCount;
  RKUInteger       writeSpinCount;
  RKUInteger       spuriousErrorsCount;
  RKUInteger       writeLocked:1;
  RKUInteger       debuggingEnabled:1;
}

+ (void)setMultithreaded:(const BOOL)enable;

- (BOOL)lock;
- (BOOL)readLock;
- (BOOL)writeLock;
- (void)unlock;

- (void)setDebug:(const BOOL)enable;
- (RKUInteger)readBusyCount;
- (RKUInteger)readSpinCount;
- (RKUInteger)readDowngradedFromWriteCount;
- (RKUInteger)writeBusyCount;
- (RKUInteger)writeSpinCount;
- (void)clearCounters;

@end

BOOL RKFastReadWriteLockWithStrategy(RKReadWriteLock * const self, const RKReadWriteLockStrategy lockStrategy, RKReadWriteLockStrategy *lockLevelAcquired) RK_ATTRIBUTES(nonnull(1), used, visibility("hidden"));
BOOL RKFastReadWriteLock(  RKReadWriteLock * const aLock, const BOOL forWriting) RK_ATTRIBUTES(nonnull(1), used, visibility("hidden"));
void RKFastReadWriteUnlock(RKReadWriteLock * const aLock)                        RK_ATTRIBUTES(nonnull(1), used, visibility("hidden"));

#endif // _REGEXKIT_RKLOCK_H_

#ifdef __cplusplus
  }  /* extern "C" */
#endif
