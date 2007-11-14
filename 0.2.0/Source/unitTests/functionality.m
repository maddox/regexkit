//
//  functionality.m
//  RegexKit
//

#import "functionality.h"

#ifndef STAssertTrue
// Used these when testing under FreeBSD and OCUnit v27

#define STAssertTrue(exeLine, ...) should(((exeLine) != 0))
#define STAssertNil(exeLine, ...) should(((exeLine) == nil))
#define STAssertNoThrow(exeLine, ...) shouldntRaise((exeLine))
#define STAssertNotNil(exeLine, ...) should(((exeLine) != nil))
#define STAssertThrows(exeLine, ...) shouldRaise((exeLine))
#define STAssertThrowsSpecificNamed(exeLine, ...) shouldRaise((exeLine))
#define STAssertFalse(exeLine, ...) should(((exeLine) == 0))

#endif
#define RKPrettyObjectMethodString(stringArg, ...) ([NSString stringWithFormat:[NSString stringWithFormat:@"%p [%@ %@]: %@", self, NSStringFromClass([(id)self class]), NSStringFromSelector(_cmd), stringArg], ##__VA_ARGS__])


@implementation functionality

+ (void)setUp
{
  startAutoreleasedObjects = (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0);
  startTopPool = [[NSAutoreleasePool alloc] init];
  
  if(getenv("LEAK_CHECK") != NULL) { leakEnvString = [[[NSString alloc] initWithCString:getenv("LEAK_CHECK") encoding:NSUTF8StringEncoding] autorelease]; }
  if(getenv("DEBUG") != NULL) { debugEnvString = [[[NSString alloc] initWithCString:getenv("DEBUG") encoding:NSUTF8StringEncoding] autorelease]; }
  if(getenv("TIMING") != NULL) { timingEnvString = [[[NSString alloc] initWithCString:getenv("TIMING") encoding:NSUTF8StringEncoding] autorelease]; }
  
  startLeakPool = [[NSAutoreleasePool alloc] init];

  [[RKRegex regexCache] clearCache];
  [[RKRegex regexCache] clearCounters];

  if(([leakEnvString intValue] > 0)) {
    NSString *leakString = [[NSString alloc] initWithFormat:@"This string should leak from [%@ %@] on purpose", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    NSLog(@"leakString @ %p: %@", leakString, leakString);
    leakString = (NSString *)0xdeadbeef;
    
    if([leakEnvString intValue] > 1) {
      NSString *leaksCommandString = [NSString stringWithFormat:@"/usr/bin/leaks -exclude \"+[%@ %@]\" -exclude \"+[NSTitledFrame initialize]\" -exclude \"+[NSLanguage initialize]\" -exclude \"NSPrintAutoreleasePools\" -exclude \"+[NSWindowBinder initialize]\" -exclude \"+[NSCollator initialize]\" -exclude \"+[NSCollatorElement initialize]\" %d", NSStringFromClass([self class]), NSStringFromSelector(_cmd), getpid()];
      
      if([NSAutoreleasePool respondsToSelector:@selector(showPools)]) { [NSAutoreleasePool showPools]; }
      NSLog(@"starting autoreleased objects: %u  Now: %u  Diff: %u", startAutoreleasedObjects, (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0), (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0) - startAutoreleasedObjects);
      NSLog(@"autoreleasedObjectCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(autoreleasedObjectCount)]) ? [NSAutoreleasePool autoreleasedObjectCount] : 0));
      NSLog(@"topAutoreleasePoolCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0));
      
      NSLog(@"Executing '%@'", leaksCommandString);
      system([leaksCommandString UTF8String]);
    }
  }
  testStartCPUTime = [NSDate cpuTimeUsed];
}

+ (void)tearDown
{
  testEndCPUTime = [NSDate cpuTimeUsed];
  testElapsedCPUTime = [NSDate differenceOfStartingTime:testStartCPUTime endingTime:testEndCPUTime];
  
  NSString *leaksCommandString = nil;
  
  NSLog(RKPrettyObjectMethodString(@"Cache status:\n%@", [RKRegex regexCache]));

  NSSet *regexCacheSet = [[RKRegex regexCache] cacheSet];
  NSLog(@"Cache set count: %d", [regexCacheSet count]);
  
  NSAutoreleasePool *cachePool = [[NSAutoreleasePool alloc] init];
  [[RKRegex regexCache] clearCache];
  [cachePool release]; cachePool = NULL;
  
  regexCacheSet = [[RKRegex regexCache] cacheSet];
  
  if(([leakEnvString intValue] > 0)) {
    leaksCommandString = [[NSString alloc] initWithFormat:@"/usr/bin/leaks -nocontext -exclude \"+[%@ %@]\" -exclude \"+[NSTitledFrame initialize]\" -exclude \"+[NSLanguage initialize]\" -exclude \"NSPrintAutoreleasePools\" -exclude \"+[NSWindowBinder initialize]\" -exclude \"+[NSCollator initialize]\" -exclude \"+[NSCollatorElement initialize]\" %d", NSStringFromClass([self class]), NSStringFromSelector(_cmd), getpid()];
    
    if([leakEnvString intValue] > 2) {
      if([NSAutoreleasePool respondsToSelector:@selector(showPools)]) { [NSAutoreleasePool showPools]; }
      NSLog(@"starting autoreleased objects: %u  Now: %u  Diff: %u", startAutoreleasedObjects, (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0), (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0) - startAutoreleasedObjects);
      NSLog(@"autoreleasedObjectCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(autoreleasedObjectCount)]) ? [NSAutoreleasePool autoreleasedObjectCount] : 0));
      NSLog(@"topAutoreleasePoolCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0));
    }
    
    if(startLeakPool != nil) { [startLeakPool release]; startLeakPool = nil; }
    
    if([leakEnvString intValue] > 1) {
      NSLog(@"\n\n---------\nReleased setUp autorelease pool\n\n");
      
      if([NSAutoreleasePool respondsToSelector:@selector(showPools)]) { [NSAutoreleasePool showPools]; }
      NSLog(@"starting autoreleased objects: %u  Now: %u  Diff: %u", startAutoreleasedObjects, (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0), (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0) - startAutoreleasedObjects);
      NSLog(@"autoreleasedObjectCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(autoreleasedObjectCount)]) ? [NSAutoreleasePool autoreleasedObjectCount] : 0));
      NSLog(@"topAutoreleasePoolCount: %u", (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0));
    }
    
    NSLog(@"Executing '%@'", leaksCommandString);
    system([leaksCommandString UTF8String]);
  }
  
  
  if(startLeakPool != nil) { [startLeakPool release]; startLeakPool = nil; }
  if(startTopPool != nil) { [startTopPool release]; startTopPool = nil; }
  
  NSLog(@"starting autoreleased objects: %u  Now: %u  Diff: %u", startAutoreleasedObjects, (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0), (([NSAutoreleasePool respondsToSelector:@selector(totalAutoreleasedObjects)]) ? [NSAutoreleasePool totalAutoreleasedObjects] : 0) - startAutoreleasedObjects);
  
  NSLog(@"Elapsed CPU time: %@", [NSDate stringFromCPUTime:testElapsedCPUTime]);
  NSLog(@"Elapsed CPU time: %@", [NSDate microSecondsStringFromCPUTime:testElapsedCPUTime]);
  NSLog(RKPrettyObjectMethodString(@"Teardown complete\n"));
  fprintf(stderr, "-----------------------------------------\n\n");
}


#ifdef OLD_GETCAPTURKSWITHRKGEX_TESTS
- (void)testExample
{
  NSString *capture0 = @"$0", *capture1 = @"$1", *capture2 = @"$2";
  
  [@"This is the subject string to be matched" getCapturesWithRegex:@"(is the).*(to be)", &capture1, &capture2, &capture0, nil];

  /*
   capture0 = @"is the subject string to be";
   capture1 = @"is the";
   capture2 = @"to be";
   */

  //NSLog(@"capture0: '%@' capture1: '%@' capture2: '%@'", capture0, capture1, capture2);
  
  STAssertTrue([capture0 isEqualToString:@"is the subject string to be"], nil);
  STAssertTrue([capture1 isEqualToString:@"is the"], nil);
  STAssertTrue([capture2 isEqualToString:@"to be"], nil);
}
#endif

#ifdef OLD_GETCAPTURKSWITHRKGEX_TESTS
- (void)testExample2
{
  NSString *subjectString = @"Todays date: 2007 - 03 - 27. Tomorrow: 2007 - 03 - 28!";
  NSString *regexString = @"(?<date> (?<year>(\\d\\d)?\\d\\d) - (?<month>\\d\\d) - (?<day>\\d\\d))";
  NSString *capture0 = @"$0", *capture1 = @"$1", *capture2 = @"$2", *captureDate = @"${date}", *captureMonth = @"${month}", *captureDay = @"${day}";
  
  [subjectString getCapturesWithRegex:regexString, &capture1, &capture0, &capture2, &captureDate, &captureMonth, &captureDay, nil];

  /*
   capture0 = @"2007 - 03 - 27";
   capture1 = @"2007 - 03 - 27";
   capture2 = @"2007";
   captureDate = @"2007 - 03 - 27";
   captureMonth = @"03";
   captureDay = @"28";
   */
 
  //NSLog(@"capture0: '%@' capture1: '%@' capture2: '%@' captureDate: '%@' captureMonth: '%@' captureDay: '%@'", capture0, capture1, capture2, captureDate, captureMonth, captureDay);

  STAssertTrue([capture0 isEqualToString:@" 2007 - 03 - 27"] , nil);
  STAssertTrue([capture1 isEqualToString:@" 2007 - 03 - 27"] , nil);
  STAssertTrue([capture2 isEqualToString:@"2007"] , nil);
  STAssertTrue([captureDate isEqualToString:@" 2007 - 03 - 27"] , nil);
  STAssertTrue([captureMonth isEqualToString:@"03"] , nil);
  STAssertTrue([captureDay isEqualToString:@"27"] , nil);
}
#endif


- (void)testSimpleStringAdditions
{
  NSString *subString0 = nil, *subString1 = nil, *subString2 = nil;
  NSString *subjectString = @"This web address, http://www.foad.org/no_way/it really/does/match/ is really neat!";
                                                     //NSString *regexString = @"http://([^/]+)(/.*/)"; // Stupid xcode seems to choke on the last 3-4 characters when they're together. It looses it's indentation mind.
  NSString *regexString = [@"http://([^/]+)(/.*" stringByAppendingString:@"/)"];
    
  STAssertTrue(([subjectString getCapturesWithRegexAndReferences:regexString, @"${2}", &subString2, nil]) , nil ) ;
  STAssertTrue([subString2 isEqualToString:@"/no_way/it really/does/match/"], @"len %d %@ = '%s'", [subString2 length], subString2, [subString2 UTF8String]);
  
  NSString *namedSubjectString = @" 1999 - 12 - 01 / 55 ";
  NSString *namedRegexString = @"(?<date> (?<year>(\\d\\d)?\\d\\d) - (?<month>\\d\\d) - (?<day>\\d\\d) / (?<month>\\d\\d))";
  NSString *subStringDate = nil, *subStringDay = nil, *subStringYear = nil;
  subString0 = nil, subString1 = nil, subString2 = nil;
    
  STAssertTrue(([namedSubjectString getCapturesWithRegexAndReferences:namedRegexString, @"${day}", &subStringDay, @"${date}", &subStringDate, @"${2}", &subString2, @"${1}", &subString1, @"${year}", &subStringYear, nil]), nil);
  
  STAssertTrue([subString1 isEqualToString:@" 1999 - 12 - 01 / 55"], nil);
  STAssertTrue([subString2 isEqualToString:@"1999"], nil);
  STAssertTrue([subStringDate isEqualToString:@" 1999 - 12 - 01 / 55"], @"got %@ %d", subStringDate, [subStringDate isEqualToString:@" 1999 - 12 - 01 / 55"]);
  STAssertTrue([subStringDay isEqualToString:@"01"], @"got %@ %d", subStringDay, [subStringDay isEqualToString:@"01"]);
  STAssertTrue([subStringYear isEqualToString:@"1999"], @"got %@ %d", subStringYear, [subStringYear isEqualToString:@"1999"]);
}

- (void)testNSStringAdditionsTrivialgetCapturesKeys
{
  NSString *capture1String = @"0xdeadbeef", *capture2String = @"0xdeadbeef";
  NSString *key1String = @"${1}", *key2String = @"${2}";
  NSString *subjectString = @"This web address, http://www.foad.org/no_way/it really/does/match/ is really neat!";
  NSString *regexString = [@"http://([^/]+)(/.*" stringByAppendingString:@"/)"]; // xcode bug, misparses Apple bugid # 5113323
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, key1String, &capture1String, nil]), nil);
  STAssertTrue(([subjectString isEqualToString:[NSString stringWithFormat:@"%s", "This web address, http://www.foad.org/no_way/it really/does/match/ is really neat!"]] == YES), nil);
  STAssertTrue(([regexString isEqualToString:[NSString stringWithFormat:@"%s%s", "http://([^/]+)(/.*", "/)"]] == YES), @"is %@", regexString);
  STAssertTrue(([key1String isEqualToString:[NSString stringWithFormat:@"${%d}", 1]] == YES), @"is %@", key1String);
  STAssertTrue(([capture1String isEqualToString:[NSString stringWithFormat:@"%s", "www.foad.org"]] == YES), @"is %@", capture1String);
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, key1String, &capture1String, key2String, &capture2String, nil]), nil);
  STAssertTrue(([subjectString isEqualToString:[NSString stringWithFormat:@"%s", "This web address, http://www.foad.org/no_way/it really/does/match/ is really neat!"]] == YES), nil);
  STAssertTrue(([regexString isEqualToString:[NSString stringWithFormat:@"%s%s", "http://([^/]+)(/.*", "/)"]] == YES), @"is %@", regexString);
  STAssertTrue(([key1String isEqualToString:[NSString stringWithFormat:@"${%d}", 1]] == YES), @"is %@", key1String);
  STAssertTrue(([key2String isEqualToString:[NSString stringWithFormat:@"${%d}", 2]] == YES), @"is %@", key2String);
  STAssertTrue(([capture1String isEqualToString:[NSString stringWithFormat:@"%s", "www.foad.org"]] == YES), @"is %@", capture1String);
  STAssertTrue(([capture2String isEqualToString:[NSString stringWithFormat:@"%s", "/no_way/it really/does/match/"]] == YES), @"is %@", capture2String);
}  



- (void)testSimpleMatches
{
  STAssertTrue([@" 012345 " isMatchedByRegex:[RKRegex regexWithRegexString:@"123" options:0]], nil);
  STAssertTrue([@" 012345 " isMatchedByRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(2, 3)], nil);
  STAssertTrue([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(2, 3) options:0], nil);
  STAssertFalse([@" 012345 " isMatchedByRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(1, 2)], nil);
  STAssertFalse([@" 012345 " isMatchedByRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(3, 2)], nil);
  STAssertFalse([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(1, 2) options:0], nil);
  STAssertFalse([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(3, 2) options:0], nil);

  STAssertThrowsSpecificNamed([@" 012345 " isMatchedByRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(400, 16)], NSException, NSRangeException, nil);
  STAssertThrowsSpecificNamed([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(400, 16) options:0], NSException, NSRangeException, nil);
  STAssertThrowsSpecificNamed([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:" 012345 " length:0 inRange:NSMakeRange(0, 8) options:0], NSException, NSRangeException, nil);

  STAssertThrowsSpecificNamed([[RKRegex regexWithRegexString:@"123" options:0] matchesCharacters:NULL length:strlen(" 012345 ") inRange:NSMakeRange(400, 16) options:0], NSException, NSInvalidArgumentException, nil);
}

- (void)testSimpleRangeForCharacters
{
  NSRange matchRange = NSMakeRange(0, 0);
  
  STAssertTrue(NSEqualRanges((matchRange = [@" 012345 " rangeOfRegex:[RKRegex regexWithRegexString:@"123" options:0]]), NSMakeRange(2, 3)), @"matchRange = %@", NSStringFromRange(matchRange));
  STAssertTrue(NSEqualRanges((matchRange = [@" 012345 " rangeOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(2, 3) capture:0]), NSMakeRange(2, 3)), @"matchRange = %@", NSStringFromRange(matchRange));

  STAssertTrue(NSEqualRanges((matchRange = [@" 012345 " rangeOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(1, 2) capture:0]), NSMakeRange(NSNotFound, 0)), @"matchRange = %@", NSStringFromRange(matchRange));
  STAssertTrue(NSEqualRanges((matchRange = [@" 012345 " rangeOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(3, 2) capture:0]), NSMakeRange(NSNotFound, 0)), @"matchRange = %@", NSStringFromRange(matchRange));

  STAssertThrowsSpecificNamed([@" 012345 " rangeOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(400, 16) capture:0], NSException, NSRangeException, nil);

  STAssertThrowsSpecificNamed([[RKRegex regexWithRegexString:@"123" options:0] rangeForCharacters:nil length:strlen(" 012345 ") inRange:NSMakeRange(400, 16) captureIndex:23 options:RKMatchNoOptions], NSException, NSInvalidArgumentException, nil);
}

- (void)testSimpleRangesData
{
  NSRange *matchRanges = NULL;
  
  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [@" 012345 " rangesOfRegex:[RKRegex regexWithRegexString:@"123" options:0]], nil);
  STAssertTrue(matchRanges != NULL, nil); if(matchRanges == NULL) { return; }
  STAssertTrue(NSEqualRanges(matchRanges[0], NSMakeRange(2, 3)), @"matchRanges[0] = %@", NSStringFromRange(matchRanges[0]));

  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [@" 012345 " rangesOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(2, 3)], nil);
  STAssertTrue(matchRanges != NULL, nil); if(matchRanges == NULL) { return; }
  STAssertTrue(NSEqualRanges(matchRanges[0], NSMakeRange(2, 3)), @"matchRanges[0] = %@", NSStringFromRange(matchRanges[0]));

  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(2, 3) options:0], nil);
  STAssertTrue(matchRanges != NULL, nil); if(matchRanges == NULL) { return; }
  STAssertTrue(NSEqualRanges(matchRanges[0], NSMakeRange(2, 3)), @"matchRanges[0] = %@", NSStringFromRange(matchRanges[0]));

  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [@" 012345 " rangesOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(1, 2)], nil);
  STAssertTrue(matchRanges == NULL, nil);

  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [@" 012345 " rangesOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(3, 2)], nil);
  STAssertTrue(matchRanges == NULL, nil);
  
  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(1, 2) options:0], nil);
  STAssertTrue(matchRanges == NULL, nil);

  matchRanges = NULL;
  STAssertNoThrow(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(3, 2) options:0], nil);
  STAssertTrue(matchRanges == NULL, nil);

  matchRanges = NULL;
  STAssertThrowsSpecificNamed(matchRanges = [@" 012345 " rangesOfRegex:[RKRegex regexWithRegexString:@"123" options:0] inRange:NSMakeRange(400, 16)], NSException, NSRangeException, nil);
  STAssertTrue(matchRanges == NULL, nil);

  matchRanges = NULL;
  STAssertThrowsSpecificNamed(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:" 012345 " length:strlen(" 012345 ") inRange:NSMakeRange(400, 16) options:0], NSException, NSRangeException, nil);
  STAssertTrue(matchRanges == NULL, nil);

  matchRanges = NULL;
  STAssertThrowsSpecificNamed(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:" 012345 " length:0 inRange:NSMakeRange(0, 8) options:0], NSException, NSRangeException, nil);
  STAssertTrue(matchRanges == NULL, nil);


  matchRanges = NULL;
  STAssertThrowsSpecificNamed(matchRanges = [[RKRegex regexWithRegexString:@"123" options:0] rangesForCharacters:NULL length:strlen(" 012345 ") inRange:NSMakeRange(0, 8) options:0], NSException, NSInvalidArgumentException, nil);
  STAssertTrue(matchRanges == NULL, nil);
}



@end
