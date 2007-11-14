//
//  multithreading.h
//  RegexKit
//

#import <Cocoa/Cocoa.h>
#import <Foundation/NSDebug.h>
#import <SenTestingKit/SenTestingKit.h>
#import <RegexKit/RegexKit.h>
#import <stdint.h>
#import <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <pthread.h>
#import "NSDate.h"

@interface multithreading : SenTestCase {
  BOOL isInitialized;

  pthread_mutex_t globalThreadLock;
  
  pthread_mutex_t globalThreadConditionLock;
  pthread_cond_t globalThreadCondition;

  pthread_mutex_t globalLogLock;
  NSMutableString *globalLogString;
  NSMutableArray *globalLogArray;
  
  pthread_mutex_t threadExitLock;
  unsigned int threadExitCount;
  
  unsigned int startAutoreleasedObjects;
  unsigned int iterations;
  
  RKCPUTime testStartCPUTime;
  RKCPUTime testEndCPUTime;
  RKCPUTime testElapsedCPUTime;
  
  NSMutableArray *timingResultsArray;
  
  NSTimer *loggingTimer;
  
  NSDateFormatter *logDateFormatter;
  
  NSString *debugEnvString;
  NSString *leakEnvString;
  NSString *timingEnvString;
  NSString *multithreadingEnvString;
}

- (int)threadEntry:(id)threadArgument;
- (void)flushLog;
- (void)thread:(int)threadID log:(NSString *)logString;

- (void)releaseResources;

- (BOOL)executeTest:(unsigned int)testNumber;

- (void)mt_cache_1;
- (void)mt_cache_2;
- (void)mt_cache_3;
- (void)mt_cache_4;
- (void)mt_cache_5;
- (void)mt_cache_6;

- (void)mt_test_1;
- (void)mt_test_2;
- (void)mt_test_3;
- (void)mt_test_4;
- (void)mt_test_5;
- (void)mt_test_6;
- (void)mt_test_7;
- (void)mt_test_8;
- (void)mt_test_9;
- (void)mt_test_10;
- (void)mt_test_11;
- (void)mt_test_12;
- (void)mt_test_13;
- (void)mt_test_14;
- (void)mt_test_15;
- (void)mt_test_16;
- (void)mt_test_17;
- (void)mt_test_18;
- (void)mt_test_19;
- (void)mt_test_20;
- (void)mt_test_21;
- (void)mt_test_22;
- (void)mt_test_23;
- (void)mt_test_24;
- (void)mt_test_25;
- (void)mt_test_26;
- (void)mt_test_27;


- (BOOL)mt_time_1;
- (BOOL)mt_time_2;
- (BOOL)mt_time_3;
- (BOOL)mt_time_4;
- (BOOL)mt_time_5;
- (BOOL)mt_time_6;
- (BOOL)mt_time_7;
- (BOOL)mt_time_8;
- (BOOL)mt_time_9;
- (BOOL)mt_time_10;
- (BOOL)mt_time_11;
- (BOOL)mt_time_12;


@end
