//
//  NSSet.m
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

#import <RegexKit/NSSet.h>
#import <RegexKit/RegexKitPrivate.h>

typedef enum {
  RKSetActionObjectOfFirstMatch = 0,
  RKSetActionSetOfMatchingObjects = 1,
  RKSetActionCountOfMatchingObjects = 2,
  RKSetActionAddMatches = 3,
  RKSetActionRemoveMatches = 4,
  RKSetActionSetMaxAction = 4
} RKSetAction;

static id RKDoSetAction(id self, SEL _cmd, id matchAgainstSet, id regexObject, const RKSetAction performAction);

@implementation NSSet (RegexKitAdditions)

static id RKDoSetAction(id self, SEL _cmd, id matchAgainstSet, id regexObject, const RKSetAction performAction) {
  RKRegex *regex = RKRegexFromStringOrRegex(self, _cmd, regexObject, RKCompileNoOptions, YES);
  id returnObject = NULL, *setObjects = NULL, *matchedObjects = NULL;
  unsigned int setCount = 0, atIndex = 0, matchedCount = 0;
  
  if(RK_EXPECTED(self == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"self == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(_cmd == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"_cmd == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(matchAgainstSet == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"matchAgainstSet == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(performAction > RKSetActionSetMaxAction, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"Unknown performAction = %u.", performAction) userInfo:NULL] raise]; }
  
  if((RK_EXPECTED(self == matchAgainstSet, 0)) && (performAction == RKSetActionAddMatches)) { goto exitNow; } // Fast path bypass on unusual case.

#ifdef USE_CORE_FOUNDATION
  if((setCount = CFSetGetCount((CFSetRef)matchAgainstSet)) == 0) { goto doAction; }
#else
  if((setCount = [matchAgainstSet count]) == 0) { goto doAction; }
#endif
  
  if(RK_EXPECTED((setObjects     = alloca(sizeof(id *) * setCount)) == NULL, 0)) { return(NULL); }
  if(RK_EXPECTED((matchedObjects = alloca(sizeof(id *) * setCount)) == NULL, 0)) { return(NULL); }
  
#ifdef USE_CORE_FOUNDATION
  CFSetGetValues((CFSetRef)matchAgainstSet, (const void **)(&setObjects[0]));
#else
  [[matchAgainstSet allObjects] getObjects:&setObjects[0]];
#endif
  
  for(atIndex = 0; atIndex < setCount; atIndex++) {
    if([setObjects[atIndex] isMatchedByRegex:regex] == YES) {
      if(performAction == RKSetActionObjectOfFirstMatch) { returnObject = setObjects[atIndex]; goto exitNow; }
      matchedObjects[matchedCount++] = setObjects[atIndex];
    }
  }

doAction:
  
  returnObject = NULL;
  switch(performAction) {
    case RKSetActionObjectOfFirstMatch: NSCAssert(matchedCount == 0, @"set RKSetActionObjectOfFirstMatch, matched count > 0 in performAction switch statement."); if(matchedCount == 0) { returnObject = NULL; goto exitNow; } break;
    case RKSetActionCountOfMatchingObjects: returnObject = (id)matchedCount; goto exitNow; break;
#ifdef USE_CORE_FOUNDATION
    case RKSetActionSetOfMatchingObjects: returnObject = (id)CFSetCreate(kCFAllocatorDefault, (const void **)(&matchedObjects[0]), matchedCount, &kCFTypeSetCallBacks); break;
#else
    case RKSetActionSetOfMatchingObjects: returnObject = [[NSSet alloc] initWithObjects:&matchedObjects[0] count:matchedCount]; break;
#endif
    case RKSetActionAddMatches:             for(unsigned int x = 0; x < matchedCount; x++) { [self addObject:matchedObjects[x]];    } goto exitNow; break;
    case RKSetActionRemoveMatches:          for(unsigned int x = 0; x < matchedCount; x++) { [self removeObject:matchedObjects[x]]; } goto exitNow; break;
    default: returnObject = NULL; NSCAssert1(1 == 0, @"Unknown RKSetAction in switch block, performAction = %d", performAction); break;
  }
  [returnObject autorelease];
  
exitNow:
    return(returnObject);
}



-(id)anyObjectMatchingRegex:(id)aRegex
{
  return(RKDoSetAction(self, _cmd, self, aRegex, RKSetActionObjectOfFirstMatch));
}

-(BOOL)containsObjectMatchingRegex:(id)aRegex
{
  return(RKDoSetAction(self, _cmd, self, aRegex, RKSetActionObjectOfFirstMatch) != NULL ? YES : NO);
}

-(unsigned int)countOfObjectsMatchingRegex:(id)aRegex
{
  return((unsigned int)RKDoSetAction(self, _cmd, self, aRegex, RKSetActionCountOfMatchingObjects));
}

-(NSSet *)setByMatchingObjectsWithRegex:(id)aRegex
{
  return(RKDoSetAction(self, _cmd, self, aRegex, RKSetActionSetOfMatchingObjects));
}


@end

@implementation NSMutableSet (RegexKitAdditions)

- (void)addObjectsFromArray:(NSArray *)otherArray matchingRegex:(id)aRegex
{
  if(RK_EXPECTED(otherArray == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"otherArray == NULL.") userInfo:NULL] raise]; }
  RKDoSetAction(self, _cmd, [NSSet setWithArray:otherArray], aRegex, RKSetActionAddMatches);
}

- (void)addObjectsFromSet:(NSSet *)otherSet matchingRegex:(id)aRegex
{
  if(RK_EXPECTED(otherSet == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"otherSet == NULL.") userInfo:NULL] raise]; }
  RKDoSetAction(self, _cmd, otherSet, aRegex, RKSetActionAddMatches);
}

-(void)removeObjectsMatchingRegex:(id)aRegex
{
  RKDoSetAction(self, _cmd, self, aRegex, RKSetActionRemoveMatches);
}

@end
