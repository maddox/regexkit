//
//  NSArray.m
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

#import <RegexKit/NSArray.h>
#import <RegexKit/RegexKitPrivate.h>

typedef enum {
  RKArrayActionIndexOfFirstMatch = 0,
  RKArrayActionArrayOfMatchingObjects = 1,
  RKArrayActionCountOfMatchingObjects = 2,
  RKArrayActionAddMatches = 3,
  RKArrayActionRemoveMatches = 4,
  RKArrayActionArrayMaxAction = 4
} RKArrayAction;

static id RKDoArrayAction(id self, SEL _cmd, id matchAgainstArray, const NSRange *againstRange, id regexObject, const RKArrayAction performAction);

@implementation NSArray (RegexKitAdditions)

static id RKDoArrayAction(id self, SEL _cmd, id matchAgainstArray, const NSRange *againstRange, id regexObject, const RKArrayAction performAction) {
  unsigned int arrayCount = 0, atIndex = 0, matchedCount = 0, matchAgainstArrayCount = 0, *matchedIndexes = NULL;
  RKRegex *regex = RKRegexFromStringOrRegex(self, _cmd, regexObject, RKCompileNoOptions, YES);
  id returnObject = NULL, *arrayObjects = NULL, *matchedObjects = NULL;
  NSRange matchRange = NSMakeRange(NSNotFound, 0);

  if(RK_EXPECTED(self == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"self == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(_cmd == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"_cmd == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(matchAgainstArray == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"matchAgainstArray == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(performAction > RKArrayActionArrayMaxAction, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"Unknown performAction = %u.", performAction) userInfo:NULL] raise]; }

#ifdef USE_CORE_FOUNDATION
  matchAgainstArrayCount = CFArrayGetCount((CFArrayRef)matchAgainstArray);
#else
  matchAgainstArrayCount = [matchAgainstArray count];
#endif
  
  if(againstRange == NULL) { matchRange = NSMakeRange(0, matchAgainstArrayCount); } else { matchRange = *againstRange; }

  if((RK_EXPECTED(matchRange.location > matchAgainstArrayCount, 0)) || (RK_EXPECTED((matchRange.location + matchRange.length) > matchAgainstArrayCount, 0))) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"Range %@ exceeds array length of %u.", NSStringFromRange(matchRange), matchAgainstArrayCount) userInfo:NULL] raise]; }
  
  if((arrayCount = matchRange.length) == 0) { goto doAction; }

  if(RK_EXPECTED((arrayObjects   = alloca(sizeof(id *)         * arrayCount)) == NULL, 0)) { return(NULL); }
  if(RK_EXPECTED((matchedIndexes = alloca(sizeof(unsigned int) * arrayCount)) == NULL, 0)) { return(NULL); }
  if(RK_EXPECTED((matchedObjects = alloca(sizeof(id *)         * arrayCount)) == NULL, 0)) { return(NULL); }
  
#ifdef USE_CORE_FOUNDATION
  CFArrayGetValues((CFArrayRef)matchAgainstArray, (CFRange){matchRange.location, matchRange.length}, (const void **)(&arrayObjects[0]));
#else
  [matchAgainstArray getObjects:&arrayObjects[0] range:matchRange];
#endif
  
  for(atIndex = 0; atIndex < arrayCount; atIndex++) {
    if([arrayObjects[atIndex] isMatchedByRegex:regex] == YES) {
      if(performAction == RKArrayActionIndexOfFirstMatch)    { returnObject = (id)(atIndex + matchRange.location); goto exitNow; }
      matchedIndexes[matchedCount]   = (atIndex + matchRange.location);
      matchedObjects[matchedCount++] = arrayObjects[atIndex];
    }
  }

doAction:
  
  returnObject = NULL;
  switch(performAction) {
    case RKArrayActionIndexOfFirstMatch: NSCAssert(matchedCount == 0, @"array RKIndexOfFirstMatch, matched count > 0 in performAction switch statement."); if(matchedCount == 0) { returnObject = (id)NSNotFound; goto exitNow; } break;
    case RKArrayActionCountOfMatchingObjects: returnObject = (id)matchedCount; goto exitNow; break;
#ifdef USE_CORE_FOUNDATION        
    case RKArrayActionArrayOfMatchingObjects: returnObject = (id)CFArrayCreate(kCFAllocatorDefault, (const void **)(&matchedObjects[0]), matchedCount, &kCFTypeArrayCallBacks); break;
#else
    case RKArrayActionArrayOfMatchingObjects: returnObject = [[NSArray alloc] initWithObjects:&matchedObjects[0] count:matchedCount]; break;
#endif
    case RKArrayActionAddMatches:             for(unsigned int x = 0; x < matchedCount; x++) { [self addObject:matchedObjects[x]];               } goto exitNow; break;
    case RKArrayActionRemoveMatches:          for(unsigned int x = 0; x < matchedCount; x++) { [self removeObjectAtIndex:matchedIndexes[x] - x]; } goto exitNow; break;
    default: returnObject = NULL; NSCAssert1(1 == 0, @"Unknown RKArrayAction in switch block, performAction = %d", performAction); break;
  }
  [returnObject autorelease];
    
exitNow:
    return(returnObject);
}


-(NSArray *)arrayByMatchingObjectsWithRegex:(id)aRegex
{
  return(RKDoArrayAction(self, _cmd, self, NULL, aRegex, RKArrayActionArrayOfMatchingObjects)); 
}

-(NSArray *)arrayByMatchingObjectsWithRegex:(id)aRegex inRange:(const NSRange)range
{
  return(RKDoArrayAction(self, _cmd, self, &range, aRegex, RKArrayActionArrayOfMatchingObjects)); 
}

-(BOOL)containsObjectMatchingRegex:(id)aRegex
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, NULL, aRegex, RKArrayActionIndexOfFirstMatch) != NSNotFound ? YES : NO); 
}

-(BOOL)containsObjectMatchingRegex:(id)aRegex inRange:(const NSRange)range
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, &range, aRegex, RKArrayActionIndexOfFirstMatch) != NSNotFound ? YES : NO); 
}

-(unsigned int)countOfObjectsMatchingRegex:(id)aRegex
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, NULL, aRegex, RKArrayActionCountOfMatchingObjects)); 
}

-(unsigned int)countOfObjectsMatchingRegex:(id)aRegex inRange:(const NSRange)range
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, &range, aRegex, RKArrayActionCountOfMatchingObjects)); 
}

-(unsigned int)indexOfObjectMatchingRegex:(id)aRegex
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, NULL, aRegex, RKArrayActionIndexOfFirstMatch)); 
}

-(unsigned int)indexOfObjectMatchingRegex:(id)aRegex inRange:(const NSRange)range
{
  return((unsigned int)RKDoArrayAction(self, _cmd, self, &range, aRegex, RKArrayActionIndexOfFirstMatch)); 
}

@end


@implementation NSMutableArray (RegexKitAdditions)

- (void)addObjectsFromArray:(NSArray *)otherArray matchingRegex:(id)aRegex;
{
  if(RK_EXPECTED(otherArray == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"otherArray == NULL.") userInfo:NULL] raise]; }
  RKDoArrayAction(self, _cmd, otherArray, NULL, aRegex, RKArrayActionAddMatches);
}

-(void)removeObjectsMatchingRegex:(id)aRegex
{
  RKDoArrayAction(self, _cmd, self, NULL, aRegex, RKArrayActionRemoveMatches);
}

-(void)removeObjectsMatchingRegex:(id)aRegex inRange:(const NSRange)range
{
  RKDoArrayAction(self, _cmd, self, &range, aRegex, RKArrayActionRemoveMatches);
}

@end
