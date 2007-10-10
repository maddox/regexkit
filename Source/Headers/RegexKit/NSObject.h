//
//  NSObject.h
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

/*!
 @header NSObject
*/

#ifndef _REGEXKIT_NSOBJECT_H_
#define _REGEXKIT_NSOBJECT_H_ 1

#import <Foundation/Foundation.h>
#import <RegexKit/RKRegex.h>

/*!
 @category    NSObject (RegexKitAdditions)
 @abstract    Convenient @link NSObject NSObject @/link additions to make regular expression pattern matching and extraction easier.
*/
  
/*!
 @toc        NSObject
 @group      Identifying and Comparing Objects
*/
  
 @interface NSObject (RegexKitAdditions)

/*!
 @method     isMatchedByRegex:
 @tocgroup   NSObject Identifying and Comparing Objects
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion Invokes @link isMatchedByRegex: isMatchedByRegex: @/link on the @link NSString NSString @/link returned by the receivers @link description description@/link.
 @param      aRegex A regular expression string or @link RKRegex RKRegex @/link object.
 @result     Returns <span class="code">YES</span> if the receiver is matched by <span class="argument">aRegex</span>, <span class="code">NO</span> otherwise.
*/
- (BOOL)isMatchedByRegex:(id)aRegex;

@end

#endif // _REGEXKIT_NSOBJECT_H_
