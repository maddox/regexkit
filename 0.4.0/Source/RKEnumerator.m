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
  return(RKAutorelease([[RKEnumerator alloc] initWithRegex:aRegex string:string inRange:NSMakeRange(0, [string length])]));
}

+ (id)enumeratorWithRegex:(id)aRegex string:(NSString * const)string inRange:(const NSRange)range;
{
  return(RKAutorelease([[RKEnumerator alloc] initWithRegex:aRegex string:string inRange:range]));
}

- (id)initWithRegex:(id)initRegex string:(NSString * const)initString
{
  return([self initWithRegex:initRegex string:initString inRange:NSMakeRange(0, [initString length])]);
}

- (id)initWithRegex:(id)initRegex string:(NSString * const)initString inRange:(const NSRange)initRange
{
  if((self = [self init]) == NULL) { goto errorExit; }

  RKAutorelease(self);
  
  regex = RKRegexFromStringOrRegex(self, _cmd, initRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), NO); // Throws an exception if there is an error.
  regexCaptureCount = [regex captureCount];
  
  if(RK_EXPECTED(initString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"initString == nil.") userInfo:nil] raise]; }
  
  string = RKRetain(initString);

  RK_STRONG_REF RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  searchUTF16Range  = initRange;
  searchByteRange   = RKutf16to8(string, initRange);
  atBufferLocation  = searchByteRange.location;
  hasPerformedMatch = 0;
  
  if(RK_EXPECTED(stringBuffer.length < searchByteRange.location, 0))    { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %lu < start location %lu for range %@.", (unsigned long)[string length], (unsigned long)searchUTF16Range.location, NSStringFromRange(searchUTF16Range)) userInfo:NULL] raise]; }  
  if(RK_EXPECTED(stringBuffer.length < NSMaxRange(searchByteRange), 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %lu < end location %lu for range %@.", (unsigned long)[string length], (unsigned long)NSMaxRange(searchUTF16Range), NSStringFromRange(searchUTF16Range)) userInfo:NULL] raise]; }  

  if(RK_EXPECTED((resultUTF8Ranges  = malloc(sizeof(NSRange) * regexCaptureCount)) == NULL, 0)) { goto errorExit; }
  if(RK_EXPECTED((resultUTF16Ranges = malloc(sizeof(NSRange) * regexCaptureCount)) == NULL, 0)) { goto errorExit; }
  
  for(RKUInteger x = 0; x < regexCaptureCount; x++) { resultUTF8Ranges[x] = resultUTF16Ranges[x] = NSMakeRange(NSNotFound, 0); }
  
  return(RKRetain(self));
  
errorExit:
  return(NULL);
}

- (RKUInteger)hash
{
  return((RKUInteger)self);
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

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  [self releaseAllResources];
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

- (RKRegex *)regex
{
  return(RKAutorelease(RKRetain(regex)));
}

- (NSString *)string
{
  return(RKAutorelease(RKRetain(string)));
}


- (NSRange)currentRange
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 

 return(resultUTF16Ranges[0]);
}

- (NSRange)currentRangeForCapture:(const RKUInteger)capture
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(capture >= regexCaptureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Requested capture %lu > %lu captures in regular expression.", (unsigned long)capture, (unsigned long)(regexCaptureCount + 1)) userInfo:NULL] raise]; } 
  
  return(resultUTF16Ranges[capture]);
}

- (NSRange)currentRangeForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED([regex isValidCaptureName:captureNameString] == NO, 0)) { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:RKPrettyObjectMethodString(@"The captureName '%@' does not exist.", captureNameString) userInfo:NULL] raise]; } 

  return(resultUTF16Ranges[[regex captureIndexForCaptureName:captureNameString inMatchedRanges:resultUTF8Ranges]]);
}

- (NSRange *)currentRanges
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  if(RK_EXPECTED(hasPerformedMatch == 0, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"A 'next...' method must be invoked before information about the current match is available.") userInfo:NULL] raise]; } 
  
  return(&resultUTF16Ranges[0]);
}


- (id)nextObject
{
  if((RK_EXPECTED(atBufferLocation == NSNotFound, 0)) || (RK_EXPECTED([self _updateToNextMatch] == NO, 0))) { return(NULL); }
  RK_STRONG_REF NSValue **rangeValues = NULL;
  RKUInteger x;
  
  if(RK_EXPECTED((rangeValues = alloca(regexCaptureCount * sizeof(NSValue *))) == NULL, 0)) { return(NULL); }
  for(x = 0; x < regexCaptureCount; x++) { rangeValues[x] = [NSValue valueWithRange:resultUTF16Ranges[x]]; }
  return([NSArray arrayWithObjects:rangeValues count:regexCaptureCount]);
}

- (NSRange)nextRange
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  [self _updateToNextMatch];
  return([self currentRange]);
}

- (NSRange)nextRangeForCapture:(RKUInteger)capture
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED(capture >= regexCaptureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Requested capture %lu > %lu captures in regular expression.", (unsigned long)capture, (unsigned long)(regexCaptureCount + 1)) userInfo:NULL] raise]; } 
  [self _updateToNextMatch];
  return([self currentRangeForCapture:capture]);
}

- (NSRange)nextRangeForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NSMakeRange(NSNotFound, 0)); }
  if(RK_EXPECTED([regex isValidCaptureName:captureNameString] == NO, 0)) { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:RKPrettyObjectMethodString(@"The captureName '%@' does not exist.", captureNameString) userInfo:NULL] raise]; } 

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
  return(RKExtractCapturesFromMatchesWithKeyArguments(self, _cmd, (const RKStringBuffer *)&stringBuffer, regex, resultUTF8Ranges, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), firstReference, varArgsList));
}


- (NSString *)stringWithReferenceString:(NSString * const)referenceString
{
  if(RK_EXPECTED(referenceString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"referenceString == nil.") userInfo:NULL] raise]; } 
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NULL); }
  RKStringBuffer stringBuffer          = RKStringBufferWithString(string);
  RKStringBuffer referenceStringBuffer = RKStringBufferWithString(referenceString);
  return(RKStringFromReferenceString(self, _cmd, regex, resultUTF8Ranges, &stringBuffer, &referenceStringBuffer));
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
  RKStringBuffer stringBuffer                = RKStringBufferWithString(string);
  RKStringBuffer referenceFormatStringBuffer = RKStringBufferWithString([[[NSString alloc] initWithFormat:referenceFormatString arguments:argList] autorelease]);
  return(RKStringFromReferenceString(self, _cmd, regex, resultUTF8Ranges, &stringBuffer, &referenceFormatStringBuffer));
}

@end


@implementation RKEnumerator (RKPrivate)

- (BOOL)_updateToNextMatch
{
  if(RK_EXPECTED(atBufferLocation == NSNotFound, 0)) { return(NO); }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
    
  RKMatchErrorCode matched = [regex getRanges:&resultUTF8Ranges[0] withCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(atBufferLocation, NSMaxRange(searchByteRange) - atBufferLocation) options:RKMatchNoUTF8Check];
  hasPerformedMatch = 1;
  if(RK_EXPECTED(matched > 0, 1)) {
    atBufferLocation = (resultUTF8Ranges[0].location + resultUTF8Ranges[0].length);
    for(RKUInteger x = 0; x < regexCaptureCount; x++) { resultUTF16Ranges[x] = RKutf8to16(string, resultUTF8Ranges[x]); }
    return(YES);
  }
  [self releaseAllResources]; // else no more matches
  return(NO);
}

- (void)releaseAllResources
{
  if(regex             != NULL) { RKRelease(regex);        regex             = NULL; }
  if(string            != NULL) { RKRelease(string);       string            = NULL; }
  if(resultUTF8Ranges  != NULL) { free(resultUTF8Ranges);  resultUTF8Ranges  = NULL; }
  if(resultUTF16Ranges != NULL) { free(resultUTF16Ranges); resultUTF16Ranges = NULL; }
  atBufferLocation = NSNotFound;
}
  
@end

