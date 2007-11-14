//
//  NSString.m
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

#import <RegexKit/NSString.h>
#import <RegexKit/RegexKitPrivate.h>
#import <RegexKit/RKLock.h>

//#define REGEXKIT_DEBUG

/*************** Match and replace operations ***************/

static BOOL RKMatchAndExtractCaptureReferences(id self, const SEL _cmd, NSString * const extractString, const unsigned int * const fromIndex, const unsigned int * const toIndex, const NSRange * const range, id aRegex, const RKCompileOption compileOptions, const RKMatchOption matchOptions, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList);
static BOOL RKExtractCapturesFromMatchesWithKeysAndPointers(id self, const SEL _cmd, const RKStringBuffer *stringBuffer, RKRegex *regex, const NSRange *matchRanges, NSString **keyStrings, void ***keyConversionPointers, const unsigned int count, const RKCaptureExtractOptions captureExtractOptions);
static NSString *RKStringByMatchingAndExpanding(id self, const SEL _cmd, NSString * const searchString, const unsigned int * const fromIndex, const unsigned int * const toIndex, const NSRange * const searchStringRange, const unsigned int count, id aRegex, NSString * const referenceString, va_list * const argListPtr, const BOOL expandOrReplace, unsigned int * const matchedCountPtr);
static void RKEvaluateCopyInstructions(const RKCopyInstructionsBuffer * const instructionsBuffer, void * const toBuffer, const size_t bufferLength);
static NSString *RKStringFromCopyInstructions(id self, const SEL _cmd, const RKCopyInstructionsBuffer * const instructionsBuffer, const RKStringBufferEncoding stringEncoding) RK_ATTRIBUTES(malloc);
static BOOL RKApplyReferenceInstructions(id self, const SEL _cmd, RKRegex * const regex, const NSRange * const matchRanges, const RKStringBuffer * const stringBuffer,
                                         const RKReferenceInstructionsBuffer * const referenceInstructionsBuffer, RKCopyInstructionsBuffer * const appliedInstructionsBuffer);
static BOOL RKCompileReferenceString(id self, const SEL _cmd, const RKStringBuffer * const referenceStringBuffer, RKRegex * const regex, RKReferenceInstructionsBuffer * const instructionBuffer);
static BOOL RKAppendInstruction(    RKReferenceInstructionsBuffer  * const instructionsBuffer,     const int op, const void * const ptr, const NSRange range);
static BOOL RKAppendCopyInstruction(RKCopyInstructionsBuffer       * const copyInstructionsBuffer,               const void * const ptr, const NSRange range);
static unsigned int RKMutableStringMatch(id self, const SEL _cmd, id aRegex, const unsigned int *fromIndex, const unsigned int *toIndex, const NSRange *range, const unsigned int count, NSString * const formatString, va_list *argListPtr);

#ifdef REGEXKIT_DEBUG
static void dumpReferenceInstructions(const RKReferenceInstructionsBuffer * const ins);
static void dumpCopyInstructions(const RKCopyInstructionsBuffer * const ins);
#endif

/*************** End match and replace operations ***************/

#define PARSEREFERENCE_CONVERSION_ALLOWED  (1<<0)
#define PARSEREFERENCE_IGNORE_CONVERSION   (1<<1)
#define PARSEREFERENCE_STRICT_REFERENCE    (1<<2)
#define PARSEREFERENCE_PERFORM_CONVERSION  (1<<3)
#define PARSEREFERENCE_CHECK_CAPTURE_NAME  (1<<4)

static BOOL RKParseReference(const RKStringBuffer * const RK_C99(restrict) referenceBuffer, const NSRange referenceRange, const RKStringBuffer * const RK_C99(restrict) subjectBuffer,
                             const NSRange * const RK_C99(restrict) subjectMatchResultRanges, RKRegex * const RK_C99(restrict) regex, int * const RK_C99(restrict) parsedReferenceInt, void * const RK_C99(restrict) conversionPtr, const int parseReferenceOptions,
                             NSRange * const RK_C99(restrict) parsedRange, NSRange * const RK_C99(restrict) parsedReferenceRange, NSString ** const RK_C99(restrict) errorString,
                             void *** const RK_C99(restrict) autoreleasePool, unsigned int * const RK_C99(restrict) autoreleasePoolIndex);

#ifdef USE_CORE_FOUNDATION
static Boolean RKCFArrayEqualCallBack(const void *value1, const void *value2) { return(CFEqual(value1, value2)); }
static void RKTypeCollectionRelease(CFAllocatorRef allocator RK_ATTRIBUTES(unused), const void *ptr) { CFRelease(ptr); }
static const CFArrayCallBacks noRetainArrayCallBacks = {0, NULL, RKTypeCollectionRelease, NULL, RKCFArrayEqualCallBack};
#endif //USE_CORE_FOUNDATION

/* Although the docs claim NSDate is multithreading safe, testing indicates otherwise.  NSDate will mis-parse strings occasionally under heavy threaded access. */
static RKLock *stringNSDateLock                      = NULL;
static int     NSStringREExtensionsLoadInitialized = 0;

@implementation NSString (RegexKitAdditions)

//
// +load is called when the runtime first loads a class or category.
//

+ (void)load
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(NSStringREExtensionsLoadInitialized == 1) { return; }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &NSStringREExtensionsLoadInitialized)) {
    NSAutoreleasePool *lockPool = [[NSAutoreleasePool alloc] init];
    
    stringNSDateLock = [(RKLock *)NSAllocateObject([RKLock class], 0, NULL) init];
    
    [lockPool release];
    lockPool = NULL;
  }
}

//
// getCapturesWithRegexAndReferences: methods
//

- (BOOL)getCapturesWithRegexAndReferences:(id)aRegex, ...
{
  va_list varArgsList; va_start(varArgsList, aRegex);
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, NULL, aRegex, RKCompileDupNames, RKMatchNoOptions, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, varArgsList));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range references:(NSString * const)firstReference, ...
{
  va_list varArgsList; va_start(varArgsList, firstReference);
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, &range, aRegex, RKCompileDupNames, RKMatchNoOptions, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), firstReference, varArgsList));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range arguments:(va_list)argList
{
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, &range, aRegex, RKCompileDupNames, RKMatchNoOptions, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, argList));
}

//
// rangesOfRegex: methods
//

- (NSRange *)rangesOfRegex:(id)aRegex
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoOptions]);
}

- (NSRange *)rangesOfRegex:(id)aRegex inRange:(const NSRange)range
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:range options:RKMatchNoOptions]);
}

//
// rangeOfRegex: methods
//

- (NSRange)rangeOfRegex:(id)aRegex
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) captureIndex:0 options:RKMatchNoOptions]);
}

- (NSRange)rangeOfRegex:(id)aRegex inRange:(const NSRange)range capture:(const unsigned int)capture
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:range captureIndex:capture options:RKMatchNoOptions]);
}

//
// isMatchedByRegex: methods
//

- (BOOL)isMatchedByRegex:(id)aRegex
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoOptions]);
}

- (BOOL)isMatchedByRegex:(id)aRegex inRange:(const NSRange)range
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:range options:RKMatchNoOptions]);
}

//
// matchEnumeratorWithRegex: methods
//

-(RKEnumerator *)matchEnumeratorWithRegex:(id)aRegex
{
  return([RKEnumerator enumeratorWithRegex:aRegex string:self]);
}

-(RKEnumerator *)matchEnumeratorWithRegex:(id)aRegex inRange:(const NSRange)range
{
  return([RKEnumerator enumeratorWithRegex:aRegex string:self inRange:range]);
}

//
// stringByMatching:withReferenceString: methods
//

- (NSString *)stringByMatching:(id)aRegex withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,     1, aRegex, referenceString, NULL, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   1, aRegex, referenceString, NULL, NO, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const unsigned int)anIndex withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, 1, aRegex, referenceString, NULL, NO, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const unsigned int)anIndex withReferenceString:(NSString * const)string
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, 1, aRegex, referenceString, NULL, NO, NULL)); }

//
// stringByMatching:withReferenceFormat: methods
//

- (NSString *)stringByMatching:(id)aRegex withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,     1, aRegex, referenceFormatString, &argList, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   1, aRegex, referenceFormatString, &argList, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range, 1, aRegex, referenceFormatString, (va_list *)&argList, NO, NULL));  }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const unsigned int)anIndex withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, 1, aRegex, referenceFormatString, &argList, NO, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const unsigned int)anIndex withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, 1, aRegex, referenceFormatString, &argList, NO, NULL)); }

//
// stringByMatching:replace:withString: methods
//

- (NSString *)stringByMatching:(id)aRegex replace:(const unsigned int)count withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,     count, aRegex, referenceString, NULL, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceString, NULL, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const unsigned int)anIndex replace:(const unsigned int)count withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, count, aRegex, referenceString, NULL, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const unsigned int)anIndex replace:(const unsigned int)count withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, count, aRegex, referenceString, NULL, YES, NULL)); }

//
// stringByMatching:replace:withReferenceFormat: methods
//

- (NSString *)stringByMatching:(id)aRegex replace:(const unsigned int)count withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,    count, aRegex, referenceFormatString, &argList, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceFormatString, &argList, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range, count, aRegex, referenceFormatString, (va_list *)&argList, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const unsigned int)anIndex replace:(const unsigned int)count withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, count, aRegex, referenceFormatString, &argList, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const unsigned int)anIndex replace:(const unsigned int)count withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, count, aRegex, referenceFormatString, &argList, YES, NULL)); }

@end

/* NSMutableString additions */

@implementation NSMutableString (RegexKitAdditions)

//
// match:replace:withString: methods
//

-(unsigned int)match:(id)aRegex replace:(const unsigned int)count withString:(NSString * const)replaceString
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, NULL,     count, replaceString, NULL)); }

-(unsigned int)match:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withString:(NSString * const)replaceString
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range,   count, replaceString, NULL)); }

//-(unsigned int)match:(id)aRegex fromIndex:(const unsigned int)anIndex replace:(const unsigned int)count withString:(NSString * const)replaceString
//{ return(RKMutableStringMatch(self, _cmd, aRegex, &anIndex, NULL, NULL, count, replaceString, NULL)); }

//-(unsigned int)match:(id)aRegex toIndex:(const unsigned int)anIndex replace:(const unsigned int)count withString:(NSString * const)replaceString
//{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, &anIndex, NULL, count, replaceString, NULL)); }

//
// match:replace:withFormat: methods
//

-(unsigned int)match:(id)aRegex replace:(const unsigned int)count withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, NULL,     count, formatString, &argList)); }

-(unsigned int)match:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range,   count, formatString, &argList)); }

-(unsigned int)match:(id)aRegex inRange:(const NSRange)range replace:(const unsigned int)count withFormat:(NSString * const)formatString arguments:(va_list)argList
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range, count, formatString, (va_list *)&argList)); }

//-(unsigned int)match:(id)aRegex fromIndex:(const unsigned int)anIndex replace:(const unsigned int)count withFormat:(NSString * const)formatString, ...
//{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, &anIndex, NULL, NULL, count, formatString, &argList)); }

//-(unsigned int)match:(id)aRegex toIndex:(const unsigned int)anIndex replace:(const unsigned int)count withFormat:(NSString * const)formatString, ...
//{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, &anIndex, NULL, count, formatString, &argList)); }

@end

static unsigned int RKMutableStringMatch(id self, const SEL _cmd, id aRegex, const unsigned int * RK_C99(restrict) fromIndex, const unsigned int * RK_C99(restrict) toIndex, const NSRange * RK_C99(restrict) range, const unsigned int count, NSString * const RK_C99(restrict) formatString, va_list * const RK_C99(restrict) argListPtr) {
  unsigned int replaceCount = 0;
  NSString * RK_C99(restrict) replacedString = RKStringByMatchingAndExpanding(self, _cmd, self, fromIndex, toIndex, range, count, aRegex, formatString, argListPtr, YES, &replaceCount);
  if(replacedString == self) { return(0); }
#ifdef USE_CORE_FOUNDATION
  CFStringReplaceAll((CFMutableStringRef)self, (CFStringRef)replacedString);
#else
  [self setString:replacedString];
#endif //USE_CORE_FOUNDATION
  return(replaceCount);
}

/* Functions for performing various regex string tasks, most private. */


//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


static BOOL RKMatchAndExtractCaptureReferences(id self, const SEL _cmd, NSString * const RK_C99(restrict) extractString, const unsigned int * const RK_C99(restrict) fromIndex, const unsigned int * const RK_C99(restrict) toIndex, const NSRange * const RK_C99(restrict) range, id aRegex, const RKCompileOption compileOptions, const RKMatchOption matchOptions, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList) {
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) matchRanges = NULL, searchRange = NSMakeRange(NSNotFound, 0);
  RKStringBuffer stringBuffer;
  BOOL returnResult = NO;
  RKRegex *regex = NULL;
  unsigned int captureCount = 0;
  
  regex = RKRegexFromStringOrRegex(self, _cmd, aRegex, compileOptions, YES);

  if(RK_EXPECTED(regex == NULL, 0)) { goto exitNow; }

  captureCount = [regex captureCount];  
  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { goto exitNow; }
  
  stringBuffer = RKStringBufferWithString(extractString);
  if(RK_EXPECTED(stringBuffer.characters == NULL, 0)) { goto exitNow; }

  if((fromIndex == NULL) && (toIndex == NULL) && (range == NULL)) { searchRange = NSMakeRange(0, stringBuffer.length);                         }
  else if(range     != NULL)                                      { searchRange = *range;                                                    }
  else if(fromIndex != NULL)                                      { searchRange = NSMakeRange(*fromIndex, (stringBuffer.length - *fromIndex)); }
  else if(toIndex   != NULL)                                      { searchRange = NSMakeRange(0, *toIndex);                                    }
  
  if((matchErrorCode = [regex getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:stringBuffer.characters length:stringBuffer.length inRange:searchRange options:matchOptions]) <= 0) { goto exitNow; }
  
  returnResult = RKExtractCapturesFromMatchesWithKeyArguments(self, _cmd, (const RKStringBuffer *)&stringBuffer, regex, matchRanges, captureExtractOptions, firstKey, useVarArgsList);
  
exitNow:
    return(returnResult);
}

BOOL RKExtractCapturesFromMatchesWithKeyArguments(id self, const SEL _cmd, const RKStringBuffer * const RK_C99(restrict) stringBuffer, RKRegex * const RK_C99(restrict) regex, const NSRange * const RK_C99(restrict) matchRanges, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList) {
  unsigned int stringArgumentsCount = 0, count = 0, x = 0;
  void ***keyConversionPointers = NULL;
  NSString **keyStrings = NULL;
  va_list varArgsList;

  va_copy(varArgsList, useVarArgsList);
  if(firstKey != NULL)                           { stringArgumentsCount++; if(va_arg(varArgsList, void **) != NULL) { stringArgumentsCount++; } else { goto finishedCountingArgs; } }
  while(va_arg(varArgsList, NSString *) != NULL) { stringArgumentsCount++; if(va_arg(varArgsList, void **) != NULL) { stringArgumentsCount++; } else { break; } }
  va_end(varArgsList);
  
finishedCountingArgs:
  if(RK_EXPECTED((stringArgumentsCount & 0x1) == 1, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Not an even pair of key and pointer to a pointer arguments.") userInfo:NULL] raise]; }

  count = stringArgumentsCount / 2;
  
  if(RK_EXPECTED((keyStrings            = alloca(count * sizeof(NSString **))) == NULL, 0)) { goto errorExit; }
  if(RK_EXPECTED((keyConversionPointers = alloca(count * sizeof(void ***)))    == NULL, 0)) { goto errorExit; }
  
  va_copy(varArgsList, useVarArgsList);
  for(x = 0; x < count; x++) {
    if((firstKey != NULL) && (x == 0)) { keyStrings[x]            = firstKey;                        }
    else {                               keyStrings[x]            = va_arg(varArgsList, NSString *); }
                                         keyConversionPointers[x] = va_arg(varArgsList, void **);
  }
  va_end(varArgsList);
  
  return(RKExtractCapturesFromMatchesWithKeysAndPointers(self, _cmd, stringBuffer, regex, matchRanges, keyStrings, keyConversionPointers, count, captureExtractOptions));
  
errorExit:
    return(NO);
}

// Takes a set of match results and loops over all keys, parses them, and fills in the result.  parseReference does the heavy work and conversion
static BOOL RKExtractCapturesFromMatchesWithKeysAndPointers(id self, const SEL _cmd, const RKStringBuffer * const RK_C99(restrict) stringBuffer, RKRegex * const RK_C99(restrict) regex, const NSRange * const RK_C99(restrict) matchRanges, NSString ** const RK_C99(restrict) keyStrings, void *** const RK_C99(restrict) keyConversionPointers, const unsigned int count, const RKCaptureExtractOptions captureExtractOptions) {
  unsigned int x = 0, autoreleaseObjectsIndex = 0;
  NSException * RK_C99(restrict) throwException = NULL;
  void ** RK_C99(restrict) autoreleaseObjects = NULL;
  NSString *parseError = NULL;
  RKStringBuffer keyBuffer;
  BOOL returnResult = NO;
  const int parseReferenceOptions = ((((captureExtractOptions & RKCaptureExtractAllowConversions) != 0) ? PARSEREFERENCE_CONVERSION_ALLOWED : 0) |
                                     (((captureExtractOptions & RKCaptureExtractStrictReference) != 0) ? PARSEREFERENCE_STRICT_REFERENCE : 0) |
                                     (((captureExtractOptions & RKCaptureExtractIgnoreConversions) != 0) ? PARSEREFERENCE_IGNORE_CONVERSION : 0) |
                                     PARSEREFERENCE_PERFORM_CONVERSION | PARSEREFERENCE_CHECK_CAPTURE_NAME);
  
  NSCParameterAssert(RK_EXPECTED(self != NULL, 1) && RK_EXPECTED(_cmd != NULL, 1) && RK_EXPECTED(keyConversionPointers != NULL, 1) && RK_EXPECTED(keyStrings != NULL, 1) && RK_EXPECTED(stringBuffer != NULL, 1) && RK_EXPECTED(matchRanges != NULL, 1) && RK_EXPECTED(regex != NULL, 1));
  
  if(RK_EXPECTED((autoreleaseObjects = alloca(count * sizeof(void *))) == NULL, 0)) { goto exitNow; }

#ifdef USE_MACRO_EXCEPTIONS
NS_DURING
#else
@try {
#endif
  for(x = 0; x < count && RK_EXPECTED(throwException == NULL, 1); x++) {
    keyBuffer = RKStringBufferWithString(keyStrings[x]);
    if(RK_EXPECTED(RKParseReference((const RKStringBuffer *)&keyBuffer, NSMakeRange(0, keyBuffer.length), stringBuffer,
                                    matchRanges, regex, NULL, keyConversionPointers[x], parseReferenceOptions, NULL, NULL, &parseError,
                                    (void ***)autoreleaseObjects, &autoreleaseObjectsIndex) == NO, 0)) {
      // We hold off on raising the exception until we make sure we've autoreleased any objects we created, if necessary.
      throwException = [NSException exceptionWithName:RKRegexCaptureReferenceException reason:RKPrettyObjectMethodString(parseError) userInfo:NULL];
    }
  }
#ifdef USE_MACRO_EXCEPTIONS
NS_HANDLER
  throwException = localException;
NS_ENDHANDLER
#else
} @catch (NSException *exception) {
  throwException = exception;
}  
#endif //USE_MACRO_EXCEPTIONS

  
exitNow:
    
  if(autoreleaseObjectsIndex > 0) {
#ifdef USE_CORE_FOUNDATION
    [(id)CFArrayCreate(NULL, (const void **)&autoreleaseObjects[0], autoreleaseObjectsIndex, &noRetainArrayCallBacks) autorelease];
#else
    [NSArray arrayWithObjects:(id *)&autoreleaseObjects[0] count:autoreleaseObjectsIndex];
#endif //USE_CORE_FOUNDATION
  }
  
  if(RK_EXPECTED(throwException == NULL, 1)) { returnResult = YES; } else { [throwException raise]; }
  
  return(returnResult);
}


//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


/*!
@function RKStringByMatchingAndExpanding
 @abstract   This function forms the bulk of the search and replace machinery.
 @param      subjectString string to search
 @param      aRegex regex to use in performing matches
 @param      replaceWithString String to substitute for the matched string.  May contain references to matches via $# perl notation
 @param      replaceCount Pointer to an int if the number of replacements performed is needed, NULL otherwise.
 @result     Returns a new @link NSString NSString @/link with all the search and replaces applied.
 @discussion     <p>This function forms the bulk of the search and replace machinery.<p>
 <p>The high level overview of what happens is this function calls compileReferenceString which parses replaceWithString and assembles a list of instructions / operations to perform for each match.  For each match, a instructions to build a replacement string are built up instruction by instruction.  The first instruction copies the text inbetween the last match to the start of the current match. Replacement instructions are fairly simple, from copying verbatim a range of characters to appending the characters of a match. The instructions to build the replacement string are 'fully resolved' and consist only of verbatim copy operations. This continues until there are no more matches left.  The result is a list of instructions to process to create the finished, fully substituted string.</p>
 
 <p>The space to record the instructions to build the finished string are initially allocated off the stack.  If the number of instructions to complete the finished string is greater than the space allocated on the stack, the instructions are copied in to a NSMutableData buffer and that is grown as required.  The number of instructions allocated off the stack is determined by INITIAL_EDIT_INS.  This means that for the majority of cases the only time a call to malloc is required is at the very end, when its ready to process all of the instructions to create the replaced string.  Additionally, because only the ranges to be copied are recorded, no temporary buffers are create to keep intermediate results.</p>
*/

static NSString *RKStringByMatchingAndExpanding(id self, const SEL _cmd, NSString * const RK_C99(restrict) searchString, const unsigned int * const RK_C99(restrict) fromIndex, const unsigned int * const RK_C99(restrict) toIndex, const NSRange * const RK_C99(restrict) searchStringRange, const unsigned int count, id aRegex, NSString * const RK_C99(restrict) referenceString, va_list * const RK_C99(restrict) argListPtr, const BOOL expandOrReplace, unsigned int * const RK_C99(restrict) matchedCountPtr) {
  RKRegex * RK_C99(restrict) regex = RKRegexFromStringOrRegex(self, _cmd, aRegex, RKCompileDupNames, YES);
  RKStringBuffer searchStringBuffer, referenceStringBuffer;
  unsigned int searchIndex = 0, matchedCount = 0, captureCount = 0;
  NSRange * RK_C99(restrict) matchRanges = NULL, searchRange = NSMakeRange(NSNotFound, 0);
  RKMatchErrorCode matched;
  
  captureCount = [regex captureCount];
  if((matchRanges = alloca(sizeof(NSRange) * RK_PRESIZE_CAPTURE_COUNT(captureCount))) == NULL) { goto errorExit; }
  searchStringBuffer = RKStringBufferWithString(searchString);
  referenceStringBuffer = RKStringBufferWithString((argListPtr == NULL) ? referenceString : (NSString *)[[[NSString alloc] initWithFormat:referenceString arguments:*argListPtr] autorelease]);
  
  if(searchStringBuffer.characters == NULL) { goto errorExit; }
  if(referenceStringBuffer.characters == NULL) { goto errorExit; }
  
  if((fromIndex == NULL) && (toIndex == NULL) && (searchStringRange == NULL)) { searchRange = NSMakeRange(0, searchStringBuffer.length);                         }
  else if(searchStringRange != NULL)                                          { searchRange = *searchStringRange;                                                      }
  else if(fromIndex   != NULL)                                                { searchRange = NSMakeRange(*fromIndex, (searchStringBuffer.length - *fromIndex)); }
  else if(toIndex     != NULL)                                                { searchRange = NSMakeRange(0, *toIndex);                                           }
  
  RKReferenceInstruction stackReferenceInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKCopyInstruction stackCopyInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKReferenceInstructionsBuffer referenceInstructionsBuffer = RKMakeReferenceInstructionsBuffer(0, RK_DEFAULT_STACK_INSTRUCTIONS,    &stackReferenceInstructions[0], NULL);
  RKCopyInstructionsBuffer      copyInstructionsBuffer      = RKMakeCopyInstructionsBuffer(     0, RK_DEFAULT_STACK_INSTRUCTIONS, 0, &stackCopyInstructions[0],      NULL);
  
  if(RKCompileReferenceString(self, _cmd, &referenceStringBuffer, regex, &referenceInstructionsBuffer) == NO) { goto errorExit; }
  
  searchIndex = searchRange.location;
  
  if((expandOrReplace == YES) && (searchIndex != 0)) { if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, NSMakeRange(0, searchIndex)) == NO) { goto errorExit; } }
  
  while((searchIndex < (searchRange.location + searchRange.length)) && ((matchedCount < count) || (count == RKReplaceAll))) {
    if((matched = [regex getRanges:&matchRanges[0] count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:searchStringBuffer.characters length:searchStringBuffer.length inRange:NSMakeRange(searchIndex, (searchRange.location + searchRange.length) - searchIndex) options:RKMatchNoOptions]) < 0) {
      if(matched != RKMatchErrorNoError) { goto errorExit; }
      break;
    }
    
    if(expandOrReplace == YES) { if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, NSMakeRange(searchIndex, (matchRanges[0].location - searchIndex))) == NO) { goto errorExit; } }
    searchIndex = matchRanges[0].location + matchRanges[0].length;
    if(RKApplyReferenceInstructions(self, _cmd, regex, matchRanges, &searchStringBuffer, &referenceInstructionsBuffer, &copyInstructionsBuffer) == NO) { goto errorExit; }
    matchedCount++;
  }

  if(matchedCountPtr != NULL) { *matchedCountPtr = matchedCount; }

  if(expandOrReplace == YES) {
    if(copyInstructionsBuffer.length == 0) { return(searchString); } // There were no matches, so the replaced string == search string.
    if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, NSMakeRange(searchIndex, (searchStringBuffer.length - searchIndex))) == NO) { goto errorExit; }
  }
    
  return(RKStringFromCopyInstructions(self, _cmd, &copyInstructionsBuffer, searchStringBuffer.encoding));
errorExit:
    return(NULL);
}


NSString *RKStringFromReferenceString(id self, const SEL _cmd, RKRegex * const RK_C99(restrict) regex, const NSRange * const RK_C99(restrict) matchRanges, const RKStringBuffer * const RK_C99(restrict) matchStringBuffer, const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer) {
  RKReferenceInstruction stackReferenceInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKCopyInstruction stackCopyInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];

  RKReferenceInstructionsBuffer referenceInstructionsBuffer = RKMakeReferenceInstructionsBuffer(0, RK_DEFAULT_STACK_INSTRUCTIONS,    &stackReferenceInstructions[0], NULL);
  RKCopyInstructionsBuffer      copyInstructionsBuffer      = RKMakeCopyInstructionsBuffer(     0, RK_DEFAULT_STACK_INSTRUCTIONS, 0, &stackCopyInstructions[0],      NULL);
  
  if(RKCompileReferenceString(self, _cmd, referenceStringBuffer, regex, &referenceInstructionsBuffer) == NO) { goto errorExit; }
  if(RKApplyReferenceInstructions(self, _cmd, regex, matchRanges, matchStringBuffer, &referenceInstructionsBuffer, &copyInstructionsBuffer) == NO) { goto errorExit; }

  return(RKStringFromCopyInstructions(self, _cmd, &copyInstructionsBuffer, matchStringBuffer->encoding));

errorExit:
  return(NULL);
}


static NSString *RKStringFromCopyInstructions(id self, const SEL _cmd, const RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const RKStringBufferEncoding stringEncoding) {
  char * RK_C99(restrict) copyBuffer = NULL;
  
  if((copyBuffer = malloc(instructionsBuffer->copiedLength + 1)) == NULL) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate memory for final copied string.") userInfo:NULL] raise]; }

  RKEvaluateCopyInstructions(instructionsBuffer, copyBuffer, (instructionsBuffer->copiedLength + 1));

#ifdef USE_CORE_FOUNDATION
  NSString * RK_C99(restrict) copyString = [(id)CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, copyBuffer, stringEncoding, kCFAllocatorMalloc) autorelease];
#else
  NSString * RK_C99(restrict) copyString = [[[NSString alloc] initWithBytesNoCopy:copyBuffer length:instructionsBuffer->copiedLength encoding:stringEncoding freeWhenDone:YES] autorelease];
#endif
  
  return(copyString);
}

static void RKEvaluateCopyInstructions(const RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, void * const RK_C99(restrict) toBuffer, const size_t bufferLength) {
  NSCParameterAssert((instructionsBuffer != NULL) && (toBuffer != NULL) && (instructionsBuffer->isValid == YES) && (instructionsBuffer->instructions != NULL));
  unsigned int instructionIndex = 0, copyBufferIndex = 0;
  
  while((instructionIndex < instructionsBuffer->length) && (copyBufferIndex <= bufferLength)) {
    RKCopyInstruction * RK_C99(restrict) atInstruction = &instructionsBuffer->instructions[instructionIndex];
    NSCParameterAssert((atInstruction != NULL) && ((copyBufferIndex + atInstruction->length) <= instructionsBuffer->copiedLength) && ((copyBufferIndex + atInstruction->length) <= bufferLength));
    
    memcpy(toBuffer + copyBufferIndex, atInstruction->ptr, atInstruction->length);
    copyBufferIndex += atInstruction->length;
    instructionIndex++;
  }
  NSCParameterAssert(copyBufferIndex <= bufferLength);
  ((char *)toBuffer)[copyBufferIndex] = 0;
}


static BOOL RKApplyReferenceInstructions(id self, const SEL _cmd, RKRegex * const RK_C99(restrict) regex, const NSRange * const RK_C99(restrict) matchRanges, const RKStringBuffer * const RK_C99(restrict) stringBuffer,
                                         const RKReferenceInstructionsBuffer * const RK_C99(restrict) referenceInstructionsBuffer, RKCopyInstructionsBuffer * const RK_C99(restrict) appliedInstructionsBuffer) {
  unsigned int captureIndex = 0, instructionIndex = 0;
  
  while((referenceInstructionsBuffer->instructions[instructionIndex].op != OP_STOP) && (instructionIndex < referenceInstructionsBuffer->length)) {
    RKReferenceInstruction * RK_C99(restrict) atInstruction = &referenceInstructionsBuffer->instructions[instructionIndex];
    switch(atInstruction->op) {
      case OP_COPY_RANGE:        if(RKAppendCopyInstruction(appliedInstructionsBuffer, atInstruction->ptr,       atInstruction->range)                       == NO) { goto errorExit; } break;
      case OP_COPY_CAPTUREINDEX: if(RKAppendCopyInstruction(appliedInstructionsBuffer, stringBuffer->characters, matchRanges[atInstruction->range.location]) == NO) { goto errorExit; } break;
      case OP_COPY_CAPTURENAME : if((captureIndex = RKCaptureIndexForCaptureNameCharacters(regex, _cmd, atInstruction->ptr + atInstruction->range.location, atInstruction->range.length, matchRanges, YES)) == NSNotFound) { break; }
                                 if(RKAppendCopyInstruction(appliedInstructionsBuffer, stringBuffer->characters, matchRanges[captureIndex])                  == NO) { goto errorExit; } break;
      default: [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"Unknown edit op code encountered.") userInfo:NULL] raise];         break;
    }
    instructionIndex++;
  }
  
  return(YES);
  
errorExit:
  return(NO);
}


static BOOL RKCompileReferenceString(id self, const SEL _cmd, const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer, RKRegex * const RK_C99(restrict) regex, RKReferenceInstructionsBuffer * const RK_C99(restrict) instructionBuffer) {
  NSCParameterAssert((referenceStringBuffer != NULL) && (regex != NULL) && (instructionBuffer != NULL));
  NSRange currentRange = NSMakeRange(0,0), validVarRange, parsedVarRange;
  int referenceIndex = 0, parsedInt = 0;
  NSString *parseErrorString = NULL;
  
  while((unsigned int)referenceIndex < referenceStringBuffer->length) {
    if((referenceStringBuffer->characters[referenceIndex] == '$') && (referenceStringBuffer->characters[referenceIndex + 1] == '$')) {
      currentRange.length++;
      if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE, referenceStringBuffer->characters, currentRange) == NO) { goto errorExit; }
      referenceIndex += 2;
      currentRange = NSMakeRange(referenceIndex, 0);
      continue;
    } else if(referenceStringBuffer->characters[referenceIndex] == '$') {
      if(RKParseReference(referenceStringBuffer, NSMakeRange(referenceIndex, (referenceStringBuffer->length - referenceIndex)), NULL, NULL, regex, &parsedInt, NULL, PARSEREFERENCE_IGNORE_CONVERSION, &parsedVarRange, &validVarRange, &parseErrorString, NULL, NULL)) {
        if(currentRange.length > 0) { if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE,       referenceStringBuffer->characters, currentRange)                   == NO) { goto errorExit; } }
        if(parsedInt == -1) {         if(RKAppendInstruction(instructionBuffer, OP_COPY_CAPTURENAME, referenceStringBuffer->characters + referenceIndex, validVarRange) == NO) { goto errorExit; } }
        else {                        if(RKAppendInstruction(instructionBuffer, OP_COPY_CAPTUREINDEX, NULL,                                  NSMakeRange(parsedInt, 0)) == NO) { goto errorExit; } }
        
        referenceIndex += parsedVarRange.length;
        currentRange = NSMakeRange(referenceIndex, 0);
        continue;
      } else { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:RKPrettyObjectMethodString(parseErrorString) userInfo:NULL] raise]; }
    }
    
    referenceIndex++;
    currentRange.length++;
  }
  
  if(currentRange.length > 0) { if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE, referenceStringBuffer->characters, currentRange) == NO) { goto errorExit; } }

  return(YES);

errorExit:
  return(NO);
}

static BOOL RKAppendInstruction(RKReferenceInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const int op, const void * const RK_C99(restrict) ptr, const NSRange range) {
  NSCParameterAssert((instructionsBuffer != NULL) && (instructionsBuffer->length <= instructionsBuffer->capacity) && (instructionsBuffer->isValid == YES));
  
  if(instructionsBuffer->length >= instructionsBuffer->capacity) {
    if(instructionsBuffer->mutableData == NULL) {
      if((instructionsBuffer->mutableData = [NSMutableData dataWithLength:(sizeof(RKReferenceInstruction) * (instructionsBuffer->capacity + 16))]) == NULL) { goto errorExit; }
      if((instructionsBuffer->instructions != NULL) && (instructionsBuffer->capacity > 0)) {
        [instructionsBuffer->mutableData appendBytes:instructionsBuffer->instructions length:(sizeof(RKReferenceInstruction) * instructionsBuffer->capacity)];
      }
      instructionsBuffer->capacity += 16;
    }
    else { [instructionsBuffer->mutableData increaseLengthBy:(sizeof(RKReferenceInstruction) * 16)]; instructionsBuffer->capacity += 16; }
    if((instructionsBuffer->instructions = [instructionsBuffer->mutableData mutableBytes]) == NULL) { goto errorExit; }
  }
  
  instructionsBuffer->instructions[instructionsBuffer->length].op    = op;
  instructionsBuffer->instructions[instructionsBuffer->length].ptr   = ptr;
  instructionsBuffer->instructions[instructionsBuffer->length].range = range;
  instructionsBuffer->length++;
  
  return(YES);
  
errorExit:
  instructionsBuffer->isValid = NO;
  return(NO);
}

static BOOL RKAppendCopyInstruction(RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const void * const RK_C99(restrict) ptr, const NSRange range) {
  NSCParameterAssert((instructionsBuffer != NULL) && (instructionsBuffer->length <= instructionsBuffer->capacity) && (instructionsBuffer->isValid == YES));
  
  if(instructionsBuffer->length >= instructionsBuffer->capacity) {
    if(instructionsBuffer->mutableData == NULL) {
      if((instructionsBuffer->mutableData = [NSMutableData dataWithLength:(sizeof(RKReferenceInstruction) * (instructionsBuffer->capacity + 16))]) == NULL) { goto errorExit; }
      if((instructionsBuffer->instructions != NULL) && (instructionsBuffer->capacity > 0)) {
        [instructionsBuffer->mutableData appendBytes:instructionsBuffer->instructions length:(sizeof(RKReferenceInstruction) * instructionsBuffer->capacity)];
      }
      instructionsBuffer->capacity += 16;
    }
    else { [instructionsBuffer->mutableData increaseLengthBy:(sizeof(RKReferenceInstruction) * 16)]; instructionsBuffer->capacity += 16; }
    if((instructionsBuffer->instructions = [instructionsBuffer->mutableData mutableBytes]) == NULL) { goto errorExit; }
  }
  
  instructionsBuffer->instructions[instructionsBuffer->length].ptr    = (ptr + range.location);
  instructionsBuffer->instructions[instructionsBuffer->length].length = range.length;
  instructionsBuffer->copiedLength += instructionsBuffer->instructions[instructionsBuffer->length].length;
  instructionsBuffer->length++;

  return(YES);
  
errorExit:
    instructionsBuffer->isValid = NO;
    return(NO);
}



//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


static BOOL RKParseReference(const RKStringBuffer * const RK_C99(restrict) referenceBuffer, const NSRange referenceRange, const RKStringBuffer * const RK_C99(restrict) subjectBuffer,
                             const NSRange * const RK_C99(restrict) subjectMatchResultRanges, RKRegex * const RK_C99(restrict) regex, int * const RK_C99(restrict) parsedReferenceInt, void * const RK_C99(restrict) conversionPtr, const int parseReferenceOptions,
                             NSRange * const RK_C99(restrict) parsedRange, NSRange * const RK_C99(restrict) parsedReferenceRange, NSString ** const RK_C99(restrict) errorString,
                             void *** const RK_C99(restrict) autoreleasePool, unsigned int * const RK_C99(restrict) autoreleasePoolIndex) {
  const RKStringBuffer rBuffer = RKMakeStringBuffer(referenceBuffer->string, referenceBuffer->characters + referenceRange.location, referenceRange.length, referenceBuffer->encoding);
  NSString * RK_C99(restrict) tempErrorString = NULL;
  const BOOL conversionAllowed = (parseReferenceOptions & PARSEREFERENCE_CONVERSION_ALLOWED) != 0 ? YES : NO;
  const BOOL ignoreConversion  = (parseReferenceOptions & PARSEREFERENCE_IGNORE_CONVERSION)  != 0 ? YES : NO;
  const BOOL strictReference   = (parseReferenceOptions & PARSEREFERENCE_STRICT_REFERENCE)   != 0 ? YES : NO;
  const BOOL performConversion = (parseReferenceOptions & PARSEREFERENCE_PERFORM_CONVERSION) != 0 ? YES : NO;
  const BOOL checkCaptureName  = (parseReferenceOptions & PARSEREFERENCE_CHECK_CAPTURE_NAME) != 0 ? YES : NO;
  BOOL successfulParse = NO, createMutableConvertedString = NO;
  int referenceInt = 0;
  
  const char *atPtr = rBuffer.characters, *startReference = atPtr, *endReference = atPtr, *startBracket = NULL, *endBracket = NULL, *startFormat = NULL, *endFormat = NULL;
  
  if(parsedRange != NULL) { *parsedRange = NSMakeRange(0, 0); }
  if(parsedReferenceRange != NULL) { *parsedReferenceRange = NSMakeRange(0, 0); }
  if(RK_EXPECTED(errorString != NULL, 1)) { *errorString = NULL; }
  if(parsedReferenceInt != NULL) { *parsedReferenceInt = -1; }

  if(RK_EXPECTED(*atPtr != '$', 0)) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
  
  if(RK_EXPECTED((*(atPtr + 1) >= '0'), 1) && (*(atPtr + 1) <= '9') && ((*(atPtr + 2) == 0) || (strictReference == NO))) { referenceInt = (*(atPtr + 1) - '0'); startReference = atPtr + 1; atPtr += 2; endReference = atPtr; goto finishedParse; } // Fast path $[0-9]

  if(RK_EXPECTED(*(atPtr + 1) != '{', 0)) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }

  if(RK_EXPECTED((*(atPtr + 2) >= '0'), 1) && (*(atPtr + 2) <= '9') && (*(atPtr + 3) == '}') && ((*(atPtr + 4) == 0) || (strictReference == NO))) { referenceInt = (*(atPtr + 2) - '0'); startReference = atPtr + 2; endReference = atPtr + 3; atPtr += 4; goto finishedParse; } // Fast path ${[0-9]}

  startBracket = atPtr+1;
  startReference = atPtr+2;
  atPtr += 2;
  
  while(((atPtr - rBuffer.characters) < (int)rBuffer.length) && (*atPtr != 0) && (*atPtr != ':') && (*atPtr != '}')) {
    if((referenceInt != -1) && (RK_EXPECTED((*atPtr >= '0'), 1) && (*atPtr <= '9'))) { referenceInt = ((referenceInt * 10) + (*atPtr - '0')); atPtr++; continue; }
    if((((*atPtr | 0x20) >= 'a') && ((*atPtr | 0x20) <= 'z')) || (*atPtr == '_') || ((referenceInt == -1 ) && RK_EXPECTED((*atPtr >= '0'), 1) && (*atPtr <= '9'))) { referenceInt = -1; atPtr++; continue; }
    break;
  }

  endReference = atPtr;

  if(RK_EXPECTED((endReference - startReference) == 0, 0)) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
  if((*atPtr == ':') && (conversionAllowed == NO) && (ignoreConversion == NO)) { tempErrorString = [NSString stringWithFormat:@"Type conversion is not permitted for capture reference '%*.*s' in this context.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }

  if((conversionAllowed == YES) && (*atPtr == ':')) {
    atPtr++;
    if((*atPtr == '%') || (*atPtr == '@')) {
      startFormat = atPtr; while(((atPtr - rBuffer.characters) < (int)rBuffer.length) && (*atPtr != 0) && (*atPtr != '}')) { atPtr++; } endFormat = atPtr;
      if((endFormat - startFormat) == 1) { tempErrorString = [NSString stringWithFormat:@"The conversion format of capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
    } else { tempErrorString = [NSString stringWithFormat:@"The conversion format of capture reference '%*.*s' is not valid. Valid formats begin with '@' or '%%'.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
  }
  
  if(*atPtr == '}') { atPtr++; endBracket = atPtr; }
  
  if(RK_EXPECTED((startBracket != NULL), 1) && RK_EXPECTED(((endBracket - startBracket) == 0), 0)) { tempErrorString = [NSString stringWithFormat:@"The conversion format of capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }

  if(RK_EXPECTED((startBracket != NULL), 1) && RK_EXPECTED((endBracket == NULL), 0)) {
    while(((atPtr - rBuffer.characters) < (int)rBuffer.length) && (*atPtr != 0) && (*atPtr != '}')) { atPtr++; }
    if(*atPtr == '}') { 
      if(conversionAllowed == NO) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
      else { endBracket = atPtr; tempErrorString = [NSString stringWithFormat:@"The conversion format of capture reference '%*.*s' is not valid.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
    }
  }

  if((RK_EXPECTED((startBracket == NULL), 0) && RK_EXPECTED((endBracket != NULL), 1)) || (RK_EXPECTED((startBracket != NULL), 1) && RK_EXPECTED((endBracket == NULL), 0))) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' has unbalanced curly brackets.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }

finishedParse:
  
  if((referenceInt == -1) && (regex != NULL)) {

    if(subjectMatchResultRanges != NULL) {
      if(RK_EXPECTED((referenceInt = RKCaptureIndexForCaptureNameCharacters(regex, NULL, startReference, (endReference - startReference), NULL, NO)) == NSNotFound, 0)) {
        referenceInt = -1;
        tempErrorString = [NSString stringWithFormat:@"The named capture '%*.*s' from capture reference '%*.*s' is not defined by the regular expression.", (endReference - startReference), (endReference - startReference), startReference, rBuffer.length, rBuffer.length, rBuffer.characters];
        goto finishedParseError;
      }
    } else if(checkCaptureName == YES) {
      if(RK_EXPECTED(RKCaptureIndexForCaptureNameCharacters(regex, NULL, startReference, (endReference - startReference), NULL, NO) == NSNotFound, 0)) {
        referenceInt = -1;
        tempErrorString = [NSString stringWithFormat:@"The named capture '%*.*s' from capture reference '%*.*s' is not defined by the regular expression.", (endReference - startReference), (endReference - startReference), startReference, rBuffer.length, rBuffer.length, rBuffer.characters];
        goto finishedParseError;
      }
    }
  }
    
  if(RK_EXPECTED(referenceInt >= (int)[regex captureCount], 0)) { tempErrorString = [NSString stringWithFormat:@"The capture reference '%*.*s' specifies a capture subpattern '%d' that is greater than number of capture subpatterns defined by the regular expression, '%d'.", rBuffer.length, rBuffer.length, rBuffer.characters, referenceInt, max(0, ((int)[regex captureCount] - 1))]; goto finishedParseError; }

  if((performConversion == YES) && (subjectMatchResultRanges[referenceInt].location != NSNotFound)) {
    NSCParameterAssert((subjectMatchResultRanges[referenceInt].location + subjectMatchResultRanges[referenceInt].length) <= subjectBuffer->length);

    id convertedString = NULL;

    if(startFormat != NULL) {
      if(*startFormat == '%') {
        char * RK_C99(restrict) convertBuffer = NULL, convertStackBuffer[4096];
        const char * RK_C99(restrict) convertPtr = (subjectBuffer->characters + subjectMatchResultRanges[referenceInt].location);
        unsigned int convertLength = subjectMatchResultRanges[referenceInt].length;
        char * RK_C99(restrict) formatBuffer = NULL, formatStackBuffer[4096]; // If it fits in our *stackBuffer, use that, otherwise grab an autoreleasedMalloc to hold the characters.

        if(RK_EXPECTED(convertLength < 4092, 1)) { memcpy(&convertStackBuffer[0], convertPtr, convertLength); convertBuffer = &convertStackBuffer[0]; }
        else { convertBuffer = RKAutoreleasedMalloc(convertLength + 1); memcpy(&convertBuffer[0], convertPtr, convertLength); }
        convertBuffer[convertLength] = 0;
        
        if(RK_EXPECTED((endFormat - startFormat) < 4092, 1)) { memcpy(&formatStackBuffer[0], startFormat, (endFormat - startFormat)); formatBuffer = &formatStackBuffer[0]; } 
        else { formatBuffer = RKAutoreleasedMalloc((endFormat - startFormat) + 1); memcpy(&formatBuffer[0], startFormat, (endFormat - startFormat)); }
        formatBuffer[(endFormat - startFormat)] = 0;
        
        if(RK_EXPECTED((convertBuffer != NULL), 1) && RK_EXPECTED((formatBuffer != NULL), 1)) {
          if(formatBuffer[2] == 0) { // Fast, inline bypass if it's a simple conversion.
            BOOL unsignedConversion = NO;
            
            switch(formatBuffer[1]) {
              case 'u': unsignedConversion = YES; // Fall-thru
              case 'x': unsignedConversion = YES; // Fall-thru
              case 'X': unsignedConversion = YES; // Fall-thru 
              case 'd': // Fall-thru
              case 'i': // Fall-thru
              case 'o':
              { // Modified from the libc conversion routine.
                int neg = 0, any = 0, cutlim = 0, base = 0;
                const char * RK_C99(restrict) s = &convertBuffer[0];
                unsigned long acc = 0, cutoff = 0;
                char c = 0;
                
                do { c = *s++; } while (isspace((unsigned char)c));
                if(c == '-') { neg = 1; c = *s++; } else if (c == '+') { c = *s++; } 
                if(c == '0' && (*s == 'x' || *s == 'X')) { c = s[1]; s += 2; base = 16; } else { base = c == '0' ? 8 : 10; }

                if(unsignedConversion == YES) { cutoff = ULONG_MAX / base; cutlim = ULONG_MAX % base; } 
                else { cutoff = (neg ? (unsigned long)-(LONG_MIN + LONG_MAX) + LONG_MAX : LONG_MAX) / base; cutlim = cutoff % base; }

                do {
                  if(c >= '0' && c <= '9') { c -= '0'; } else if(c >= 'A' && c <= 'F') { c -= 'A' - 10; } else if(c >= 'a' && c <= 'f') { c -= 'a' - 10; } else { break; }
                  if(c >= base) {  break; }
                  if(any < 0 || acc > cutoff || (acc == cutoff && c > cutlim)) { any = -1; }
                  else { any = 1; acc *= base; acc += c; }
                } while((c = *s++) != 0);

                if(any < 0) { if(unsignedConversion == YES) { acc = ULONG_MAX; } else { acc = neg ? LONG_MIN : LONG_MAX; } } else if(neg) { acc = -acc; }
                
                *((int *)conversionPtr) = acc;
                goto finishedParseSuccess;
              }
                break;
              default: break; // Will fall thru to sscanf if we didn't convert it here.
            }
          }
          sscanf(convertBuffer, formatBuffer, conversionPtr); 
        }
        goto finishedParseSuccess;
      }
      
      NSCParameterAssert(endFormat != NULL);
      
      // Before we create a string, check if it's something reasonable.
      if( ! ( RK_EXPECTED((*startFormat == '@'), 1) && 
              ( ((*(endFormat - 1) == 'n') && (((startFormat + 1) == (endFormat - 1)) || ((startFormat + 2) == (endFormat - 1)))) ||
                ((*(endFormat - 1) == 'd') && ((startFormat + 1) == (endFormat - 1))) ))) {
        tempErrorString = [NSString stringWithFormat:@"Unknown type conversion requested in capture reference '%*.*s'.", rBuffer.length, rBuffer.length, rBuffer.characters];
        goto finishedParseError;
      }
    }

#ifdef USE_CORE_FOUNDATION
    if(RK_EXPECTED(createMutableConvertedString == NO, 1)) { convertedString = (id)CFStringCreateWithBytes(NULL, (const UInt8 *)(&subjectBuffer->characters[subjectMatchResultRanges[referenceInt].location]), subjectMatchResultRanges[referenceInt].length, subjectBuffer->encoding, YES); } 
    else { convertedString = [[NSMutableString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[referenceInt].location] length:subjectMatchResultRanges[referenceInt].length encoding:CFStringConvertEncodingToNSStringEncoding(subjectBuffer->encoding)]; }
#else
    if(RK_EXPECTED(createMutableConvertedString == YES, 0)) { convertedString = [[NSMutableString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[referenceInt].location] length:subjectMatchResultRanges[referenceInt].length encoding:subjectBuffer->encoding]; }
    else { convertedString = [[NSString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[referenceInt].location] length:subjectMatchResultRanges[referenceInt].length encoding:subjectBuffer->encoding]; }
#endif
    if(autoreleasePool != NULL) { autoreleasePool[*autoreleasePoolIndex] = (void *)convertedString; *autoreleasePoolIndex = *autoreleasePoolIndex + 1; } else { [convertedString autorelease]; }

    if(startFormat == NULL) { *((NSString **)conversionPtr) = convertedString; goto finishedParseSuccess; }
    
    if(RK_EXPECTED((*startFormat == '@'), 1) && RK_EXPECTED((*(endFormat - 1) == 'd'), 1) && RK_EXPECTED(((startFormat + 1) == (endFormat - 1)), 1)) {
      static BOOL didPrintLockWarning = NO;
      if(RK_EXPECTED(RKFastLock(stringNSDateLock) == NO, 0)) {
        if(didPrintLockWarning == NO) { NSLog(@"Unable to acquire the NSDate access serialization lock.  Heavy concurrent date conversions may return incorrect results."); didPrintLockWarning = YES; }
      }
      *((NSDate **)conversionPtr) = [NSDate dateWithNaturalLanguageString:convertedString];
      RKFastUnlock(stringNSDateLock);
      goto finishedParseSuccess;
    }
#ifdef HAVE_NSNUMBERFORMATTER_CONVERSIONS
    else if(RK_EXPECTED((*startFormat == '@'), 1) && (*(endFormat - 1) == 'n') && (((startFormat + 1) == (endFormat - 1)) || ((startFormat + 2) == (endFormat - 1)))) {
      struct __RKThreadLocalData * RK_C99(restrict) tld = RKGetThreadLocalData();
      if(RK_EXPECTED(tld == NULL, 0)) { goto finishedParseError; }
      NSNumberFormatter * RK_C99(restrict) numberFormatter = RK_EXPECTED((tld->_numberFormatter == NULL), 0) ? RKGetThreadLocalNumberFormatter() : tld->_numberFormatter;
      if((startFormat + 1) != (endFormat - 1)) {
        switch(*(startFormat + 1)) {
          case '.': if(tld->_currentFormatterStyle != NSNumberFormatterDecimalStyle) { tld->_currentFormatterStyle = NSNumberFormatterDecimalStyle; [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle]; } break;
          case '$': if(tld->_currentFormatterStyle != NSNumberFormatterCurrencyStyle) { tld->_currentFormatterStyle = NSNumberFormatterCurrencyStyle; [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle]; } break;
          case '%': if(tld->_currentFormatterStyle != NSNumberFormatterPercentStyle) { tld->_currentFormatterStyle = NSNumberFormatterPercentStyle; [numberFormatter setNumberStyle:NSNumberFormatterPercentStyle]; } break;
          case 's': if(tld->_currentFormatterStyle != NSNumberFormatterScientificStyle) { tld->_currentFormatterStyle = NSNumberFormatterScientificStyle; [numberFormatter setNumberStyle:NSNumberFormatterScientificStyle]; } break;
          case 'w': if(tld->_currentFormatterStyle != NSNumberFormatterSpellOutStyle) { tld->_currentFormatterStyle = NSNumberFormatterSpellOutStyle; [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle]; } break;
          default: tempErrorString = [NSString stringWithFormat:@"Capture reference '%*.*s' NSNumber conversion is invalid. Valid NSNumber conversion options are '.$%%ew'.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; break;
        }
      } else { if(tld->_currentFormatterStyle != NSNumberFormatterNoStyle) { tld->_currentFormatterStyle = NSNumberFormatterNoStyle; [numberFormatter setNumberStyle:NSNumberFormatterNoStyle]; } }
      *((NSNumber **)conversionPtr) = [numberFormatter numberFromString:convertedString];
      goto finishedParseSuccess;
    }
#endif // HAVE_NSNUMBERFORMATTER_CONVERSIONS
    else { tempErrorString = [NSString stringWithFormat:@"Unknown type conversion requested in capture reference '%*.*s'.", rBuffer.length, rBuffer.length, rBuffer.characters]; goto finishedParseError; }
  }
   
finishedParseSuccess:
  successfulParse = YES;
  goto finishedExit;
  
finishedParseError:
  if(RK_EXPECTED(errorString != NULL, 1)) { *errorString = tempErrorString; }
  
  successfulParse = NO;
  goto finishedExit;
  
finishedExit:

  if(parsedRange != NULL) { *parsedRange = NSMakeRange(0, (atPtr - rBuffer.characters)); }
  if(parsedReferenceRange != NULL) { *parsedReferenceRange = NSMakeRange(startReference - rBuffer.characters, (endReference - startReference)); }
  if(parsedReferenceInt != NULL) { *parsedReferenceInt = referenceInt; }
  
  return(successfulParse);
}

#ifdef REGEXKIT_DEBUG

static void dumpReferenceInstructions(const RKReferenceInstructionsBuffer *ins) {
  if(ins == NULL) { NSLog(@"NULL replacement instructions"); return; }
  NSLog(@"Replacement instructions");
  NSLog(@"isValid     : %@", RKYesOrNo(ins->isValid));
  NSLog(@"Length      : %u", ins->length);
  NSLog(@"Capacity    : %u", ins->capacity);
  NSLog(@"Instructions: 0x%8.8x", ins->instructions);
  NSLog(@"mutableData : 0x%8.8x", ins->mutableData);
  
  for(unsigned int x = 0; x < ins->length; x++) {
    RKReferenceInstruction *at = &ins->instructions[x];
    NSMutableString *logString = [NSMutableString stringWithFormat:@"op: %d ptr: 0x%8.8x range {%6u, %6u} ", at->op, at->ptr, at->range.location, at->range.length];
    switch(at->op) {
      case OP_STOP: [logString appendFormat:@"Stop"]; break;
      case OP_COPY_CAPTUREINDEX: [logString appendFormat:@"Capture Index #%d", at->range.location]; break;
      case OP_COPY_CAPTURENAME: [logString appendFormat:@"Capture Name '%@'", at->ptr]; break;
      case OP_COPY_RANGE: [logString appendFormat:@"Copy range: ptr: 0x%8.8x length: %u '%*.*s'", at->ptr + at->range.location, at->range.length, at->range.length, at->range.length, at->ptr + at->range.location]; break;
      case OP_COMMENT: [logString appendFormat:@"Comment"]; break;
      default: [logString appendFormat:@"UNKNOWN"]; break;
    }
    NSLog(@"%@", logString);
  }
}


static void dumpCopyInstructions(const RKCopyInstructionsBuffer *ins) {
  if(ins == NULL) { NSLog(@"NULL copy instructions"); return; }
  NSLog(@"Copy instructions");
  NSLog(@"isValid      : %@", RKYesOrNo(ins->isValid));
  NSLog(@"Length       : %u", ins->length);
  NSLog(@"Capacity     : %u", ins->capacity);
  NSLog(@"Copied length: %z", ins->copiedLength);
  NSLog(@"Instructions : 0x%8.8x", ins->instructions);
  NSLog(@"mutableData  : 0x%8.8x", ins->mutableData);
  
  for(unsigned int x = 0; x < ins->length; x++) {
    RKCopyInstructions *at = &ins->instructions[x];
    NSLog(@"ptr: 0x%8.8x - 0x%8.8x length %u (0x%8.8x)", at->ptr, at->ptr + at->length, at->length, at->length); 
  }
}

#endif //REGEXKIT_DEBUG
