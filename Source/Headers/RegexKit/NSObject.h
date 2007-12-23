//
//  NSObject.h
//  RegexKit
//  http://regexkit.sourceforge.net/
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

#ifdef __cplusplus
extern "C" {
#endif
  
#ifndef _REGEXKIT_NSOBJECT_H_
#define _REGEXKIT_NSOBJECT_H_ 1

/*!
 @header NSObject
*/

#import <Foundation/Foundation.h>
#import <RegexKit/RegexKit.h>

/*!
 @category    NSObject (RegexKitAdditions)
 @abstract    Convenient @link NSObject NSObject @/link additions to make regular expression pattern matching and extraction easier.
*/
  
/*!
 @toc        NSObject
 @group      Identifying and Comparing Objects
 @group      Identifying Matches in an Array
 @group      Identifying Matches in a Set
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


/*!
 @method     isMatchedByAnyRegexInArray:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by any regular expression in <span class="argument">regexArray</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @result     Returns <span class="code">YES</span> if the receiver is matched by any regular expression in <span class="argument">regexArray</span>, <span class="code">NO</span> otherwise.
*/
- (BOOL)isMatchedByAnyRegexInArray:(NSArray *)regexArray;
/*!
 @method     anyMatchingRegexInArray:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @result     Returns any regular expression from <span class="argument">regexArray</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)anyMatchingRegexInArray:(NSArray *)regexArray;
/*!
 @method     firstMatchingRegexInArray:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @result     Returns the first regular expression from <span class="argument">regexArray</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)firstMatchingRegexInArray:(NSArray *)regexArray;
/*!
 @method     isMatchedByAnyRegexInArray:library:options:error:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by any regular expression in <span class="argument">regexArray</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @param      libraryString <span class="XXX UNKNOWN">TODO</span>
 @param      libraryOptions <span class="XXX UNKNOWN">TODO</span>
 @param      outError <span class="XXX UNKNOWN">TODO</span>
 @result     Returns <span class="code">YES</span> if the receiver is matched by any regular expression in <span class="argument">regexArray</span>, <span class="code">NO</span> otherwise.
*/
- (BOOL)isMatchedByAnyRegexInArray:(NSArray *)regexArray library:(NSString *)libraryString options:(RKCompileOption)libraryOptions error:(NSError **)outError;
/*!
 @method     anyMatchingRegexInArray:library:options:error:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @param      libraryString <span class="XXX UNKNOWN">TODO</span>
 @param      libraryOptions <span class="XXX UNKNOWN">TODO</span>
 @param      outError <span class="XXX UNKNOWN">TODO</span>
 @result     Returns any regular expression from <span class="argument">regexArray</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)anyMatchingRegexInArray:(NSArray *)regexArray library:(NSString *)libraryString options:(RKCompileOption)libraryOptions error:(NSError **)outError;
/*!
 @method     firstMatchingRegexInArray:library:options:error:
 @tocgroup   NSObject Identifying Matches in an Array
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexArray A @link NSArray NSArray @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @param      libraryString <span class="XXX UNKNOWN">TODO</span>
 @param      libraryOptions <span class="XXX UNKNOWN">TODO</span>
 @param      outError <span class="XXX UNKNOWN">TODO</span>
 @result     Returns the first regular expression from <span class="argument">regexArray</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)firstMatchingRegexInArray:(NSArray *)regexArray library:(NSString *)libraryString options:(RKCompileOption)libraryOptions error:(NSError **)outError;

/*!
 @method     isMatchedByAnyRegexInSet:
 @tocgroup   NSObject Identifying Matches in a Set
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by any regular expression in <span class="argument">regexSet</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexSet A @link NSSet NSSet @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @result     Returns <span class="code">YES</span> if the receiver is matched by any regular expression in <span class="argument">regexSet</span>, <span class="code">NO</span> otherwise.
*/
- (BOOL)isMatchedByAnyRegexInSet:(NSSet *)regexSet;
/*!
 @method     anyMatchingRegexInSet:
 @tocgroup   NSObject Identifying Matches in a Set
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexSet A @link NSSet NSSet @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @result     Returns any regular expression from <span class="argument">regexSet</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)anyMatchingRegexInSet:(NSSet *)regexSet;
/*!
 @method     isMatchedByAnyRegexInSet:library:options:error:
 @tocgroup   NSObject Identifying Matches in a Set
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by any regular expression in <span class="argument">regexSet</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexSet A @link NSSet NSSet @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @param      libraryString <span class="XXX UNKNOWN">TODO</span>
 @param      libraryOptions <span class="XXX UNKNOWN">TODO</span>
 @param      outError <span class="XXX UNKNOWN">TODO</span>
 @result     Returns <span class="code">YES</span> if the receiver is matched by any regular expression in <span class="argument">regexSet</span>, <span class="code">NO</span> otherwise.
*/
- (BOOL)isMatchedByAnyRegexInSet:(NSSet *)regexSet library:(NSString *)libraryString options:(RKCompileOption)libraryOptions error:(NSError **)outError;
/*!
 @method     anyMatchingRegexInSet:library:options:error:
 @tocgroup   NSObject Identifying Matches in a Set
 @abstract   Returns a Boolean value that indicates whether the receiver is matched by <span class="argument">aRegex</span>.
 @discussion <span class="XXX UNKNOWN">TODO</span>
 @param      regexSet A @link NSSet NSSet @/link containing either regular expression strings or @link RKRegex RKRegex @/link objects.
 @param      libraryString <span class="XXX UNKNOWN">TODO</span>
 @param      libraryOptions <span class="XXX UNKNOWN">TODO</span>
 @param      outError <span class="XXX UNKNOWN">TODO</span>
 @result     Returns any regular expression from <span class="argument">regexSet</span> that matches the receiver, or <span class="code">NULL</span> if there is no match.
*/
- (RKRegex *)anyMatchingRegexInSet:(NSSet *)regexSet library:(NSString *)libraryString options:(RKCompileOption)libraryOptions error:(NSError **)outError;

@end

#endif // _REGEXKIT_NSOBJECT_H_

#ifdef __cplusplus
  }  /* extern "C" */
#endif
