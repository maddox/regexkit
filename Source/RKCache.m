//
//  RKCache.m
//  RegexKit
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
 This object uses locks to enforce cache consistency.
 
 Code that is acquires and releases the lock are surrounded with the comment pair
 
 // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv

 // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^

 as a visual reminder that code within the comments is sensitive to lock based programming problems.
*/

#import <RegexKit/RKCache.h>
#import <RegexKit/RegexKitPrivate.h>
// Not placed in RKCache.h because that's a public include which would require RKLock.h to be public, but it's only used internally.
#import <RegexKit/RKLock.h>

@implementation RKCache

#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION

// This creates the support objects that we'll need if garbage collection is found to be enabled at run time.
// If GC is enabled (RKRegexGarbageCollect == 1) then the following is used to create a Mac OS X 10.5
// NSHashMap object that uses NSPointerFunctionsZeroingWeakMemory, or in other words the GC system will
// automatically remove a cached RKRegex object when it falls out of scope and is no longer reachable.
// This means the cache is automatically trimmed to the working set.  The new class NSPointerFunctions
// are used to perform the typicaly isEqual/Hash comparision primitives.  Since we use the computer
// NSUInteger hash for a given regex for the map key, we don't need to store objects per se, so our
// overhead is very low.  Unfortunatly, a pre-fabbed NSUInteger key based NSHashMap is not provided,
// unlike it's predecesor (which we use if GC is not enabled).
//
// We use some clever preprocessor macros to selectively include the enhanced garbage collection
// functionality while keeping

static               int32_t             RKCacheLoadInitialized             = 0;
static RK_STRONG_REF NSPointerFunctions *RKCacheIntegerKeyPointerFunctions  = NULL;
static RK_STRONG_REF NSPointerFunctions *RKCacheObjectValuePointerFunctions = NULL;

void       *intPointerFunctionsAcquire(const void *src, NSUInteger (*size)(const void *item) RK_ATTRIBUTES(unused), BOOL shouldCopy RK_ATTRIBUTES(unused)) { return((void *)src); }
NSString   *intPointerFunctionsDescription(const void *item) { return([NSString stringWithFormat:@"%lu", (unsigned long)item]); }
RKUInteger  intPointerFunctionsHash(const void *item, NSUInteger (*size)(const void *item) RK_ATTRIBUTES(unused)) { return((RKUInteger)item); }
BOOL        intPointerFunctionsIsEqual(const void *item1, const void*item2, NSUInteger (*size)(const void *item) RK_ATTRIBUTES(unused)) { return(item1 == item2); }
void        intPointerFunctionsRelinquish(const void *item RK_ATTRIBUTES(unused), NSUInteger (*size)(const void *item) RK_ATTRIBUTES(unused)) { return; }
RKUInteger  intPointerFunctionsSize(const void *item RK_ATTRIBUTES(unused)) { return(sizeof(RKUInteger)); }

+ (void)load
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(RKCacheLoadInitialized == 1) { return; }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &RKCacheLoadInitialized)) {
    id garbageCollector = objc_getClass("NSGarbageCollector");
    
    if(garbageCollector != NULL) {
      if([garbageCollector defaultCollector] != NULL) {
        id pointerFunctions = objc_getClass("NSPointerFunctions");

        RKCacheIntegerKeyPointerFunctions = [pointerFunctions pointerFunctionsWithOptions:NSPointerFunctionsIntegerPersonality];
        RKCacheIntegerKeyPointerFunctions.acquireFunction     = intPointerFunctionsAcquire;
        RKCacheIntegerKeyPointerFunctions.descriptionFunction = intPointerFunctionsDescription;
        RKCacheIntegerKeyPointerFunctions.hashFunction        = intPointerFunctionsHash;
        RKCacheIntegerKeyPointerFunctions.isEqualFunction     = intPointerFunctionsIsEqual;
        RKCacheIntegerKeyPointerFunctions.relinquishFunction  = intPointerFunctionsRelinquish;
        RKCacheIntegerKeyPointerFunctions.sizeFunction        = intPointerFunctionsSize;
        
        RKCacheObjectValuePointerFunctions = [pointerFunctions pointerFunctionsWithOptions:(NSPointerFunctionsZeroingWeakMemory | NSPointerFunctionsObjectPersonality)];
        
        [[garbageCollector defaultCollector] disableCollectorForPointer:RKCacheIntegerKeyPointerFunctions];
        [[garbageCollector defaultCollector] disableCollectorForPointer:RKCacheObjectValuePointerFunctions];
      }
    }
  }
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

- (id)init
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(cacheInitialized == 1) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"This cache is already initialized.") userInfo:NULL] raise]; }
  
  if((self = [super init]) == NULL) { goto errorExit; }

  RKAutorelease(self);
  
  if((cacheMapKeyCallBacks = dlsym(RTLD_DEFAULT, "NSIntegerMapKeyCallBacks")) == NULL) { cacheMapKeyCallBacks = dlsym(RTLD_DEFAULT, "NSIntMapKeyCallBacks"); }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &cacheInitialized)) {
    if((cacheRWLock = [[RKReadWriteLock alloc] init]) == NULL) { NSLog(@"Unable to initialize cache lock, caching is disabled."); goto errorExit; }
    else {
      if([self clearCache] == NO) { NSLog(@"Unable to create cache hash map."); goto errorExit; }
      cacheClearedCount = 0;
      cacheAddingIsEnabled = cacheLookupIsEnabled = cacheIsEnabled = YES;
    }
  }
  
  return(RKRetain(self));
  
errorExit:
  return(NULL);
}

- (id)initWithDescription:(NSString * const)descriptionString
{
  if((self = [self init]) == NULL) { return(NULL); }
  [self setDescription:descriptionString];
  return(self);
}

- (void)setDescription:(NSString * const)descriptionString
{
  if(cacheDescriptionString != NULL) { RKAutorelease(cacheDescriptionString); cacheDescriptionString = NULL; }
  if(descriptionString      != NULL) { cacheDescriptionString = RKRetain(descriptionString);                 }
}

- (void)dealloc
{
  if(cacheRWLock)            { RKFastReadWriteLock(cacheRWLock, YES); RKRelease(cacheRWLock);    cacheRWLock            = NULL; }
  if(cacheMapTable)          { if(RKRegexGarbageCollect == 0) { NSFreeMapTable(cacheMapTable); } cacheMapTable          = NULL; }
  if(cacheDescriptionString) { RKRelease(cacheDescriptionString);                                cacheDescriptionString = NULL; }
  
  [super dealloc];
}

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  if(cacheMapTable)          { if(RKRegexGarbageCollect == 0) { NSFreeMapTable(cacheMapTable); } cacheMapTable          = NULL; }
  
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

- (RKUInteger)hash
{
  return((RKUInteger)self);
}

- (BOOL)isEqual:(id)anObject
{
  if(self == anObject) { return(YES); } else { return(NO); }
}

- (BOOL)clearCache
{
  RK_STRONG_REF NSMapTable * RK_C99(restrict) newMapTable = NULL, * RK_C99(restrict) oldMapTable = NULL;
  BOOL didClearCache = NO;
  
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
  if(RKRegexGarbageCollect == 1) {
    if((newMapTable = [[objc_getClass("NSMapTable") alloc] initWithKeyPointerFunctions:RKCacheIntegerKeyPointerFunctions valuePointerFunctions:RKCacheObjectValuePointerFunctions capacity:256]) == NULL) { goto exitNow; }
  } else
#endif
  { if(RK_EXPECTED((newMapTable = NSCreateMapTable(*cacheMapKeyCallBacks, NSObjectMapValueCallBacks, 256)) == NULL, 0)) { goto exitNow; } }
  
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, YES) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  if(RK_EXPECTED((cacheMapTable != NULL), 1)) { oldMapTable = cacheMapTable; } 
  cacheMapTable = newMapTable;
  newMapTable = NULL;
  RKAtomicIncrementInt((int *)&cacheClearedCount);
  cacheHits = 0;
  cacheMisses = 0;
  didClearCache = YES;
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
exitNow:
  if(RKRegexGarbageCollect == 0) {
    if(newMapTable != NULL) { NSFreeMapTable(newMapTable); newMapTable = NULL; }
    if(oldMapTable != NULL) { NSFreeMapTable(oldMapTable); oldMapTable = NULL; }
  }
  
  return(didClearCache);
}

- (NSString *)status
{
  double cacheLookups = (((double)cacheHits) + (double)cacheMisses);
  if(cacheLookups == 0.0) { cacheLookups = 1.0; }
  char *GCStatus = "";
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
  GCStatus = (RKRegexGarbageCollect == 0) ? ", GC Active = No" : ", GC Active = Yes";
#endif
  return([NSString stringWithFormat:@"Enabled = %@ (Add: %@, Lookup: %@), Cleared count = %lu, Cache count = %lu, Hit rate = %6.2lf%%, Hits = %lu, Misses = %lu, Total = %.0lf%s", RKYesOrNo(cacheIsEnabled), RKYesOrNo(cacheAddingIsEnabled), RKYesOrNo(cacheLookupIsEnabled), (long)[self cacheClearedCount], (long)[self cacheCount], (((double)cacheHits) / cacheLookups) * 100.0, (long)cacheHits, (long)cacheMisses, (((double)cacheHits) + (double)cacheMisses), GCStatus]);
}

- (NSString *)description
{
  return([NSString stringWithFormat:@"<%@: %p>%s%@%s %@", [self className], self, (cacheDescriptionString != NULL) ? " \"":"", (cacheDescriptionString != NULL) ? cacheDescriptionString : (NSString *)@"", (cacheDescriptionString != NULL) ? "\"":"", [self status]]);
}

- (id)objectForHash:(const RKUInteger)objectHash
{
  return(RKFastCacheLookup(self, _cmd, objectHash, YES));
}

- (id)objectForHash:(const RKUInteger)objectHash autorelease:(const BOOL)shouldAutorelease
{
  return(RKFastCacheLookup(self, _cmd, objectHash, shouldAutorelease));
}

id RKFastCacheLookup(RKCache * const aCache, const SEL _cmd RK_ATTRIBUTES(unused), const RKUInteger objectHash, const BOOL shouldAutorelease) {
  if(RK_EXPECTED(aCache == NULL, 0)) { return(NULL); }
  RK_STRONG_REF RKCache *self = aCache;
  
  RK_STRONG_REF id returnObject = NULL;
  
  if(RK_EXPECTED(RKFastReadWriteLock(self->cacheRWLock, NO) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  if(RK_EXPECTED((self->cacheIsEnabled == YES), 1) && RK_EXPECTED((self->cacheLookupIsEnabled == YES), 1)) {
    if(RK_EXPECTED(self->cacheMapTable != NULL, 1)) {
      // If we get a hit, do a retain on the object so it will be within our current autorelease scope.  Once we unlock, the map table could vanish, taking
      // the returned object with it.  This way we ensure it stays around.  Convenience methods handle autoreleasing.
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
      if(RKRegexGarbageCollect == 1) { returnObject = [self->cacheMapTable objectForKey:(id)objectHash]; } else
#endif
      { if((returnObject = NSMapGet(self->cacheMapTable, (const void *)objectHash)) != NULL) { [returnObject retain]; } }
    }
  }
  
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(self->cacheRWLock);
  
exitNow:
  if(returnObject != NULL) {
    self->cacheHits++;
    if(RK_EXPECTED(shouldAutorelease == YES, 1)) { RKAutorelease(returnObject); }
  } else { self->cacheMisses++; }

  return(returnObject);
}


- (BOOL)addObjectToCache:(id)object
{
  return([self addObjectToCache:object withHash:[object hash]]);
}

- (BOOL)addObjectToCache:(id)object withHash:(const RKUInteger)objectHash
{
  BOOL didCache = NO;
  
  if(object == NULL) { goto exitNow; }
  
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, YES) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  if(RK_EXPECTED((cacheAddingIsEnabled == YES), 1) && RK_EXPECTED((cacheIsEnabled == YES), 1)) {
    if(RK_EXPECTED(cacheMapTable != NULL, 1)) {
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
      if(RK_EXPECTED(RKRegexGarbageCollect == 1, 0)) { [cacheMapTable setObject:object forKey:(id)objectHash]; } else
#endif
      { if(NSMapInsertIfAbsent(cacheMapTable, (const void *)objectHash, object) == NULL) { didCache = YES; } }
    }
  }
  
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
exitNow:
  return(didCache);
}

- (id)removeObjectFromCache:(id)object
{
  return([self removeObjectWithHash:[object hash]]);
}

- (id)removeObjectWithHash:(const RKUInteger)objectHash
{
  void **cachedKey = NULL, RK_STRONG_REF **cachedObject = NULL;
  
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, YES) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  if(RK_EXPECTED(cacheMapTable != NULL, 1)) {
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
    if(RK_EXPECTED(RKRegexGarbageCollect == 1, 0)) { cachedObject = (void **)[cacheMapTable objectForKey:(id)objectHash]; if(cachedObject != NULL) { [cacheMapTable removeObjectForKey:(id)objectHash]; } } else
#endif
    { if(NSMapMember(cacheMapTable, (const void *)objectHash, (void **)&cachedKey, (void **)&cachedObject) == YES) { [(id)cachedObject retain]; NSMapRemove(cacheMapTable, (const void *)objectHash); }
    }
  }
  
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
  if(cachedObject != NULL) { RKAutorelease((id)cachedObject); }
  
exitNow:
  return((id)cachedObject);
}

- (NSSet *)cacheSet
{  

#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
  if(RKRegexGarbageCollect == 1) {
    NSMutableSet *currentCacheSet = [NSMutableSet set];
    if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, NO) == NO, 0)) { return(NULL); } // Did not acquire lock for some reason
    id cachedObject = NULL;
    NSEnumerator *cacheMapTableEnumerator = [cacheMapTable objectEnumerator];
    while((cachedObject = [cacheMapTableEnumerator nextObject]) != NULL) { [currentCacheSet addObject:cachedObject]; }
    RKFastReadWriteUnlock(cacheRWLock);
    return([NSSet setWithSet:currentCacheSet]);
  }
#endif

  RKUInteger atCachedObject = 0, retrievedCount = 0, cacheCount = 0;
  NSMapEnumerator cacheMapTableEnumerator;
  BOOL retrievedObjects = NO;
  RK_STRONG_REF NSSet * RK_C99(restrict) returnSet = NULL;
  RK_STRONG_REF id * RK_C99(restrict) objects = NULL;
  void *tempKey = NULL;
  
  if(RK_EXPECTED(cacheMapTable == NULL,                                 0)) { return(NULL); } // Fast exit case.  Does not not an atomic compare on NULL.
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, NO) == NO,            0)) { return(NULL); } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  // On an error condition we goto unlockExitNow. Any resource acquisition inside here needs to ensure that the resources in question will remain valid once the lock is released.
  
  if(RK_EXPECTED(cacheMapTable == NULL,                                 0)) { goto unlockExitNow; } // Reverify under lock as this could have changed.
  if(RK_EXPECTED((cacheCount = NSCountMapTable(cacheMapTable)) == 0,    0)) { goto unlockExitNow; }
  if(RK_EXPECTED((objects = alloca(cacheCount * sizeof(id *))) == NULL, 0)) { goto unlockExitNow; }
  
  cacheMapTableEnumerator = NSEnumerateMapTable(cacheMapTable);
  while((NSNextMapEnumeratorPair(&cacheMapTableEnumerator, &tempKey, (void **)&objects[atCachedObject])) == YES) { RKRetain(objects[atCachedObject]); atCachedObject++; }
  NSEndMapTableEnumeration(&cacheMapTableEnumerator);
  
  retrievedCount = atCachedObject;
  retrievedObjects = YES;
  
unlockExitNow:
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
  if((retrievedObjects == YES) && (retrievedCount > 0)) {
    returnSet = [NSSet setWithObjects:&objects[0] count:retrievedCount];
    for(atCachedObject = 0; atCachedObject < retrievedCount; atCachedObject++) { RKRelease(objects[atCachedObject]); }
  }
  
  return(returnSet);
}

- (BOOL)isCacheEnabled
{
  return(cacheIsEnabled);
}

- (BOOL)setCacheEnabled:(const BOOL)enableCache
{
  RKAtomicMemoryBarrier(); // Extra cautious
  int enabledState = cacheIsEnabled;
  int returnEnabledState = RKAtomicCompareAndSwapInt(enabledState, enableCache, &cacheIsEnabled);
  return((returnEnabledState == 0) ? NO : YES);
}

- (RKUInteger)cacheCount
{
  RKUInteger returnCount = 0;
  
  if(cacheMapTable == NULL) { return(0); }
  if(RKFastReadWriteLock(cacheRWLock, NO) == NO) { return(0); } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
#ifdef ENABLE_MACOSX_GARBAGE_COLLECTION
  if(RKRegexGarbageCollect == 1) { returnCount = [cacheMapTable count]; } else
#endif
  { returnCount = NSCountMapTable(cacheMapTable); }
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
  return(returnCount);
}

@end


@implementation RKCache (CacheDebugging)

- (BOOL)isCacheAddingEnabled
{
  return(cacheAddingIsEnabled);
}

- (BOOL)setCacheAddingEnabled:(const BOOL)enableCacheAdding
{
  RKAtomicMemoryBarrier(); // Extra cautious
  int lookupEnabledState = cacheAddingIsEnabled;
  int returnEnabledState = RKAtomicCompareAndSwapInt(lookupEnabledState, enableCacheAdding, &cacheAddingIsEnabled);
  return((returnEnabledState == 0) ? NO : YES);
}

- (BOOL)isCacheLookupEnabled
{
  return(cacheLookupIsEnabled);
}

- (BOOL)setCacheLookupEnabled:(const BOOL)enableCacheLookup
{
  RKAtomicMemoryBarrier(); // Extra cautious
  int lookupEnabledState = cacheLookupIsEnabled;
  int returnEnabledState = RKAtomicCompareAndSwapInt(lookupEnabledState, enableCacheLookup, &cacheLookupIsEnabled);
  return((returnEnabledState == 0) ? NO : YES);
}

@end

@implementation RKCache (CountersDebugging)

- (void) setDebug:(const BOOL)enableDebugging { [cacheRWLock setDebug:enableDebugging]; }
- (void) clearCounters                        { cacheClearedCount = 0; [cacheRWLock clearCounters]; }
- (RKUInteger) cacheClearedCount              { return(cacheClearedCount);              }
- (RKUInteger) readBusyCount                  { return([cacheRWLock readBusyCount]);    }
- (RKUInteger) readSpinCount                  { return([cacheRWLock readSpinCount]);    }
- (RKUInteger) writeBusyCount                 { return([cacheRWLock writeBusyCount]);   }
- (RKUInteger) writeSpinCount                 { return([cacheRWLock writeSpinCount]);   }

@end
