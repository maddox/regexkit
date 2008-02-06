//
//  RKUnicode.h
//  RegexKit
//  http://regexkit.sourceforge.net/
//
//  PRIVATE HEADER -- NOT in RegexKit.framework/Headers
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

#ifdef __cplusplus
extern "C" {
#endif
  
#ifndef _REGEXKIT_RKUNICODE_H_
#define _REGEXKIT_RKUNICODE_H_ 1

/*!
 @header RKUnicode
*/

#import <Foundation/Foundation.h>
#import <RegexKit/RegexKit.h>


RKREGEX_STATIC_INLINE char *RKGetUTF8String(NSString *string, char *temporaryBuffer, size_t length) RK_ATTRIBUTES(nonnull(1, 2), pure);

#ifdef    USE_CORE_FOUNDATION
RKREGEX_STATIC_INLINE char *RKGetUTF8String(NSString *string, char *temporaryBuffer, size_t length) {
  NSCParameterAssert(string != NULL); NSCParameterAssert(temporaryBuffer != NULL); NSCParameterAssert(length > 0);
  CFIndex copiedLength = 0;
  
  if(RK_EXPECTED(string != NULL, 1)) {
    //char *fastBuffer = (char *)CFStringGetCStringPtr((CFStringRef)string, kCFStringEncodingUTF8);
    //if(fastBuffer != NULL) { return(fastBuffer); }
    copiedLength = CFStringGetBytes((CFStringRef)string, (CFRange){0, CFStringGetLength((CFStringRef)string)}, kCFStringEncodingUTF8, '?', false, (UInt8 *)temporaryBuffer, (CFIndex)(length - 1), NULL);
  }
  temporaryBuffer[copiedLength] = 0;
  
  return(temporaryBuffer);
}
#else
RKREGEX_STATIC_INLINE char *RKGetUTF8String(NSString *string, char *temporaryBuffer, size_t length) {
  NSCParameterAssert(string != NULL); NSCParameterAssert(temporaryBuffer != NULL); NSCParameterAssert(length > 0);
  temporaryBuffer[0] = 0;
  [string getCString:temporaryBuffer maxLength:(RKUInteger)length encoding:NSUTF8StringEncoding];
  
  return(temporaryBuffer);
}
#endif // USE_CORE_FOUNDATION

#define RKutf16to8(a,b) RKConvertUTF16ToUTF8RangeForString(a, b)
#define RKutf8to16(a,b) RKConvertUTF8ToUTF16RangeForString(a, b)

// In NSString.m
unsigned char RKLengthOfUTF8Character(const unsigned char *p)  RK_ATTRIBUTES(nonnull, pure, used, visibility("hidden"));
NSRange       RKConvertUTF8ToUTF16RangeForStringBuffer(RKStringBuffer *stringBuffer, NSRange utf8Range);
NSRange       RKConvertUTF16ToUTF8RangeForStringBuffer(RKStringBuffer *stringBuffer, NSRange utf16Range);
NSRange       RKRangeForUTF8CharacterAtLocation(RKStringBuffer *stringBuffer, RKUInteger utf8Location);

extern const unsigned char utf8ExtraBytes[];

#endif _REGEXKIT_RKUNICODE_H_
  
#ifdef __cplusplus
}  /* extern "C" */
#endif
