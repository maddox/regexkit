//
//  RKUnicode.m
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

#import <RegexKit/RegexKitPrivate.h>
#import <RegexKit/RKUnicode.h>


const unsigned char utf8ExtraBytes[] = {
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5 };

static const unsigned char utf8ExtraUTF16Characters[] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2 };

unsigned char RKLengthOfUTF8Character(const unsigned char *p) {
  const unsigned char c = *p;
  if (c < 128) { return(1); }
  const unsigned char idx = c & 0x3f;
  return(utf8ExtraBytes[idx] + 1);
}

/*
int utf16_length(const unsigned char *string) {
  const unsigned char *p;
  int utf16len = 0;
  
  for (p = string; *p != 0; p++) {
    utf16len++;
    const unsigned char c = *p;
    if (c < 128) { continue; }
    const unsigned char idx = c & 0x3f;
    p += utf8ExtraBytes[idx];
    utf16len += utf8ExtraUTF16Characters[idx];
  }
  return(utf16len);
}
*/

NSRange RKRangeForUTF8CharacterAtLocation(RKStringBuffer *stringBuffer, RKUInteger utf8Location) {
  if(stringBuffer == NULL) { [[NSException rkException:NSInvalidArgumentException localizeReason:@"The stringBuffer parameter is NULL."] raise]; }
  RKUInteger stringUTF8Location = utf8Location;
  
  // Find the start of the previous unicode character.

  if((stringBuffer->length == stringUTF8Location) && (stringUTF8Location > 0)) { stringUTF8Location--; }
  if(((unsigned char)stringBuffer->characters[stringUTF8Location] > 127) && ((unsigned char)stringBuffer->characters[stringUTF8Location] < 0xc0)) {
    while((stringUTF8Location > 0) && (((unsigned char)stringBuffer->characters[stringUTF8Location] > 127) && ((unsigned char)stringBuffer->characters[stringUTF8Location] < 0xc0))) { stringUTF8Location--; }
  }

  return(NSMakeRange(stringUTF8Location, RKLengthOfUTF8Character((unsigned char *)stringBuffer->characters + stringUTF8Location)));
}

NSRange RKConvertUTF8ToUTF16RangeForString(NSString *string, NSRange utf8Range) {
  if(string == NULL) { [[NSException rkException:NSInvalidArgumentException localizeReason:@"String parameter is NULL."] raise]; }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  return(RKConvertUTF8ToUTF16RangeForStringBuffer(&stringBuffer, utf8Range));
}

NSRange RKConvertUTF8ToUTF16RangeForStringBuffer(RKStringBuffer *stringBuffer, NSRange utf8Range) {
  if(stringBuffer == NULL) { [[NSException rkException:NSInvalidArgumentException localizeReason:@"The stringBuffer parameter is NULL."] raise]; }
  
  if(utf8Range.location == NSNotFound) { return(utf8Range); }

  if((utf8Range.location > stringBuffer->length) || (NSMaxRange(utf8Range) > stringBuffer->length)) { [[NSException rkException:NSRangeException localizeReason:@"RKConvertUTF8ToUTF16RangeForStringBuffer: Range invalid. utf8Range: %@. MaxRange: %lu stringBuffer->length: %lu", NSStringFromRange(utf8Range), (unsigned long)NSMaxRange(utf8Range), (unsigned long)stringBuffer->length] raise]; }
  
#ifdef USE_CORE_FOUNDATION
  if((stringBuffer->encoding == kCFStringEncodingMacRoman) || (stringBuffer->encoding == kCFStringEncodingASCII)) { return(utf8Range); }
#else
  if((stringBuffer->encoding == NSMacOSRomanStringEncoding) || (stringBuffer->encoding == NSASCIIStringEncoding)) { return(utf8Range); }
#endif
  
  RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 1, "UTF8 to UTF16 requires slow conversion.");
  const unsigned char RK_STRONG_REF *p = (const unsigned char *)stringBuffer->characters;
  NSRange    utf16Range = NSMakeRange(NSNotFound, 0);
  RKUInteger utf16len   = 0;
  
  while((unsigned)(p - (const unsigned char *)stringBuffer->characters) < NSMaxRange(utf8Range)) {
    if((unsigned)(p - (const unsigned char *)stringBuffer->characters) == utf8Range.location) { utf16Range.location = utf16len; }
    
    const unsigned char c = *p;
    p++;
    utf16len++;
    if(c < 128) { continue; }
    const unsigned char idx = c & 0x3f;
    p += utf8ExtraBytes[idx];
    utf16len += utf8ExtraUTF16Characters[idx];
  }
  if((unsigned)(p - (const unsigned char *)stringBuffer->characters) == utf8Range.location) { utf16Range.location = utf16len; }
  utf16Range.length = utf16len - utf16Range.location;

  RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, NSMaxRange(utf8Range), -1, 2, "UTF8 to UTF16 requires slow conversion.");
  
  return(utf16Range);
}

NSRange RKConvertUTF16ToUTF8RangeForString(NSString *string, NSRange utf16Range) {
  if(string == NULL) { [[NSException rkException:NSInvalidArgumentException localizeReason:@"String parameter is NULL."] raise]; }
  RKStringBuffer stringBuffer = RKStringBufferWithString(string);
  return(RKConvertUTF16ToUTF8RangeForStringBuffer(&stringBuffer, utf16Range));
}

NSRange RKConvertUTF16ToUTF8RangeForStringBuffer(RKStringBuffer *stringBuffer, NSRange utf16Range) {
  if(stringBuffer == NULL) { [[NSException rkException:NSInvalidArgumentException localizeReason:@"The stringBuffer parameter is NULL."] raise]; }

  if(utf16Range.location == NSNotFound) { return(utf16Range); }

  RKUInteger stringLength = [stringBuffer->string length];
  if((utf16Range.location > stringLength) || (NSMaxRange(utf16Range) > stringLength)) { [[NSException rkException:NSRangeException localizeReason:@"RKConvertUTF16ToUTF8RangeForStringBuffer: Range invalid. utf16Range: %@. MaxRange: %lu stringLength: %lu", NSStringFromRange(utf16Range), (unsigned long)NSMaxRange(utf16Range), (unsigned long)stringLength] raise]; }
  
#ifdef USE_CORE_FOUNDATION
  if((stringBuffer->encoding == kCFStringEncodingMacRoman) || (stringBuffer->encoding == kCFStringEncodingASCII)) { return(utf16Range); }
#else
  if((stringBuffer->encoding == NSMacOSRomanStringEncoding) || (stringBuffer->encoding == NSASCIIStringEncoding)) { return(utf16Range); }
#endif
  RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, 0, -1, 1, "UTF16 to UTF8 requires slow conversion.");

  const unsigned char RK_STRONG_REF *p = (const unsigned char *)stringBuffer->characters;
  NSRange    utf8Range = NSMakeRange(NSNotFound, 0);
  RKUInteger utf16len  = 0;
  
  while(utf16len < NSMaxRange(utf16Range)) {
    if(utf16len == utf16Range.location) { utf8Range.location = (p - (const unsigned char *)stringBuffer->characters); }
    
    const unsigned char c = *p;
    p++;
    utf16len++;
    if(c < 128) { continue; }
    const unsigned char idx = c & 0x3f;
    p += utf8ExtraBytes[idx];
    utf16len += utf8ExtraUTF16Characters[idx];
  }
  if(utf16len == utf16Range.location) { utf8Range.location = (p - (const unsigned char *)stringBuffer->characters); }
  utf8Range.length = (p - (const unsigned char *)stringBuffer->characters) - utf8Range.location;
  
  RK_PROBE(PERFORMANCENOTE, NULL, 0, NULL, NSMaxRange(utf8Range), -1, 2, "UTF16 to UTF8 requires slow conversion.");

  return(utf8Range);
}

