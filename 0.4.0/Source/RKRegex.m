//
//  RegexKit.m
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

#import <RegexKit/RKRegex.h>
#import <RegexKit/RegexKitPrivate.h>

NSString * const RKRegexSyntaxErrorException      = @"RKRegexSyntaxErrorException";
NSString * const RKRegexUnsupportedException      = @"RKRegexUnsupportedException";
NSString * const RKRegexCaptureReferenceException = @"RKRegexCaptureReferenceException";


#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
       int32_t        RKRegexGarbageCollect    = 0;
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION
static int32_t        RKRegexLoadInitialized   = 0;
static RKCache       *RKRegexCache             = NULL;
static NSString      *RKRegexPCREVersionString = NULL;
static int32_t        RKRegexPCREMajorVersion  = 0;
static int32_t        RKRegexPCREMinorVersion  = 0;
static RKBuildConfig  RKRegexPCREBuildConfig   = 0;

#ifdef    USE_CORE_FOUNDATION
static Boolean RKCFArrayEqualCallBack(const void *value1, const void *value2) { return(CFEqual(value1, value2)); }
static void RKCFArrayRelease(CFAllocatorRef allocator RK_ATTRIBUTES(unused), const void *ptr) { RKCFRelease(ptr); }
static CFArrayCallBacks noRetainArrayCallBacks = {0, NULL, RKCFArrayRelease, NULL, RKCFArrayEqualCallBack};
#endif // USE_CORE_FOUNDATION


#ifdef    RK_ENABLE_THREAD_LOCAL_STORAGE

// Thread local data functions.

pthread_key_t __RKRegexThreadLocalDataKey = (pthread_key_t)NULL;

static void __RKThreadIsExiting(void *arg) {
  RK_STRONG_REF struct __RKThreadLocalData *tld = (struct __RKThreadLocalData *)arg;
  if (tld == NULL) { return; }
  if(tld->_numberFormatter != NULL) { RKEnableCollectorForPointer(tld->_numberFormatter); RKRelease(tld->_numberFormatter); tld->_numberFormatter = NULL; }
  free(tld);
  tld = NULL;
}

struct __RKThreadLocalData *__RKGetThreadLocalData(void) {
  RK_STRONG_REF struct __RKThreadLocalData *tld = pthread_getspecific(__RKRegexThreadLocalDataKey);
  if(tld != NULL) { return(tld); }
  
  if((tld = malloc(sizeof(struct __RKThreadLocalData))) == NULL) { return(NULL); }
  memset(tld, 0, sizeof(struct __RKThreadLocalData));
  pthread_setspecific(__RKRegexThreadLocalDataKey, tld);
  
  return(tld);
}

#ifdef    HAVE_NSNUMBERFORMATTER_CONVERSIONS

NSNumberFormatter *__RKGetThreadLocalNumberFormatter(void) {
  RK_STRONG_REF struct __RKThreadLocalData *tld = NULL;
  
  if((tld = __RKGetThreadLocalData()) == NULL) { return(NULL); }
  if(tld->_numberFormatter != NULL) { return (tld->_numberFormatter); }
  
  tld->_numberFormatter = [[NSNumberFormatter alloc] init];
  RKDisableCollectorForPointer(tld->_numberFormatter);
  [tld->_numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
  [tld->_numberFormatter setNumberStyle:NSNumberFormatterNoStyle];
  tld->_currentFormatterStyle = NSNumberFormatterNoStyle;
  return(tld->_numberFormatter);
}

#endif // HAVE_NSNUMBERFORMATTER_CONVERSIONS
#endif // RK_ENABLE_THREAD_LOCAL_STORAGE

@implementation RKRegex

//
// +load is called when the runtime first loads a class or category.
//

+ (void)load
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(RKRegexLoadInitialized == 1) { return; }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &RKRegexLoadInitialized)) {
    pcre_callout = RKRegexPCRECallout;

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
    if([objc_getClass("NSGarbageCollector") defaultCollector] != NULL) {
      RKRegexGarbageCollect = 1;
#ifdef    USE_CORE_FOUNDATION
      noRetainArrayCallBacks.release = NULL;
#endif // USE_CORE_FOUNDATION
    }
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION
    
#ifdef    RK_ENABLE_THREAD_LOCAL_STORAGE
    int pthreadError = 0;
    if((pthreadError = pthread_key_create(&__RKRegexThreadLocalDataKey, __RKThreadIsExiting)) != 0) {
      NSLog(@"Unable to create a pthread key for per thread resources.  Some functionality may not be available.  pthread_key_create returned %d, '%s'.", pthreadError, strerror(pthreadError));
    }
#endif // RK_ENABLE_THREAD_LOCAL_STORAGE
    
    const char *pcreVersionCharacters = pcre_version();
    char majorBuffer[64], minorBuffer[64];
    memset(&majorBuffer[0], 0, 64); memset(&minorBuffer[0], 0, 64);
    
    if((RKRegexPCREVersionString = [[NSString alloc] initWithFormat:@"%s", pcreVersionCharacters]) == NULL) { RKRegexPCREVersionString = @"UNKNOWN"; }
    RKDisableCollectorForPointer(RKRegexPCREVersionString);

    // This would be far, far simpler if could use a RKRegex matcher, but this is runtime initialization and we have to assume nothing else is ready.

    int tempErrorCode = 0, tempErrorOffset = 0, vectors[15] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    const char *tempErrorPtr = NULL;
    pcre *tempPCRE = NULL;
    
    tempPCRE = pcre_compile2("^(\\d+)\\.(\\d+)", 0, &tempErrorCode, &tempErrorPtr, &tempErrorOffset, NULL);
    if((tempPCRE == NULL) || (tempErrorCode != 0)) { NSLog(@"%@", RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library.")); }
    else {
      if((tempErrorCode = pcre_exec(tempPCRE, NULL, pcreVersionCharacters, (int)strlen(pcreVersionCharacters), 0, 0, vectors, 15)) <= 0) {
        NSLog(@"%@", RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library."));
      }
    }
    
    if(tempPCRE != NULL) { pcre_free(tempPCRE); tempPCRE = NULL; }

    if(tempErrorCode == 3) {
      memcpy(&majorBuffer[0], pcreVersionCharacters + vectors[2], max((vectors[3] - vectors[2]), 32));
      memcpy(&minorBuffer[0], pcreVersionCharacters + vectors[4], max((vectors[5] - vectors[4]), 32));
      
      RKRegexPCREMajorVersion = atoi(majorBuffer);
      RKRegexPCREMinorVersion = atoi(minorBuffer);
    } else { NSLog(@"%@", RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library.")); }

    int tempConfigInt = 0;
    if(pcre_config(PCRE_CONFIG_UTF8, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; } else if(tempConfigInt == 1) { RKRegexPCREBuildConfig |= RKBuildConfigUTF8; }
    if(pcre_config(PCRE_CONFIG_UNICODE_PROPERTIES, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; } else if(tempConfigInt == 1) { RKRegexPCREBuildConfig |= RKBuildConfigUnicodeProperties; }
    
    if(pcre_config(PCRE_CONFIG_NEWLINE, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; }
    switch(tempConfigInt) {
      case -1:   RKRegexPCREBuildConfig |= RKBuildConfigNewlineAny;      break;
#if PCRE_MAJOR >= 7 && PCRE_MINOR >= 1
      case -2:   RKRegexPCREBuildConfig |= RKBuildConfigNewlineAnyCRLF;  break;
#endif // >= 7.1
      case 10:   RKRegexPCREBuildConfig |= RKBuildConfigNewlineLF;       break;
      case 13:   RKRegexPCREBuildConfig |= RKBuildConfigNewlineCR;       break;
      case 3338: RKRegexPCREBuildConfig |= RKBuildConfigNewlineCRLF;     break;
      default: goto errorExit; break;
    }

#if PCRE_MAJOR >= 7 && PCRE_MINOR >= 4
    if(pcre_config(PCRE_CONFIG_BSR, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; }
    switch(tempConfigInt) {
      case 0:   RKRegexPCREBuildConfig |= RKBuildConfigBackslashRUnicode; break;
      case 1:   RKRegexPCREBuildConfig |= RKBuildConfigBackslashRAnyCRLR; break;
      default: goto errorExit; break;
    }
#endif // >= 7.4

  }
errorExit:
    return;
}

//
// +initialize is called by the runtime just before the class receives its first message.
//

+ (void)initialize
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(RKRegexCache == NULL) {
    RKRegex *tmpRegex = RKAutorelease([[RKCache alloc] initWithDescription:@"RKRegex Regular Expression Cache"]);
    if(RKAtomicCompareAndSwapPtr(NULL, tmpRegex, &RKRegexCache)) { RKRetain(RKRegexCache); RKDisableCollectorForPointer(RKRegexCache); }
  }
}

+ (RKCache *)regexCache
{
  return(RKRegexCache);
}

//
// PCRE library information methods
//

+ (NSString *)PCREVersionString
{
  return(RKRegexPCREVersionString);
}

+ (int32_t)PCREMajorVersion
{
  return(RKRegexPCREMajorVersion);
}

+ (int32_t)PCREMinorVersion
{
  return(RKRegexPCREMinorVersion);
}

+ (RKBuildConfig)PCREBuildConfig
{
  return(RKRegexPCREBuildConfig);
}

//
// NSCoder support, see RKCoder.m for the coding routines.
//

- (id)initWithCoder:(NSCoder *)coder
{
  return(RKRegexInitWithCoder(self, _cmd, coder));
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  RKRegexEncodeWithCoder(self, _cmd, coder);
}

//
// NSCopying support
//

- (id)copyWithZone:(NSZone *)zone
{
  return([(id)NSAllocateObject([self class], 0, zone) initWithRegexString:[NSString stringWithString:[self regexString]] options:[self compileOption]]);
}

//
// Class methods
//

+ (BOOL)isValidRegexString:(NSString * const)regexString options:(const RKCompileOption)options
{
  if(regexString == NULL) { return(NO); }

  BOOL validRegex = NO;

#ifdef    USE_MACRO_EXCEPTIONS

NS_DURING
  if([self regexWithRegexString:regexString options:options] != NULL) { validRegex = YES; }
NS_HANDLER
  validRegex = NO;
NS_ENDHANDLER

#else  // USE_MACRO_EXCEPTIONS not macro exceptions, new style compiler -fobjc-exceptions
    
@try { if([self regexWithRegexString:regexString options:options] != NULL) { validRegex = YES; } }
@catch (NSException *exception) { validRegex = NO; }

#endif // USE_MACRO_EXCEPTIONS

  return(validRegex);
}

RKRegex *RKRegexFromStringOrRegex(id self, const SEL _cmd, id aRegex, const RKCompileOption compileOptions, const BOOL shouldAutorelease) {
  static Class RK_C99(restrict) stringClass = NULL;
  static Class RK_C99(restrict) regexClass = NULL;
  static BOOL lookupInitialized = NO;
  
  if(RK_EXPECTED([aRegex isKindOfClass:stringClass], 1)) {
    id cachedRegex;
    if(RK_EXPECTED((cachedRegex = RKFastCacheLookup(RKRegexCache, _cmd, RKHashForStringAndCompileOption(aRegex, compileOptions), shouldAutorelease)) != NULL, 1)) { return(cachedRegex); }
    cachedRegex = [(id)NSAllocateObject([RKRegex class], 0, NULL) initWithRegexString:aRegex options:compileOptions];
    if(RK_EXPECTED(shouldAutorelease == YES, 1)) { RKAutorelease(cachedRegex); }
    return(cachedRegex);
  }
  else if(RK_EXPECTED([aRegex isKindOfClass:regexClass], 1)) {
    RKRegex *returnRegex = aRegex;
    if(([aRegex compileOption] & compileOptions) != compileOptions) { returnRegex = [RKRegex regexWithRegexString:[aRegex regexString] options:([aRegex compileOption] | compileOptions)]; }
    if(shouldAutorelease == NO) { RKRetain(returnRegex); }
    return(returnRegex);
  }
  else if(RK_EXPECTED(aRegex == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"The specified regular expression is nil.") userInfo:NULL] raise]; }
  
  if(RK_EXPECTED(lookupInitialized == NO, 0)) {
    stringClass = [NSString class];
    regexClass = [RKRegex class];
    lookupInitialized = YES;
    RKAtomicMemoryBarrier();
    return(RKRegexFromStringOrRegex(self, _cmd, aRegex, compileOptions, shouldAutorelease));
  }
  
  [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"Unable to convert the class '%@' to a regular expression.", [aRegex className]) userInfo:NULL] raise];
  return(NULL);
}

#ifdef    USE_PLACEHOLDER

+ (id)allocWithZone:(NSZone *)zone {
#pragma unused(zone)
  return([RKRegexPlaceholder sharedObject]);
}

+ (id)regexWithRegexString:(NSString * const)regexString options:(const RKCompileOption)options
{  
  return(RKRegexFromStringOrRegex(self, _cmd, regexString, options, YES));
}

#else  // USE_PLACEHOLDER is not defined

+ (id)regexWithRegexString:(NSString * const)regexString options:(const RKCompileOption)options
{
  return(RKRegexFromStringOrRegex(self, _cmd, regexString, options, YES));
}

#endif // USE_PLACEHOLDER

- (id)initWithRegexString:(NSString * const RK_C99(restrict))regexString options:(const RKCompileOption)options;
{
  // In case anything goes wrong (ie, exception), we're guaranteed to be in the autorelease pool.  On successful initialization, we send ourselves a retain.
  // Any resources we allocate that are not automatically deallocated need to be referenced via an ivar.  Since we only send ourselves a retain on successful initialization,
  // if we exit prematurely for whatever reason, the autorelease pool will pop and then dealloc this object.  The dealloc method frees any resources that are referenced by ivars.
  // This greatly simplifies resource tracking during initialization for corner cases / partial initializations.
  RKAutorelease(self);

  if(RK_EXPECTED(regexString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"regexString == nil.") userInfo:nil] raise]; }

#ifndef   USE_PLACEHOLDER
  id cachedRegex = NULL;
  if(RK_EXPECTED((cachedRegex = [RKRegexCache objectForHash:RKHashForStringAndCompileOption(regexString, options) autorelease:NO]) != NULL, 0)) { return(cachedRegex); }
#endif // USE_PLACEHOLDER

  if(RK_EXPECTED((self = [self init]) == NULL, 0)) { goto errorExit; }

#ifdef    USE_CORE_FOUNDATION
  if(RK_EXPECTED((compiledRegexString = RKMakeCollectable(CFStringCreateCopy(NULL, (CFStringRef)regexString))) == NULL, 0)) { goto errorExit; }
#else  // USE_CORE_FOUNDATION is not defined
  if(RK_EXPECTED((compiledRegexString = [regexString copy]) == NULL, 0)) { goto errorExit; }
#endif // USE_CORE_FOUNDATION
  compileOption = options;
  
  int compileErrorOffset = 0;
  const char *errorCharPtr = NULL;
  RKCompileErrorCode initErrorCode = RKCompileErrorNoError;
  RKStringBuffer compiledRegexStringBuffer = RKStringBufferWithString(compiledRegexString);

  if(RK_EXPECTED(compiledRegexStringBuffer.characters == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"Unable to get string buffer from object '%@', which is a copy of the passed object '%@'.", RKPrettyObjectDescription(compiledRegexString), RKPrettyObjectDescription(regexString)) userInfo:NULL] raise]; }


  _compiledPCRE = pcre_compile2(compiledRegexStringBuffer.characters, (int)compileOption, (int *)&initErrorCode, &errorCharPtr, &compileErrorOffset, NULL);
  if(RK_EXPECTED(RK_EXPECTED((initErrorCode != RKCompileErrorNoError), 0) || RK_EXPECTED((_compiledPCRE == NULL), 0), 0)) {
    NSString *errorString = [NSString stringWithCString:(RK_EXPECTED((errorCharPtr == NULL), 0) ? "Internal error":errorCharPtr) encoding:NSUTF8StringEncoding];
    NSString *initErrorCodeString = RKStringFromCompileErrorCode(initErrorCode);
    NSArray  *compileOptionArray = RKArrayFromCompileOption(compileOption);

#ifdef    __MACOSX_RUNTIME__
    NSMutableAttributedString *regexAttributedString = [[[NSMutableAttributedString alloc] initWithString:regexString attributes:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@ at character %d", errorString, compileErrorOffset] forKey:NSToolTipAttributeName]] autorelease];
#else  // __MACOSX_RUNTIME__ GNUstep doesn't have NSToolTipAttributeName right now.
    NSMutableAttributedString *regexAttributedString = [[[NSMutableAttributedString alloc] initWithString:regexString] autorelease];
#endif // __MACOSX_RUNTIME__
    NSRange highlightRange = NSMakeRange(max(compileErrorOffset - 1, 0), min(1, (int)[regexString length]));
    if((highlightRange.location > [regexString length]) || (NSMaxRange(highlightRange) > [regexString length])) { highlightRange = NSMakeRange(0, [regexString length]); }
    [regexAttributedString addAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor redColor], NSBackgroundColorAttributeName, NULL] range:highlightRange];
    
    NSDictionary *exceptionInfoDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
      regexString, @"regexString",
      regexAttributedString, @"regexAttributedString",
      [NSNumber numberWithInt:compileOption], @"RKCompileOption",
      [NSString stringWithFormat:@"(%@)", [compileOptionArray componentsJoinedByString:@" | "]], @"RKCompileOptionString",
      compileOptionArray, @"RKCompileOptionArray",
      [NSNumber numberWithInt:initErrorCode], @"RKCompileErrorCode",
      initErrorCodeString, @"RKCompileErrorCodeString",
      [NSNumber numberWithInt:compileErrorOffset], @"regexStringErrorLocation",
      errorString, @"errorString",
      NULL];
    [[NSException exceptionWithName:RKRegexSyntaxErrorException reason:RKPrettyObjectMethodString(@"RKCompileErrorCode = %@ (#%d), '%s', at character %d while compiling the regular expression '%@'.", initErrorCodeString, initErrorCode, errorCharPtr, compileErrorOffset, regexString) userInfo:exceptionInfoDictionary] raise];
    goto errorExit;

  }
  
  _extraPCRE = pcre_study(_compiledPCRE, 0, &errorCharPtr);
  if(RK_EXPECTED((_extraPCRE == NULL), 0) && RK_EXPECTED((errorCharPtr != NULL), 0)) { goto errorExit; }
  
  if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_CAPTURECOUNT, &captureCount) != RKMatchErrorNoError, 0)) { goto errorExit; }
  captureCount++;
  
  if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE,   _extraPCRE, PCRE_INFO_NAMECOUNT,     &captureNameTableLength) != RKMatchErrorNoError, 0)) { goto errorExit; }
  if(captureNameTableLength > 0) {
    if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_NAMEENTRYSIZE, &captureNameLength)      != RKMatchErrorNoError, 0)) { goto errorExit; }
    if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_NAMETABLE,     &captureNameTable)       != RKMatchErrorNoError, 0)) { goto errorExit; }

    // XXX WARNING: This block of code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
    // See the PCRE documentation for a description of the capture name layout.  Roughly, nameEntrySize represents the largest name possible,
    // and each name is the first two bytes representing the index number, then a NULL terminated string for the name.
#ifdef    USE_CORE_FOUNDATION
    // Using core foundation directly is a big win here.  No message dispatching overhead and we save a lot of retain / release calls to boot.
    // We create a CFTypeRef array to hold pointers to our instantiated strings.
    // We then load all of them up in to an array in one call, with a special allocator structure that does not call CFRetain() on the objects.
    // The array, when freed, will call CFRelease on them.  This saves a retain/release pair for every object.
    // We need to be careful on error and make sure the the objects are released.

    BOOL objectsReady = YES;
    RKUInteger captureNameIndex = 0, x = 0;
    RK_STRONG_REF CFTypeRef * RK_C99(restrict) arrayObjectPointers = NULL;
    
    if(RK_EXPECTED((arrayObjectPointers = alloca((sizeof(void *) * 1) * captureCount)) == NULL, 0)) { goto errorExit; }
    for(x = 0; x < captureCount; x++) { arrayObjectPointers[x] = kCFNull; } // For capture indexes that don't have a name associated with them

    for(x = 0; x < captureNameTableLength; x++) {
      captureNameIndex = (((((RKUInteger)(captureNameTable[(x * captureNameLength)])) & 0xff) << 8) + ((((RKUInteger)(captureNameTable[(x * captureNameLength) + 1])) & 0xff) << 0));
      arrayObjectPointers[captureNameIndex] = (id)CFMakeCollectable(CFStringCreateWithCString(NULL, &captureNameTable[(x * captureNameLength) + 2], compiledRegexStringBuffer.encoding));
      if(RK_EXPECTED(arrayObjectPointers[captureNameIndex] == NULL, 0)) { objectsReady = NO; break; }
    }

    if(RK_EXPECTED(objectsReady == YES, 1)) {
      // CFArray has weak references to objects, NSArray has strong references, which we need when GC is enabled.
      if(RKRegexGarbageCollect == 0) { captureNameArray = (id)CFMakeCollectable(CFArrayCreate(NULL, &arrayObjectPointers[0], (CFIndex)captureCount, &noRetainArrayCallBacks)); }
      else { captureNameArray = [[NSArray alloc] initWithObjects:(const id *)(&arrayObjectPointers[0]) count:captureCount]; }
    }
    else { // Only release when objectsReady == NO
      if(RKRegexGarbageCollect == 0) {  for(x = 0; x < captureCount; x++) { if(arrayObjectPointers[x] != kCFNull) { RKCFRelease(arrayObjectPointers[x]); arrayObjectPointers[x] = NULL; } } }
    }

    if(RK_EXPECTED(captureNameArray == NULL, 0)) { goto errorExit; }
    
#else  // USE_CORE_FOUNDATION is not defined

    // We create an id array to hold pointers to our instantiated strings.  The instantiated strings are NOT autoreleased on creation.
    // If we instantiate all the strings successfully, we create a NSArray in one shot.
    // Regardless of whether or not we successfully create the NSArray, we send a release (not autorelease) message to any string we might have instantiated.
    // This is a surprisingly substantial win over a naive NSMutableArray adding convenience class autoreleased objects and then converting to an NSArray.
    // Since any initialization should be as fast as possible, we go through the trouble.

    BOOL objectsReady = YES;
    RKUInteger captureNameIndex = 0, x = 0;
    id * RK_C99(restrict) arrayObjectPointers = NULL;

    if(RK_EXPECTED((arrayObjectPointers = alloca(sizeof(id) * captureCount)) == NULL, 0)) { goto errorExit; }
    for(x = 0; x < captureCount; x++) { arrayObjectPointers[x] = [NSNull null]; } // For capture indexes that don't have a name associated with them

    for(x = 0; x < captureNameTableLength; x++) {
      captureNameIndex = (((((RKUInteger)(captureNameTable[(x * captureNameLength)])) & 0xff) << 8) + ((((RKUInteger)(captureNameTable[(x * captureNameLength) + 1])) & 0xff) << 0));
      arrayObjectPointers[captureNameIndex] = [[NSString alloc] initWithCString:&captureNameTable[(x * captureNameLength) + 2] encoding:compiledRegexStringBuffer.encoding];
      if(RK_EXPECTED(arrayObjectPointers[captureNameIndex] == NULL, 0)) { objectsReady = NO; break; }
    }
    
    if(RK_EXPECTED(objectsReady == YES, 1)) { captureNameArray = [[NSArray alloc] initWithObjects:&arrayObjectPointers[0] count:captureCount]; }
    for(x = 0; x < captureCount; x++) { if(arrayObjectPointers[x] != NULL) { RKRelease(arrayObjectPointers[x]); arrayObjectPointers[x] = NULL; } } // Safe to release NSNull object

    if(RK_EXPECTED(captureNameArray == NULL, 0)) { goto errorExit; }

#endif // USE_CORE_FOUNDATION

  }
  
  hash = RKHashForStringAndCompileOption(compiledRegexString, compileOption);
  [RKRegexCache addObjectToCache:self withHash:hash];

  return(RKRetain(self)); // We have successfully initialized, so rescue ourselves from the autorelease pool.
  
errorExit: // Catch point in case any clean up needs to be done.  Currently, none is necessary.
           // We are autoreleased at the start, any objects/resources we created will be handled by dealloc
  return(NULL);
}

- (id)retain
{
  if(RKRegexGarbageCollect == 0) { RKAtomicIncrementInt(&referenceCountMinusOne); }
  return(self);
}

- (void)release
{
  if(RKRegexGarbageCollect == 0) {
    RKAtomicDecrementInt(&referenceCountMinusOne);
    if(RK_EXPECTED(referenceCountMinusOne == -1, 0)) { [self dealloc]; }
  }
}

- (RKUInteger)retainCount
{
  if(RKRegexGarbageCollect == 0) { return(referenceCountMinusOne + 1); } else { return(RKUIntegerMax); }
}

- (void)dealloc
{
  if(compiledRegexString != NULL) { RKAutorelease(compiledRegexString); compiledRegexString = NULL; }
  if(captureNameArray    != NULL) { RKAutorelease(captureNameArray);    captureNameArray    = NULL; }
  if(_compiledPCRE       != NULL) { pcre_free(_compiledPCRE);          _compiledPCRE        = NULL; }
  if(_extraPCRE          != NULL) { pcre_free(_extraPCRE);             _extraPCRE           = NULL; }

  [super dealloc];
}

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
- (void)finalize
{
  if(_compiledPCRE       != NULL) { pcre_free(_compiledPCRE);          _compiledPCRE        = NULL; }
  if(_extraPCRE          != NULL) { pcre_free(_extraPCRE);             _extraPCRE           = NULL; }
  
  [super finalize];
}
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION

- (RKUInteger)hash
{
  if((RK_EXPECTED(hash == 0, 0)) && RK_EXPECTED(compiledRegexString != NULL, 1)) { hash = RKHashForStringAndCompileOption(compiledRegexString, compileOption); }
  return(hash);
}

- (BOOL)isEqual:(id)anObject
{
  BOOL equal = NO;
  
  if(self == anObject)                                                                                                     { equal = YES; goto exitNow; }
  if([anObject isKindOfClass:[self class]] == NO)                                                                          { equal = NO;  goto exitNow; }
  if([anObject hash] != [self hash])                                                                                       { equal = NO;  goto exitNow; }
  if(([compiledRegexString isEqualToString:[anObject regexString]]) && ([self compileOption] == [anObject compileOption])) { equal = YES; goto exitNow; }
  // Fall through with equal = NO initialization

exitNow:
  return(equal);
}

- (NSString *)description
{
  return([NSString stringWithFormat: @"<%@: %p> Regular expression = '%s', Compiled options = 0x%8.8x (%@)", [self className], self, [compiledRegexString UTF8String], (unsigned int)compileOption, [RKArrayFromCompileOption(compileOption) componentsJoinedByString:@" | "]]);
}

- (NSString *)regexString
{
  return(compiledRegexString);
}

- (RKCompileOption)compileOption
{
  return(compileOption);
}

- (RKUInteger)captureCount
{
  return(captureCount);
}

- (NSArray *)captureNameArray
{
  if(RK_EXPECTED(captureNameArray == NULL, 0)) { return(NULL); }
  return(captureNameArray);
}

- (BOOL)isValidCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:nil] raise]; }
  RKStringBuffer captureNameStringBuffer = RKStringBufferWithString(captureNameString);
  return(RKCaptureIndexForCaptureNameCharacters(self, _cmd, captureNameStringBuffer.characters, captureNameStringBuffer.length, NULL, NO) == NSNotFound ? NO : YES);
}

- (NSString *)captureNameForCaptureIndex:(const RKUInteger)captureIndex
{
  id captureName = NULL;

  if(RK_EXPECTED(captureIndex >= captureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureIndex > %lu captures in regular expression.", (unsigned long)(captureCount + 1)) userInfo:NULL] raise]; } 
  if(RK_EXPECTED(captureNameArray == NULL, 0)) { return(NULL); }

  NSParameterAssert(RK_EXPECTED(captureIndex < [captureNameArray count], 1));
  captureName = [captureNameArray objectAtIndex:captureIndex];
  return([captureName isEqual:[NSNull null]] ? NULL : captureName);
}

- (RKUInteger)captureIndexForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; }
  
  RKStringBuffer captureNameStringBuffer = RKStringBufferWithString(captureNameString);
  return(RKCaptureIndexForCaptureNameCharacters(self, _cmd, captureNameStringBuffer.characters, captureNameStringBuffer.length, NULL, YES));
}
  
- (RKUInteger)captureIndexForCaptureName:(NSString * const RK_C99(restrict))captureNameString inMatchedRanges:(const NSRange * const RK_C99(restrict))matchedRanges
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(matchedRanges     == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"matchedRanges == NULL.") userInfo:NULL] raise]; }
  
  RKStringBuffer captureNameStringBuffer = RKStringBufferWithString(captureNameString);
  return(RKCaptureIndexForCaptureNameCharacters(self, _cmd, captureNameStringBuffer.characters, captureNameStringBuffer.length, matchedRanges, YES));
}

- (BOOL)matchesCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const RKUInteger)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  return((NSEqualRanges(NSMakeRange(NSNotFound, 0), [self rangeForCharacters:matchCharacters length:length inRange:searchRange captureIndex:0 options:options]) == YES) ? NO : YES);
}

// XXX WARNING: This code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
- (NSRange)rangeForCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const RKUInteger)length inRange:(const NSRange)searchRange captureIndex:(const RKUInteger)captureIndex options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) matchRanges = NULL;

  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }

  if(RK_EXPECTED(captureIndex >= captureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureIndex %lu >= captureCount %lu.", (unsigned long)captureIndex, (unsigned long)(captureCount + 1)) userInfo:NULL] raise]; }

  matchErrorCode = [self getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:matchCharacters length:length inRange:searchRange options:options];
  if((matchErrorCode <= 0) || RK_EXPECTED(RKRangeInsideRange(matchRanges[0], searchRange) == NO, 0)) { return(NSMakeRange(NSNotFound, 0)); } // safe despite uninitialized matchRanges[0] on error
  return(matchRanges[captureIndex]);  
}


//
// Returns a pointer to a chunk of memory that is an array of NSRanges with captureCount elements.  Example:
//
// NSRange *ranges;
// ranges[0].location;
// ...
// ranges[(captureCount)].location;
//
// The pointer returned is the mutableBytes of an autoreleased NSMutableData.  Therefore, the buffer is only valid for the scope
// of the current autorelease pool.  If the range information is required past that, a private copy must be made.
//


// XXX WARNING: This code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
- (NSRange *)rangesForCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const RKUInteger)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
                NSRange * RK_C99(restrict) matchRanges  = NULL;
  RK_STRONG_REF NSRange * RK_C99(restrict) returnRanges = NULL;

  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }

  matchErrorCode = [self getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:matchCharacters length:length inRange:searchRange options:options];
  if((matchErrorCode <= 0)) { return(NULL); }

#ifdef    ENABLE_MACOSX_GARBAGE_COLLECTION
  if(RKRegexGarbageCollect == 1) {
    if(RK_EXPECTED((returnRanges = NSAllocateCollectable(captureCount * sizeof(NSRange), 0)) == NULL, 0)) { return(NULL); }
    memcpy(returnRanges, matchRanges, (captureCount * sizeof(NSRange)));
  } else
#endif // ENABLE_MACOSX_GARBAGE_COLLECTION
  {
    if(RK_EXPECTED((returnRanges = RKAutoreleasedMalloc(captureCount * sizeof(NSRange))) == NULL, 0)) { return(NULL); }
    memcpy(returnRanges, matchRanges, (captureCount * sizeof(NSRange)));
  }
  return(returnRanges);
}

//
// Low level access to pcre library.
// Allocates temporary storage space for capture information (pcre 'vectors') off the stack with alloca().
// pcre reserves 1/3 of the vectors for internal use. We allocate enough for our captures using the macro RK_PRESIZE_CAPTURE_COUNT().
//

// XXX WARNING: This code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
- (RKMatchErrorCode)getRanges:(NSRange * const RK_C99(restrict))ranges withCharacters:(const void * const RK_C99(restrict))charactersBuffer length:(const RKUInteger)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) matchRanges = NULL;
  
  if(RK_EXPECTED(ranges == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"ranges == NULL") userInfo:NULL] raise]; }
  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }
  
  matchErrorCode = [self getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:charactersBuffer length:length inRange:searchRange options:options];
  if(matchErrorCode > 0) { memcpy(ranges, matchRanges, sizeof(NSRange) * captureCount); }
  return(matchErrorCode);
}

// The next function is the low level access / checking methods for any capture names.  It works on raw char * + length buffers.
// The public API methods wrap these in more friendly NSString * style methods.
// This can save us a lot of time when doing capture name heavy processing as no objects are created.  Very light weight.

RKUInteger RKCaptureIndexForCaptureNameCharacters(RKRegex * const aRegex, const SEL _cmd, const char * const RK_C99(restrict) captureNameCharacters, const RKUInteger length, const NSRange * const RK_C99(restrict) matchedRanges, const BOOL raiseExceptionOnDoesNotExist) {
  if(RK_EXPECTED(aRegex == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"RKCaptureIndexForCaptureNameCharacters: aRegex == NULL." userInfo:NULL] raise]; }
  RKRegex *self = aRegex;
  RKUInteger searchBottom = 0, searchMiddle = 0, searchTop = self->captureNameTableLength, captureIndex = 0;
  char * RK_C99(restrict) atCaptureName = NULL;
  
  NSCParameterAssert(RK_EXPECTED(captureNameCharacters != NULL, 1));
  
  if(RK_EXPECTED(self->captureNameTableLength == 0, 0)) { goto doesNotExist; }
  if(RK_EXPECTED((length > self->captureNameLength), 0)) { goto doesNotExist; }

  while (searchTop > searchBottom) {
    int compareResult;
    searchMiddle = (searchTop + searchBottom) / 2;
    atCaptureName = (self->captureNameTable + (self->captureNameLength * searchMiddle));
    compareResult = strncmp(captureNameCharacters, atCaptureName + 2, length);
    if(compareResult == 0) { if(atCaptureName[length + 2] != 0) { compareResult = -1; } else { captureIndex = ((atCaptureName[0] << 8) + atCaptureName[1]); goto validName; } }
    if(compareResult > 0) { searchBottom = searchMiddle + 1; } else { searchTop = searchMiddle; }
  }
  
doesNotExist:
  if(raiseExceptionOnDoesNotExist == YES ) { [[NSException exceptionWithName:RKRegexCaptureReferenceException reason:RKPrettyObjectMethodString(@"The captureName '%*.*s' does not exist.", (int)length, (int)length, captureNameCharacters) userInfo:NULL] raise]; }
  return(NSNotFound);
  
validName:
  
  if(matchedRanges == NULL) { goto successExit;  }

  int optionJChanged = 0;

#ifdef    PCRE_INFO_JCHANGED
  // Only checked if defined, which is pcre >= 7.2
  if(RK_EXPECTED(pcre_fullinfo(self->_compiledPCRE, self->_extraPCRE, PCRE_INFO_JCHANGED, &optionJChanged) != RKMatchErrorNoError, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:RKPrettyObjectMethodString(@"pcre_fullinfo for PCRE_INFO_JCHANGED failed.") userInfo:NULL] raise]; }
#endif // PCRE_INFO_JCHANGED

  if((optionJChanged == 0) && ((self->compileOption & RKCompileDupNames) == 0)) {
    if(matchedRanges[captureIndex].location == NSNotFound) { captureIndex = NSNotFound; }
    goto successExit;
  }

  char *topCaptureName = self->captureNameTable + self->captureNameLength * (self->captureNameTableLength - 1), *startingCaptureName = atCaptureName;
  RKUInteger lowestCaptureIndex = (matchedRanges[captureIndex].location != NSNotFound) ? captureIndex : NSNotFound;
  
  while (atCaptureName > self->captureNameTable) {
    if(strncmp(captureNameCharacters, (atCaptureName - self->captureNameLength + 2), length) != 0) { break; }
    if(atCaptureName[length - self->captureNameLength + 2] != 0) { break; }
    atCaptureName -= self->captureNameLength;
    captureIndex = ((atCaptureName[0] << 8) + atCaptureName[1]);
    if(matchedRanges[captureIndex].location != NSNotFound) { lowestCaptureIndex = captureIndex; }
  }
  if(lowestCaptureIndex != NSNotFound) { captureIndex = lowestCaptureIndex; goto successExit; }
  atCaptureName = startingCaptureName;
  while(atCaptureName < topCaptureName) {
    if(strncmp(captureNameCharacters, (atCaptureName + self->captureNameLength + 2), length) != 0) { break; }
    if(atCaptureName[length + self->captureNameLength + 2] != 0) { break; }
    atCaptureName += self->captureNameLength;
    captureIndex = ((atCaptureName[0] << 8) + atCaptureName[1]);
    if(matchedRanges[captureIndex].location != NSNotFound) { goto successExit; }
  }
  captureIndex = NSNotFound;
  
successExit:
    return(captureIndex);
}

@end

@implementation RKRegex (Private)

// This is a semi-private interface to the low level PCRE match function.
// It assumes that the caller has correctly pre-sized an allocation according to the pcre_exec vector rules.
//
// WARNING!!
//
// This block of code is -=EXTREMELY SENSITIVE=- to 32 <-> 64 bit porting issues.
//
// pcre currently is not '64bit optimal', but we try to be forward looking by hiding the fact that we deal
// with size_t/NSUInteger values, but PCRE deals with 32 bit ints.
//
- (RKMatchErrorCode)getRanges:(NSRange * const)ranges count:(const RKUInteger)rangeCount withCharacters:(const void * const)charactersBuffer length:(const RKUInteger)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode errorCode = RKMatchErrorNoError;
  RKUInteger x = 0, numberOfVectors = rangeCount;
  int *vectors = (int *)ranges;
  
  NSAssert1(rangeCount >= RK_MINIMUM_CAPTURE_COUNT(captureCount), @"rangeCount < minimum required: %d", (int)RK_MINIMUM_CAPTURE_COUNT(captureCount));
  
  if(RK_EXPECTED(ranges == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"ranges == NULL") userInfo:NULL] raise]; }
  if(RK_EXPECTED(charactersBuffer == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"charactersBuffer == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(length < searchRange.location, 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %lu < start location %lu for range %@.", (unsigned long)length, (unsigned long)searchRange.location, NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  
  if(RK_EXPECTED(length < (searchRange.location + searchRange.length), 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %lu < end location %lu for range %@.", (unsigned long)length, (unsigned long)NSMaxRange(searchRange), NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  

  // The following lines ensure proper 64 bit behavior by guarding against PCRE's 32 bit ints.
  if(RK_EXPECTED(searchRange.location > INT_MAX, 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"searchRange.location %lu > 32 bit signed int.", (unsigned long)searchRange.location) userInfo:NULL] raise]; }
  if(RK_EXPECTED(searchRange.length > INT_MAX, 0))   { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"searchRange.length %lu > 32 bit signed int.", (unsigned long)searchRange.length) userInfo:NULL] raise]; }
  if(RK_EXPECTED(length > INT_MAX, 0))               { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %lu > 32 bit signed int.", (unsigned long)length) userInfo:NULL] raise]; }
  
  errorCode = (RKMatchErrorCode)pcre_exec(_compiledPCRE, _extraPCRE, (const char *)charactersBuffer, (int)length, (int)searchRange.location, (int)options, (int *)vectors, (int)numberOfVectors);
  
  // Convert PCRE vector format (start, end location) to NSRange format (start, length) on success
  if(errorCode > 0) {
    // The order of evaluation is -=EXTREMELY=- important.
    // On Mac OS X 10.5 under 64 bit, a NSRange is two NSUIntegers, or two LP64 'unsigned long's, or two 64 bit unsigned values.
    // On GNUstep LP64 platforms, a NSRange is two 'unsigned int's, or two 32 bit unsigned values.
    // PCRE defines its pair of vectors as 'int's, or two signed 32 bit values on all platforms.
    // We received a NSRange pointer that has enough for (argument)length NSRange structs.
    // We tell PCRE to use the NSRange pointer area to store it's pair of ints.  Then, we convert
    // those results in-place to NSRange style values.
    // Under 32 bit Mac OS X, there's no problem as the size of the NSRange and the size of two ints is exactly the same.
    // The problem is under 64 bits, a NSRange is now twice as large as the values we need to replace.
    // Therefore, we -=MUST=- start at the tail/last/end result from pcre_exec() and work towards the first result.
    // The byte offset to a given NSRange will always be greater than the byte offset to the pair of ints from pcre_exec().
    // If this is not done, we begin to over-write the results from pcre_exec with our re-written NSRange format.
    if((vectors[1] != -1) && ((RKUInteger)vectors[1] > NSMaxRange(searchRange))) { errorCode = RKMatchErrorNoMatch; }
    else {
      for(x = (RKUInteger)(errorCode - 1); x > 0; x--) {
        if(RK_EXPECTED(vectors[(x * 2)] == -1, 0)) { ranges[x] = NSMakeRange(NSNotFound, 0); } else { ranges[x] = NSMakeRange(vectors[(x * 2)], (vectors[(x * 2) + 1] - vectors[(x * 2)])); }
      }
      if(RK_EXPECTED(vectors[0] == -1, 0)) { ranges[0] = NSMakeRange(NSNotFound, 0); } else { ranges[0] = NSMakeRange(vectors[0], (vectors[1] - vectors[0])); }
      // pcre_exec may not always return up to captureCount number of results depending on the details of the match.
      // However, we guarantee that all up to captureCount elements will have valid results.  Since pcre_exec not returning
      // a result is equivalent to not finding the result, we write {NSNotFound, 0} values to reflect that.  The above 32 <-> 64 bit value
      // issues do not apply here as we have dealt with all the valid results from pcre_exec in the above loop.
      for(x = (size_t)errorCode; x < captureCount; x++) { ranges[x] = NSMakeRange(NSNotFound, 0); }
    }
  }
    
  return(errorCode);
}

@end
