//
//  RKThreadPool.m
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

#import <RegexKit/RKLock.h>
#import <RegexKit/RegexKitPrivate.h>
#import <RegexKit/RKThreadPool.h>
#import <stdlib.h>
#import <sys/sysctl.h>

// Used to provide lockBefore: NSDate timeIntervalSinceNow: time delays to locks.
// These are 1.0/prime, jobQueueDelays prime < 100, threadStartDelays > 100
// This is to help break up any inter-lock / scheduling synchronization modes.
// Many kernel scheduling methods tend to have a quantum that is % 100, so this stradles that heurestic.

static double jobQueueDelays[3]    = {0.0120481927710843, 0.0112359550561797, 0.0103092783505154};
static double threadStartDelays[5] = {0.0099009900990099, 0.0097087378640776, 0.0093457943925233, 0.0091743119266055, 0.0088495575221238};

@implementation RKThreadPool

- (id)init
{
  return([self initWithError:NULL]);
}

- (id)initWithError:(NSError **)outError
{
  if(outError != NULL) { *outError = NULL; }
  BOOL        outOfMemoryError = NO, unableToAllocateObjectError = NO;
  NSError    *initError        = NULL;
  RKUInteger  objectsCount     = 0;
  id         *objects          = NULL;
  
  if((self = [super init]) == NULL) { unableToAllocateObjectError = YES; goto errorExit; }
  RKAutorelease(self);
  
  unsigned int cpuCoresUInt;
  size_t cpuCoresUIntSize = sizeof(unsigned int);
  if(sysctlbyname("hw.ncpu", &cpuCoresUInt, &cpuCoresUIntSize, NULL, 0) != 0) { initError = [NSError rkErrorWithDomain:NSPOSIXErrorDomain code:errno localizeDescription:[NSString stringWithUTF8String:strerror(errno)]]; goto errorExit; }
  cpuCores = cpuCoresUInt;
  
  // For development testing, we always create extra threads. Normally, threads == cpuCores
  RKUInteger initThreadCount = cpuCores + 4;
  
  if((objects       = alloca(sizeof(id) * (initThreadCount * 3)))                      == NULL) { outOfMemoryError = YES; goto errorExit; }
  
  if((threads       = RKCallocScanned(   sizeof(NSThread *)        * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  if((locks         = RKCallocScanned(   sizeof(NSConditionLock *) * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  if((threadStatus  = RKCallocNotScanned(sizeof(unsigned char)     * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  if((lockStatus    = RKCallocNotScanned(sizeof(unsigned char)     * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  if((jobs          = RKCallocScanned(   sizeof(RKThreadPoolJob)   * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  if((threadQueue   = RKCallocScanned(   sizeof(RKThreadPoolJob *) * initThreadCount)) == NULL) { outOfMemoryError = YES; goto errorExit; }
  
  for(unsigned int atThread = 0; atThread < initThreadCount; atThread++) {
    if((locks[atThread]        = RKAutorelease([[NSConditionLock alloc] initWithCondition:RKThreadConditionStarting])) == NULL) { unableToAllocateObjectError = YES; goto errorExit; }
    objects[objectsCount++] = locks[atThread];

    if((jobs[atThread].jobLock = RKAutorelease([[NSConditionLock alloc] initWithCondition:RKJobConditionAvailable]))   == NULL) { unableToAllocateObjectError = YES; goto errorExit; }
    objects[objectsCount++] = jobs[atThread].jobLock;

    [NSThread detachNewThreadSelector:@selector(workerThreadStart:) toTarget:self withObject:[NSNumber numberWithUnsignedInt:atThread]];
    threadCount++;
  }
  
  objectsArray = [[NSArray alloc] initWithObjects:&objects[0] count:objectsCount];
  
  return(RKRetain(self));
  
errorExit:
  if((initError == NULL) && (unableToAllocateObjectError == YES))  { initError = [NSError rkErrorWithDomain:NSCocoaErrorDomain code:0 localizeDescription:@"Unable to allocate object."]; }
  if((initError == NULL) && (outOfMemoryError            == YES))  { initError = [NSError rkErrorWithDomain:NSPOSIXErrorDomain code:0 localizeDescription:@"Unable to allocate memory."]; }
  if((initError != NULL) && (outError                    != NULL)) { *outError = initError; }
  return(NULL);
}

- (void)reapThreads
{
  if(RKAtomicTestAndSetBarrier(RKThreadPoolReapingThreadsBit, &threadPoolControl) == 0) {
    RKAtomicTestAndSetBit(     RKThreadPoolStopBit,           &threadPoolControl);
    while(liveThreads != 0) { for(RKUInteger x = 0; x < threadCount; x++) { [self wakeThread:x]; RKThreadYield(); } }
    RKAtomicTestAndSetBit(     RKThreadPoolThreadsReapedBit,  &threadPoolControl);
  } else {
    while(liveThreads != 0) { RKThreadYield(); }
  }
}

- (void)dealloc
{
  [self reapThreads];
  NSParameterAssert(liveThreads == 0);
  
  if(objectsArray  != NULL) { RKRelease(objectsArray);      }

  if(threads       != NULL) { RKFreeAndNULL(threads);       }
  if(locks         != NULL) { RKFreeAndNULL(locks);         }
  if(threadStatus  != NULL) { RKFreeAndNULL(threadStatus);  }
  if(lockStatus    != NULL) { RKFreeAndNULL(lockStatus);    }

  if(jobs          != NULL) { RKFreeAndNULL(jobs);          }
  if(threadQueue   != NULL) { RKFreeAndNULL(threadQueue);   }
  
  [super dealloc];
}

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  [self reapThreads];
  NSParameterAssert(liveThreads == 0);
  
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

- (BOOL)wakeThread:(RKUInteger)threadNumber
{
  if(threadNumber > threadCount) { [[NSException rkException:NSInvalidArgumentException for:self selector:_cmd localizeReason:@"The threadNumber argument is greater than the total threads in the pool."] raise]; return(NO); }
  
  if([locks[threadNumber] condition]    == RKThreadConditionNotRunning) { return(NO); }
  
  [locks[threadNumber] lockWhenCondition:  RKThreadConditionSleeping];
  [locks[threadNumber] unlockWithCondition:RKThreadConditionWakeup];
  RKThreadYield();
  [locks[threadNumber] lockWhenCondition:  RKThreadConditionAwake];
  [locks[threadNumber] unlockWithCondition:RKThreadConditionRunningJob];
  
  return(YES);
}

- (BOOL)threadFunction:(int(*)(void *))function argument:(void *)argument
{ 
  // Single CPU fast case bypass removed to better excercise threading during development.
  //
  // if(cpuCores == 1) { function(argument); return(YES); }
  //
  RKUInteger startedJobThreads = 0, jobQueueDelayIndex = 0, threadStartDelayIndex = 0;
  
  RK_STRONG_REF RKThreadPoolJob *runJob = NULL;
  while((runJob == NULL) && ((threadPoolControl & RKThreadPoolStopMask) == 0)) {
    for(RKUInteger threadNumber = 0; threadNumber < threadCount; threadNumber++) {
      if([jobs[threadNumber].jobLock lockWhenCondition:RKJobConditionAvailable beforeDate:[NSDate dateWithTimeIntervalSinceNow:jobQueueDelays[jobQueueDelayIndex]]]) { runJob = &jobs[threadNumber]; break; }
    }
    jobQueueDelayIndex = (jobQueueDelayIndex < 3) ? (jobQueueDelayIndex + 1) : 0;
  }

  if(runJob == NULL) { NSLog(@"Odd, unable to acquire a job queue slot. Executing function in-line."); function(argument); return(YES); }

  NSParameterAssert(runJob->jobStatus          == 0);
  NSParameterAssert(runJob->activeThreadsCount == 0);
  NSParameterAssert(runJob->jobFunction        == NULL);
  NSParameterAssert(runJob->jobArgument        == NULL);

  runJob->jobStatus   = 0;
  runJob->jobFunction = function;
  runJob->jobArgument = argument;
  [runJob->jobLock unlockWithCondition:  RKJobConditionExecuting];

  while(([runJob->jobLock condition] == RKJobConditionExecuting) && (startedJobThreads < liveThreads) && ((threadPoolControl & RKThreadPoolStopMask) == 0)) {
    for(RKUInteger threadNumber = 0; ((threadNumber < threadCount) && ([runJob->jobLock condition] == RKJobConditionExecuting)); threadNumber++) {
      if([locks[threadNumber] lockWhenCondition: RKThreadConditionSleeping beforeDate:[NSDate dateWithTimeIntervalSinceNow:threadStartDelays[threadStartDelayIndex]]] == YES) {
        threadQueue[threadNumber] = runJob;
        [locks[threadNumber] unlockWithCondition:RKThreadConditionWakeup];
        [locks[threadNumber] lockWhenCondition:  RKThreadConditionAwake];
        [locks[threadNumber] unlockWithCondition:RKThreadConditionRunningJob];
        startedJobThreads++;
        if(startedJobThreads >= liveThreads) { break; }
      }
    }
    threadStartDelayIndex = (threadStartDelayIndex < 5) ? (threadStartDelayIndex + 1) : 0;
  }
  if([runJob->jobLock condition]  == RKJobConditionFinishing) { RKThreadYield(); }
  [runJob->jobLock lockWhenCondition:RKJobConditionCompleted];

  runJob->jobStatus   = 0;
  runJob->jobFunction = NULL;
  runJob->jobArgument = NULL;
  [runJob->jobLock unlockWithCondition:RKJobConditionAvailable];
  
  return(YES);
}

- (void)workerThreadStart:(id)startObject
{
                NSAutoreleasePool *topThreadPool = [[NSAutoreleasePool alloc] init], *loopThreadPool = NULL;
                unsigned int       threadNumber  = 0;
                NSThread          *thisThread    = NULL;
  RK_STRONG_REF RKThreadPoolJob   *currentJob    = NULL;
                NSConditionLock   *threadLock    = NULL;
  
  if(startObject == NULL) { goto exitThreadNow; }
  
  loopThreadPool        = [[NSAutoreleasePool alloc] init];
  threadNumber          = [startObject unsignedIntValue];
  thisThread            = [NSThread currentThread];
  threads[threadNumber] = thisThread;
  threadLock            = locks[threadNumber];
  
  RKAtomicIncrementIntegerBarrier(&liveThreads);
  
  if([threadLock tryLockWhenCondition:RKThreadConditionStarting] == NO) { NSLog(@"Unknown start up lock state, %ld.", (long)[threadLock condition]); goto exitThread; }

  [threadLock unlockWithCondition:RKThreadConditionSleeping];

  while((threadPoolControl & RKThreadPoolStopMask) == 0) {
    if(loopThreadPool == NULL) { loopThreadPool = [[NSAutoreleasePool alloc] init]; }
    
    [threadLock lockWhenCondition:RKThreadConditionWakeup];
    
    if((threadPoolControl & RKThreadPoolStopMask) != 0) { break; } // Check if we're exiting.
    
    if(threadQueue[threadNumber] != NULL) {
      do {
        if([threadQueue[threadNumber]->jobLock lockWhenCondition:RKJobConditionExecuting beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0078740157480314]]) {
          currentJob = threadQueue[threadNumber];
          RKAtomicIncrementIntegerBarrier(&currentJob->activeThreadsCount);
          [currentJob->jobLock unlockWithCondition:RKJobConditionExecuting];
          break;
        }
      } while([threadQueue[threadNumber]->jobLock condition] == RKJobConditionExecuting);

      threadQueue[threadNumber] = NULL;
    }
    
    [threadLock unlockWithCondition:RKThreadConditionAwake];
    
    // Do something
    
    if(currentJob != NULL) {
      currentJob->jobFunction(currentJob->jobArgument);
      if(RKAtomicTestAndSetBarrier(RKThreadPoolJobFinishedBit, &currentJob->jobStatus) == 0) {
        [currentJob->jobLock lockWhenCondition:  RKJobConditionExecuting];
        [currentJob->jobLock unlockWithCondition:RKJobConditionFinishing];
      }

      [currentJob->jobLock lockWhenCondition:RKJobConditionFinishing];

      RKInteger activeThreads = RKAtomicDecrementIntegerBarrier(&currentJob->activeThreadsCount);
      if(activeThreads == 0) { [currentJob->jobLock unlockWithCondition:RKJobConditionCompleted]; RKThreadYield(); }
      else                   { [currentJob->jobLock unlockWithCondition:RKJobConditionFinishing]; }

      currentJob = NULL;
    }
    
    [threadLock lockWhenCondition:  RKThreadConditionRunningJob];
    [threadLock unlockWithCondition:RKThreadConditionSleeping];
    RKThreadYield();
    
    if(loopThreadPool != NULL) { [loopThreadPool release]; loopThreadPool = NULL; }
  }
  
exitThread:
    
  if(currentJob != NULL) {
    do { if([currentJob->jobLock lockWhenCondition:RKJobConditionExecuting beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.0076335877862595]]) { break; } }
    while(  [currentJob->jobLock condition]        == RKJobConditionExecuting);
    
    if([currentJob->jobLock condition] != RKJobConditionExecuting) { [currentJob->jobLock lockWhenCondition:RKJobConditionFinishing]; }
    
    RKInteger activeThreads = RKAtomicDecrementIntegerBarrier(&currentJob->activeThreadsCount);
    if(activeThreads == 0) {
      if([currentJob->jobLock condition]      == RKJobConditionExecuting) {
        [currentJob->jobLock unlockWithCondition:RKJobConditionFinishing];
        [currentJob->jobLock lockWhenCondition:  RKJobConditionFinishing];
      }
      [currentJob->jobLock unlockWithCondition:  RKJobConditionCompleted];
    } else {
      if([currentJob->jobLock condition] == RKJobConditionExecuting) { [currentJob->jobLock unlockWithCondition:RKJobConditionExecuting]; }
      else { [currentJob->jobLock unlockWithCondition:RKJobConditionFinishing]; }
    }
    currentJob = NULL;
  }
  
  if([threadLock condition]        == RKThreadConditionWakeup) {
    [threadLock unlockWithCondition:  RKThreadConditionAwake];
    [threadLock lockWhenCondition:    RKThreadConditionRunningJob];
    [threadLock unlockWithCondition:  RKThreadConditionNotRunning];
  } else if([threadLock condition] == RKThreadConditionRunningJob) {
    [threadLock lockWhenCondition:    RKThreadConditionRunningJob];
    [threadLock unlockWithCondition:  RKThreadConditionNotRunning];
  }
  
  threads[threadNumber] = NULL;
  RKAtomicDecrementIntegerBarrier(&liveThreads);

exitThreadNow:
  if(loopThreadPool != NULL) { [loopThreadPool release]; loopThreadPool = NULL; }
  if(topThreadPool  != NULL) { [topThreadPool  release]; topThreadPool  = NULL; }
}

@end
