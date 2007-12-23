//
//  RKLock.m
//  RegexKit
//  http://regexkit.sourceforge.net/
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
 VERY IMPORTANT!!
 These locks use a fast single threaded bypass.  However, in order for lock / unlock semantics to be atomic in single and multithreaded cases, the following condition MUST be met:
 The users of the lock MUST NOT cause the application to become multithreaded while they own the lock!
 Guaranteeing this condition is trivial and results in a 10% - 20% speed improvement for the single threaded case.
*/

#import <RegexKit/RKLock.h>

static int globalIsMultiThreaded = 0;

static void releaseRKLockResources(     RKLock          * const self, SEL _cmd) RK_ATTRIBUTES(nonnull(1), used);
static void releaseRKReadWriteResources(RKReadWriteLock * const self, SEL _cmd) RK_ATTRIBUTES(nonnull(1), used);

@implementation RKLock

+ (void)setMultithreaded:(const BOOL)enable
{
  if(enable == YES) { globalIsMultiThreaded = YES; }
}

- (id)init
{
  int pthreadError = 0, initTryCount = 0, spuriousErrors = 0;
  pthread_mutexattr_t threadMutexAttribute;
  BOOL mutexAttributeInitialized = NO;

  if((self = [super init]) == NULL) { goto errorExit; }

  RKAutorelease(self);

  if((pthreadError = pthread_mutexattr_init(&threadMutexAttribute))                              != 0) { NSLog(@"pthread_mutexattr_init returned #%d, %s.",    pthreadError, strerror(pthreadError)); goto errorExit; }
  mutexAttributeInitialized = YES;
  if((pthreadError = pthread_mutexattr_settype(&threadMutexAttribute, PTHREAD_MUTEX_ERRORCHECK)) != 0) { NSLog(@"pthread_mutexattr_settype returned #%d, %s.", pthreadError, strerror(pthreadError)); goto errorExit; }

  lock = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
  
  while((pthreadError = pthread_mutex_init(&lock, &threadMutexAttribute)) != 0) {
    if(pthreadError == EAGAIN) {
      initTryCount++;
      if(initTryCount > 5) { NSLog(@"pthread_mutex_init returned EAGAIN 5 times, giving up."); goto errorExit; }
      RKThreadYield();
      continue;
    }
    if(pthreadError == EINVAL)  { NSLog(@"pthread_mutex_init returned EINVAL.");  goto errorExit; }
    if(pthreadError == EDEADLK) { NSLog(@"pthread_mutex_init returned EDEADLK."); goto errorExit; }
    if(pthreadError == ENOMEM)  { NSLog(@"pthread_mutex_init returned ENOMEM.");  goto errorExit; }
    
    if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
      spuriousErrors++;
      RKAtomicIncrementInteger(&spuriousErrorsCount);
      NSLog(@"pthread_mutex_init returned an unknown error code #%d, %s. This may be a spurious error, retry %d of %d.", pthreadError, strerror(pthreadError), spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
    } else {
      NSLog(@"pthread_mutex_init returned an unknown error code #%d, %s. Giving up after %d attempts.", pthreadError, strerror(pthreadError), RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
      goto errorExit;
    }
  }

  if(mutexAttributeInitialized == YES) {
    mutexAttributeInitialized = NO;
    if((pthreadError = pthread_mutexattr_destroy(&threadMutexAttribute)) != 0) { NSLog(@"pthread_mutexattr_destroy returned #%d, %s.", pthreadError, strerror(pthreadError)); goto errorExit; }
  }

  return(RKRetain(self));

errorExit:

  if(mutexAttributeInitialized == YES) {
    mutexAttributeInitialized = NO;
    if((pthreadError = pthread_mutexattr_destroy(&threadMutexAttribute)) != 0) { NSLog(@"pthread_mutexattr_destroy returned #%d, %s.", pthreadError, strerror(pthreadError)); goto errorExit; }
  }

  return(NULL);
}

- (void)dealloc
{
  releaseRKLockResources(self, _cmd);
  [super dealloc];
}

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  releaseRKLockResources(self, _cmd);
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

static void releaseRKLockResources(RKLock * const self, SEL _cmd RK_ATTRIBUTES(unused)) {
  int pthreadError = 0, destroyTryCount = 0;

  while((pthreadError = pthread_mutex_destroy(&self->lock)) != 0) {
    if(pthreadError == EBUSY) {
      usleep(50);
      destroyTryCount++;
      if(destroyTryCount > 100) { NSLog(@"pthread_mutex_destroy returned EAGAIN 100 times, giving up."); goto errorExit; }
      RKThreadYield();
      continue;
    }
    if(pthreadError == EINVAL)  { NSLog(@"pthread_mutex_destroy returned EINVAL.");  goto errorExit; }
  }

errorExit:
  return;
}

- (RKUInteger)hash
{
  return((RKUInteger)self);
}

- (BOOL)isEqual:(id)anObject
{
  if(self == anObject) { return(YES); } else { return(NO); }
}

- (BOOL)lock
{
  return(RKFastLock(self));
}

- (void)unlock
{
  RKFastUnlock(self);
}

- (void)setDebug:(const BOOL)enable
{
  debuggingEnabled = enable;
}

- (RKUInteger)busyCount
{
  return(busyCount);
}

- (RKUInteger)spinCount
{
  return(spinCount);
}

- (void)clearCounters
{
  busyCount = 0;
  spinCount = 0;
}

BOOL RKFastLock(RKLock * const self) {
  int pthreadError = 0, spuriousErrors = 0, spinCount = 0;
  NSString * RK_C99(restrict) functionString = @"pthread_mutex_trylock";
  BOOL didLock = NO;

  RK_PROBE(BEGINLOCK, self, 0, globalIsMultiThreaded);

  if(globalIsMultiThreaded == 0) {
    if(RK_EXPECTED([NSThread isMultiThreaded] == NO, 1)) { RK_PROBE(ENDLOCK, self, 0, globalIsMultiThreaded, 1, 0); return(YES); }
    RKAtomicCompareAndSwapInt(0, 1, &globalIsMultiThreaded);
  }

  if(RK_EXPECTED((pthreadError = pthread_mutex_trylock(&self->lock)) == 0, 1)) { return(YES); } // Fast exit on the common acquired lock case.
  
  switch(pthreadError) {
    case 0:                                               didLock = YES; goto exitNow; break; // Lock was acquired
    case EBUSY:  spinCount++; if(self->debuggingEnabled == YES) { self->busyCount++; } break; // Do nothing, we need to wait on the lock, which we do after the switch
    case EINVAL: NSLog(@"%@ returned EINVAL.", functionString);          goto exitNow; break; // XXX Hopeless?
    default:
      if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
        spuriousErrors++;
        RKAtomicIncrementInteger(&self->spuriousErrorsCount);
        NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
      } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
      break;
  }
  
  functionString = (self->debuggingEnabled == YES) ? @"pthread_mutex_trylock":@"pthread_mutex_lock";
  
  do {
    if(self->debuggingEnabled == YES) { pthreadError = pthread_mutex_trylock(&self->lock); } else { pthreadError = pthread_mutex_lock(&self->lock); }
      
    switch(pthreadError) {
      case 0:                                                                                    didLock = YES; goto exitNow; break; // Lock was acquired
      case EBUSY:   spinCount++; if(self->debuggingEnabled == YES) { self->spinCount++; }                    RKThreadYield(); break; // Yield and then try again
      case EINVAL:  NSLog(@"%@ returned EINVAL after a trylock succeeded without any error.", functionString);  goto exitNow; break; // XXX Hopeless?
      case EDEADLK: NSLog(@"%@ returned EDEADLK after a trylock succeeded without any error.", functionString); goto exitNow; break; // XXX Hopeless?
      default:
        if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
          spuriousErrors++;
          RKAtomicIncrementInteger(&self->spuriousErrorsCount);
          NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
        } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
        break;
    }    
  } while(pthreadError != 0);

exitNow:
  RK_PROBE(ENDLOCK, self, 0, globalIsMultiThreaded, didLock, spinCount); 
  return(didLock);
}

void RKFastUnlock(RKLock * const self) {
  int pthreadError = 0;
  
  RK_PROBE(UNLOCK, self, 0, globalIsMultiThreaded); 

  if(globalIsMultiThreaded == 0) { return; }
  if(RK_EXPECTED((pthreadError = pthread_mutex_unlock(&self->lock)) != 0, 0)) {
    if(pthreadError == EINVAL) { NSLog(@"pthread_mutex_unlock returned EINVAL.");           return; }
    if(pthreadError == EPERM)  { NSLog(@"pthread_mutex_unlock returned EPERM, not owner? Current thread: %@, main thread? %@", [NSThread currentThread], RKYesOrNo([NSThread isMainThread])); sleep(10); return; }
  }
}

@end

@implementation RKReadWriteLock

+ (void)setMultithreaded:(const BOOL)enable
{
  if(enable == YES) { globalIsMultiThreaded = YES; }
}

- (id)init
{
  RKAutorelease(self);
  
  if((self = [super init]) == NULL) { goto errorExit; }
  
  int pthreadError = 0, initTryCount = 0, spuriousErrors = 0;

  readWriteLock = (pthread_rwlock_t)PTHREAD_RWLOCK_INITIALIZER;
  
  while((pthreadError = pthread_rwlock_init(&readWriteLock, NULL)) != 0) {
    if(pthreadError == EAGAIN) {
      initTryCount++;
      if(initTryCount > 5) { NSLog(@"pthread_rwlock_init returned EAGAIN 5 times, giving up."); goto errorExit; }
      RKThreadYield();
      continue;
    }
    if(pthreadError == EINVAL)  { NSLog(@"pthread_rwlock_init returned EINVAL.");  goto errorExit; }
    if(pthreadError == EDEADLK) { NSLog(@"pthread_rwlock_init returned EDEADLK."); goto errorExit; }
    if(pthreadError == ENOMEM)  { NSLog(@"pthread_rwlock_init returned ENOMEM.");  goto errorExit; }
    
    if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
      spuriousErrors++;
      RKAtomicIncrementInteger(&spuriousErrorsCount);
      NSLog(@"pthread_rwlock_init returned an unknown error code %d. This may be a spurious error, retry %d of %d.", pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
    } else { NSLog(@"pthread_rwlock_init returned an unknown error code %d. Giving up after %d attempts.", pthreadError, spuriousErrors); goto errorExit; }
  }
  
  return(RKRetain(self));
  
errorExit:
    return(NULL);
}

- (void)dealloc
{
  releaseRKReadWriteResources(self, _cmd);
  [super dealloc];
}

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  releaseRKReadWriteResources(self, _cmd);
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

static void releaseRKReadWriteResources(RKReadWriteLock * const self, SEL _cmd RK_ATTRIBUTES(unused)) {
  int pthreadError = 0, destroyTryCount = 0;
  
  while((pthreadError = pthread_rwlock_destroy(&self->readWriteLock)) != 0) {
    if(pthreadError == EBUSY) {
      usleep(50);
      destroyTryCount++;
      if(destroyTryCount > 100) { NSLog(@"pthread_rwlock_destroy returned EAGAIN 100 times, giving up."); goto errorExit; }
      RKThreadYield();
      continue;
    }
    if(pthreadError == EPERM)  { NSLog(@"pthread_rwlock_destroy returned EPERM.");  goto errorExit; }
    if(pthreadError == EINVAL) { NSLog(@"pthread_rwlock_destroy returned EINVAL."); goto errorExit; }
  }
  
errorExit:
  return;
}

- (RKUInteger)hash
{
  return((RKUInteger)self);
}

- (BOOL)isEqual:(id)anObject
{
  if(self == anObject) { return(YES); } else { return(NO); }
}

- (BOOL)lock
{
  return(RKFastReadWriteLockWithStrategy(self, RKLockForWriting, NULL)); // Be conservative and assume a write lock
}

- (BOOL)readLock
{
  return(RKFastReadWriteLockWithStrategy(self, RKLockForReading, NULL));
}

- (BOOL)writeLock
{
  return(RKFastReadWriteLock(self, YES));
}

- (void)unlock
{
  RKFastReadWriteUnlock(self);
}

- (void)setDebug:(const BOOL)enable
{
  debuggingEnabled = enable;
}

- (RKUInteger)readBusyCount
{
  return(readBusyCount);
}

- (RKUInteger)readSpinCount
{
  return(readSpinCount);
}

- (RKUInteger)readDowngradedFromWriteCount
{
  return(readDowngradedFromWriteCount);
}

- (RKUInteger)writeBusyCount
{
  return(writeBusyCount);
}

- (RKUInteger)writeSpinCount
{
  return(writeSpinCount);
}

- (void)clearCounters
{
  readBusyCount = 0;
  readSpinCount = 0;
  readDowngradedFromWriteCount = 0;
  writeBusyCount = 0;
  writeSpinCount = 0;
}

BOOL RKFastReadWriteLock(RKReadWriteLock * const self, const BOOL forWriting) {
  return(RKFastReadWriteLockWithStrategy(self, (forWriting == NO) ? RKLockForReading : RKLockForWriting, NULL));
}

BOOL RKFastReadWriteLockWithStrategy(RKReadWriteLock * const self, const RKReadWriteLockStrategy lockStrategy, RKReadWriteLockStrategy *lockLevelAcquired) {
  int pthreadError = 0, spuriousErrors = 0, spinCount = 0;
  NSString * RK_C99(restrict) functionString = NULL;
  BOOL didLock = NO, forWriting = ((lockStrategy == RKLockForReading) || (lockStrategy == RKLockTryForReading)) ? NO : YES;

  RK_PROBE(BEGINLOCK, self, lockStrategy, globalIsMultiThreaded); 

  if(globalIsMultiThreaded == 0) {
    if(RK_EXPECTED([NSThread isMultiThreaded] == NO, 1)) { self->writeLocked = forWriting; RK_PROBE(ENDLOCK, self, forWriting, 0, 1, 0); if(lockLevelAcquired) { *lockLevelAcquired = forWriting; } return(YES); }
    RKAtomicCompareAndSwapInt(0, 1, &globalIsMultiThreaded);
  }

  if(RK_EXPECTED(lockStrategy == RKLockTryForWritingThenForReading, 0)) {
    if(RK_EXPECTED((pthreadError = pthread_rwlock_trywrlock(&self->readWriteLock)) == 0, 1)) { // Fast exit on the common acquired lock case.
      self->writeLocked = forWriting;
      RK_PROBE(ENDLOCK, self, forWriting, globalIsMultiThreaded, 1, spinCount);
      if(lockLevelAcquired) { *lockLevelAcquired = RKLockForWriting; }
      return(YES);
    }
    forWriting = NO; // Unable to acquire a write level lock, downgrade and acquire a read level lock.
  }
  
  if(RK_EXPECTED(forWriting == YES, 0)) {
    functionString = @"pthread_rwlock_trywrlock";
    if(RK_EXPECTED((pthreadError = pthread_rwlock_trywrlock(&self->readWriteLock)) == 0, 1)) { self->writeLocked = forWriting; RK_PROBE(ENDLOCK, self, forWriting, globalIsMultiThreaded, 1, spinCount); if(lockLevelAcquired) { *lockLevelAcquired = RKLockForWriting; } return(YES); } // Fast exit on the common acquired lock case.

    switch(pthreadError) {
      case 0:                                                      didLock = YES; goto exitNow; break; // Lock was acquired
      case EAGAIN:                                                                                     // drop through
      case EBUSY:   spinCount++; if(self->debuggingEnabled == YES) { self->writeBusyCount++; }  break; // Do nothing, we need to wait on the lock, which we do after the switch
      case EDEADLK: NSLog(@"%@ returned EDEADLK.", functionString);               goto exitNow; break; // XXX Hopeless?
      case ENOMEM:  NSLog(@"%@ returned ENOMEM.", functionString);                goto exitNow; break; // XXX Hopeless?
      case EINVAL:  NSLog(@"%@ returned EINVAL.", functionString);                goto exitNow; break; // XXX Hopeless?
      default:
        if((spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) || (lockStrategy == RKLockTryForWriting)) {
          spuriousErrors++;
          RKAtomicIncrementInteger(&self->spuriousErrorsCount);
          NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
        } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
        break;
    }

    if(lockStrategy == RKLockTryForWriting) { goto exitNow; }
    functionString = @"pthread_rwlock_wrlock";
    
    do {
      pthreadError = pthread_rwlock_wrlock(&self->readWriteLock);  // Don't trylock, allow write lock request to block reads for priority access
      
      switch(pthreadError) {
        case 0:                                                                                    didLock = YES; goto exitNow; break; // Lock was acquired
        case EAGAIN:                                                                                                                   // drop through
        case EBUSY:   spinCount++; if(self->debuggingEnabled == YES) { self->writeSpinCount++; }               RKThreadYield(); break; // This normally shouldn't happen.
        case EINVAL:  NSLog(@"%@ returned EINVAL after a trylock succeeded without any error.",  functionString); goto exitNow; break; // XXX Hopeless?
        case EDEADLK: NSLog(@"%@ returned EDEADLK after a trylock succeeded without any error.", functionString); goto exitNow; break; // XXX Hopeless?
        case ENOMEM:  NSLog(@"%@ returned ENOMEM after a trylock succeeded without any error.",  functionString); goto exitNow; break; // XXX Hopeless?
        default:
          if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
            spuriousErrors++;
            RKAtomicIncrementInteger(&self->spuriousErrorsCount);
            NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
          } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
          break;
      }    
    } while(pthreadError != 0);
    
  } else { // forWriting == NO
    if(RK_EXPECTED((pthreadError = pthread_rwlock_tryrdlock(&self->readWriteLock)) == 0, 1)) { self->writeLocked = forWriting; RK_PROBE(ENDLOCK, self, forWriting, globalIsMultiThreaded, 1, spinCount); if(lockLevelAcquired) { *lockLevelAcquired = RKLockForReading; } return(YES); } // Fast exit on the common acquired lock case.
    functionString = @"pthread_rwlock_tryrdlock";
    
    switch(pthreadError) {
      case 0:                                                    didLock = YES; goto exitNow; break; // Lock was acquired
      case EAGAIN:                                                                                   // drop through
      case EBUSY:   spinCount++; if(self->debuggingEnabled == YES) { self->readBusyCount++; } break; // Do nothing, we need to wait on the lock, which we do after the switch
      case EDEADLK: NSLog(@"%@ returned EDEADLK.", functionString);             goto exitNow; break; // XXX Hopeless?
      case ENOMEM:  NSLog(@"%@ returned ENOMEM.", functionString);              goto exitNow; break; // XXX Hopeless?
      case EINVAL:  NSLog(@"%@ returned EINVAL.", functionString);              goto exitNow; break; // XXX Hopeless?
      default:
        if((spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) || (lockStrategy == RKLockTryForReading)){
          spuriousErrors++;
          RKAtomicIncrementInteger(&self->spuriousErrorsCount);
          NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
        } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
        break;
    }
    
    if(lockStrategy == RKLockTryForReading) { goto exitNow; }
    functionString = (self->debuggingEnabled == YES) ? @"pthread_rwlock_tryrdlock":@"pthread_rwlock_rdlock";
    
    do {
      if(self->debuggingEnabled == YES) { pthreadError = pthread_rwlock_tryrdlock(&self->readWriteLock); } else { pthreadError = pthread_rwlock_rdlock(&self->readWriteLock); }
      
      switch(pthreadError) {
        case 0:                                                                                    didLock = YES; goto exitNow; break; // Lock was acquired
        case EAGAIN:                                                                                                                   // drop through
        case EBUSY:   spinCount++; if(self->debuggingEnabled == YES) { self->readSpinCount++; }                RKThreadYield(); break; // Yield and then try again
        case EINVAL:  NSLog(@"%@ returned EINVAL after a trylock succeeded without any error.",  functionString); goto exitNow; break; // XXX Hopeless?
        case EDEADLK: NSLog(@"%@ returned EDEADLK after a trylock succeeded without any error.", functionString); goto exitNow; break; // XXX Hopeless?
        case ENOMEM:  NSLog(@"%@ returned ENOMEM after a trylock succeeded without any error.",  functionString); goto exitNow; break; // XXX Hopeless?
        default:
          if(spuriousErrors < RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS) {
            spuriousErrors++;
            RKAtomicIncrementInteger(&self->spuriousErrorsCount);
            NSLog(@"%@ returned an unknown error code %d. This may be a spurious error, retry %d of %d.", functionString, pthreadError, spuriousErrors, RKLOCK_MAX_SPURIOUS_ERROR_ATTEMPTS);
          } else { NSLog(@"%@ returned an unknown error code %d. Giving up after %d attempts.", functionString, pthreadError, spuriousErrors); goto exitNow; }
          break;
      }    
    } while(pthreadError != 0);
  }
  
exitNow:
  if(didLock == YES) { self->writeLocked = forWriting; }
  RK_PROBE(ENDLOCK, self, forWriting, globalIsMultiThreaded, didLock, spinCount);
  if(lockLevelAcquired) { if(didLock == YES) { *lockLevelAcquired = forWriting; } else { *lockLevelAcquired = RKLockDidNotLock; } }
  return(didLock);
}

void RKFastReadWriteUnlock(RKReadWriteLock * const self) {
  int pthreadError = 0;

  RK_PROBE(UNLOCK, self, self->writeLocked, globalIsMultiThreaded); 
  
  if(globalIsMultiThreaded == 0) { return; }
  if(RK_EXPECTED((pthreadError = pthread_rwlock_unlock(&self->readWriteLock)) != 0, 0)) {
    if(pthreadError == EINVAL) { NSLog(@"pthread_mutex_unlock returned EINVAL.");           return; }
    if(pthreadError == EPERM)  { NSLog(@"pthread_mutex_unlock returned EPERM, not owner?"); return; }
  }
}

@end
