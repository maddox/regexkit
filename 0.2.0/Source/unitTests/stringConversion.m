//
//  stringConversion.m
//  RegexKit
//

#import "stringConversion.h"

#define RKPrettyObjectMethodString(stringArg, ...) ([NSString stringWithFormat:[NSString stringWithFormat:@"%p [%@ %@]: %@", self, NSStringFromClass([(id)self class]), NSStringFromSelector(_cmd), stringArg], ##__VA_ARGS__])

@implementation stringConversion

+ (void)tearDown
{
  NSLog(RKPrettyObjectMethodString(@"Cache status:\n%@", [RKRegex regexCache]));
  NSLog(RKPrettyObjectMethodString(@"Teardown complete\n\n"));
  fprintf(stderr, "-----------------------------------------\n\n");
}

- (void)testStringParseCommonConversions
{
  float floatValue = 0.0;  
  STAssertTrueNoThrow(([@"234335.125" getCapturesWithRegexAndReferences:@"(\\d+\\.\\d+)", @"${1:%f}", &floatValue, nil] == YES), nil);
  STAssertTrue(floatValue == 234335.125, @"float: %f", floatValue);

  double doubleValue = 0.0;  
  STAssertTrueNoThrow(([@"9342.123" getCapturesWithRegexAndReferences:@"(\\d+\\.\\d+)", @"${1:%lf}", &doubleValue, nil] == YES), nil);
  STAssertTrue(doubleValue == 9342.123, @"double: %f", doubleValue);
  
  unsigned int hexValue;

  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x0badcafe" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x0badcafe, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xabcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xabcdefgh" getCapturesWithRegexAndReferences:@"(0x[0-9a-hA-H]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x00abcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x00abcdef, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xABCDEF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xABCDEF, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xaBcDeF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x01234567" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x01234567, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x89abcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x89abcdef, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x89ABCDEF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x89ABCDEF, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xFFFFFFFF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xffffffff, @"hex: %x", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xffffffff" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%x}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xffffffff, @"hex: %x", hexValue);

  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x0badcafe" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x0badcafe, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xabcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xabcdefgh" getCapturesWithRegexAndReferences:@"(0x[0-9a-hA-H]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x00abcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x00abcdef, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xABCDEF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xABCDEF, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xaBcDeF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xabcdef, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x01234567" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x01234567, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x89abcdef" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x89abcdef, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0x89ABCDEF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0x89ABCDEF, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xFFFFFFFF" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xffffffff, @"hex: %X", hexValue);
  hexValue = 0x1234; STAssertTrueNoThrow(([@"0xffffffff" getCapturesWithRegexAndReferences:@"(0x[0-9a-fA-F]+)", @"${1:%X}", &hexValue, nil] == YES), nil); STAssertTrue(hexValue == 0xffffffff, @"hex: %X", hexValue);
  
  
  unsigned int uintValue;
  uintValue = 3356399801; STAssertTrueNoThrow(([@"1298345149" getCapturesWithRegexAndReferences:@"([0-9]+)", @"${1:%u}", &uintValue, nil] == YES), nil); STAssertTrue(uintValue == 1298345149, @"uint: %u", uintValue);
  uintValue = 3356399801; STAssertTrueNoThrow(([@"4294967295" getCapturesWithRegexAndReferences:@"([0-9]+)", @"${1:%u}", &uintValue, nil] == YES), nil); STAssertTrue(uintValue == 4294967295, @"uint: %u", uintValue);
  uintValue = 3356399801; STAssertTrueNoThrow(([@"4294967296" getCapturesWithRegexAndReferences:@"([0-9]+)", @"${1:%u}", &uintValue, nil] == YES), nil); STAssertTrue(uintValue == 4294967295, @"uint: %u", uintValue);

  int intValue;
  intValue = 2768037889; STAssertTrueNoThrow(([@"-1705920017" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%d}", &intValue, nil] == YES), nil); STAssertTrue(intValue == -1705920017, @"int: %d", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"-2147483648" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%d}", &intValue, nil] == YES), nil); STAssertTrue(intValue == -2147483648, @"int: %d", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"-2147483649" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%d}", &intValue, nil] == YES), nil); STAssertTrue(intValue == -2147483648, @"int: %d", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"2147483647" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%d}", &intValue, nil] == YES), nil); STAssertTrue(intValue == 2147483647, @"int: %d", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"2147483648" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%d}", &intValue, nil] == YES), nil); STAssertTrue(intValue == 2147483647, @"int: %d", intValue);

  intValue = 2768037889; STAssertTrueNoThrow(([@"017777777777" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%o}", &intValue, nil] == YES), nil); STAssertTrue(intValue == 2147483647, @"oct: %o", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"020000000000" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%o}", &intValue, nil] == YES), nil); STAssertTrue(intValue == 2147483647, @"oct: %o", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"-020000000000" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%o}", &intValue, nil] == YES), nil); STAssertTrue(intValue == -2147483648, @"oct: %o", intValue);
  intValue = 2768037889; STAssertTrueNoThrow(([@"-020000000001" getCapturesWithRegexAndReferences:@"(\\-?[0-9]+)", @"${1:%o}", &intValue, nil] == YES), nil); STAssertTrue(intValue == -2147483648, @"oct: %o", intValue);

  
  doubleValue = 24693708654421.0;
  STAssertTrueNoThrow(([@"0x3.fe69149f758p+45" getCapturesWithRegexAndReferences:@"(\\-?0x[0-9a-fA-F]+\\.[0-9a-fA-F]+p(?:\\-|\\+)\\d+)", @"${1:%lf}", &doubleValue, nil] == YES), nil);
  STAssertTrue(doubleValue == 140519025143472.0, @"double: %f", doubleValue);
}

- (void)testStringParseBasicSyntax
{
  NSString *subjectString = nil, *regexString = nil, *captured0String = nil, *captured1String = nil, *captured2String = nil;
  int int0Type = 59, int1Type = 61, int2Type = 67;
  
  subjectString = @"12345";
  regexString = @"(\\d+)";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 12345, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue([captured1String isEqualToString:@"12345"] == YES, @"captured1String = %@", captured1String);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String); 
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  

  subjectString = @"";

  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 61, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String);
  STAssertTrue(captured1String == nil, @"captured1String = %@", captured1String); 
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  

  subjectString = @" ";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 61, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String);
  STAssertTrue(captured1String == nil, @"captured1String = %@", captured1String); 
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  

  subjectString = @"1";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 1, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String); 
  STAssertTrue([captured1String isEqualToString:@"1"] == YES, @"captured1String = %@", captured1String);
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  
  subjectString = @" 12 ";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 12, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String); 
  STAssertTrue([captured1String isEqualToString:@"12"] == YES, @"captured1String = %@", captured1String);
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  

  subjectString = @"ab 123 456 ";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &int1Type, nil]), nil);
  STAssertTrue(int0Type == 59, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 123, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(captured0String == nil, @"captured0String = %@", captured0String); 
  STAssertTrue([captured1String isEqualToString:@"123"] == YES, @"captured1String = %@", captured1String);
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;

  subjectString = @"ab 123 456 ";
  regexString = @"(\\d\\d)\\d";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${0:%d}", &int0Type, @"${1:%d}", &int1Type, @"${0}", &captured0String, @"${1}", &captured1String, nil]), nil);
  STAssertTrue(int0Type == 123, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 12, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 67, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertTrue([captured0String isEqualToString:@"123"] == YES, @"captured0String = %@", captured0String); 
  STAssertTrue([captured1String isEqualToString:@"12"] == YES, @"captured1String = %@", captured1String); 
  STAssertTrue(captured2String == nil, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;

  subjectString = @" 1 ab123456 ";
  regexString = @"(\\d(\\d\\d))\\d";
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${0:%d}", &int0Type, @"${1:%d}", &int1Type, @"${2:%d}", &int2Type, @"${0}", &captured0String, @"${1}", &captured1String, @"${2}", &captured2String, nil]), nil);
  STAssertTrue(int0Type == 1234, @"int0Type = %d", int0Type);
  STAssertTrue(int1Type == 123, @"int1Type = %d", int1Type);
  STAssertTrue(int2Type == 23, @"int2Type = %d", int2Type);
  int0Type = 59; int1Type = 61; int2Type = 67;
  STAssertTrue([captured0String isEqualToString:@"1234"] == YES, @"captured0String = %@", captured0String); 
  STAssertTrue([captured1String isEqualToString:@"123"] == YES, @"captured1String = %@", captured1String); 
  STAssertTrue([captured2String isEqualToString:@"23"] == YES, @"captured2String = %@", captured2String); 
  captured0String = captured1String = captured2String = nil;
  
}

- (void)testStringParseBadSyntaxCornerCases
{
  NSString *subjectString = nil, *regexString = nil;//, *captureString = nil;
  int intType = 7;

  subjectString = @"12345";
  regexString = @"(\\d+)";

  STAssertTrue(intType == 7, nil);
  
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$1:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:d", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:d", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:%", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"2", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;

  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${a:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$a:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${a:d", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"a:d}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"a:", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"a", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;

  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$1:%}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:%}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:%", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;

  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$1:@}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:@}", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:@", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;

  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"1:@z", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;

  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"$$1:", &intType, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(intType == 7, @"int value is: %d", intType); intType = 7;
}

- (void)testStringParseBadObjectConversionSyntax
{
  NSString *subjectString = nil, *regexString = nil;
  id captureObject = (id)17;
  
  subjectString = @"12345";
  regexString = @"(\\d+)";
  
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@x}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@$}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@Xzn}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@D}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@$d}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:@Zxd}", &captureObject, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureObject == (id)17, @"captureObject ptr is: %p / [%@] %@", captureObject, [captureObject className], captureObject); captureObject = (id)17;

}

- (void)testStringParseNumericConvertToInt
{
  NSString *subjectString = nil, *regexString = nil, *captureString = nil;
  int intType = 7;
  
  subjectString = @"12345";
  regexString = @"(\\d+)";
  
  STAssertTrue(intType == 7, nil);
 
  captureString = nil;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${num:%d}", &captureString, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureString == nil, nil);
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1:%d}", &intType, nil]), nil);
  STAssertTrue(intType == 12345, nil);
  
  captureString = nil;
  STAssertTrue(captureString == nil, nil);
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${1}", &captureString, nil]), nil);
  STAssertTrue(captureString != nil, nil);
  STAssertTrue([captureString isEqualToString:@"12345"], nil);  
}

- (void)testStringParseNamedConvertToInt
{
  NSString *subjectString = nil, *regexString = nil, *captureString = nil;
  int intType = 7;
  
  subjectString = @"12345";
  regexString = @"(?<num>\\d+)";
  
  STAssertTrue(intType == 7, nil);
  
  captureString = nil;
  STAssertThrowsSpecificNamed(([subjectString getCapturesWithRegexAndReferences:regexString, @"${zip:%d}", &captureString, nil]), NSException, RKRegexCaptureReferenceException, nil);
  STAssertTrue(captureString == nil, nil);
  
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${num:%d}", &intType, nil]), nil);
  STAssertTrue(intType == 12345, nil);
  
  captureString = nil;
  STAssertTrue(captureString == nil, nil);
  STAssertNoThrow(([subjectString getCapturesWithRegexAndReferences:regexString, @"${num}", &captureString, nil]), nil);
  STAssertTrue(captureString != nil, nil);
  STAssertTrue([captureString isEqualToString:@"12345"], nil);  
}

- (void)testStringParseNumericConvertToNSNumberAllFormats
{
  NSNumber *number1 = nil, *number2 = nil;
  
  STAssertNoThrow(([@"123, 456" getCapturesWithRegexAndReferences:@"(\\d+), (\\d+)", @"${1:@n}", &number1, @"${2:@n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"$123, 99.5%" getCapturesWithRegexAndReferences:@"([^,]*), (.*)", @"${1:@$n}", &number1, @"${2:@%n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"forty-two, 100,954,123.92" getCapturesWithRegexAndReferences:@"([^,]*), (.*)", @"${1:@wn}", &number1, @"${2:@.n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"2.657066311614524e+78, $5,917.23" getCapturesWithRegexAndReferences:@"([^,]*), (.*)", @"${1:@sn}", &number1, @"${2:@$n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
}

- (void)testStringParseNamedConvertToNSNumberAllFormats
{
  NSNumber *number1 = nil, *number2 = nil;
  
  STAssertNoThrow(([@"123, 456" getCapturesWithRegexAndReferences:@"(?<num1>\\d+), (?<num2>\\d+)", @"${num1:@n}", &number1, @"${num2:@n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"$123, 99.5%" getCapturesWithRegexAndReferences:@"(?<num1>[^,]*), (?<num2>.*)", @"${num1:@$n}", &number1, @"${num2:@%n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"forty-two, 100,954,123.92" getCapturesWithRegexAndReferences:@"(?<num1>[^,]*), (?<num2>.*)", @"${num1:@wn}", &number1, @"${num2:@.n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
  
  number1 = number2 = nil;
  STAssertNoThrow(([@"2.657066311614524e+78, $5,917.23" getCapturesWithRegexAndReferences:@"(?<num1>[^,]*), (?<num2>.*)", @"${num1:@sn}", &number1, @"${num2:@$n}", &number2, nil]), nil);
  STAssertTrue(number1 != nil, nil); STAssertTrue(number2 != nil, nil);
}


- (void)testStringParseNumericConvertToDate
{
  id dateCapture = nil;
  
  STAssertNoThrow(([@"07/20/2007" getCapturesWithRegexAndReferences:@"(.*)", @"${1:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 7, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 20, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  STAssertTrue([dateCapture yearOfCommonEra] == 2007, [NSString stringWithFormat:@"yearOfCommonEra == %d", [dateCapture yearOfCommonEra]]);
  
  dateCapture = nil;
  STAssertNoThrow(([@"6:44 PM" getCapturesWithRegexAndReferences:@"(.*)", @"${1:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture hourOfDay] == 18, [NSString stringWithFormat:@"hourOfDay == %d", [dateCapture hourOfDay]]);
  STAssertTrue([dateCapture minuteOfHour] == 44, [NSString stringWithFormat:@"minuteOfHour == %d", [dateCapture minuteOfHour]]);
  
  dateCapture = nil;
  STAssertNoThrow(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${1:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 2, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 5, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);

  dateCapture = nil;
  STAssertNoThrow(([@"6/20/2007, 11:34PM EDT" getCapturesWithRegexAndReferences:@"(.*)", @"${1:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 6, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 20, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  STAssertTrue([dateCapture yearOfCommonEra] == 2007, [NSString stringWithFormat:@"yearOfCommonEra == %d", [dateCapture yearOfCommonEra]]);
  STAssertTrue([dateCapture hourOfDay] == 23, [NSString stringWithFormat:@"hourOfDay == %d", [dateCapture hourOfDay]]);
  STAssertTrue([dateCapture minuteOfHour] == 34, [NSString stringWithFormat:@"minuteOfHour == %d", [dateCapture minuteOfHour]]);
  STAssertTrue([[dateCapture timeZone] isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EDT"]] == YES, [NSString stringWithFormat:@"timeZone name: %@, abbreviation: %@", [[dateCapture timeZone] name], [[dateCapture timeZone] abbreviation]]);


  dateCapture = nil;
  STAssertNoThrow(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${0:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 2, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 5, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);

  dateCapture = nil;
  STAssertNoThrow(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${00:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 2, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 5, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);

  dateCapture = nil;
  STAssertNoThrow(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${001:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 2, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 5, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  
  
  dateCapture = nil;
  STAssertThrowsSpecificNamed(([@"6/20/2007, 11:34PM EDT" getCapturesWithRegexAndReferences:@"(.*)", @"${2:@d}", &dateCapture, nil]), NSException, RKRegexCaptureReferenceException, nil);
  dateCapture = nil;
  STAssertThrowsSpecificNamed(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${002:@d}", &dateCapture, nil]), NSException, RKRegexCaptureReferenceException, nil);
  dateCapture = nil;
  STAssertThrowsSpecificNamed(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${ 1:@d}", &dateCapture, nil]), NSException, RKRegexCaptureReferenceException, nil);
  dateCapture = nil;
  STAssertThrowsSpecificNamed(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(.*)", @"${1:@$d}", &dateCapture, nil]), NSException, RKRegexCaptureReferenceException, nil);


}

- (void)testStringParseNamedConvertToDate
{
  id dateCapture = nil;
  
  STAssertNoThrow(([@"07/20/2007" getCapturesWithRegexAndReferences:@"(?<date>.*)", @"${date:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 7, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 20, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  STAssertTrue([dateCapture yearOfCommonEra] == 2007, [NSString stringWithFormat:@"yearOfCommonEra == %d", [dateCapture yearOfCommonEra]]);
  
  dateCapture = nil;
  STAssertNoThrow(([@"6:44 PM" getCapturesWithRegexAndReferences:@"(?<date>.*)", @"${date:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture hourOfDay] == 18, [NSString stringWithFormat:@"hourOfDay == %d", [dateCapture hourOfDay]]);
  STAssertTrue([dateCapture minuteOfHour] == 44, [NSString stringWithFormat:@"minuteOfHour == %d", [dateCapture minuteOfHour]]);
  
  dateCapture = nil;
  STAssertNoThrow(([@"Feb 5th" getCapturesWithRegexAndReferences:@"(?<date>.*)", @"${date:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 2, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 5, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  
  dateCapture = nil;
  STAssertNoThrow(([@"6/20/2007, 11:34PM EDT" getCapturesWithRegexAndReferences:@"(?<date>.*)", @"${date:@d}", &dateCapture, nil]), nil);
  STAssertTrue(dateCapture != nil, nil);
  STAssertTrue([dateCapture monthOfYear] == 6, [NSString stringWithFormat:@"monthOfYear == %d", [dateCapture monthOfYear]]);
  STAssertTrue([dateCapture dayOfMonth] == 20, [NSString stringWithFormat:@"dayOfMonth == %d", [dateCapture dayOfMonth]]);
  STAssertTrue([dateCapture yearOfCommonEra] == 2007, [NSString stringWithFormat:@"yearOfCommonEra == %d", [dateCapture yearOfCommonEra]]);
  STAssertTrue([dateCapture hourOfDay] == 23, [NSString stringWithFormat:@"hourOfDay == %d", [dateCapture hourOfDay]]);
  STAssertTrue([dateCapture minuteOfHour] == 34, [NSString stringWithFormat:@"minuteOfHour == %d", [dateCapture minuteOfHour]]);
  STAssertTrue([[dateCapture timeZone] isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EDT"]] == YES, [NSString stringWithFormat:@"timeZone name: %@, abbreviation: %@", [[dateCapture timeZone] name], [[dateCapture timeZone] abbreviation]]);
}

@end
