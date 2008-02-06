//
//  NSString.m
//  RegexKit
//  http://regexkit.sourceforge.net/
//

/*
 Copyright © 2007-2008, John Engelhart
 
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

static BOOL RKMatchAndExtractCaptureReferences(id self, const SEL _cmd, NSString * const extractString, RK_STRONG_REF const RKUInteger * const fromIndex, RK_STRONG_REF const RKUInteger * const toIndex, RK_STRONG_REF const NSRange * const range, id aRegex, const RKCompileOption compileOptions, const RKMatchOption matchOptions, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList);
static BOOL RKMatchAndExtractCaptureReferencesX(id self, const SEL _cmd, NSString * const extractString, RK_STRONG_REF const RKUInteger * const fromIndex, RK_STRONG_REF const RKUInteger * const toIndex, RK_STRONG_REF const NSRange * const range, id aRegex, const RKCompileOption compileOptions, const RKMatchOption matchOptions, const RKCaptureExtractOptions captureExtractOptions, NSString * const firstKey, va_list useVarArgsList, NSError **error);
static BOOL RKExtractCapturesFromMatchesWithKeysAndPointers(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) stringBuffer,
                                                            RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges,
                                                            NSString ** const RK_C99(restrict) keyStrings, RK_STRONG_REF void *** const RK_C99(restrict) keyConversionPointers,
                                                            const RKUInteger count, const RKCaptureExtractOptions captureExtractOptions, NSError **error);

static NSString *RKStringByMatchingAndExpanding(id self, const SEL _cmd, NSString * const searchString, RK_STRONG_REF const RKUInteger * const fromIndex, RK_STRONG_REF const RKUInteger * const toIndex, RK_STRONG_REF const NSRange * const searchStringRange, const RKUInteger count, id aRegex, NSString * const referenceString, RK_STRONG_REF va_list * const argListPtr, const BOOL expandOrReplace, RK_STRONG_REF RKUInteger * const matchedCountPtr);
static NSString *RKStringByMatchingAndExpandingX(id self, const SEL _cmd, NSString * const searchString, RK_STRONG_REF const RKUInteger * const fromIndex, RK_STRONG_REF const RKUInteger * const toIndex, RK_STRONG_REF const NSRange * const searchStringRange, const RKUInteger count, id aRegex, NSString * const referenceString, RK_STRONG_REF va_list * const argListPtr, const BOOL expandOrReplace, RK_STRONG_REF RKUInteger * const matchedCountPtr, NSError **error);
static void RKEvaluateCopyInstructions(RK_STRONG_REF const RKCopyInstructionsBuffer * const instructionsBuffer, RK_STRONG_REF void * const toBuffer, const size_t bufferLength);
static NSString *RKStringFromCopyInstructions(id self, const SEL _cmd, RK_STRONG_REF const RKCopyInstructionsBuffer * const instructionsBuffer, const RKStringBufferEncoding stringEncoding) RK_ATTRIBUTES(malloc);
static NSString *RKStringFromCopyInstructionsX(id self, const SEL _cmd, RK_STRONG_REF const RKCopyInstructionsBuffer * const instructionsBuffer, const RKStringBufferEncoding stringEncoding, NSError **error) RK_ATTRIBUTES(malloc);
static BOOL RKApplyReferenceInstructions(id self, const SEL _cmd, RKRegex * const regex, RK_STRONG_REF const NSRange * const matchRanges, RK_STRONG_REF const RKStringBuffer * const stringBuffer,
                                         RK_STRONG_REF const RKReferenceInstructionsBuffer * const referenceInstructionsBuffer, RK_STRONG_REF RKCopyInstructionsBuffer * const appliedInstructionsBuffer);
static BOOL RKCompileReferenceString(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const referenceStringBuffer, RKRegex * const regex,\
                                     RK_STRONG_REF RKReferenceInstructionsBuffer * const instructionBuffer);
static BOOL RKCompileReferenceStringX(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const referenceStringBuffer, RKRegex * const regex,\
                                     RK_STRONG_REF RKReferenceInstructionsBuffer * const instructionBuffer, NSError **error);
static BOOL RKAppendInstruction(RK_STRONG_REF RKReferenceInstructionsBuffer * const instructionsBuffer, const int op, RK_STRONG_REF const void * const ptr, const NSRange range);
static BOOL RKAppendCopyInstruction(RK_STRONG_REF RKCopyInstructionsBuffer * const copyInstructionsBuffer, RK_STRONG_REF const void * const ptr, const NSRange range);
static RKUInteger RKMutableStringMatch(id self, const SEL _cmd, id aRegex,
                                       RK_STRONG_REF const RKUInteger * RK_C99(restrict) fromIndex, RK_STRONG_REF const RKUInteger * RK_C99(restrict) toIndex,
                                       RK_STRONG_REF const NSRange * RK_C99(restrict) range, const RKUInteger count,
                                       NSString * const RK_C99(restrict) formatString, RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr);
static RKUInteger RKMutableStringMatchX(id self, const SEL _cmd, id aRegex,
                                       RK_STRONG_REF const RKUInteger * RK_C99(restrict) fromIndex, RK_STRONG_REF const RKUInteger * RK_C99(restrict) toIndex,
                                       RK_STRONG_REF const NSRange * RK_C99(restrict) range, const RKUInteger count,
                                       NSString * const RK_C99(restrict) formatString, RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr, NSError **error);

#ifdef REGEXKIT_DEBUG
static void dumpReferenceInstructions(RK_STRONG_REF const RKReferenceInstructionsBuffer *ins);
static void dumpCopyInstructions(RK_STRONG_REF const RKCopyInstructionsBuffer *ins);
#endif // REGEXKIT_DEBUG

/*************** End match and replace operations ***************/

enum _parseErrorMessage {
  RKParseErrorNotValid                        = 0,
  RKParseErrorTypeConversionNotPermitted      = 1,
  RKParseErrorConversionFormatNotValid        = 2,
  RKParseErrorConversionFormatValidBeginsWith = 3,
  RKParseErrorUnbalancedCurlyBrackets         = 4,
  RKParseErrorNamedCaptureUndefined           = 5,
  RKParseErrorCaptureGreaterThanRegexCaptures = 6,
  RKParseErrorStoragePointerNull              = 7,
  RKParseErrorUnknownTypeConversion           = 8,
  RKParseErrorNSNumberConversionNotValid      = 9
};

typedef RKUInteger RKParseErrorMessage;

enum _parseReferenceFlags {
 RKParseReferenceConversionAllowed = (1<<0),
 RKParseReferenceIgnoreConversion  = (1<<1),
 RKParseReferenceStrictReference   = (1<<2),
 RKParseReferencePerformConversion = (1<<3),
 RKParseReferenceCheckCaptureName  = (1<<4)
};

typedef RKUInteger RKParseReferenceFlags;

static BOOL RKParseReference(RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceBuffer, const NSRange referenceRange,
                             RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) subjectBuffer, RK_STRONG_REF const NSRange * const RK_C99(restrict) subjectMatchResultRanges,
                             RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF RKUInteger * const RK_C99(restrict) parsedReferenceUInteger,
                             RK_STRONG_REF void * const RK_C99(restrict) conversionPtr, const RKParseReferenceFlags parseReferenceOptions, RK_STRONG_REF NSRange * const RK_C99(restrict) parsedRange,
                             RK_STRONG_REF NSRange * const RK_C99(restrict) parsedReferenceRange, NSString ** const RK_C99(restrict) errorString,
                             RK_STRONG_REF void *** const RK_C99(restrict) autoreleasePool, RK_STRONG_REF RKUInteger * const RK_C99(restrict) autoreleasePoolIndex, NSError **error);

/* Although the docs claim NSDate is multithreading safe, testing indicates otherwise.  NSDate will mis-parse strings occasionally under heavy threaded access. */
static RKLock RK_STRONG_REF *NSStringRKExtensionsNSDateLock  = NULL;
static              int32_t  NSStringRKExtensionsInitialized = 0;

#ifdef USE_CORE_FOUNDATION
static Boolean          RKCFArrayEqualCallBack  (const void *value1,                             const void *value2) { return(CFEqual(value1, value2));                             }
static void             RKTypeCollectionRelease (CFAllocatorRef allocator RK_ATTRIBUTES(unused), const void *ptr)    { RKCFRelease(ptr);                                            }
static CFArrayCallBacks noRetainArrayCallBacks =                                                                     {0, NULL, RKTypeCollectionRelease, NULL, RKCFArrayEqualCallBack};
#endif // USE_CORE_FOUNDATION

@implementation NSString (RegexKitAdditions)

//
// +initialize is called by the runtime just before the class receives its first message.
//

static void NSStringRKExtensionsInitializeFunction(void);

+ (void)initalize
{
  NSStringRKExtensionsInitializeFunction();
}

static void NSStringRKExtensionsInitializeFunction(void) {
  RKAtomicMemoryBarrier(); // Extra cautious
  if(NSStringRKExtensionsInitialized == 1) { return; }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &NSStringRKExtensionsInitialized)) {
    NSAutoreleasePool *lockPool = [[NSAutoreleasePool alloc] init];
    
    NSStringRKExtensionsNSDateLock = [(RKLock *)NSAllocateObject([RKLock class], 0, NULL) init];
#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
    if([objc_getClass("NSGarbageCollector") defaultCollector] != NULL) { [[objc_getClass("NSGarbageCollector") defaultCollector] disableCollectorForPointer:NSStringRKExtensionsNSDateLock]; }
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION
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
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, NULL, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, varArgsList));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range references:(NSString * const)firstReference, ...
{
  va_list varArgsList; va_start(varArgsList, firstReference);
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, &range, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), firstReference, varArgsList));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range arguments:(va_list)argList
{
  return(RKMatchAndExtractCaptureReferences(self, _cmd, self, NULL, NULL, &range, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, argList));
}



- (BOOL)getCapturesWithRegex:(id)aRegex error:(NSError **)error references:(NSString * const)firstReference, ...
{
  va_list varArgsList; va_start(varArgsList, firstReference);
  return(RKMatchAndExtractCaptureReferencesX(self, _cmd, self, NULL, NULL, NULL, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, varArgsList, error));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range error:(NSError **)error references:(NSString * const)firstReference, ...
{
  va_list varArgsList; va_start(varArgsList, firstReference);
  return(RKMatchAndExtractCaptureReferencesX(self, _cmd, self, NULL, NULL, &range, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), firstReference, varArgsList, error));
}

- (BOOL)getCapturesWithRegex:(id)aRegex inRange:(const NSRange)range error:(NSError **)error arguments:(va_list)argList
{
  return(RKMatchAndExtractCaptureReferencesX(self, _cmd, self, NULL, NULL, &range, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), RKMatchNoUTF8Check, (RKCaptureExtractAllowConversions | RKCaptureExtractStrictReference), NULL, argList, error));
}

//
// rangesOfRegex: methods
//

- (NSRange *)rangesOfRegex:(id)aRegex
{
  RKStringBuffer         stringBuffer = RKStringBufferWithString(self);
  RKRegex               *regex        = RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES);
  NSRange RK_STRONG_REF *matchRanges  = [regex rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoUTF8Check];
  if(matchRanges != NULL) { RKUInteger captures = [regex captureCount]; for(RKUInteger x = 0; x < captures; x++) { matchRanges[x] = RKutf8to16(self, matchRanges[x]); } }
  return(matchRanges);
}

- (NSRange *)rangesOfRegex:(id)aRegex inRange:(const NSRange)range
{
  RKStringBuffer         stringBuffer = RKStringBufferWithString(self);
  RKRegex               *regex        = RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES);
  NSRange RK_STRONG_REF *matchRanges  = [regex rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) options:RKMatchNoUTF8Check];
  if(matchRanges != NULL) { RKUInteger captures = [regex captureCount]; for(RKUInteger x = 0; x < captures; x++) { matchRanges[x] = RKutf8to16(self, matchRanges[x]); } }
  return(matchRanges);
}

- (NSRange *)rangesOfRegex:(id)aRegex error:(NSError **)error
{
  RKStringBuffer         stringBuffer = RKStringBufferWithString(self);
  RKRegex               *regex        = RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES);
  NSRange RK_STRONG_REF *matchRanges  = [regex rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoUTF8Check error:error];
  if(matchRanges != NULL) { RKUInteger captures = [regex captureCount]; for(RKUInteger x = 0; x < captures; x++) { matchRanges[x] = RKutf8to16(self, matchRanges[x]); } }
  return(matchRanges);
}

- (NSRange *)rangesOfRegex:(id)aRegex inRange:(const NSRange)range error:(NSError **)error
{
  RKStringBuffer         stringBuffer = RKStringBufferWithString(self);
  RKRegex               *regex        = RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES);
  NSRange RK_STRONG_REF *matchRanges  = [regex rangesForCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) options:RKMatchNoUTF8Check error:error];
  if(matchRanges != NULL) { RKUInteger captures = [regex captureCount]; for(RKUInteger x = 0; x < captures; x++) { matchRanges[x] = RKutf8to16(self, matchRanges[x]); } }
  return(matchRanges);
}

//
// rangeOfRegex: methods
//

- (NSRange)rangeOfRegex:(id)aRegex
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return(RKutf8to16(self, [RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) captureIndex:0 options:RKMatchNoUTF8Check]));
}

- (NSRange)rangeOfRegex:(id)aRegex inRange:(const NSRange)range capture:(const RKUInteger)capture
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return(RKutf8to16(self, [RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) captureIndex:capture options:RKMatchNoUTF8Check]));
}

- (NSRange)rangeOfRegex:(id)aRegex error:(NSError **)error
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return(RKutf8to16(self, [RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) captureIndex:0 options:RKMatchNoUTF8Check error:error]));
}

- (NSRange)rangeOfRegex:(id)aRegex inRange:(const NSRange)range capture:(const RKUInteger)capture error:(NSError **)error
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return(RKutf8to16(self, [RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) rangeForCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) captureIndex:capture options:RKMatchNoUTF8Check error:error]));
}


//
// isMatchedByRegex: methods
//

- (BOOL)isMatchedByRegex:(id)aRegex
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoUTF8Check]);
}

- (BOOL)isMatchedByRegex:(id)aRegex inRange:(const NSRange)range
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) options:RKMatchNoUTF8Check]);
}

- (BOOL)isMatchedByRegex:(id)aRegex error:(NSError **)error
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:NSMakeRange(0, stringBuffer.length) options:RKMatchNoUTF8Check error:error]);
}

- (BOOL)isMatchedByRegex:(id)aRegex inRange:(const NSRange)range error:(NSError **)error
{
  RKStringBuffer stringBuffer = RKStringBufferWithString(self);
  return([RKRegexFromStringOrRegex(self, _cmd, aRegex, (RKCompileUTF8 | RKCompileNoUTF8Check), YES) matchesCharacters:stringBuffer.characters length:stringBuffer.length inRange:RKutf16to8(self, range) options:RKMatchNoUTF8Check error:error]);
}

//
// matchEnumeratorWithRegex: methods
//

-(RKEnumerator *)matchEnumeratorWithRegex:(id)aRegex error:(NSError **)error
{
  return([RKEnumerator enumeratorWithRegex:aRegex string:self error:error]);
}

-(RKEnumerator *)matchEnumeratorWithRegex:(id)aRegex inRange:(const NSRange)range error:(NSError **)error
{
  return([RKEnumerator enumeratorWithRegex:aRegex string:self inRange:range error:error]);
}

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

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const RKUInteger)anIndex withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, 1, aRegex, referenceString, NULL, NO, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const RKUInteger)anIndex withReferenceString:(NSString * const)string
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, 1, aRegex, referenceString, NULL, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex withReferenceString:(NSString * const)referenceString error:(NSError **)error
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, NULL,     1, aRegex, referenceString, NULL, NO, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceString:(NSString * const)referenceString  error:(NSError **)error
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range,   1, aRegex, referenceString, NULL, NO, NULL, error)); }



//
// stringByMatching:withReferenceFormat: methods
//

- (NSString *)stringByMatching:(id)aRegex withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,     1, aRegex, referenceFormatString, &argList, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   1, aRegex, referenceFormatString, &argList, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range, 1, aRegex, referenceFormatString, (va_list *)&argList, NO, NULL));  }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const RKUInteger)anIndex withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, 1, aRegex, referenceFormatString, &argList, NO, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const RKUInteger)anIndex withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, 1, aRegex, referenceFormatString, &argList, NO, NULL)); }

- (NSString *)stringByMatching:(id)aRegex error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, NULL,     1, aRegex, referenceFormatString, &argList, NO, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range,   1, aRegex, referenceFormatString, &argList, NO, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range, 1, aRegex, referenceFormatString, (va_list *)&argList, NO, NULL, error));  }


//
// stringByMatching:replace:withString: methods
//

- (NSString *)stringByMatching:(id)aRegex replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,     count, aRegex, referenceString, NULL, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceString, NULL, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, count, aRegex, referenceString, NULL, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString
//{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, count, aRegex, referenceString, NULL, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString error:(NSError **)error
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, NULL,     count, aRegex, referenceString, NULL, YES, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withReferenceString:(NSString * const)referenceString error:(NSError **)error
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceString, NULL, YES, NULL, error)); }


//
// stringByMatching:replace:withReferenceFormat: methods
//

- (NSString *)stringByMatching:(id)aRegex replace:(const RKUInteger)count withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, NULL,    count, aRegex, referenceFormatString, &argList, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceFormatString, &argList, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, NULL, &range, count, aRegex, referenceFormatString, (va_list *)&argList, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex fromIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, &anIndex, NULL, NULL, count, aRegex, referenceFormatString, &argList, YES, NULL)); }

//- (NSString *)stringByMatching:(id)aRegex toIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withReferenceFormat:(NSString * const)referenceFormatString, ...
//{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpanding(self, _cmd, self, NULL, &anIndex, NULL, count, aRegex, referenceFormatString, &argList, YES, NULL)); }

- (NSString *)stringByMatching:(id)aRegex replace:(const RKUInteger)count error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, NULL,    count, aRegex, referenceFormatString, &argList, YES, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString, ...
{ va_list argList; va_start(argList, referenceFormatString); return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range,   count, aRegex, referenceFormatString, &argList, YES, NULL, error)); }

- (NSString *)stringByMatching:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count error:(NSError **)error withReferenceFormat:(NSString * const)referenceFormatString arguments:(va_list)argList
{ return(RKStringByMatchingAndExpandingX(self, _cmd, self, NULL, NULL, &range, count, aRegex, referenceFormatString, (va_list *)&argList, YES, NULL, error)); }

@end

/* NSMutableString additions */

@implementation NSMutableString (RegexKitAdditions)

//
// match:replace:withString: methods
//

-(RKUInteger)match:(id)aRegex replace:(const RKUInteger)count withString:(NSString * const)replaceString
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, NULL,     count, replaceString, NULL)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withString:(NSString * const)replaceString
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range,   count, replaceString, NULL)); }

//-(RKUInteger)match:(id)aRegex fromIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withString:(NSString * const)replaceString
//{ return(RKMutableStringMatch(self, _cmd, aRegex, &anIndex, NULL, NULL, count, replaceString, NULL)); }

//-(RKUInteger)match:(id)aRegex toIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withString:(NSString * const)replaceString
//{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, &anIndex, NULL, count, replaceString, NULL)); }

-(RKUInteger)match:(id)aRegex replace:(const RKUInteger)count withString:(NSString * const)replaceString error:(NSError **)error
{ return(RKMutableStringMatchX(self, _cmd, aRegex, NULL, NULL, NULL,     count, replaceString, NULL, error)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withString:(NSString * const)replaceString error:(NSError **)error
{ return(RKMutableStringMatchX(self, _cmd, aRegex, NULL, NULL, &range,   count, replaceString, NULL, error)); }

//
// match:replace:withFormat: methods
//

-(RKUInteger)match:(id)aRegex replace:(const RKUInteger)count withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, NULL,     count, formatString, &argList)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range,   count, formatString, &argList)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count withFormat:(NSString * const)formatString arguments:(va_list)argList
{ return(RKMutableStringMatch(self, _cmd, aRegex, NULL, NULL, &range, count, formatString, (va_list *)&argList)); }

//-(RKUInteger)match:(id)aRegex fromIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withFormat:(NSString * const)formatString, ...
//{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, &anIndex, NULL, NULL, count, formatString, &argList)); }

//-(RKUInteger)match:(id)aRegex toIndex:(const RKUInteger)anIndex replace:(const RKUInteger)count withFormat:(NSString * const)formatString, ...
//{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatch(self, _cmd, aRegex, NULL, &anIndex, NULL, count, formatString, &argList)); }

-(RKUInteger)match:(id)aRegex replace:(const RKUInteger)count error:(NSError **)error withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatchX(self, _cmd, aRegex, NULL, NULL, NULL,     count, formatString, &argList, error)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count error:(NSError **)error withFormat:(NSString * const)formatString, ...
{ va_list argList; va_start(argList, formatString); return(RKMutableStringMatchX(self, _cmd, aRegex, NULL, NULL, &range,   count, formatString, &argList, error)); }

-(RKUInteger)match:(id)aRegex inRange:(const NSRange)range replace:(const RKUInteger)count error:(NSError **)error withFormat:(NSString * const)formatString arguments:(va_list)argList
{ return(RKMutableStringMatchX(self, _cmd, aRegex, NULL, NULL, &range, count, formatString, (va_list *)&argList, error)); }

@end
static RKUInteger RKMutableStringMatch(id self, const SEL _cmd, id aRegex,
                                       RK_STRONG_REF const RKUInteger * RK_C99(restrict) fromIndex, RK_STRONG_REF const RKUInteger * RK_C99(restrict) toIndex,
                                       RK_STRONG_REF const NSRange * RK_C99(restrict) range, const RKUInteger count,
                                       NSString * const RK_C99(restrict) formatString, RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr) {
  RKUInteger                  replaceCount   = 0;
  NSString * RK_C99(restrict) replacedString = RKStringByMatchingAndExpanding(self, _cmd, self, fromIndex, toIndex, range, count, aRegex, formatString, argListPtr, YES, &replaceCount);
  if(replacedString == self) { return(0); }
#ifdef USE_CORE_FOUNDATION
  CFStringReplaceAll((CFMutableStringRef)self, (CFStringRef)replacedString);
#else  // USE_CORE_FOUNDATION is not defined
  [self setString:replacedString];
#endif // USE_CORE_FOUNDATION
  return(replaceCount);
}

static RKUInteger RKMutableStringMatchX(id self, const SEL _cmd, id aRegex,
                                       RK_STRONG_REF const RKUInteger * RK_C99(restrict) fromIndex, RK_STRONG_REF const RKUInteger * RK_C99(restrict) toIndex,
                                       RK_STRONG_REF const NSRange * RK_C99(restrict) range, const RKUInteger count,
                                       NSString * const RK_C99(restrict) formatString, RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr, NSError **error) {
  RKUInteger                  replaceCount   = 0;
  NSString * RK_C99(restrict) replacedString = RKStringByMatchingAndExpandingX(self, _cmd, self, fromIndex, toIndex, range, count, aRegex, formatString, argListPtr, YES, &replaceCount, error);
  if(replacedString == self) { return(0); }
#ifdef USE_CORE_FOUNDATION
  CFStringReplaceAll((CFMutableStringRef)self, (CFStringRef)replacedString);
#else  // USE_CORE_FOUNDATION is not defined
  [self setString:replacedString];
#endif // USE_CORE_FOUNDATION
  return(replaceCount);
}



/* Functions for performing various regex string tasks, most private. */


//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////


static BOOL RKMatchAndExtractCaptureReferences(id self, const SEL _cmd, NSString * const RK_C99(restrict) extractString,
                                               RK_STRONG_REF const RKUInteger * const RK_C99(restrict) fromIndex,
                                               RK_STRONG_REF const RKUInteger * const RK_C99(restrict) toIndex,
                                               RK_STRONG_REF const NSRange    * const RK_C99(restrict) range,
                                               id aRegex,
                                               const RKCompileOption         compileOptions,
                                               const RKMatchOption           matchOptions,
                                               const RKCaptureExtractOptions captureExtractOptions,
                                               NSString * const firstKey,    va_list useVarArgsList) {
  BOOL     didExtract   = NO;
  NSError *extractError = NULL;
  
  didExtract = RKMatchAndExtractCaptureReferencesX(self, _cmd, extractString, fromIndex, toIndex, range, aRegex, compileOptions, matchOptions, captureExtractOptions, firstKey, useVarArgsList, &extractError);
  
  if(extractError != NULL) { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:[extractError localizedDescription] userInfo:NULL] raise]; }
  return(didExtract);
}

static BOOL RKMatchAndExtractCaptureReferencesX(id self, const SEL _cmd, NSString * const RK_C99(restrict) extractString,
                                               RK_STRONG_REF const RKUInteger * const RK_C99(restrict) fromIndex,
                                               RK_STRONG_REF const RKUInteger * const RK_C99(restrict) toIndex,
                                               RK_STRONG_REF const NSRange    * const RK_C99(restrict) range,
                                               id aRegex,
                                               const RKCompileOption         compileOptions,
                                               const RKMatchOption           matchOptions,
                                               const RKCaptureExtractOptions captureExtractOptions,
                                               NSString * const firstKey,    va_list useVarArgsList,
                                               NSError **error) {
  NSRange RK_STRONG_REF * RK_C99(restrict) matchRanges = NULL;
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  RKUInteger       captureCount   = 0, fromIndexByte = 0;
  NSRange          searchRange    = NSMakeRange(NSNotFound, 0);
  NSError         *extractError   = NULL;
  BOOL             returnResult   = NO;
  RKRegex         *regex          = NULL;
  RKStringBuffer   stringBuffer;
  
  if((regex = RKRegexFromStringOrRegexWithError(self, _cmd, aRegex, RKRegexPCRELibrary, (compileOptions | RKCompileUTF8 | RKCompileNoUTF8Check), &extractError, YES)) == NULL) { goto exitNow; }
  NSCParameterAssert(extractError == NULL);

  captureCount = [regex captureCount];  
  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { goto exitNow; }
  
  stringBuffer = RKStringBufferWithString(extractString);
  if(RK_EXPECTED(stringBuffer.characters == NULL, 0)) { goto exitNow; }

  if(fromIndex != NULL) { fromIndexByte = RKutf16to8(self, NSMakeRange(*fromIndex, 0)).location; }

  if((fromIndex == NULL) && (toIndex == NULL) && (range == NULL)) { searchRange = NSMakeRange(0, stringBuffer.length);                               }
  else if(range     != NULL)                                      { searchRange = RKutf16to8(self, *range);                                          }
  else if(fromIndex != NULL)                                      { searchRange = NSMakeRange(fromIndexByte, (stringBuffer.length - fromIndexByte)); }
  else if(toIndex   != NULL)                                      { searchRange = RKutf16to8(self, NSMakeRange(0, *toIndex));                        }
  
  if((matchErrorCode = [regex getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:stringBuffer.characters length:stringBuffer.length inRange:searchRange options:matchOptions error:&extractError]) <= 0) { goto exitNow; }
  NSCParameterAssert(extractError == NULL);
  
  returnResult = RKExtractCapturesFromMatchesWithKeyArgumentsX(self, _cmd, (const RKStringBuffer *)&stringBuffer, regex, matchRanges, captureExtractOptions, firstKey, useVarArgsList, &extractError);
  
exitNow:
  if(error != NULL) { *error = extractError; }
  return(returnResult);
}

BOOL RKExtractCapturesFromMatchesWithKeyArguments(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) stringBuffer, RKRegex * const RK_C99(restrict) regex,
                                                  RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges, const RKCaptureExtractOptions captureExtractOptions,
                                                  NSString * const firstKey, va_list useVarArgsList) {
  BOOL     didExtract   = NO;
  NSError *extractError = NULL;
  
  didExtract = RKExtractCapturesFromMatchesWithKeyArgumentsX(self, _cmd, stringBuffer, regex, matchRanges, captureExtractOptions, firstKey, useVarArgsList, &extractError);

  if(extractError != NULL) {
    if(([[extractError domain] isEqualToString:RKRegexErrorDomain] == YES) && ([extractError userInfo] != NULL)) { [RKExceptionFromInitFailureForOlderAPI(self, _cmd, extractError) raise]; }
    [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:[extractError localizedDescription] userInfo:NULL] raise];
  }
  return(didExtract);
}

BOOL RKExtractCapturesFromMatchesWithKeyArgumentsX(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) stringBuffer, RKRegex * const RK_C99(restrict) regex,
                                                  RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges, const RKCaptureExtractOptions captureExtractOptions,
                                                  NSString * const firstKey, va_list useVarArgsList, NSError **error) {
  RKUInteger            stringArgumentsCount  = 0, count = 0, x = 0;
  void RK_STRONG_REF ***keyConversionPointers = NULL;
  NSString            **keyStrings            = NULL;
  NSError               *extractError         = NULL;
  BOOL                   returnBool           = NO;
  va_list                varArgsList;

  va_copy(varArgsList, useVarArgsList);
  if(firstKey != NULL)                           { stringArgumentsCount++; if(va_arg(varArgsList, void **) != NULL) { stringArgumentsCount++; } else { goto finishedCountingArgs; } }
  while(va_arg(varArgsList, NSString *) != NULL) { stringArgumentsCount++; if(va_arg(varArgsList, void **) != NULL) { stringArgumentsCount++; } else { break; } }
  va_end(varArgsList);
  
finishedCountingArgs:
  if(RK_EXPECTED((stringArgumentsCount & 0x1) == 1, 0)) { [[NSException rkException:NSInvalidArgumentException for:self selector:_cmd localizeReason:@"Not an even pair of key and pointer to a pointer arguments."] raise]; }

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
  
  returnBool = RKExtractCapturesFromMatchesWithKeysAndPointers(self, _cmd, stringBuffer, regex, matchRanges, keyStrings, keyConversionPointers, count, captureExtractOptions, &extractError);
  
errorExit:
  if(error != NULL) { *error = extractError; }
  return(returnBool);
}

// Takes a set of match results and loops over all keys, parses them, and fills in the result.  parseReference does the heavy work and conversion
static BOOL RKExtractCapturesFromMatchesWithKeysAndPointers(id self RK_ATTRIBUTES(unused), const SEL _cmd RK_ATTRIBUTES(unused), RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) stringBuffer, 
                                                            RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges,
                                                            NSString ** const RK_C99(restrict) keyStrings, RK_STRONG_REF void *** const RK_C99(restrict) keyConversionPointers,
                                                            const RKUInteger count, const RKCaptureExtractOptions captureExtractOptions, NSError **error) {
  RKUInteger                      autoreleaseObjectsIndex = 0, x = 0;
  NSException * RK_C99(restrict)  caughtException         = NULL;
  NSError                        *extractError            = NULL;
  void RK_STRONG_REF            **autoreleaseObjects      = NULL;
  NSString                       *parseErrorString        = NULL;
  BOOL                            returnResult            = NO;
  RKStringBuffer                  keyBuffer;

  const int parseReferenceOptions = ((((captureExtractOptions & RKCaptureExtractAllowConversions)  != 0) ? RKParseReferenceConversionAllowed : 0) |
                                     (((captureExtractOptions & RKCaptureExtractStrictReference)   != 0) ? RKParseReferenceStrictReference   : 0) |
                                     (((captureExtractOptions & RKCaptureExtractIgnoreConversions) != 0) ? RKParseReferenceIgnoreConversion  : 0) |
                                     RKParseReferencePerformConversion | RKParseReferenceCheckCaptureName);
  
  NSCParameterAssert(RK_EXPECTED(self != NULL, 1) && RK_EXPECTED(_cmd != NULL, 1) && RK_EXPECTED(keyConversionPointers != NULL, 1) && RK_EXPECTED(keyStrings != NULL, 1) && RK_EXPECTED(stringBuffer != NULL, 1) && RK_EXPECTED(matchRanges != NULL, 1) && RK_EXPECTED(regex != NULL, 1));
  
  if(RK_EXPECTED((autoreleaseObjects = alloca(count * sizeof(void *))) == NULL, 0)) { goto exitNow; }

#ifdef USE_MACRO_EXCEPTIONS
NS_DURING
#else  // USE_MACRO_EXCEPTIONS is not defined
@try {
#endif // USE_MACRO_EXCEPTIONS
  for(x = 0; x < count && RK_EXPECTED(extractError == NULL, 1); x++) {
    keyBuffer = RKStringBufferWithString(keyStrings[x]);
    if(RK_EXPECTED(RKParseReference((const RKStringBuffer *)&keyBuffer, NSMakeRange(0, keyBuffer.length), stringBuffer,
                                    matchRanges, regex, NULL, keyConversionPointers[x], parseReferenceOptions, NULL, NULL, &parseErrorString,
                                    (void ***)autoreleaseObjects, &autoreleaseObjectsIndex, &extractError) == NO, 0)) {
      // We hold off on raising the exception until we make sure we've autoreleased any objects we created, if necessary.
      //extractError = [NSError errorWithDomain:RKRegexErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObject:parseErrorString forKey:NSLocalizedDescriptionKey]];
    }
  }
#ifdef USE_MACRO_EXCEPTIONS
NS_HANDLER
  caughtException = localException;
NS_ENDHANDLER
#else  // USE_MACRO_EXCEPTIONS is not defined
} @catch (NSException *exception) {
  caughtException = exception;
}  
#endif // USE_MACRO_EXCEPTIONS

exitNow:
    
  if(autoreleaseObjectsIndex > 0) {
#ifdef USE_CORE_FOUNDATION
    if(RKRegexGarbageCollect == 0) { RKMakeCollectableOrAutorelease(CFArrayCreate(NULL, (const void **)&autoreleaseObjects[0], autoreleaseObjectsIndex, &noRetainArrayCallBacks)); }
    else                           { CFMakeCollectable             (CFArrayCreate(NULL, (const void **)&autoreleaseObjects[0], autoreleaseObjectsIndex, &kCFTypeArrayCallBacks));  }
#else  // USE_CORE_FOUNDATION is not defined
    [NSArray arrayWithObjects:(id *)&autoreleaseObjects[0] count:autoreleaseObjectsIndex];
#endif // USE_CORE_FOUNDATION
  }
  
  if(RK_EXPECTED(caughtException == NULL, 1)) { returnResult = YES; } else { [caughtException raise]; }
  if(error != NULL) { *error = extractError; }
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
static NSString *RKStringByMatchingAndExpanding(id self, const SEL _cmd, NSString * const RK_C99(restrict) searchString, RK_STRONG_REF const RKUInteger * const RK_C99(restrict) fromIndex,
                                                RK_STRONG_REF const RKUInteger * const RK_C99(restrict) toIndex, RK_STRONG_REF const NSRange * const RK_C99(restrict) searchStringRange,
                                                const RKUInteger count, id aRegex, NSString * const RK_C99(restrict) referenceString,
                                                RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr, const BOOL expandOrReplace,
                                                RK_STRONG_REF RKUInteger * const RK_C99(restrict) matchedCountPtr) {
  NSString *matchedAndExpandedString = NULL;
  NSError  *stringError              = NULL;
  
  matchedAndExpandedString = RKStringByMatchingAndExpandingX(self, _cmd, searchString, fromIndex, toIndex, searchStringRange, count, aRegex, referenceString, argListPtr, expandOrReplace, matchedCountPtr, &stringError);
  //NSLog(@"RKStringByMatchingAndExpanding: error == %p '%@'", stringError, stringError);
  if(stringError != NULL) {
    if(([[stringError domain] isEqualToString:RKRegexErrorDomain] == YES) && ([stringError userInfo] != NULL)) { [RKExceptionFromInitFailureForOlderAPI(self, _cmd, stringError) raise]; }
    [[NSException exceptionWithName:NSGenericException reason:[stringError localizedDescription]  userInfo:NULL] raise];
  }
  
  return(matchedAndExpandedString);
}

static NSString *RKStringByMatchingAndExpandingX(id self, const SEL _cmd, NSString * const RK_C99(restrict) searchString, RK_STRONG_REF const RKUInteger * const RK_C99(restrict) fromIndex,
                                                RK_STRONG_REF const RKUInteger * const RK_C99(restrict) toIndex, RK_STRONG_REF const NSRange * const RK_C99(restrict) searchStringRange,
                                                const RKUInteger count, id aRegex, NSString * const RK_C99(restrict) referenceString,
                                                RK_STRONG_REF va_list * const RK_C99(restrict) argListPtr, const BOOL expandOrReplace,
                                                RK_STRONG_REF RKUInteger * const RK_C99(restrict) matchedCountPtr, NSError **error) {
  RKRegex * RK_C99(restrict)               regex       = NULL;
  NSError                                 *stringError = NULL;
  RKStringBuffer                           searchStringBuffer, referenceStringBuffer;
  RKUInteger                               searchIndex = 0,    matchedCount = 0, captureCount = 0, fromIndexByte = 0;
  NSRange RK_STRONG_REF * RK_C99(restrict) matchRanges = NULL; NSRange searchRange;
  RKMatchErrorCode                         matched;
  RKReferenceInstruction                   stackReferenceInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKCopyInstruction                        stackCopyInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  
  searchRange = NSMakeRange(NSNotFound, 0);
  if((regex = RKRegexFromStringOrRegexWithError(self, _cmd, aRegex, RKRegexPCRELibrary, (RKCompileUTF8 | RKCompileNoUTF8Check), &stringError, YES)) == NULL) { NSCParameterAssert(stringError != NULL); goto errorExit; }
  
  captureCount          = [regex captureCount];
  if((matchRanges = alloca(sizeof(NSRange) * RK_PRESIZE_CAPTURE_COUNT(captureCount))) == NULL) { goto errorExit; }
  searchStringBuffer    = RKStringBufferWithString(searchString);
  referenceStringBuffer = RKStringBufferWithString((argListPtr == NULL) ? referenceString : (NSString *)RKAutorelease([[NSString alloc] initWithFormat:referenceString arguments:*argListPtr]));
  
  if(searchStringBuffer.characters    == NULL) { goto errorExit; }
  if(referenceStringBuffer.characters == NULL) { goto errorExit; }
  
  if(fromIndex != NULL) { fromIndexByte = RKutf16to8(self, NSMakeRange(*fromIndex, 0)).location; }

  if((fromIndex == NULL) && (toIndex == NULL) && (searchStringRange == NULL)) { searchRange = NSMakeRange(0, searchStringBuffer.length);                               }
  else if(searchStringRange != NULL)                                          { searchRange = RKutf16to8(self, *searchStringRange);                                    }
  else if(fromIndex         != NULL)                                          { searchRange = NSMakeRange(fromIndexByte, (searchStringBuffer.length - fromIndexByte)); }
  else if(toIndex           != NULL)                                          { searchRange = RKutf16to8(self, NSMakeRange(0, *toIndex));                              }
  
  RKReferenceInstructionsBuffer referenceInstructionsBuffer = RKMakeReferenceInstructionsBuffer(0, RK_DEFAULT_STACK_INSTRUCTIONS,    &stackReferenceInstructions[0], NULL);
  RKCopyInstructionsBuffer      copyInstructionsBuffer      = RKMakeCopyInstructionsBuffer(     0, RK_DEFAULT_STACK_INSTRUCTIONS, 0, &stackCopyInstructions[0],      NULL);
  
  if(RKCompileReferenceString(self, _cmd, &referenceStringBuffer, regex, &referenceInstructionsBuffer) == NO) { goto errorExit; }
  
  searchIndex = searchRange.location;
  
  if((expandOrReplace == YES) && (searchIndex != 0)) { if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, NSMakeRange(0, searchIndex)) == NO) { goto errorExit; } }
  
  while((searchIndex < (searchRange.location + searchRange.length)) && ((matchedCount < count) || (count == RKReplaceAll)) && (stringError == NULL)) {
    if((matched = [regex getRanges:&matchRanges[0] count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:searchStringBuffer.characters length:searchStringBuffer.length inRange:NSMakeRange(searchIndex, (searchRange.location + searchRange.length) - searchIndex) options:RKMatchNoUTF8Check error:&stringError]) < 0) {
      if(matched != RKMatchErrorNoMatch) { goto errorExit; }
      break;
    }
    
    if(expandOrReplace == YES) { if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, NSMakeRange(searchIndex, (matchRanges[0].location - searchIndex))) == NO) { goto errorExit; } }
    searchIndex = matchRanges[0].location + matchRanges[0].length;
    if(RKApplyReferenceInstructions(self, _cmd, regex, matchRanges, &searchStringBuffer, &referenceInstructionsBuffer, &copyInstructionsBuffer) == NO) { goto errorExit; }
    matchedCount++;
  }

  if(matchedCountPtr != NULL) { *matchedCountPtr = matchedCount; }
  
  if(expandOrReplace == YES) {
    NSRange copySearchStringRange = NSMakeRange(searchIndex, (searchStringBuffer.length - searchIndex));
    if((copyInstructionsBuffer.length == 0) && (NSEqualRanges(NSMakeRange(0, copyInstructionsBuffer.length), copySearchStringRange) == YES)) { return(searchString); } // There were no changes, so the replaced string == search string.
    if(RKAppendCopyInstruction(&copyInstructionsBuffer, searchStringBuffer.characters, copySearchStringRange) == NO) { goto errorExit; }
  }
    
  return(RKStringFromCopyInstructions(self, _cmd, &copyInstructionsBuffer, RKUTF8StringEncoding));

errorExit:
  if(error != NULL) { *error = stringError; }
  return(NULL);
}

NSString *RKStringFromReferenceString(id self, const SEL _cmd, RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) matchStringBuffer, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer) {
  RKReferenceInstruction        stackReferenceInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKCopyInstruction             stackCopyInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];

  RKReferenceInstructionsBuffer referenceInstructionsBuffer = RKMakeReferenceInstructionsBuffer(0, RK_DEFAULT_STACK_INSTRUCTIONS,    &stackReferenceInstructions[0], NULL);
  RKCopyInstructionsBuffer      copyInstructionsBuffer      = RKMakeCopyInstructionsBuffer(     0, RK_DEFAULT_STACK_INSTRUCTIONS, 0, &stackCopyInstructions[0],      NULL);
  
  if(RKCompileReferenceString(    self, _cmd, referenceStringBuffer, regex, &referenceInstructionsBuffer)                                   == NO) { goto errorExit; }
  if(RKApplyReferenceInstructions(self, _cmd, regex, matchRanges, matchStringBuffer, &referenceInstructionsBuffer, &copyInstructionsBuffer) == NO) { goto errorExit; }

  return(RKStringFromCopyInstructions(self, _cmd, &copyInstructionsBuffer, RKUTF8StringEncoding));

errorExit:
  return(NULL);
}

NSString *RKStringFromReferenceStringX(id self, const SEL _cmd, RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) matchStringBuffer, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer, NSError **error) {
  RKReferenceInstruction        stackReferenceInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  RKCopyInstruction             stackCopyInstructions[RK_DEFAULT_STACK_INSTRUCTIONS];
  
  RKReferenceInstructionsBuffer referenceInstructionsBuffer = RKMakeReferenceInstructionsBuffer(0, RK_DEFAULT_STACK_INSTRUCTIONS,    &stackReferenceInstructions[0], NULL);
  RKCopyInstructionsBuffer      copyInstructionsBuffer      = RKMakeCopyInstructionsBuffer(     0, RK_DEFAULT_STACK_INSTRUCTIONS, 0, &stackCopyInstructions[0],      NULL);
  
  if(RKCompileReferenceStringX(   self, _cmd, referenceStringBuffer, regex, &referenceInstructionsBuffer, error)                            == NO) { goto errorExit; }
  if(RKApplyReferenceInstructions(self, _cmd, regex, matchRanges, matchStringBuffer, &referenceInstructionsBuffer, &copyInstructionsBuffer) == NO) { goto errorExit; }
  
  return(RKStringFromCopyInstructionsX(self, _cmd, &copyInstructionsBuffer, RKUTF8StringEncoding, error));
  
errorExit:
  return(NULL);
}


static NSString *RKStringFromCopyInstructions(id self, const SEL _cmd, RK_STRONG_REF const RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const RKStringBufferEncoding stringEncoding) {
  NSString *copyString = NULL;
  NSError  *copyError  = NULL;
  
  copyString = RKStringFromCopyInstructionsX(self, _cmd, instructionsBuffer, stringEncoding, &copyError);
  if(copyError != NULL) { [[NSException exceptionWithName:NSGenericException reason:[copyError localizedDescription] userInfo:NULL] raise]; }

  return(copyString);
}
NSAllocateCollectable
static NSString *RKStringFromCopyInstructionsX(id self RK_ATTRIBUTES(unused), const SEL _cmd RK_ATTRIBUTES(unused), RK_STRONG_REF const RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const RKStringBufferEncoding stringEncoding, NSError **error) {
  char RK_STRONG_REF * RK_C99(restrict) copyBuffer = NULL;
  NSString           * RK_C99(restrict) copyString = NULL;
  NSError            * RK_C99(restrict) copyError  = NULL;
  
  // Temporarily removed allocating the backing store in a garbage collected fashion because of the following theory:
  // 
  // I suspect that allocating the strings content buffer as GC eligible, and then handing that pointer to CFString, exposes a pathological condition in the Leopard 10.5
  // GC system.  Specifically, because I suspect (there is no documentation which covers the low level details of the 10.5 GC system) that the 10.5 GC system does not scan
  // memory to determine if an allocation is live as one might expect (and as the Boehm GC system does), but instead relies entirely on keeping the GC system aware of
  // changes in the heap by explicit funtions calls (objc_assign_*) that update the GC systems state, allocating the strings buffer as GC eligible and then handling
  // that pointer to CFString causes the GC system to 'loose track of' the liveness of the string buffer because CoreFoundation does not issue the proper 'GC Notification'
  // function calls regarding the GC backed pointer we hand it.
  
  //if((copyBuffer = RKMallocNotScanned(instructionsBuffer->copiedLength + 1)) == NULL) { copyError = [NSError rkErrorWithDomain:NSPOSIXErrorDomain code:0 localizeDescription:@"Unable to allocate memory for final copied string."]; goto errorExit; }
  if((copyBuffer = RKMallocNoGC(instructionsBuffer->copiedLength + 1)) == NULL) { copyError = [NSError rkErrorWithDomain:NSPOSIXErrorDomain code:0 localizeDescription:@"Unable to allocate memory for final copied string."]; goto errorExit; }

  RKEvaluateCopyInstructions(instructionsBuffer, copyBuffer, (instructionsBuffer->copiedLength + 1));

#ifdef USE_CORE_FOUNDATION
  //copyString = RKMakeCollectableOrAutorelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, copyBuffer, stringEncoding, RK_EXPECTED(RKRegexGarbageCollect == 1, 0) ? kCFAllocatorNull : kCFAllocatorMalloc));
  copyString = RKMakeCollectableOrAutorelease(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, copyBuffer, stringEncoding, kCFAllocatorMalloc));
#else  // USE_CORE_FOUNDATION is not defined
  //copyString = RKAutorelease([[NSString alloc] initWithBytesNoCopy:copyBuffer length:instructionsBuffer->copiedLength encoding:stringEncoding freeWhenDone:(RKRegexGarbageCollect == 1, 0) ? NO : YES]);
  copyString = RKAutorelease([[NSString alloc] initWithBytesNoCopy:copyBuffer length:instructionsBuffer->copiedLength encoding:stringEncoding freeWhenDone:YES]);
#endif // USE_CORE_FOUNDATION

errorExit:
  if(error != NULL) { *error = copyError; }
  return(copyString);
}

static void RKEvaluateCopyInstructions(RK_STRONG_REF const RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, RK_STRONG_REF void * const RK_C99(restrict) toBuffer, const size_t bufferLength) {
  NSCParameterAssert(instructionsBuffer != NULL); NSCParameterAssert(toBuffer != NULL); NSCParameterAssert(instructionsBuffer->isValid == YES); NSCParameterAssert(instructionsBuffer->instructions != NULL);
  RKUInteger instructionIndex = 0, copyBufferIndex = 0;
  
  while((instructionIndex < instructionsBuffer->length) && (copyBufferIndex <= bufferLength)) {
    RKCopyInstruction * RK_C99(restrict) atInstruction = &instructionsBuffer->instructions[instructionIndex];
    NSCParameterAssert(atInstruction != NULL); NSCParameterAssert((copyBufferIndex + atInstruction->length) <= instructionsBuffer->copiedLength); NSCParameterAssert((copyBufferIndex + atInstruction->length) <= bufferLength);
    
    memcpy(toBuffer + copyBufferIndex, atInstruction->ptr, atInstruction->length);
    copyBufferIndex += atInstruction->length;
    instructionIndex++;
  }
  NSCParameterAssert(copyBufferIndex <= bufferLength);
  ((char *)toBuffer)[copyBufferIndex] = 0;
}

static BOOL RKApplyReferenceInstructions(id self, const SEL _cmd, RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF const NSRange * const RK_C99(restrict) matchRanges,
                                         RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) stringBuffer,
                                         RK_STRONG_REF const RKReferenceInstructionsBuffer * const RK_C99(restrict) referenceInstructionsBuffer,
                                         RK_STRONG_REF RKCopyInstructionsBuffer * const RK_C99(restrict) appliedInstructionsBuffer) {
  int              currentOp        = 0, lastOp           = referenceInstructionsBuffer->instructions[0].op;
  RKUInteger       captureIndex     = 0, instructionIndex = 0;
  NSMutableString *conversionString = NULL;
  
  while((lastOp != OP_STOP) && (instructionIndex < referenceInstructionsBuffer->length)) {
    RKReferenceInstruction RK_STRONG_REF * RK_C99(restrict) atInstruction = &referenceInstructionsBuffer->instructions[instructionIndex];
    const char RK_STRONG_REF *fromPtr = NULL;
    NSRange fromRange = NSMakeRange(0, 0);
    int     thisOp    = 0;
    lastOp = atInstruction->op;
    
    switch(atInstruction->op) {
      case OP_COPY_RANGE:        fromPtr = atInstruction->ptr;       fromRange = atInstruction->range;                       break;
      case OP_COPY_CAPTUREINDEX: fromPtr = stringBuffer->characters; fromRange = matchRanges[atInstruction->range.location]; break;
      case OP_COPY_CAPTURENAME :
        if((captureIndex = RKCaptureIndexForCaptureNameCharacters(regex, _cmd, atInstruction->ptr + atInstruction->range.location, atInstruction->range.length, matchRanges, YES)) == NSNotFound) { break; }
                                 fromPtr = stringBuffer->characters; fromRange = matchRanges[captureIndex];                  break;
        
      case OP_UPPERCASE_NEXT_CHAR: thisOp = atInstruction->op; break;
      case OP_LOWERCASE_NEXT_CHAR: thisOp = atInstruction->op; break;
      case OP_UPPERCASE_BEGIN:     thisOp = atInstruction->op; break;
      case OP_LOWERCASE_BEGIN:     thisOp = atInstruction->op; break;
      case OP_CHANGE_CASE_END:     thisOp = atInstruction->op; break;
      case OP_STOP:                                            break;
      
      default: [[NSException rkException:NSInternalInconsistencyException for:self selector:_cmd localizeReason:@"Unknown edit op code encountered."] raise]; break;
    }
    
    instructionIndex++;

    NSCParameterAssert(currentOp != OP_CHANGE_CASE_END);
    
    if((currentOp == 0) && (thisOp == OP_CHANGE_CASE_END)) { continue; }

    if((thisOp == OP_CHANGE_CASE_END) && ((currentOp == OP_UPPERCASE_NEXT_CHAR) || (currentOp == OP_LOWERCASE_NEXT_CHAR) || (currentOp == OP_UPPERCASE_BEGIN) || (currentOp == OP_LOWERCASE_BEGIN)) && ([conversionString length] == 0)) {
      currentOp = 0;
      continue;
    }
    
    if((currentOp == 0) && (thisOp == 0) && ((fromPtr != NULL) && (fromRange.length > 0))) {
      if(RKAppendCopyInstruction(appliedInstructionsBuffer, fromPtr, fromRange) == NO) { goto errorExit; }
      continue;
    }

    if(((currentOp == OP_UPPERCASE_BEGIN) || (currentOp == OP_LOWERCASE_BEGIN)) && (thisOp == 0) && ((fromPtr != NULL) && (fromRange.length > 0))) {
      if(conversionString == NULL) { RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 0, "Temporary NSMutableString for case conversion created."); if((conversionString = [[NSMutableString alloc] initWithCapacity:1024]) == NULL) { goto errorExit; } }
      NSString *fromString = [[NSString alloc] initWithBytes:(fromPtr + fromRange.location) length:fromRange.length encoding:NSUTF8StringEncoding];
      [conversionString appendString:fromString];
      RKRelease(fromString);
      continue;
    }
    
    if(((currentOp == OP_UPPERCASE_BEGIN) || (currentOp == OP_LOWERCASE_BEGIN)) && (thisOp != currentOp) && ((thisOp != 0) || (lastOp == OP_STOP))) {
      const char RK_STRONG_REF *convertedPtr    = NULL;
      size_t                    convertedLength = 0;
      
      if([conversionString length] > 0) {
        if(currentOp == OP_UPPERCASE_BEGIN) { convertedPtr = [[conversionString uppercaseString] UTF8String]; } else { convertedPtr = [[conversionString lowercaseString] UTF8String]; } 
        if(convertedPtr != NULL) { convertedLength = strlen(convertedPtr); }
      
        if(RKAppendCopyInstruction(appliedInstructionsBuffer, convertedPtr, NSMakeRange(0, convertedLength)) == NO) { goto errorExit; }
        [conversionString setString:@""];
      }
      currentOp = 0;
      if(thisOp == OP_CHANGE_CASE_END) { continue; }
    }

    if(((currentOp == OP_UPPERCASE_NEXT_CHAR) || (currentOp == OP_LOWERCASE_NEXT_CHAR)) && (thisOp == 0) && ((fromPtr != NULL) && (fromRange.length > 0))) {
      const char RK_STRONG_REF *convertedPtr = NULL, RK_STRONG_REF *fromBasePtr = (fromPtr + fromRange.location);
      const unsigned char       convertChar  = *((const unsigned char *)fromBasePtr);
      int                       fromLength   = (convertChar < 128) ? 1 : utf8ExtraBytes[(convertChar & 0x3f)] + 1;
      NSString                 *sourceString = [[NSString alloc] initWithBytes:fromBasePtr length:fromLength encoding:NSUTF8StringEncoding];

      if(currentOp == OP_UPPERCASE_NEXT_CHAR) { convertedPtr = [[sourceString uppercaseString] UTF8String]; } else { convertedPtr = [[sourceString lowercaseString] UTF8String]; }
      
      if(sourceString != NULL) { RKRelease(sourceString); sourceString = NULL; }

      if(RKAppendCopyInstruction(appliedInstructionsBuffer, convertedPtr,               NSMakeRange(0, (convertedPtr == NULL) ? 0 : strlen(convertedPtr))) == NO) { goto errorExit; }
      if(RKAppendCopyInstruction(appliedInstructionsBuffer, (fromBasePtr + fromLength), NSMakeRange(0, fromRange.length - fromLength))                     == NO) { goto errorExit; }
      
      currentOp = 0;
      continue;
    }

    NSCAssert1(thisOp != OP_CHANGE_CASE_END, @"currentOp == %d", currentOp);
    currentOp = thisOp;
  }

  NSCParameterAssert([conversionString length] == 0);
  
  if(conversionString != NULL) { RKRelease(conversionString); conversionString = NULL; }
  return(YES);
  
errorExit:
  if(conversionString != NULL) { RKRelease(conversionString); conversionString = NULL; }
  return(NO);
}


static BOOL RKCompileReferenceString(id self, const SEL _cmd, RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer, RKRegex * const RK_C99(restrict) regex,
                                     RK_STRONG_REF RKReferenceInstructionsBuffer * const RK_C99(restrict) instructionBuffer) {
  NSError *compileError = NULL;
  BOOL     didCompile   = NO;
  
  didCompile = RKCompileReferenceStringX(self, _cmd, referenceStringBuffer, regex, instructionBuffer, &compileError);
  if(compileError != NULL) { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:[compileError localizedDescription] userInfo:NULL] raise]; }
  
  return(didCompile);
}

static BOOL RKCompileReferenceStringX(id self RK_ATTRIBUTES(unused), const SEL _cmd RK_ATTRIBUTES(unused), RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceStringBuffer, RKRegex * const RK_C99(restrict) regex,
                                     RK_STRONG_REF RKReferenceInstructionsBuffer * const RK_C99(restrict) instructionBuffer, NSError **error) {
  NSCParameterAssert((referenceStringBuffer != NULL) && (regex != NULL) && (instructionBuffer != NULL));
  NSRange     currentRange     = NSMakeRange(0, 0), validVarRange  = NSMakeRange(NSNotFound, 0), parsedVarRange = NSMakeRange(NSNotFound, 0);
  RKUInteger  referenceIndex   = 0,                 parsedUInteger = 0;
  NSString   *parseErrorString = NULL;
  NSError    *compileError     = NULL;
  
  while((RKUInteger)referenceIndex < referenceStringBuffer->length) {
    if((referenceStringBuffer->characters[referenceIndex] == '$') && (referenceStringBuffer->characters[referenceIndex + 1] == '$')) {
      currentRange.length++;
      if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE, referenceStringBuffer->characters, currentRange) == NO) { goto errorExit; }
      referenceIndex += 2;
      currentRange    = NSMakeRange(referenceIndex, 0);
      continue;
    } else if(referenceStringBuffer->characters[referenceIndex] == '$') {
      if(RKParseReference(referenceStringBuffer, NSMakeRange(referenceIndex, (referenceStringBuffer->length - referenceIndex)), NULL, NULL, regex, &parsedUInteger, NULL, RKParseReferenceIgnoreConversion | RKParseReferenceCheckCaptureName, &parsedVarRange, &validVarRange, &parseErrorString, NULL, NULL, &compileError)) {
        if(currentRange.length > 0)      {
          if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE,        referenceStringBuffer->characters,                  currentRange)  == NO) { goto errorExit; }
        } if(parsedUInteger == NSNotFound) {
          if(RKAppendInstruction(instructionBuffer, OP_COPY_CAPTURENAME,  referenceStringBuffer->characters + referenceIndex, validVarRange) == NO) { goto errorExit; }
        } else {
          if(RKAppendInstruction(instructionBuffer, OP_COPY_CAPTUREINDEX, NULL,                              NSMakeRange(parsedUInteger, 0)) == NO) { goto errorExit; }
        }
        
        referenceIndex += parsedVarRange.length;
        currentRange    = NSMakeRange(referenceIndex, 0);
        continue;
      }
      else { goto errorExit; }
    }
    else if(referenceStringBuffer->characters[referenceIndex] == '\\') {
      char       nextChar            = referenceStringBuffer->characters[referenceIndex + 1];
      RKUInteger appendRangeLocation = 0;
      int        appendOp            = 0;
      
      if((nextChar >= '0') && (nextChar <= '9')) {
        appendOp            = OP_COPY_CAPTUREINDEX;
        appendRangeLocation = nextChar - '0';

        if(appendRangeLocation >= [regex captureCount]) {
          compileError = [NSError rkErrorWithCode:0 localizeDescription:@"The capture reference '\\%c' specifies a capture subpattern '%lu' that is greater than number of capture subpatterns defined by the regular expression, '%ld'.", nextChar, (unsigned long)appendRangeLocation, (long)max(0, ((RKInteger)[regex captureCount] - 1))];
          goto errorExit;
        }
      } else {
        switch(nextChar) {
          case 'u': appendOp = OP_UPPERCASE_NEXT_CHAR; break;
          case 'l': appendOp = OP_LOWERCASE_NEXT_CHAR; break;
          case 'U': appendOp = OP_UPPERCASE_BEGIN;     break;
          case 'L': appendOp = OP_LOWERCASE_BEGIN;     break;
          case 'E': appendOp = OP_CHANGE_CASE_END;     break;
          default:                                     break;
        }
      }

      if(appendOp != 0) {
        if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE, referenceStringBuffer->characters, currentRange)      == NO) { goto errorExit; }
        referenceIndex += 2;
        currentRange    = NSMakeRange(referenceIndex, 0);
        if(RKAppendInstruction(instructionBuffer, appendOp,      NULL,            NSMakeRange(appendRangeLocation, 0)) == NO) { goto errorExit; }
        continue;
      }
    }
    
    referenceIndex++;
    currentRange.length++;
  }
  
  if(RKAppendInstruction(instructionBuffer, OP_COPY_RANGE, referenceStringBuffer->characters, currentRange)               == NO) { goto errorExit; }
  if(RKAppendInstruction(instructionBuffer, OP_STOP,       NULL,                              NSMakeRange(NSNotFound, 0)) == NO) { goto errorExit; }

  return(YES);

errorExit:
  if(error != NULL) { *error = compileError; }
  return(NO);
}

static BOOL RKAppendInstruction(RK_STRONG_REF RKReferenceInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, const int op, RK_STRONG_REF const void * const RK_C99(restrict) ptr, const NSRange range) {
  NSCParameterAssert(instructionsBuffer != NULL); NSCParameterAssert(instructionsBuffer->length <= instructionsBuffer->capacity); NSCParameterAssert(instructionsBuffer->isValid == YES);

  if((range.length == 0) && ((op == OP_COPY_RANGE))) { return(YES); }
  
  if(instructionsBuffer->length >= instructionsBuffer->capacity) {
    if(instructionsBuffer->mutableData == NULL) {
      RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 0, "The number of RKReferenceInstructions exceeded stack buffer requiring a buffer to be allocated from the heap.");
      if((instructionsBuffer->mutableData = [NSMutableData dataWithLength:(sizeof(RKReferenceInstruction) * (instructionsBuffer->capacity + RK_DEFAULT_STACK_INSTRUCTIONS))]) == NULL) { goto errorExit; }
      if((instructionsBuffer->instructions != NULL) && (instructionsBuffer->capacity > 0)) {
        [instructionsBuffer->mutableData appendBytes:instructionsBuffer->instructions length:(sizeof(RKReferenceInstruction) * instructionsBuffer->capacity)];
      }
      instructionsBuffer->capacity += RK_DEFAULT_STACK_INSTRUCTIONS;
    }
    else {
      RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 0, "The number of RKReferenceInstructions exceeded current heap buffer size requiring additional heap storage be allocated.");
      [instructionsBuffer->mutableData increaseLengthBy:(sizeof(RKReferenceInstruction) * RK_DEFAULT_STACK_INSTRUCTIONS)];
      instructionsBuffer->capacity += RK_DEFAULT_STACK_INSTRUCTIONS;
    }
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

static BOOL RKAppendCopyInstruction(RK_STRONG_REF RKCopyInstructionsBuffer * const RK_C99(restrict) instructionsBuffer, RK_STRONG_REF const void * const RK_C99(restrict) ptr, const NSRange range) {
  NSCParameterAssert(instructionsBuffer != NULL); NSCParameterAssert(instructionsBuffer->length <= instructionsBuffer->capacity); NSCParameterAssert(instructionsBuffer->isValid == YES);
  
  if(range.length == 0) { return(YES); }

  // If the current append request starts where the last copy ends, just append the current requests length
  if(instructionsBuffer->length > 0) {
    RKCopyInstruction RK_STRONG_REF *lastInstruction = &instructionsBuffer->instructions[(instructionsBuffer->length) - 1];
    if((lastInstruction->ptr + lastInstruction->length) == (ptr + range.location)) {
      lastInstruction->length          += range.length;
      instructionsBuffer->copiedLength += range.length;
      return(YES);
    }
  }

  if(instructionsBuffer->length >= instructionsBuffer->capacity) {
    if(instructionsBuffer->mutableData == NULL) {
      RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 0, "The number of RKCopyInstructions exceeded stack buffer requiring a buffer to be allocated from the heap.");
      if((instructionsBuffer->mutableData = [NSMutableData dataWithLength:(sizeof(RKCopyInstruction) * (instructionsBuffer->capacity + RK_DEFAULT_STACK_INSTRUCTIONS))]) == NULL) { goto errorExit; }
      if((instructionsBuffer->instructions != NULL) && (instructionsBuffer->capacity > 0)) {
        [instructionsBuffer->mutableData appendBytes:instructionsBuffer->instructions length:(sizeof(RKCopyInstruction) * instructionsBuffer->capacity)];
      }
      instructionsBuffer->capacity += RK_DEFAULT_STACK_INSTRUCTIONS;
    }
    else {
      RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 0, "The number of RKCopyInstructions exceeded current heap buffer size requiring additional heap storage be allocated.");
      [instructionsBuffer->mutableData increaseLengthBy:(sizeof(RKCopyInstruction) * RK_DEFAULT_STACK_INSTRUCTIONS)];
      instructionsBuffer->capacity += RK_DEFAULT_STACK_INSTRUCTIONS;
    }
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


static BOOL RKParseReference(RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) referenceBuffer, const NSRange referenceRange,
                             RK_STRONG_REF const RKStringBuffer * const RK_C99(restrict) subjectBuffer, RK_STRONG_REF const NSRange * const RK_C99(restrict) subjectMatchResultRanges,
                             RKRegex * const RK_C99(restrict) regex, RK_STRONG_REF RKUInteger * const RK_C99(restrict) parsedReferenceUIntegerPtr,
                             RK_STRONG_REF void * const RK_C99(restrict) conversionPtr, const RKParseReferenceFlags parseReferenceOptions, RK_STRONG_REF NSRange * const RK_C99(restrict) parsedRangePtr,
                             RK_STRONG_REF NSRange * const RK_C99(restrict) parsedReferenceRangePtr, NSString ** const RK_C99(restrict) errorString,
                             RK_STRONG_REF void *** const RK_C99(restrict) autoreleasePool, RK_STRONG_REF RKUInteger * const RK_C99(restrict) autoreleasePoolIndex, NSError **error) {
  NSCParameterAssert(referenceBuffer != NULL);
  NSCParameterAssert(regex           != NULL);

  RKParseErrorMessage   parseErrorMessage      = RKParseErrorNotValid;
  NSError              *parseError             = NULL;
  const RKStringBuffer  captureReferenceBuffer = RKMakeStringBuffer(referenceBuffer->string, referenceBuffer->characters + referenceRange.location, referenceRange.length, referenceBuffer->encoding);
  NSString * RK_C99(restrict) parseErrorString = NULL, * RK_C99(restrict) captureReferenceString = NULL, * RK_C99(restrict) captureString = NULL, * RK_C99(restrict) conversionString = NULL;
  const BOOL conversionAllowed = (parseReferenceOptions & RKParseReferenceConversionAllowed) != 0 ? YES : NO;
  const BOOL ignoreConversion  = (parseReferenceOptions & RKParseReferenceIgnoreConversion)  != 0 ? YES : NO;
  const BOOL strictReference   = (parseReferenceOptions & RKParseReferenceStrictReference)   != 0 ? YES : NO;
  const BOOL performConversion = (parseReferenceOptions & RKParseReferencePerformConversion) != 0 ? YES : NO;
  const BOOL checkCaptureName  = (parseReferenceOptions & RKParseReferenceCheckCaptureName)  != 0 ? YES : NO;
        BOOL successfulParse   = NO, createMutableConvertedString = NO;
  RKUInteger captureIndex      = 0;
  
  const char RK_STRONG_REF *startOfCaptureReference = captureReferenceBuffer.characters, RK_STRONG_REF *endOfCaptureReference = captureReferenceBuffer.characters;;
  const char RK_STRONG_REF *startOfCapture          = captureReferenceBuffer.characters, RK_STRONG_REF *endOfCapture          = captureReferenceBuffer.characters;
  const char RK_STRONG_REF *startOfConversion       = NULL,                              RK_STRONG_REF *endOfConversion       = NULL;
  const char RK_STRONG_REF *startOfBracket          = NULL,                              RK_STRONG_REF *endOfBracket          = NULL;
  
  if(parsedRangePtr             != NULL)     { *parsedRangePtr             = NSMakeRange(0, 0); }
  if(parsedReferenceRangePtr    != NULL)     { *parsedReferenceRangePtr    = NSMakeRange(0, 0); }
  if(RK_EXPECTED(errorString    != NULL, 1)) { *errorString                = NULL;              }
  if(parsedReferenceUIntegerPtr != NULL)     { *parsedReferenceUIntegerPtr = NSNotFound;        }

  if((*endOfCaptureReference != '\\') && RK_EXPECTED((*(endOfCaptureReference + 1) <= '9'), 1) && RK_EXPECTED((*(endOfCaptureReference + 1) >= '0'), 1) && ((*(endOfCaptureReference + 2) == 0) || (strictReference == NO))) { captureIndex = (*(endOfCaptureReference + 1) - '0'); startOfCapture = endOfCaptureReference + 1; endOfCaptureReference += 2; endOfCapture = endOfCaptureReference; goto finishedParse; } // Fast path \\[0-9]

  if(RK_EXPECTED(*endOfCaptureReference != '$', 0)) { parseErrorMessage = RKParseErrorNotValid; goto finishedParseError; }

  if(RK_EXPECTED((*(endOfCaptureReference + 1) <= '9'), 1) && RK_EXPECTED((*(endOfCaptureReference + 1) >= '0'), 1) && ((*(endOfCaptureReference + 2) == 0) || (strictReference == NO))) { captureIndex = (*(endOfCaptureReference + 1) - '0'); startOfCapture = endOfCaptureReference + 1; endOfCaptureReference += 2; endOfCapture = endOfCaptureReference; goto finishedParse; } // Fast path $[0-9]

  if(RK_EXPECTED(*(endOfCaptureReference + 1) != '{', 0)) { parseErrorMessage = RKParseErrorNotValid; goto finishedParseError; }

  if(RK_EXPECTED((*(endOfCaptureReference + 2) <= '9'), 1) && RK_EXPECTED((*(endOfCaptureReference + 2) >= '0'), 1) && RK_EXPECTED((*(endOfCaptureReference + 3) == '}'), 1) && ((*(endOfCaptureReference + 4) == 0) || (strictReference == NO))) { captureIndex = (*(endOfCaptureReference + 2) - '0'); startOfCapture = endOfCaptureReference + 2; endOfCapture = endOfCaptureReference + 3; endOfCaptureReference += 4; goto finishedParse; } // Fast path ${[0-9]}

  startOfBracket         = endOfCaptureReference + 1;
  startOfCapture         = endOfCaptureReference + 2;
  endOfCaptureReference += 2;
  
  while(((endOfCaptureReference - captureReferenceBuffer.characters) < (int)captureReferenceBuffer.length) && (*endOfCaptureReference != 0) && (*endOfCaptureReference != ':') && (*endOfCaptureReference != '}')) {
    if((captureIndex != NSNotFound) && (RK_EXPECTED((*endOfCaptureReference <= '9'), 1) && RK_EXPECTED((*endOfCaptureReference >= '0'), 1))) { captureIndex = ((captureIndex * 10) + (*endOfCaptureReference - '0')); endOfCaptureReference++; continue; }
    if((RK_EXPECTED(((*endOfCaptureReference | 0x20) >= 'a'), 1) && RK_EXPECTED(((*endOfCaptureReference | 0x20) <= 'z'), 1)) || RK_EXPECTED((*endOfCaptureReference == '_'), 0) || ((captureIndex == NSNotFound ) && RK_EXPECTED((*endOfCaptureReference >= '0'), 1) && (*endOfCaptureReference <= '9'))) { captureIndex = NSNotFound; endOfCaptureReference++; continue; }
    break;
  }

  endOfCapture = endOfCaptureReference;
  
  if(RK_EXPECTED((endOfCapture - startOfCapture) == 0, 0)) { parseErrorMessage = RKParseErrorNotValid; goto finishedParseError; }

  if((*endOfCaptureReference == ':') && (conversionAllowed == NO) && (ignoreConversion == NO)) { parseErrorMessage = RKParseErrorTypeConversionNotPermitted; goto finishedParseError; }

  if((conversionAllowed == YES) && (*endOfCaptureReference == ':')) {
    endOfCaptureReference++;
    if((*endOfCaptureReference == '%') || (*endOfCaptureReference == '@')) {
      startOfConversion = endOfCaptureReference;
      while(((endOfCaptureReference - captureReferenceBuffer.characters) < (int)captureReferenceBuffer.length) && (*endOfCaptureReference != 0) && (*endOfCaptureReference != '}')) { endOfCaptureReference++; }
      endOfConversion = endOfCaptureReference;
      if((endOfConversion - startOfConversion) == 1) { parseErrorMessage = RKParseErrorConversionFormatNotValid;        goto finishedParseError; }
    } else                                           { parseErrorMessage = RKParseErrorConversionFormatValidBeginsWith; goto finishedParseError; }
  }
  
  if(*endOfCaptureReference == '}') { endOfCaptureReference++; endOfBracket = endOfCaptureReference; }
  
  if(RK_EXPECTED((startOfBracket != NULL), 1) && RK_EXPECTED(((endOfBracket - startOfBracket) == 0), 0)) { parseErrorMessage = RKParseErrorConversionFormatNotValid; goto finishedParseError; }

  if(RK_EXPECTED((startOfBracket != NULL), 1) && RK_EXPECTED((endOfBracket == NULL), 0)) {
    while(((endOfCaptureReference - captureReferenceBuffer.characters) < (int)captureReferenceBuffer.length) && (*endOfCaptureReference != 0) && (*endOfCaptureReference != '}')) { endOfCaptureReference++; }
    if(*endOfCaptureReference == '}') {
      endOfCaptureReference++;
      endOfBracket = endOfCaptureReference;
      if(conversionAllowed == NO) { parseErrorMessage = RKParseErrorNotValid; goto finishedParseError; } else { parseErrorMessage = RKParseErrorConversionFormatNotValid; goto finishedParseError; }
    }
  }

  if((RK_EXPECTED((startOfBracket == NULL), 0) && RK_EXPECTED((endOfBracket != NULL), 1)) || (RK_EXPECTED((startOfBracket != NULL), 1) && RK_EXPECTED((endOfBracket == NULL), 0))) { parseErrorMessage = RKParseErrorUnbalancedCurlyBrackets; goto finishedParseError; }

finishedParse:
  
  if((captureIndex == NSNotFound) && (regex != NULL)) {
    NSError *nameError = NULL;
    captureIndex = RKCaptureIndexForCaptureNameCharactersWithError(regex, NULL, startOfCapture, (endOfCapture - startOfCapture), NULL, &nameError);
    if(((captureIndex == NSNotFound) || (nameError != NULL)) && ((subjectMatchResultRanges != NULL) || (checkCaptureName == YES))) { parseErrorMessage = RKParseErrorNamedCaptureUndefined; goto finishedParseError; }
  }
    
  if(captureIndex != NSNotFound) {
    if(RK_EXPECTED(captureIndex >= [regex captureCount], 0)) { parseErrorMessage = RKParseErrorCaptureGreaterThanRegexCaptures; goto finishedParseError; }

    if((performConversion == YES) && (subjectMatchResultRanges[captureIndex].location != NSNotFound)) {
      NSCParameterAssert((subjectMatchResultRanges[captureIndex].location + subjectMatchResultRanges[captureIndex].length) <= subjectBuffer->length);
      
      id convertedString = NULL;
      
      if(startOfConversion != NULL) {
        if(*startOfConversion == '%') {
          RKUInteger convertLength = subjectMatchResultRanges[captureIndex].length;
          RK_STRONG_REF       char * RK_C99(restrict) convertBuffer = NULL; char convertStackBuffer[1024];
          RK_STRONG_REF const char * RK_C99(restrict) convertPtr    = (subjectBuffer->characters + subjectMatchResultRanges[captureIndex].location);
          RK_STRONG_REF       char * RK_C99(restrict) formatBuffer  = NULL; char formatStackBuffer[1024]; // If it fits in our *stackBuffer, use that, otherwise grab an autoreleasedMalloc to hold the characters.
          
          if(RK_EXPECTED(convertLength < 1020, 1)) { memcpy(&convertStackBuffer[0], convertPtr, convertLength); convertBuffer = &convertStackBuffer[0]; }
          else { convertBuffer = RKAutoreleasedMalloc(convertLength + 1); memcpy(&convertBuffer[0], convertPtr, convertLength); }
          convertBuffer[convertLength] = 0;
          
          if(RK_EXPECTED((endOfConversion - startOfConversion) < 1020, 1)) { memcpy(&formatStackBuffer[0], startOfConversion, (endOfConversion - startOfConversion)); formatBuffer = &formatStackBuffer[0]; } 
          else { formatBuffer = RKAutoreleasedMalloc((endOfConversion - startOfConversion) + 1); memcpy(&formatBuffer[0], startOfConversion, (endOfConversion - startOfConversion)); }
          formatBuffer[(endOfConversion - startOfConversion)] = 0;
          
          if(RK_EXPECTED((convertBuffer != NULL), 1) && RK_EXPECTED((formatBuffer != NULL), 1)) {
            if(formatBuffer[2] == 0) { // Fast, inline bypass if it's a simple (32 bit int) conversion.
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
                  unsigned int acc = 0, cutoff = 0;
                  char c = 0;
                  
                  NSCParameterAssert(s != NULL);
                  
                  do { c = *s++; } while (isspace((unsigned char)c) && (s <= &convertBuffer[convertLength]));
                  if(c == '-') { neg = 1; c = *s++; } else if (c == '+') { c = *s++; } 
                  if((c == '0') && (*s == 'x' || *s == 'X') && (s <= &convertBuffer[convertLength])) { c = s[1]; s += 2; base = 16; } else { base = c == '0' ? 8 : 10; }
                  
                  if(unsignedConversion == YES) { cutoff = UINT_MAX / base; cutlim = UINT_MAX % base; } 
                  else { cutoff = (neg ? (unsigned int)-(INT_MIN + INT_MAX) + INT_MAX : INT_MAX) / base; cutlim = cutoff % base; }
                  
                  do {
                    if(c >= '0' && c <= '9') { c -= '0'; } else if(c >= 'A' && c <= 'F') { c -= 'A' - 10; } else if(c >= 'a' && c <= 'f') { c -= 'a' - 10; } else { break; }
                    if(c >= base) {  break; }
                    if(any < 0 || acc > cutoff || (acc == cutoff && c > cutlim)) { any = -1; }
                    else { any = 1; acc *= base; acc += c; }
                  } while(((c = *s++) != 0) && (s <= &convertBuffer[convertLength]));
                  
                  if(any < 0) { if(unsignedConversion == YES) { acc = UINT_MAX; } else { acc = neg ? INT_MIN : INT_MAX; } } else if(neg) { acc = -acc; }
                  
                  if(RK_EXPECTED(conversionPtr == NULL, 0)) { parseErrorMessage = RKParseErrorStoragePointerNull; goto finishedParseError; }
                  *((int *)conversionPtr) = acc;
                  goto finishedParseSuccess;
                }
                  break;
                default: break; // Will fall thru to sscanf if we didn't fast bypass convert it here.
              }
            }
            RK_PROBE(PERFORMANCENOTE, regex, [regex hash], (char *)regexUTF8String(regex), 0, -1, 0, "Slow conversion via sscanf.");
            sscanf(convertBuffer, formatBuffer, conversionPtr); 
          }
          goto finishedParseSuccess;
        }
        
        NSCParameterAssert(endOfConversion != NULL);
        
        // Before we create a string, check if it's something reasonable.
        if( ! ( RK_EXPECTED((*startOfConversion == '@'), 1) && 
                     ( ((*(endOfConversion - 1) == 'n') && (((startOfConversion + 1) == (endOfConversion - 1)) || ((startOfConversion + 2) == (endOfConversion - 1)))) ||
                       ((*(endOfConversion - 1) == 'd') &&  ((startOfConversion + 1) == (endOfConversion - 1))) ))) { parseErrorMessage = RKParseErrorUnknownTypeConversion; goto finishedParseError; }
      }
#ifdef USE_CORE_FOUNDATION
      if(RK_EXPECTED(createMutableConvertedString == NO, 1)) { convertedString = RKMakeCollectable(CFStringCreateWithBytes(NULL, (const UInt8 *)(&subjectBuffer->characters[subjectMatchResultRanges[captureIndex].location]), (CFIndex)subjectMatchResultRanges[captureIndex].length, kCFStringEncodingUTF8, NO));
      } else { convertedString = [[NSMutableString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[captureIndex].location] length:subjectMatchResultRanges[captureIndex].length encoding:NSUTF8StringEncoding]; }
#else  // USE_CORE_FOUNDATION is not defined
      if(RK_EXPECTED(createMutableConvertedString == YES, 0)) { convertedString = [[NSMutableString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[captureIndex].location] length:subjectMatchResultRanges[captureIndex].length encoding:NSUTF8StringEncoding]; }
      else { convertedString = [[NSString alloc] initWithBytes:&subjectBuffer->characters[subjectMatchResultRanges[captureIndex].location] length:subjectMatchResultRanges[captureIndex].length encoding:NSUTF8StringEncoding]; }
#endif // USE_CORE_FOUNDATION
      if((autoreleasePool != NULL) && (RKRegexGarbageCollect == 0)) { autoreleasePool[*autoreleasePoolIndex] = (void *)convertedString; *autoreleasePoolIndex = *autoreleasePoolIndex + 1; }
      if((autoreleasePool == NULL) && (RKRegexGarbageCollect == 0)) { RKAutorelease(convertedString); }

      if(startOfConversion == NULL) { *((NSString **)conversionPtr) = convertedString; goto finishedParseSuccess; }
      
      if(RK_EXPECTED((*startOfConversion == '@'), 1) && RK_EXPECTED((*(endOfConversion - 1) == 'd'), 1) && RK_EXPECTED(((startOfConversion + 1) == (endOfConversion - 1)), 1)) {
        static BOOL didPrintLockWarning = NO;
        if(RK_EXPECTED(NSStringRKExtensionsInitialized == 0, 0)) { NSStringRKExtensionsInitializeFunction(); } 
        if(RK_EXPECTED(RKFastLock(NSStringRKExtensionsNSDateLock) == NO, 0)) {
          if(didPrintLockWarning == NO) { NSLog(@"Unable to acquire the NSDate access serialization lock.  Heavy concurrent date conversions may return incorrect results."); didPrintLockWarning = YES; }
        }
        *((NSDate **)conversionPtr) = [NSDate dateWithNaturalLanguageString:convertedString];
        RKFastUnlock(NSStringRKExtensionsNSDateLock);
        goto finishedParseSuccess;
      }
#ifdef HAVE_NSNUMBERFORMATTER_CONVERSIONS
      else if(RK_EXPECTED((*startOfConversion == '@'), 1) && (*(endOfConversion - 1) == 'n') && (((startOfConversion + 1) == (endOfConversion - 1)) || ((startOfConversion + 2) == (endOfConversion - 1)))) {
        struct __RKThreadLocalData RK_STRONG_REF * RK_C99(restrict) tld = RKGetThreadLocalData();
        if(RK_EXPECTED(tld == NULL, 0)) { parseErrorMessage = RKParseErrorNotValid; goto finishedParseError; }
        NSNumberFormatter * RK_C99(restrict) numberFormatter = RK_EXPECTED((tld->_numberFormatter == NULL), 0) ? RKGetThreadLocalNumberFormatter() : tld->_numberFormatter;
        if((startOfConversion + 1) != (endOfConversion - 1)) {
          switch(*(startOfConversion + 1)) {
            case '.': if(tld->_currentFormatterStyle != NSNumberFormatterDecimalStyle)    { tld->_currentFormatterStyle = NSNumberFormatterDecimalStyle;    [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle]; }    break;
            case '$': if(tld->_currentFormatterStyle != NSNumberFormatterCurrencyStyle)   { tld->_currentFormatterStyle = NSNumberFormatterCurrencyStyle;   [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle]; }   break;
            case '%': if(tld->_currentFormatterStyle != NSNumberFormatterPercentStyle)    { tld->_currentFormatterStyle = NSNumberFormatterPercentStyle;    [numberFormatter setNumberStyle:NSNumberFormatterPercentStyle]; }    break;
            case 's': if(tld->_currentFormatterStyle != NSNumberFormatterScientificStyle) { tld->_currentFormatterStyle = NSNumberFormatterScientificStyle; [numberFormatter setNumberStyle:NSNumberFormatterScientificStyle]; } break;
            case 'w': if(tld->_currentFormatterStyle != NSNumberFormatterSpellOutStyle)   { tld->_currentFormatterStyle = NSNumberFormatterSpellOutStyle;   [numberFormatter setNumberStyle:NSNumberFormatterSpellOutStyle]; }   break;
            default: parseErrorMessage = RKParseErrorNSNumberConversionNotValid; goto finishedParseError; break;
          }
        } else { if(tld->_currentFormatterStyle != NSNumberFormatterNoStyle) { tld->_currentFormatterStyle = NSNumberFormatterNoStyle; [numberFormatter setNumberStyle:NSNumberFormatterNoStyle]; } }
        *((NSNumber **)conversionPtr) = [numberFormatter numberFromString:convertedString];
        goto finishedParseSuccess;
      }
#endif // HAVE_NSNUMBERFORMATTER_CONVERSIONS
      else { parseErrorMessage = RKParseErrorUnknownTypeConversion; goto finishedParseError; }
    }
  }
  
finishedParseSuccess:
  successfulParse = YES;
  goto finishedExit;
  
finishedParseError:
  {} // Compiler bug
    
  NSRange                         captureReferenceUTF8Range  = NSMakeRange(0,                                                             (endOfCaptureReference - startOfCaptureReference));
  NSRange                         captureUTF8Range           = NSMakeRange((startOfCapture          - captureReferenceBuffer.characters), (endOfCapture          - startOfCapture));
  NSRange                         referenceUTF8Range         = NSMakeRange((startOfCaptureReference - referenceBuffer->characters),       (endOfCaptureReference - startOfCaptureReference));
  NSRange                         conversionUTF8Range        = NSMakeRange(NSNotFound, 0);
  if(startOfConversion != NULL) { conversionUTF8Range        = NSMakeRange((startOfConversion       - captureReferenceBuffer.characters), (endOfConversion       - startOfConversion)); }

  NSRange                         captureReferenceUTF16Range = RKConvertUTF8ToUTF16RangeForStringBuffer((RKStringBuffer *)(&captureReferenceBuffer), captureReferenceUTF8Range);
  NSRange                         captureUTF16Range          = RKConvertUTF8ToUTF16RangeForStringBuffer((RKStringBuffer *)(&captureReferenceBuffer), captureUTF8Range);
  NSRange                         referenceUTF16Range        = RKConvertUTF8ToUTF16RangeForStringBuffer((RKStringBuffer *)referenceBuffer,           referenceUTF8Range);
  NSRange                         conversionUTF16Range       = NSMakeRange(NSNotFound, 0);
  if(startOfConversion != NULL) { conversionUTF16Range       = RKConvertUTF8ToUTF16RangeForStringBuffer((RKStringBuffer *)(&captureReferenceBuffer), conversionUTF8Range); }

  captureReferenceString              = RKAutorelease([[NSString alloc] initWithBytes:startOfCaptureReference length:captureReferenceUTF8Range.length  encoding:NSUTF8StringEncoding]);
  captureString                       = RKAutorelease([[NSString alloc] initWithBytes:startOfCapture          length:captureUTF8Range.length           encoding:NSUTF8StringEncoding]);
  conversionString                    = @"";
  if(startOfConversion != NULL) { conversionString = RKAutorelease([[NSString alloc] initWithBytes:startOfConversion length:conversionUTF8Range.length encoding:NSUTF8StringEncoding]); }
  
  switch(parseErrorMessage) {
    case RKParseErrorTypeConversionNotPermitted:       parseErrorString = RKLocalizedFormat(@"Type conversion is not permitted for capture reference '%@' in this context.",                                               captureReferenceString); break;
    case RKParseErrorConversionFormatNotValid:         parseErrorString = RKLocalizedFormat(@"The conversion format of capture reference '%@' is not valid.",                                                              captureReferenceString); break;
    case RKParseErrorConversionFormatValidBeginsWith:  parseErrorString = RKLocalizedFormat(@"The conversion format of capture reference '%@' is not valid. Valid formats begin with '@' or '%%'.",                        captureReferenceString); break;
    case RKParseErrorUnbalancedCurlyBrackets:          parseErrorString = RKLocalizedFormat(@"The capture reference '%@' has unbalanced curly brackets.",                                                                  captureReferenceString); break;
    case RKParseErrorNamedCaptureUndefined:            parseErrorString = RKLocalizedFormat(@"The named capture '%@' from capture reference '%@' is not defined by the regular expression.", captureString,                captureReferenceString); break;
    case RKParseErrorCaptureGreaterThanRegexCaptures:  parseErrorString = RKLocalizedFormat(@"The capture reference '%@' specifies a capture subpattern, %lu, that is greater than number of capture subpatterns defined by the regular expression, %ld.", captureReferenceString, (unsigned long)captureIndex, (long)max(0, ((RKInteger)[regex captureCount] - 1))); break;
    case RKParseErrorStoragePointerNull:               parseErrorString = RKLocalizedFormat(@"The capture reference '%@' storage pointer is NULL.",                                                                        captureReferenceString); break;
    case RKParseErrorUnknownTypeConversion:            parseErrorString = RKLocalizedFormat(@"Unknown type conversion requested in capture reference '%@'.",                                                               captureReferenceString); break;
    case RKParseErrorNSNumberConversionNotValid:       parseErrorString = RKLocalizedFormat(@"Capture reference '%@' NSNumber conversion is invalid. Valid NSNumber conversion options are '.', '$', '%%', 'e', and 'w'.", captureReferenceString); break;
    case RKParseErrorNotValid: /* fall-thru */
    default:                                           parseErrorString = RKLocalizedFormat(@"The capture reference '%@' is not valid.",                                                                                   captureReferenceString); break;
  }
  NSCParameterAssert(parseErrorString != NULL);
  
  if(RK_EXPECTED(errorString != NULL, 1)) { *errorString = parseErrorString; }
  
  parseError = [NSError errorWithDomain:RKRegexErrorDomain
                                   code:0
                               userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                         parseErrorString,                                    NSLocalizedDescriptionKey,
                                         regex,                                               RKRegexErrorKey,
                                         captureReferenceString,                              RKRegexCaptureReferenceStringErrorKey,
                                         captureString,                                       RKRegexCaptureStringErrorKey,
                                         conversionString,                                    RKRegexConversionStringErrorKey,
                                         referenceBuffer->string,                             RKRegexReferenceStringErrorKey,
                                         [NSValue valueWithRange:captureReferenceUTF16Range], RKRegexCaptureReferenceRangeErrorKey,
                                         [NSValue valueWithRange:captureUTF16Range],          RKRegexCaptureRangeErrorKey,
                                         [NSValue valueWithRange:conversionUTF16Range],       RKRegexConversionRangeErrorKey,
                                         [NSValue valueWithRange:referenceUTF16Range],        RKRegexReferenceRangeErrorKey,
                                         [NSNumber numberWithUnsignedLong:captureIndex],      RKRegexCaptureIndexErrorKey,
                                         NULL]];
  
  successfulParse = NO;
  goto finishedExit;
  
finishedExit:

  if(error                      != NULL) { *error                      = parseError; }
  if(parsedRangePtr             != NULL) { *parsedRangePtr             = NSMakeRange(0, (endOfCaptureReference - captureReferenceBuffer.characters)); }
  if(parsedReferenceRangePtr    != NULL) { *parsedReferenceRangePtr    = NSMakeRange(startOfCapture - captureReferenceBuffer.characters, (endOfCapture - startOfCapture)); }
  if(parsedReferenceUIntegerPtr != NULL) { *parsedReferenceUIntegerPtr = captureIndex; }
  return(successfulParse);
}


#ifdef REGEXKIT_DEBUG

static void dumpReferenceInstructions(RK_STRONG_REF const RKReferenceInstructionsBuffer *ins) {
  if(ins == NULL) { NSLog(@"NULL replacement instructions"); return; }
  NSLog(@"Replacement instructions");
  NSLog(@"isValid     : %@",  RKYesOrNo(ins->isValid));
  NSLog(@"Length      : %lu", (unsigned long)ins->length);
  NSLog(@"Capacity    : %lu", (unsigned long)ins->capacity);
  NSLog(@"Instructions: %p",  ins->instructions);
  NSLog(@"mutableData : %p",  ins->mutableData);
  
  for(RKUInteger x = 0; x < ins->length; x++) {
    RKReferenceInstruction *at        = &ins->instructions[x];
    NSMutableString        *logString = [NSMutableString stringWithFormat:@"[%4lu] op: %lu ptr: %p range {%6lu, %6lu} ", (unsigned long)x, (unsigned long)at->op, at->ptr, (unsigned long)at->range.location, (unsigned long)at->range.length];
    switch(at->op) {
      case OP_STOP:                [logString appendFormat:@"Stop"]; break;
      case OP_COPY_CAPTUREINDEX:   [logString appendFormat:@"Capture Index #%lu", (unsigned long)at->range.location]; break;
      case OP_COPY_CAPTURENAME:    [logString appendFormat:@"Capture Name '%@'", at->ptr]; break;
      case OP_COPY_RANGE:          [logString appendFormat:@"Copy range: ptr: %p length: %lu '%*.*s'", (at->ptr + at->range.location), (unsigned long)at->range.length, (int)at->range.length, (int)at->range.length, at->ptr + at->range.location]; break;
      case OP_COMMENT:             [logString appendFormat:@"Comment"]; break;

      case OP_UPPERCASE_NEXT_CHAR: [logString appendFormat:@"Uppercase Next Char"]; break;
      case OP_LOWERCASE_NEXT_CHAR: [logString appendFormat:@"Lowercase Next Char"]; break;
      case OP_UPPERCASE_BEGIN:     [logString appendFormat:@"Uppercase Begin"]; break;
      case OP_LOWERCASE_BEGIN:     [logString appendFormat:@"Lowercase Begin"]; break;
      case OP_CHANGE_CASE_END:     [logString appendFormat:@"Change Case End"]; break;
      default:                     [logString appendFormat:@"UNKNOWN"]; break;
    }
    NSLog(@"%@", logString);
  }
}


static void dumpCopyInstructions(RK_STRONG_REF const RKCopyInstructionsBuffer *ins) {
  if(ins == NULL) { NSLog(@"NULL copy instructions"); return; }
  NSLog(@"Copy instructions");
  NSLog(@"isValid      : %@",  RKYesOrNo(ins->isValid));
  NSLog(@"Length       : %lu", (unsigned long)ins->length);
  NSLog(@"Capacity     : %lu", (unsigned long)ins->capacity);
  NSLog(@"Copied length: %lu", (unsigned long)ins->copiedLength);
  NSLog(@"Instructions : %p",  ins->instructions);
  NSLog(@"mutableData  : %p",  ins->mutableData);
  
  for(RKUInteger x = 0; x < ins->length; x++) {
    RKCopyInstruction *at = &ins->instructions[x];
    NSLog(@"[%4lu] ptr: %p - %p length %lu (0x%8.8lx) = '%*.*s'", (unsigned long)x, at->ptr, at->ptr + at->length, (unsigned long)at->length, (unsigned long)at->length, (int)min(at->length, (unsigned)16), (int)min(at->length, (unsigned)16), at->ptr); 
  }
}

#endif // REGEXKIT_DEBUG
