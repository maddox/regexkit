# GNUstep Makefile for RegexKit Framework

include $(GNUSTEP_MAKEFILES)/common.make

# Assumes that the CWD is GNUstep
REGEXKIT_ROOT_DIR = $(abspath ..)

GNUSTEP_BUILD_DIR   = ${REGEXKIT_ROOT_DIR}/GNUstep
REGEXKIT_SOURCE_DIR  = ${REGEXKIT_ROOT_DIR}/Source
REGEXKIT_HEADERS_DIR = ${REGEXKIT_SOURCE_DIR}/Headers

PCRE_LIBS=$(shell pcre-config --libs)
PCRE_CFLAGS=$(shell pcre-config --cflags)

vpath %.m ${REGEXKIT_SOURCE_DIR}
vpath %.h ${REGEXKIT_HEADERS_DIR}/RegexKit

ADDITIONAL_FLAGS += -I${REGEXKIT_HEADERS_DIR} ${PCRE_CFLAGS} -std=gnu99

LIBRARY_VAR  = REGEXKIT
LIBRARY_NAME = libRegexKit
PACKAGE_NAME = RegexKit

libRegexKit_HEADER_FILES             = NSArray.h NSDictionary.h NSObject.h NSSet.h NSString.h RKEnumerator.h RKCache.h RKEnumerator.h RKRegex.h RKUtility.h RegexKit.h RegexKitDefines.h RegexKitTypes.h pcre.h
libRegexKit_OBJC_FILES               = NSArray.m NSDictionary.m NSObject.m NSSet.m NSString.m RKAutoreleasedMemory.m RKCache.m RKCoder.m RKEnumerator.m RKLock.m RKPlaceholder.m RKPrivate.m RKRegex.m RKUtility.m
libRegexKit_HEADER_FILES_DIR         = ${REGEXKIT_HEADERS_DIR}/RegexKit
libRegexKit_HEADER_FILES_INSTALL_DIR = /RegexKit

# Include the PCRE library
libRegexKit_LIBRARIES_DEPEND_UPON   += $(FND_LIBS) ${PCRE_LIBS}

#${REGEXKIT_HEADERS_DIR}/pcre.h:
#	cp -p /usr/local/include/pcre.h '${REGEXKIT_HEADERS_DIR}/${PACKAGE_NAME}/pcre.h'


include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/aggregate.make

-include GNUmakefile.postamble



