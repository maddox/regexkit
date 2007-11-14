//
//  RKPrivate.m
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

#import <RegexKit/RegexKitPrivate.h>

void nsprintf(NSString * const formatString, ...) {
  va_list ap;
  
  va_start(ap, formatString);
  vnsprintf(formatString, ap);
  va_end(ap);
  
  return;
}

void vnsprintf(NSString * const formatString, va_list ap) {
  NSString *logString = [[[NSString alloc] initWithFormat:formatString arguments:ap] autorelease];
  
  printf("%s", [logString UTF8String]);
}

int RKRegexPCRECallout(pcre_callout_block * const callout_block RK_ATTRIBUTES(unused)) {
  [[NSException exceptionWithName:RKRegexUnsupportedException reason:@"Callouts are not supported." userInfo:NULL] raise];
  return(RKMatchErrorBadOption);
}

NSArray *RKArrayOfPrettyNewlineTypes(NSString * const prefixString) {
  return([NSArray arrayWithObjects:
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineDefault, prefixString), RKCompileNewlineDefault],
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineCR,      prefixString), RKCompileNewlineCR],
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineLF,      prefixString), RKCompileNewlineLF],
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineCRLF,    prefixString), RKCompileNewlineCRLF],
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineAnyCRLF, prefixString), RKCompileNewlineAnyCRLF],
    [NSString stringWithFormat:@"%@ 0x%8.8x", RKStringFromNewlineOption(RKCompileNewlineAny,     prefixString), RKCompileNewlineAny],
    
    NULL]);
}  

