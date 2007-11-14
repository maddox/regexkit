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

static int           globalInitialized       = 0;
static RKCache      *globalRegexCache        = NULL;
static NSString     *globalPCREVersionString = NULL;
static unsigned int  globalPCREMajorVersion  = 0;
static unsigned int  globalPCREMinorVersion  = 0;
static RKBuildConfig globalPCREBuildConfig   = 0;

#ifdef USE_CORE_FOUNDATION
static Boolean RKCFArrayEqualCallBack(const void *value1, const void *value2) { return(CFEqual(value1, value2)); }
static void RKCFArrayRelease(CFAllocatorRef allocator RK_ATTRIBUTES(unused), const void *ptr) { CFRelease(ptr); }
static const CFArrayCallBacks noRetainArrayCallBacks = {0, NULL, RKCFArrayRelease, NULL, RKCFArrayEqualCallBack};
#endif //USE_CORE_FOUNDATION


#ifdef RK_ENABLE_THREAD_LOCAL_STORAGE

// Thread local data functions.

pthread_key_t __RKRegexThreadLocalDataKey = (pthread_key_t)NULL;

static void __RKThreadIsExiting(void *arg) {
  struct __RKThreadLocalData *tld = (struct __RKThreadLocalData *)arg;
  if (tld == NULL) { return; }
  if(tld->_numberFormatter != NULL) { [tld->_numberFormatter release]; tld->_numberFormatter = NULL; }
}

struct __RKThreadLocalData *__RKGetThreadLocalData(void) {
  struct __RKThreadLocalData *tld = pthread_getspecific(__RKRegexThreadLocalDataKey);
  if(tld != NULL) { return(tld); }
  
  if((tld = malloc(sizeof(struct __RKThreadLocalData))) == NULL) { return(NULL); }
  memset(tld, 0, sizeof(struct __RKThreadLocalData));
  pthread_setspecific(__RKRegexThreadLocalDataKey, tld);
  
  return(tld);
}

#ifdef HAVE_NSNUMBERFORMATTER_CONVERSIONS

NSNumberFormatter *__RKGetThreadLocalNumberFormatter(void) {
  struct __RKThreadLocalData *tld = NULL;
  
  if((tld = __RKGetThreadLocalData()) == NULL) { return(NULL); }
  if(tld->_numberFormatter != NULL) { return (tld->_numberFormatter); }
  
  tld->_numberFormatter = [[NSNumberFormatter alloc] init];
  [tld->_numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
  [tld->_numberFormatter setNumberStyle:NSNumberFormatterNoStyle];
  tld->_currentFormatterStyle = NSNumberFormatterNoStyle;
  return(tld->_numberFormatter);
}

#endif //HAVE_NSNUMBERFORMATTER_CONVERSIONS
#endif //RK_ENABLE_THREAD_LOCAL_STORAGE

@implementation RKRegex

//
// +load is called when the runtime first loads a class or category.
//

+ (void)load
{
  RKAtomicMemoryBarrier(); // Extra cautious
  if(globalInitialized == 1) { return; }
  
  if(RKAtomicCompareAndSwapInt(0, 1, &globalInitialized)) {
    pcre_callout = RKRegexPCRECallout;
    
#ifdef RK_ENABLE_THREAD_LOCAL_STORAGE
    int pthreadError = 0;
    if((pthreadError = pthread_key_create(&__RKRegexThreadLocalDataKey, __RKThreadIsExiting)) != 0) {
      NSLog(@"Unable to create a pthread key for per thread resources.  Some functionality may not be available.  pthread_key_create returned %d, '%s'.", pthreadError, strerror(pthreadError));
    }
#endif
    
    const char *pcreVersionCharacters = pcre_version();
    char majorBuffer[64], minorBuffer[64];
    memset(&majorBuffer[0], 0, 64); memset(&minorBuffer[0], 0, 64);
    
    if((globalPCREVersionString = [[NSString alloc] initWithFormat:@"%s", pcreVersionCharacters]) == NULL) { globalPCREVersionString = @"UNKNOWN"; }

    // This would be far, far simpler if could use a RKRegex matcher, but this is runtime initialization and we have to assume nothing else is ready.

    int tempErrorCode = 0, tempErrorOffset = 0, vectors[15] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0};
    const char *tempErrorPtr = NULL;
    pcre *tempPCRE = NULL;
    
    tempPCRE = pcre_compile2("^(\\d+)\\.(\\d+)", 0, &tempErrorCode, &tempErrorPtr, &tempErrorOffset, NULL);
    if((tempPCRE == NULL) || (tempErrorCode != 0)) { NSLog(RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library.")); }
    else {
      if((tempErrorCode = pcre_exec(tempPCRE, NULL, pcreVersionCharacters, strlen(pcreVersionCharacters), 0, 0, vectors, 15)) <= 0) {
        NSLog(RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library."));
      }
    }
    
    if(tempPCRE != NULL) { pcre_free(tempPCRE); tempPCRE = NULL; }

    if(tempErrorCode == 3) {
      memcpy(&majorBuffer[0], pcreVersionCharacters + vectors[2], max((vectors[3] - vectors[2]), 32));
      memcpy(&minorBuffer[0], pcreVersionCharacters + vectors[4], max((vectors[5] - vectors[4]), 32));
      
      globalPCREMajorVersion = atoi(majorBuffer);
      globalPCREMinorVersion = atoi(minorBuffer);
    } else { NSLog(RKPrettyObjectMethodString(@"Unable to determine the major and minor version of the pcre library.")); }

    int tempConfigInt = 0;
    if(pcre_config(PCRE_CONFIG_UTF8, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; } else if(tempConfigInt == 1) { globalPCREBuildConfig |= RKBuildConfigUTF8; }
    if(pcre_config(PCRE_CONFIG_UNICODE_PROPERTIES, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; } else if(tempConfigInt == 1) { globalPCREBuildConfig |= RKBuildConfigUnicodeProperties; }
    
    if(pcre_config(PCRE_CONFIG_NEWLINE, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; }
    switch(tempConfigInt) {
      case -1:   globalPCREBuildConfig |= RKBuildConfigNewlineAny;      break;
#if PCRE_MAJOR >= 7 && PCRE_MINOR >= 1
      case -2:   globalPCREBuildConfig |= RKBuildConfigNewlineAnyCRLF;  break;
#endif // >= 7.1
      case 10:   globalPCREBuildConfig |= RKBuildConfigNewlineLF;       break;
      case 13:   globalPCREBuildConfig |= RKBuildConfigNewlineCR;       break;
      case 3338: globalPCREBuildConfig |= RKBuildConfigNewlineCRLF;     break;
      default: goto errorExit; break;
    }

#if PCRE_MAJOR >= 7 && PCRE_MINOR >= 4
    if(pcre_config(PCRE_CONFIG_BSR, &tempConfigInt) != RKMatchErrorNoError) { goto errorExit; }
    switch(tempConfigInt) {
      case 0:   globalPCREBuildConfig |= RKBuildConfigBackslashRUnicode; break;
      case 1:   globalPCREBuildConfig |= RKBuildConfigBackslashRAnyCRLR; break;
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
  if(globalRegexCache == NULL) {
    RKRegex *tmpRegex = [[[RKCache alloc] initWithDescription:@"RKRegex Regular Expression Cache"] autorelease];
    if(RKAtomicCompareAndSwapPtr(NULL, tmpRegex, &globalRegexCache)) { [globalRegexCache retain]; }
  }
}

+ (RKCache *)regexCache
{
  return(globalRegexCache);
}

//
// PCRE library information methods
//

+ (NSString *)PCREVersionString
{
  return(globalPCREVersionString);
}

+ (unsigned int)PCREMajorVersion
{
  return(globalPCREMajorVersion);
}

+ (unsigned int)PCREMinorVersion
{
  return(globalPCREMinorVersion);
}

+ (RKBuildConfig)PCREBuildConfig
{
  return(globalPCREBuildConfig);
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

#ifdef USE_MACRO_EXCEPTIONS

NS_DURING
  if([self regexWithRegexString:regexString options:options] != NULL) { validRegex = YES; }
NS_HANDLER
  validRegex = NO;
NS_ENDHANDLER

#else // not macro exceptions, new style compiler -fobjc-exceptions
    
@try { if([self regexWithRegexString:regexString options:options] != NULL) { validRegex = YES; } }
@catch (NSException *exception) { validRegex = NO; }

#endif //USE_MACRO_EXCEPTIONS

  return(validRegex);
}

RKRegex *RKRegexFromStringOrRegex(id self, const SEL _cmd, id aRegex, const RKCompileOption compileOptions, const BOOL shouldAutorelease) {
  static Class RK_C99(restrict) stringClass = NULL;
  static Class RK_C99(restrict) regexClass = NULL;
  static BOOL lookupInitialized = NO;
  
  if(RK_EXPECTED([aRegex isKindOfClass:stringClass], 1)) {
    id cachedRegex;
    if(RK_EXPECTED((cachedRegex = RKFastCacheLookup(globalRegexCache, _cmd, RKHashForStringAndCompileOption(aRegex, compileOptions), shouldAutorelease)) != NULL, 1)) { return(cachedRegex); }
    cachedRegex = [(id)NSAllocateObject([RKRegex class], 0, NULL) initWithRegexString:aRegex options:compileOptions];
    if(RK_EXPECTED(shouldAutorelease == YES, 1)) { [cachedRegex autorelease]; }
    return(cachedRegex);
  }
  else if(RK_EXPECTED([aRegex isKindOfClass:regexClass], 1)) {
    if(shouldAutorelease == NO) { [aRegex retain]; }
    return(aRegex);
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

#ifdef USE_PLACEHOLDER

+ (id)allocWithZone:(NSZone *)zone {
#pragma unused(zone)
  return([RKRegexPlaceholder sharedObject]);
}

+ (id)regexWithRegexString:(NSString * const)regexString options:(const RKCompileOption)options
{  
  return(RKRegexFromStringOrRegex(self, _cmd, regexString, options, YES));
}

#else // Do not use placeholder

+ (id)regexWithRegexString:(NSString * const)regexString options:(const RKCompileOption)options
{
  return(RKRegexFromStringOrRegex(self, _cmd, regexString, options, YES));
}

#endif //USE_PLACEHOLDER

- (id)initWithRegexString:(NSString * const RK_C99(restrict))regexString options:(const RKCompileOption)options;
{
  // In case anything goes wrong (ie, exception), we're guaranteed to be in the autorelease pool.  On successful initialization, we send ourselves a retain.
  // Any resources we allocate that are not automatically deallocated need to be referenced via an ivar.  Since we only send ourselves a retain on successful initialization,
  // if we exit prematurely for whatever reason, the autorelease pool will pop and then dealloc this object.  The dealloc method frees any resources that are referenced by ivars.
  // This greatly simplifies resource tracking during initialization for corner cases / partial initializations.
  [self autorelease];

  if(RK_EXPECTED(regexString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"regexString == nil.") userInfo:nil] raise]; }

#ifndef USE_PLACEHOLDER
  id cachedRegex = NULL;
  if(RK_EXPECTED((cachedRegex = [globalRegexCache objectForHash:RKHashForStringAndCompileOption(regexString, options) autorelease:NO]) != NULL, 0)) { return(cachedRegex); }
#endif

  if(RK_EXPECTED((self = [self init]) == NULL, 0)) { goto errorExit; }

#ifdef USE_CORE_FOUNDATION
  if(RK_EXPECTED((compiledRegexString = (NSString *)CFStringCreateCopy(NULL, (CFStringRef)regexString)) == NULL, 0)) { goto errorExit; }
#else
  if(RK_EXPECTED((compiledRegexString = [regexString copy]) == NULL, 0)) { goto errorExit; }
#endif //USE_CORE_FOUNDATION
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
    NSArray *compileOptionArray = RKArrayFromCompileOption(compileOption);

#ifdef __MACOSX_RUNTIME__
    NSMutableAttributedString *regexAttributedString = [[[NSMutableAttributedString alloc] initWithString:regexString attributes:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"%@ at character %d", errorString, compileErrorOffset] forKey:NSToolTipAttributeName]] autorelease];
#else // GNUstep doesn't have NSToolTipAttributeName right now.
    NSMutableAttributedString *regexAttributedString = [[[NSMutableAttributedString alloc] initWithString:regexString] autorelease];
#endif //__MACOSX_RUNTIME__
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
  
  if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_NAMECOUNT, &captureNameTableLength) != RKMatchErrorNoError, 0)) { goto errorExit; }
  if(captureNameTableLength > 0) {
    if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_NAMEENTRYSIZE, &captureNameLength) != RKMatchErrorNoError, 0)) { goto errorExit; }
    if(RK_EXPECTED(pcre_fullinfo(_compiledPCRE, _extraPCRE, PCRE_INFO_NAMETABLE, &captureNameTable) != RKMatchErrorNoError, 0)) { goto errorExit; }

    // XXX WARNING: This block of code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
    // See the PCRE documentation for a description of the capture name layout.  Roughly, nameEntrySize represents the largest name possible,
    // and each name is the first two bytes representing the index number, then a NULL terminated string for the name.
#ifdef USE_CORE_FOUNDATION
    // Using core foundation directly is a big win here.  No message dispatching overhead and we save a lot of retain / release calls to boot.
    // We create a CFTypeRef array to hold pointers to our instantiated strings.
    // We then load all of them up in to an array in one call, with a special allocator structure that does not call CFRetain() on the objects.
    // The array, when freed, will call CFRelease on them.  This saves a retain/release pair for every object.
    // We need to be careful on error and make sure the the objects are released.

    BOOL objectsReady = YES;
    unsigned int captureNameIndex = 0, x = 0;
    CFTypeRef * RK_C99(restrict) arrayObjectPointers = NULL;
    
    if(RK_EXPECTED((arrayObjectPointers = alloca((sizeof(void *) * 1) * captureCount)) == NULL, 0)) { goto errorExit; }
    for(x = 0; x < captureCount; x++) { arrayObjectPointers[x] = kCFNull; } // For capture indexes that don't have a name associated with them

    for(x = 0; x < captureNameTableLength; x++) {
      captureNameIndex = (((((unsigned int)(captureNameTable[(x * captureNameLength)])) & 0xff) << 8) + ((((unsigned int)(captureNameTable[(x * captureNameLength) + 1])) & 0xff) << 0));
      arrayObjectPointers[captureNameIndex] = CFStringCreateWithCString(NULL, &captureNameTable[(x * captureNameLength) + 2], compiledRegexStringBuffer.encoding);
      if(RK_EXPECTED(arrayObjectPointers[captureNameIndex] == NULL, 0)) { objectsReady = NO; break; }
    }

    if(RK_EXPECTED(objectsReady == YES, 1)) { captureNameArray = (NSArray *)CFArrayCreate(NULL, &arrayObjectPointers[0], captureCount, &noRetainArrayCallBacks); }
    else { // Only release when objectsReady == NO
      for(x = 0; x < captureCount; x++) {
        if(arrayObjectPointers[x] != kCFNull) { CFRelease(arrayObjectPointers[x]); arrayObjectPointers[x] = NULL; }
      }
    }

    if(RK_EXPECTED(captureNameArray == NULL, 0)) { goto errorExit; }
    
#else // Use OpenStep Foundation

    // We create an id array to hold pointers to our instantiated strings.  The instantiated strings are NOT autoreleased on creation.
    // If we instantiate all the strings successfully, we create a NSArray in one shot.
    // Regardless of whether or not we successfully create the NSArray, we send a release (not autorelease) message to any string we might have instantiated.
    // This is a surprisingly substantial win over a naive NSMutableArray adding convenience class autoreleased objects and then converting to an NSArray.
    // Since any initialization should be as fast as possible, we go through the trouble.

    BOOL objectsReady = YES;
    unsigned int captureNameIndex = 0, x = 0;
    id * RK_C99(restrict) arrayObjectPointers = NULL;

    if(RK_EXPECTED((arrayObjectPointers = alloca(sizeof(id) * captureCount)) == NULL, 0)) { goto errorExit; }
    for(x = 0; x < captureCount; x++) { arrayObjectPointers[x] = [NSNull null]; } // For capture indexes that don't have a name associated with them

    for(x = 0; x < captureNameTableLength; x++) {
      captureNameIndex = (((((unsigned int)(captureNameTable[(x * captureNameLength)])) & 0xff) << 8) + ((((unsigned int)(captureNameTable[(x * captureNameLength) + 1])) & 0xff) << 0));
      arrayObjectPointers[captureNameIndex] = [[NSString alloc] initWithCString:&captureNameTable[(x * captureNameLength) + 2] encoding:compiledRegexStringBuffer.encoding];
      if(RK_EXPECTED(arrayObjectPointers[captureNameIndex] == NULL, 0)) { objectsReady = NO; break; }
    }
    
    if(RK_EXPECTED(objectsReady == YES, 1)) { captureNameArray = [[NSArray alloc] initWithObjects:&arrayObjectPointers[0] count:captureCount]; }
    for(x = 0; x < captureCount; x++) { if(arrayObjectPointers[x] != NULL) { [arrayObjectPointers[x] release]; arrayObjectPointers[x] = NULL; } } // Safe to release NSNull object

    if(RK_EXPECTED(captureNameArray == NULL, 0)) { goto errorExit; }    

#endif //USE_CORE_FOUNDATION

  }
  
  hash = RKHashForStringAndCompileOption(compiledRegexString, compileOption);
  [globalRegexCache addObjectToCache:self withHash:hash];

  return([self retain]); // We have successfully initialized, so rescue ourselves from the autorelease pool.

errorExit: // Catch point in case any clean up needs to be done.  Currently, none is necessary.
           // We are autoreleased at the start, any objects/resources we created will be handled by dealloc
  return(NULL);
}

- (id)retain
{
  RKAtomicIncrementInt(&referenceCountMinusOne);
  return(self);
}

- (void)release
{
  RKAtomicDecrementInt(&referenceCountMinusOne);
  if(RK_EXPECTED(referenceCountMinusOne == -1, 0)) { [self dealloc]; }
}

- (unsigned int)retainCount
{
  return(referenceCountMinusOne + 1);
}

- (void)dealloc
{
  if(compiledRegexString != NULL) { [compiledRegexString autorelease]; compiledRegexString = NULL; }
  if(captureNameArray    != NULL) { [captureNameArray    autorelease]; captureNameArray    = NULL; }
  if(_compiledPCRE       != NULL) { pcre_free(_compiledPCRE);          _compiledPCRE       = NULL; }
  if(_extraPCRE          != NULL) { pcre_free(_extraPCRE);             _extraPCRE          = NULL; }
  
  [super dealloc];
}

- (unsigned int)hash
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
  return([NSString stringWithFormat: @"<%@: %p> Regular expression = '%s', Compiled options = 0x%8.8x (%@)", [self className], self, [compiledRegexString UTF8String], compileOption, [RKArrayFromCompileOption(compileOption) componentsJoinedByString:@" | "]]);
}

- (NSString *)regexString
{
  return(compiledRegexString);
}

- (RKCompileOption)compileOption
{
  return(compileOption);
}

- (unsigned int)captureCount
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

- (NSString *)captureNameForCaptureIndex:(const unsigned int)captureIndex
{
  id captureName = NULL;

  if(RK_EXPECTED(captureIndex >= captureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureIndex > %u captures in regular expression.", captureCount + 1) userInfo:NULL] raise]; } 
  if(RK_EXPECTED(captureNameArray == NULL, 0)) { return(NULL); }

  NSParameterAssert(RK_EXPECTED(captureIndex < [captureNameArray count], 1));
  captureName = [captureNameArray objectAtIndex:captureIndex];
  return([captureName isEqual:[NSNull null]] ? NULL : captureName);
}

- (unsigned int)captureIndexForCaptureName:(NSString * const)captureNameString
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; }
  
  RKStringBuffer captureNameStringBuffer = RKStringBufferWithString(captureNameString);
  return(RKCaptureIndexForCaptureNameCharacters(self, _cmd, captureNameStringBuffer.characters, captureNameStringBuffer.length, NULL, YES));
}
  
- (unsigned int)captureIndexForCaptureName:(NSString * const RK_C99(restrict))captureNameString inMatchedRanges:(const NSRange * const RK_C99(restrict))matchedRanges
{
  if(RK_EXPECTED(captureNameString == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureNameString == nil.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(matchedRanges == NULL, 0))    { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"matchedRanges == NULL.") userInfo:NULL] raise]; }
  
  RKStringBuffer captureNameStringBuffer = RKStringBufferWithString(captureNameString);
  return(RKCaptureIndexForCaptureNameCharacters(self, _cmd, captureNameStringBuffer.characters, captureNameStringBuffer.length, matchedRanges, YES));
}

- (BOOL)matchesCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const unsigned int)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  return((NSEqualRanges(NSMakeRange(NSNotFound, 0), [self rangeForCharacters:matchCharacters length:length inRange:searchRange captureIndex:0 options:options]) == YES) ? NO : YES);
}

// XXX WARNING: This code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
- (NSRange)rangeForCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const unsigned int)length inRange:(const NSRange)searchRange captureIndex:(const unsigned int)captureIndex options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) matchRanges = NULL;

  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }

  if(RK_EXPECTED(captureIndex >= captureCount, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"captureIndex %u >= captureCount %u.", captureIndex, captureCount + 1) userInfo:NULL] raise]; }

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
- (NSRange *)rangesForCharacters:(const void * const RK_C99(restrict))matchCharacters length:(const unsigned int)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) returnRanges = NULL, * RK_C99(restrict) matchRanges = NULL;

  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }

  matchErrorCode = [self getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:matchCharacters length:length inRange:searchRange options:options];
  if((matchErrorCode <= 0)) { return(NULL); }

  if(RK_EXPECTED((returnRanges = RKAutoreleasedMalloc(captureCount * sizeof(NSRange))) == NULL, 0)) { return(NULL); }
  memcpy(returnRanges, matchRanges, (captureCount * sizeof(NSRange)));
  return(returnRanges);
}

//
// Low level access to pcre library.
// Allocates temporary storage space for capture information (pcre 'vectors') off the stack with alloca().
// pcre reserves 1/3 of the vectors for internal use. We allocate enough for our captures using the macro RK_PRESIZE_CAPTURE_COUNT().
//

// XXX WARNING: This code uses alloca().  If you do not -=COMPLETELY=- understand what alloca() does, you MUST NOT alter this code.
- (RKMatchErrorCode)getRanges:(NSRange * const RK_C99(restrict))ranges withCharacters:(const void * const RK_C99(restrict))charactersBuffer length:(const unsigned int)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode matchErrorCode = RKMatchErrorNoError;
  NSRange * RK_C99(restrict) matchRanges = NULL;
  
  if(RK_EXPECTED(ranges == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"ranges == NULL") userInfo:NULL] raise]; }
  if(RK_EXPECTED((matchRanges = alloca(RK_PRESIZE_CAPTURE_COUNT(captureCount) * sizeof(NSRange))) == NULL, 0)) { [[NSException exceptionWithName:NSMallocException reason:RKPrettyObjectMethodString(@"Unable to allocate temporary stack space.") userInfo:NULL] raise]; }
  
  matchErrorCode = [self getRanges:matchRanges count:RK_PRESIZE_CAPTURE_COUNT(captureCount) withCharacters:charactersBuffer length:length inRange:searchRange options:options];
  if(matchErrorCode > 0) { memcpy(ranges, matchRanges, sizeof(NSRange) * captureCount); }
  return(matchErrorCode);
}

@end


@implementation RKRegex (Private)

// This is a semi-private interface to the low level PCRE match function.
// It assumes that the caller has correctly pre-sized an allocation according to the pcre_exec vector rules.
- (RKMatchErrorCode)getRanges:(NSRange * const RK_C99(restrict))ranges count:(const unsigned int)rangeCount withCharacters:(const void * const RK_C99(restrict))charactersBuffer length:(const unsigned int)length inRange:(const NSRange)searchRange options:(const RKMatchOption)options
{
  RKMatchErrorCode errorCode = RKMatchErrorNoError;
  unsigned int x = 0, * RK_C99(restrict) vectors = (unsigned int *)ranges, numberOfVectors = rangeCount;
  
  NSAssert1(rangeCount >= RK_MINIMUM_CAPTURE_COUNT(captureCount), @"rangeCount < minimum required: %d", RK_MINIMUM_CAPTURE_COUNT(captureCount));
  
  if(RK_EXPECTED(ranges == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"ranges == NULL") userInfo:NULL] raise]; }
  if(RK_EXPECTED(charactersBuffer == NULL, 0)) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"charactersBuffer == NULL.") userInfo:NULL] raise]; }
  if(RK_EXPECTED(length < searchRange.location, 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %u < start location %u for range %@.", length, searchRange.location, NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  
  if(RK_EXPECTED(length < (searchRange.location + searchRange.length), 0)) { [[NSException exceptionWithName:NSRangeException reason:RKPrettyObjectMethodString(@"length %u < end location %u for range %@.", length, NSMaxRange(searchRange), NSStringFromRange(searchRange)) userInfo:NULL] raise]; }  
  
  errorCode = (RKMatchErrorCode)pcre_exec(_compiledPCRE, _extraPCRE, (const char *)charactersBuffer, (int)length, (int)searchRange.location, (int)options, (int *)vectors, (int)numberOfVectors);
  
  // Convert PCRE vector format (start, end location) to NSRange format (start, length) on success
  if(errorCode > 0) {
    if(vectors[1] > NSMaxRange(searchRange)) { errorCode = RKMatchErrorNoMatch; }
    else {
      for(x = 0; x < (u_int)errorCode; x++) {
        if(RK_EXPECTED(vectors[(x * 2)] == UINT_MAX, 0)) { ranges[x] = NSMakeRange(NSNotFound, 0); } else { ranges[x] = NSMakeRange(vectors[(x * 2)], (vectors[(x * 2) + 1] - vectors[(x * 2)])); }
      }
      for(x = (u_int)errorCode; x < captureCount; x++) { ranges[x] = NSMakeRange(NSNotFound, 0); }
    }
  }
  
  return(errorCode);
}

@end

// The next function is the low level access / checking methods for any capture names.  It works on raw char * + length buffers.
// The public API methods wrap these in more friendly NSString * style methods.
// This can save us a lot of time when doing capture name heavy processing as no objects are created.  Very light weight.

unsigned int RKCaptureIndexForCaptureNameCharacters(RKRegex * const aRegex, const SEL _cmd, const char * const RK_C99(restrict) captureNameCharacters, const size_t length, const NSRange * const RK_C99(restrict) matchedRanges, const BOOL raiseExceptionOnDoesNotExist) {
  if(RK_EXPECTED(aRegex == NULL, 0)) { [[NSException exceptionWithName:NSInternalInconsistencyException reason:@"RKCaptureIndexForCaptureNameCharacters: aRegex == NULL." userInfo:NULL] raise]; }
  struct RKRegexDef { @defs(RKRegex) } *self = (struct RKRegexDef *)aRegex;
  int searchBottom = 0, searchMiddle = 0, searchTop = self->captureNameTableLength, captureIndex = 0;
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
  if(raiseExceptionOnDoesNotExist == YES ) { [[NSException exceptionWithName:NSInvalidArgumentException reason:RKPrettyObjectMethodString(@"The captureName '%*.*s' does not exist.", length, length, captureNameCharacters) userInfo:NULL] raise]; }
  return(NSNotFound);
  
validName:
  
  if(matchedRanges == NULL) { goto successExit;  }

  if((self->compileOption & RKCompileDupNames) == 0) {
    if(matchedRanges[captureIndex].location == NSNotFound) { captureIndex = NSNotFound; }
    goto successExit;
  }

  char *topCaptureName = self->captureNameTable + self->captureNameLength * (self->captureNameTableLength - 1), *startingCaptureName = atCaptureName;
  int lowestCaptureIndex = (matchedRanges[captureIndex].location != NSNotFound) ? captureIndex : -1;
  
  while (atCaptureName > self->captureNameTable) {
    if(strncmp(captureNameCharacters, (atCaptureName - self->captureNameLength + 2), length) != 0) { break; }
    if(atCaptureName[length - self->captureNameLength + 2] != 0) { break; }
    atCaptureName -= self->captureNameLength;
    captureIndex = ((atCaptureName[0] << 8) + atCaptureName[1]);
    if(matchedRanges[captureIndex].location != NSNotFound) { lowestCaptureIndex = captureIndex; }
  }
  if(lowestCaptureIndex != -1) { captureIndex = lowestCaptureIndex; goto successExit; }
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
