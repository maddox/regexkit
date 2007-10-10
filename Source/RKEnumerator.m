//
//  RKEnumerator.m
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

#import <RegexKit/RKEnumerator.h>
#import <RegexKit/RegexKitPrivate.h>


@interface RKEnumerator (RKPrivate)

- (BOOL)_updateToNextMatch;
- (void)releaseAllResources;

@end

@implementation RKEnumerator

+ (id)enumeratorWithRegex:(id)aRegex string:(NSString * const)string;
{
  return([[[RKEnumerator alloc] initWithRegex:aRegex string:string inRange:NSMakeRange(0, [string length])] autorelease]);
}

+ (id)enumeratorWithRegex:(id)aRegex string:(NSString * const)string inRange:(const NSRange)range;
{
  return([[[RKEnumerator alloc] initWithRegex:aRegex string:string inRange:range] autorelease]);
}

- (id)initWithRegex:(id)initRegex string:(NSString * const)initString
{
  return([self initWithRegex:initRegex string:initString inRange:NSMakeRange(0, [initString length])]);
}

- (id)initWithRegex:(id)initRegex string:(NSString * const)initString inRange:(const NSRange)initRange
{
  if((self = [self init]) == NULL) { goto errorExit; }

  [self autorelease];
  
  regex = RKRegexFromStringOrRegex(self, _cmd, initRegex, RKCompileNoOptions, NO); // Throws an exception if there is an error.
  regexCaptureCount = [regex captureCount];
  
  if(RK_EXPECTED(initString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"initString == nil.") userInfo:nil] raise]; }
  
  string = [initString retain];
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  searchRange = initRange;
  atBufferLocation = searchRange.location;
  hasPerformedMatch = 0;
  
  if(RK_EXPECTED(stringBuffer.length < searchRange.location, 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %u < start location %u for range %@.", stringBuffer.length, searchRange.location, NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  
  if(RK_EXPECTED(stringBuffer.length < NSMaxRange(searchRange), 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %u < end location %u for range %@.", stringBuffer.length, NSMaxRange(searchRange), NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  

  if(RK_EXPECTED((resultRanges = malloc(sizeof(NSRange) * regexCaptureCount)) == NULL, 0)) { goto errorExit; }
  
  for(unsigned int x = 0; x < regexCaptureCount; x++) { resultRanges[x] = NSMakeRange(NSNotFound, 0); }
  
  return([self retain]);
  
errorExit:
  return(NULL);
}

- (unsigned int)hash
{
  return((unsigned int)self);
}

- (BOOL)isEqual:(id)anObject
{
  if(self == anObject) { return(YES); } else { return(NO); }
}

- (void)dealloc
{
  [self releaseAllResources];
  [super dealloc];
}


- (RKRegex *)regex
{
#ifdef REGEXKIT_DEBUGGING
  return(regex);
#else
  return([[regex retain] autorelease]);
#endif
}

- (NSString *)string
{
  return([[string retain] autorelease]);
}


- (NSRange)currentRange
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 

 return(resultRanges[0]);
}

- (NSRange)currentRangeForCapture:(const unsigned int)capture
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(capture >= regexCaptureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Requested capture %u > %u captures in regular expression.", capture, regexCaptureCount + 1) userInfo:NULL] raise]; } 
  
  return(resultRanges[capture]);
}

- (NSRange)currentRangeForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED([regex isValidCaptureName:captureNameString] == NO, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"The captureName '%@' does not exist.", captureNameString) userInfo:NULL] raise]; } 

  return(resultRanges[[regex captureIndexForCaptureName:captureNameString inMatchedRanges:resultRanges]]);
}

- (NSRange *)currentRanges
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  
  return(&resultRanges[0]);
}


- (id)nextObject
{
  if((RK_EXPECTED(atBufferLocation == NSNotFound, 0)) || (RK_EXPECTED([self _updateToNextMatch] == NO, 0))) { return(NULL); }
  NSValue **rangeValues = NULL;
  unsigned int x;
  
  if(RK_EXPECTED((rangeValues = alloca(regexCaptureCount * sizeof(NSValue *))) == NULL, 0)) { return(NULL); }
  for(x = 0; x < regexCaptureCount; x++) { rangeValues[x] = [NSValue valueWithRange:resultRanges[x]]; }
  return([NSArray arrayWithObjects:rangeValues count:regexCaptureCount]);
}

- (NSRange)nextRange
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  [self _updateToNextMatch];
  return([self currentRange]);
}

- (NSRange)nextRangeForCapture:(unsigned int)capture
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(capture >= regexCaptureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Requested capture %u > %u captures in regular expression.", capture, regexCaptureCount + 1) userInfo:NULL] raise]; } 
  [self _updateToNextMatch];
  return([self currentRangeForCapture:capture]);
}

- (NSRange)nextRangeForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED([regex isValidCaptureName:captureNameString] == NO, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"The captureName '%@' does not exist.", captureNameString) userInfo:NULL] raise]; } 

  [self _updateToNextMatch];
  return([self currentRangeForCaptureName:captureNameString]);
}

- (NSRange *)nextRanges
{
  [self _updateToNextMatch];
  return([self currentRanges]);
}


- (BOOL)getCapturesWithReferences:(NSString * const)firstReference, ...
{
  if(RK_EXPECTED(firstReference == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"firstReference == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NO); }
  va_list varArgsList; va_start(varArgsList, firstReference);
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  return(RKExtractCapturesFromMatchesWithKeyArguments(self, _cmd, (const RKStringBuffer *)&stringBuffer, regex, resultRanges, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), firstReference, varArgsList));
}


- (NSString *)stringWithReferenceString:(NSString * const)referenceString
{
  if(RK_EXPECTED(referenceString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"referenceString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  RKStringBuffer referenceStringBuffer = RKStringBufferWithString(referenceString);
  return(RKStringFromReferenceString(self, _cmd, regex, resultRanges, &stringBuffer, &referenceStringBuffer));
}


- (NSString *)stringWithReferenceFormat:(NSString * const)referenceFormatString, ...
{
  if(RK_EXPECTED(referenceFormatString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"referenceFormatString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  va_list argList; va_start(argList, referenceFormatString);
  return([self stringWithReferenceFormat:referenceFormatString arguments:argList]);
}

- (NSString *)stringWithReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{
  if(RK_EXPECTED(referenceFormatString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"referenceFormatString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  RKStringBuffer referenceFormatStringBuffer = RKStringBufferWithString([[[NSString alloc] initWithFormat:referenceFormatString arguments:argList] autorelease]);
  return(RKStringFromReferenceString(self, _cmd, regex, resultRanges, &stringBuffer, &referenceFormatStringBuffer));
}

@end


@implementation RKEnumerator (RKPrivate)

- (BOOL)_updateToNextMatch
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NO); }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
    
  RKMatchErrorCode matched = [regex getRanges:&resultRanges[0] withCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(atBufferLocation, NSMaxRange(searchRange) - atBufferLocation) options:RKMatchNoOptions];
  hasPerformedMatch = 1;
  if(RK_EXPECTED(matched > 0, 1)) { atBufferLocation = (resultRanges[0].location + resultRanges[0].length); return(YES); }
  [self releaseAllResources]; // else no more matches
  return(NO);
}

- (void)releaseAllResources
{
  if(regex        != NULL) { [regex release];    regex        = NULL; }
  if(string       != NULL) { [string release];   string       = NULL; }
  if(resultRanges != NULL) { free(resultRanges); resultRanges = NULL; }
  atBufferLocation = NSNotFound;
}
  
@end

