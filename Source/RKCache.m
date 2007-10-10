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

- (id)init
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(cacheInitialized == 1) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"This cache is already initialized.") userInfo:NULL] raise]; }

  if((self = [super init]) == NULL) { goto errorExit; }
  
  [self autorelease];
    
  if(RKAtomicCompareAndSwapInt(0, 1, &cacheInitialized)) {
    if((cacheRWLock = [[RKReadWriteLock alloc] init]) == NULL) { NSLog(@"Unable to initialize cache lock, caching is disabled."); goto errorExit; }
    else {
      if([self clearCache] == NO) { NSLog(@"Unable to create cache hash map."); goto errorExit; }
      cacheClearedCount = 0;
      cacheAddingIsEnabled = cacheLookupIsEnabled = cacheIsEnabled = YES;
    }
  }

  [self retain];
  return(self);

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
  if(cacheDescriptionString != NULL) { [cacheDescriptionString autorelease]; cacheDescriptionString = NULL; }
  if(descriptionString      != NULL) { cacheDescriptionString = [descriptionString copy];                   }
}

- (void)dealloc
{
  if(cacheRWLock)            { RKFastReadWriteLock(cacheRWLock, YES); [cacheRWLock release]; cacheRWLock            = NULL; }
  if(cacheMapTable)          { NSFreeMapTable(cacheMapTable);                                cacheMapTable          = NULL; }
  if(cacheDescriptionString) { [cacheDescriptionString release];                             cacheDescriptionString = NULL; }
  [super dealloc];
}

- (unsigned int)hash
{
  return((unsigned int)self);
}

- (BOOL)isEqual:(id)anObject
{
  if(self == anObject) { return(YES); } else { return(NO); }
}

- (BOOL)clearCache
{
  NSMapTable * RK_C99(restrict) newMapTable = NULL, * RK_C99(restrict) oldMapTable = NULL;
  BOOL didClearCache = NO;
  
  if(RK_EXPECTED((newMapTable = NSCreateMapTable(NSIntMapKeyCallBacks, NSObjectMapValueCallBacks, 256)) == NULL, 0)) { goto exitNow; }
  
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
  if(newMapTable != NULL) { NSFreeMapTable(newMapTable); newMapTable = NULL; }
  if(oldMapTable != NULL) { NSFreeMapTable(oldMapTable); oldMapTable = NULL; }
  
  return(didClearCache);
}

- (NSString *)status
{
  double cacheLookups = (((double)cacheHits) + (double)cacheMisses);
  if(cacheLookups == 0.0) { cacheLookups = 1.0; }
  return([NSString stringWithFormat:@"Enabled = %@ (Add: %@, Lookup: %@), Cleared count = %u, Cache count = %u, Hit rate = %6.2f%%, Hits = %u, Misses = %u, Total = %.0f", RKYesOrNo(cacheIsEnabled), RKYesOrNo(cacheAddingIsEnabled), RKYesOrNo(cacheLookupIsEnabled), [self cacheClearedCount], [self cacheCount], (((double)cacheHits) / cacheLookups) * 100.0, cacheHits, cacheMisses, (((double)cacheHits) + (double)cacheMisses)]);
}

- (NSString *)description
{
  return([NSString stringWithFormat:@"<%@: %p>%s%@%s %@", [self className], self, (cacheDescriptionString != NULL) ? " \"":"", (cacheDescriptionString != NULL) ? cacheDescriptionString : (NSString *)@"", (cacheDescriptionString != NULL) ? "\"":"", [self status]]);
}

- (id)objectForHash:(const unsigned int)objectHash
{
  return(RKFastCacheLookup(self, _cmd, objectHash, YES));
}

- (id)objectForHash:(const unsigned int)objectHash autorelease:(const BOOL)shouldAutorelease
{
  return(RKFastCacheLookup(self, _cmd, objectHash, shouldAutorelease));
}

id RKFastCacheLookup(RKCache * const aCache, const SEL _cmd RK_ATTRIBUTES(unused), const unsigned int objectHash, const BOOL shouldAutorelease) {
  if(RK_EXPECTED(aCache == NULL, 0)) { return(NULL); }
  struct RKCacheDef { @defs(RKCache) } *self = (struct RKCacheDef *)aCache;
  
  id returnObject = NULL;
  
  if(RK_EXPECTED(RKFastReadWriteLock(self->cacheRWLock, NO) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  if(RK_EXPECTED((self->cacheIsEnabled == YES), 1) && RK_EXPECTED((self->cacheLookupIsEnabled == YES), 1)) {
    if(RK_EXPECTED(self->cacheMapTable != NULL, 1)) {
      // If we get a hit, do a retain on the object so it will be within our current autorelease scope.  Once we unlock, the map table could vanish, taking
      // the returned object with it.  This way we ensure it stays around.  Convenience methods handle autoreleasing.
      if((returnObject = NSMapGet(self->cacheMapTable, (const void *)objectHash)) != NULL) { [returnObject retain]; }
    }
  }
  
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(self->cacheRWLock);
  
exitNow:
  if(returnObject != NULL) { self->cacheHits++; if(RK_EXPECTED(shouldAutorelease == YES, 1)) { [returnObject autorelease]; } } else { self->cacheMisses++; }
  return(returnObject);
}


- (BOOL)addObjectToCache:(id)object
{
  return([self addObjectToCache:object withHash:[object hash]]);
}

- (BOOL)addObjectToCache:(id)object withHash:(const unsigned int)objectHash
{
  BOOL didCache = NO;

  if(object == NULL) { goto exitNow; }
  
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, YES) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv

  if(RK_EXPECTED((cacheAddingIsEnabled == YES), 1) && RK_EXPECTED((cacheIsEnabled == YES), 1)) {
    if(RK_EXPECTED(cacheMapTable != NULL, 1)) {
      if(NSMapInsertIfAbsent(cacheMapTable, (const void *)objectHash, object) == NULL) { didCache = YES; }
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

- (id)removeObjectWithHash:(const unsigned int)objectHash
{
  void **cachedKey = NULL, **cachedObject = NULL;
      
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, YES) == NO, 0)) { goto exitNow; } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv

  if(cacheMapTable != NULL) {
    if(NSMapMember(cacheMapTable, (const void *)objectHash, (void **)&cachedKey, (void **)&cachedObject) == YES) {
      [(id)cachedObject retain];
      NSMapRemove(cacheMapTable, (const void *)objectHash);
    }
  }

  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);

  if(cachedObject != NULL) { [(id)cachedObject autorelease]; }

exitNow:
  return((id)cachedObject);
}

- (NSSet *)cacheSet
{
  unsigned int atCachedObject = 0, retrievedCount = 0, cacheCount = 0;
  NSMapEnumerator cacheMapTableEnumerator;
  BOOL retrievedObjects = NO;
  NSSet * RK_C99(restrict) returnSet = NULL;
  id * RK_C99(restrict) objects = NULL;
  void *tempKey = NULL;
  
  if(RK_EXPECTED(cacheMapTable == NULL,                                 0)) { return(NULL); } // Fast exit case.  Does not not an atomic compare on NULL.
  if(RK_EXPECTED(RKFastReadWriteLock(cacheRWLock, NO) == NO,            0)) { return(NULL); } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  
  // On an error condition we goto unlockExitNow. Any resource acquisition inside here needs to ensure that the resources in question will remain valid once the lock is released.
  
  if(RK_EXPECTED(cacheMapTable == NULL,                                 0)) { goto unlockExitNow; } // Reverify under lock as this could have changed.
  if(RK_EXPECTED((cacheCount = NSCountMapTable(cacheMapTable)) == 0,    0)) { goto unlockExitNow; }
  if(RK_EXPECTED((objects = alloca(cacheCount * sizeof(id *))) == NULL, 0)) { goto unlockExitNow; }
  
  cacheMapTableEnumerator = NSEnumerateMapTable(cacheMapTable);
  while((NSNextMapEnumeratorPair(&cacheMapTableEnumerator, &tempKey, (void **)&objects[atCachedObject])) == YES) { [objects[atCachedObject] retain]; atCachedObject++; }
  NSEndMapTableEnumeration(&cacheMapTableEnumerator);
  
  retrievedCount = atCachedObject;
  retrievedObjects = YES;
  
unlockExitNow:
  // ^^^^^^^^^^^^^ END LOCK CRITICAL PATH ^^^^^^^^^^^^^
  RKFastReadWriteUnlock(cacheRWLock);
  
  if((retrievedObjects == YES) && (retrievedCount > 0)) {
    returnSet = [NSSet setWithObjects:&objects[0] count:retrievedCount];
    for(atCachedObject = 0; atCachedObject < retrievedCount; atCachedObject++) { [objects[atCachedObject] release]; }
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

- (unsigned int)cacheCount
{
  unsigned int returnCount = 0;
  
  if(cacheMapTable == NULL) { return(0); }
  if(RKFastReadWriteLock(cacheRWLock, NO) == NO) { return(0); } // Did not acquire lock for some reason
  // vvvvvvvvvvvv BEGIN LOCK CRITICAL PATH vvvvvvvvvvvv
  returnCount = NSCountMapTable(cacheMapTable);
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
- (unsigned int) cacheClearedCount            { return(cacheClearedCount);                 }
- (unsigned int) readBusyCount                { return([cacheRWLock readBusyCount]);  }
- (unsigned int) readSpinCount                { return([cacheRWLock readSpinCount]);  }
- (unsigned int) writeBusyCount               { return([cacheRWLock writeBusyCount]); }
- (unsigned int) writeSpinCount               { return([cacheRWLock writeSpinCount]); }

@end
