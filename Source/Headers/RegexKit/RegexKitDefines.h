//
//  RegexKitDefines.h
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


#ifndef _REGEXKITDEFINES_H_
#define _REGEXKITDEFINES_H_ 1

#define __REGEXKIT__

// Determine runtime environment
#if !defined(__MACOSX_RUNTIME__) && !defined(__GNUSTEP_RUNTIME__)

#if defined(__APPLE__) && defined(__MACH__) && !defined(GNUSTEP)
#define __MACOSX_RUNTIME__
#else // If not Mac OS X, GNUstep?
#if defined(GNUSTEP) 
#define __GNUSTEP_RUNTIME__
#else // Not Mac OS X or GNUstep, that's a problem.
#error "Unable to determine run time environment, automatic Mac OS X and GNUstep detection failed"
#endif // GNUSTEP
#endif //__APPLE__ && __MACH__

#endif // !defined(__MACOSX_RUNTIME__) && !defined(__GNUSTEP_RUNTIME__)

/*!
@defined RKREGEX_STATIC_INLINE
 @tocgroup Constants Preprocessor Macros
 @abstract Preprocessor definition for making functions static inline.
 @discussion <p>@link RKREGEX_STATIC_INLINE RKREGEX_STATIC_INLINE @/link is a wrapper around GCC 4+ directives to always static inline.</p>
<p>Borrowed from <span class="nobr">Mac OS X</span> @link NSObjCRuntime.h NSObjCRuntime.h @/link @link FOUNDATION_STATIC_INLINE FOUNDATION_STATIC_INLINE @/link to be portable to @link GNUstep GNUstep@/link.</p>
<p>Evaluates to <span class="nobr code">static __inline__</span> for compilers other than GCC 4+.</p>
 */

/*!
@defined RK_EXPECTED
 @tocgroup Constants Preprocessor Macros
 @abstract Macro to assist the compiler by providing branch prediction information.
 @param cond The boolean conditional statement to be evaluated, for example <span class="code nobr">(aPtr == NULL)</span>.
 @param expect The expected result of the conditional statement, expressed as a <span class="code">0</span> or a <span class="code">1</span>.
 @discussion  <div class="box important"><div class="table"><div class="row"><div class="label cell">Important:</div><div class="message cell"><span class="code">RK_EXPECTED</span> should only be used when the likelihood of the prediction is nearly certain. <b><i>DO NOT GUESS</i></b>.</div></div></div></div>
 <p>@link RK_EXPECTED RK_EXPECTED @/link is a wrapper around the GCC 4+ built-in function <a href="http://gcc.gnu.org/onlinedocs/gcc-4.0.4/gcc/Other-Builtins.html#index-g_t_005f_005fbuiltin_005fexpect-2284" class="code">__builtin_expect</a>, which is used to provide the compiler with branch prediction information for conditional statements.  If a compiler other than GCC 4+ is used then the macro leaves the conditional expression unaltered.</p>
 <p>An example of an appropriate use is parameter validation checks at the start of a function, such as <span class="code nobr">(aPtr == NULL)</span>.  Since callers are always expected to pass a valid pointer, the likelyhood of the conditional evaluating to true is extremely unlikely.  This allows the compiler to schedule instructions to minimize branch miss-prediction penalties. For example:
 <div class="box sourcecode">if(RK_EXPECTED((aPtr == NULL), 0)) { abort(); }</div>
*/

/*!
@defined RK_ATTRIBUTES
 @tocgroup Constants Preprocessor Macros
 @abstract Macro wrapper around GCC <a href="http://gcc.gnu.org/onlinedocs/gcc-4.0.4/gcc/Attribute-Syntax.html#Attribute-Syntax" class="code">__attribute__</a> syntax.
 @discussion <p>When a compiler other than GCC 4+ is used, <span class="code">RK_ATTRIBUTES</span> evaluates to an empty string, removing itself and its arguments from the code to be compiled.</p>
*/

#if defined (__GNUC__) && (__GNUC__ >= 4)
#define RKREGEX_STATIC_INLINE static __inline__ __attribute__((always_inline))
#define RK_EXPECTED(cond, expect) __builtin_expect(cond, expect)
#define RK_ATTRIBUTES(attr, ...) __attribute__((attr, ##__VA_ARGS__))
#else
#define RKREGEX_STATIC_INLINE static __inline__
#define RK_EXPECTED(cond, expect) cond
#define RK_ATTRIBUTES(attr, ...)
#endif

/*!
@defined RK_C99
 @tocgroup Constants Preprocessor Macros
 @abstract Macro wrapper around <span class="code">C99</span> keywords.
 @discussion <p>@link RK_C99 RK_C99 @/link is a wrapper for <span class="code">C99</span> standard keywords that are not compatible with previous <span class="code">C</span> standards, such as <span class="code">C89</span>.</p>
<p>This is used almost exclusively to wrap the <span class="code">C99</span> <span class="code">restrict</span> keyword.</p>
 */

#if __STDC_VERSION__ >= 199901L
#define RK_C99(keyword) keyword
#else
#define RK_C99(keyword) 
#endif

#ifdef __cplusplus
#define REGEXKIT_EXTERN           extern "C"
#define REGEXKIT_PRIVATE_EXTERN   __private_extern__
#else
#define REGEXKIT_EXTERN           extern
#define REGEXKIT_PRIVATE_EXTERN   __private_extern__
#endif

/*!
@defined RKReplaceAll
 @tocgroup Constants Constants
 @abstract Predefined <span class="argument">count</span> for use with <a href="NSString.html#ExpansionofCaptureSubpatternMatchReferencesinStrings" class="section-link">Search and Replace</a> methods to specify all matches are to be replaced.
 */
#define RKReplaceAll UINT_MAX

// Used to size/check buffers when calling private RKRegex getRanges:count:withCharacters:length:inRange:options:
#define RK_PRESIZE_CAPTURE_COUNT(x) (256 + x + (x >> 1))
#define RK_MINIMUM_CAPTURE_COUNT(x) (x + ((x / 3) + ((3 - (x % 3)) % 3)))

/*************** Feature and config knobs ***************/

// Default enabled
#define USE_AUTORELEASED_MALLOC
#define USE_PLACEHOLDER


#ifdef __COREFOUNDATION__
#define USE_CORE_FOUNDATION
#endif

#ifdef __MACOSX_RUNTIME__
#define HAVE_NSNUMBERFORMATTER_CONVERSIONS
#endif

#if defined(HAVE_NSNUMBERFORMATTER_CONVERSIONS)
#define RK_ENABLE_THREAD_LOCAL_STORAGE
#endif

// AFAIK, only the GCC 3.3+ Mac OSX objc runtime has -fobjc-exception support
#if (!defined(__MACOSX_RUNTIME__)) || (!defined(__GNUC__)) || ((__GNUC__ == 3) && (__GNUC_MINOR__ < 3)) || (!defined(MAC_OS_X_VERSION_10_3))
// Otherwise, use NS_DURING / NS_HANDLER and friends
#warning "NOTICE: Support for -fobjc-exception not present, using NS_DURING / NS_HANDLER macros for exceptions"
#define USE_MACRO_EXCEPTIONS
#endif

/*************** END Feature and config knobs ***************/

#endif //_REGEXKITDEFINES_H_
