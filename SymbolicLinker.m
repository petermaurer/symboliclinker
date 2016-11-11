/*
 *  SymbolicLinker.m
 *  SymbolicLinker
 *
 *  Created by Nick Zitzmann on Sun Mar 21 2004.
 *  Copyright (c) 2004 Nick Zitzmann. All rights reserved.
 *
 */
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "SymbolicLinker.h"
#include <stdio.h>
#include <unistd.h>
#include <Carbon/Carbon.h>
#ifdef USE_COCOA
#import <Cocoa/Cocoa.h>
#else
#include "MoreFinderEvents.h"
#endif


CF_INLINE CFBundleRef SLOurBundle(void)
{
	CFStringRef bundleCFStringRef = CFSTR("de.petermaurer.SymbolicLinker");
	return CFBundleGetBundleWithIdentifier(bundleCFStringRef);
}


CF_INLINE OSStatus StandardAlertCF(AlertType inAlertType, CFStringRef inError, CFStringRef inExplanation, const AlertStdCFStringAlertParamRec *inAlertParam, SInt16 *outItemHit)
{
	OSStatus err = noErr;
	
#ifdef USE_COCOA
	CFUserNotificationDisplayAlert(0.0, kCFUserNotificationPlainAlertLevel, NULL, NULL, NULL, (inError ? inError : CFSTR("")), inExplanation, NULL, NULL, NULL, NULL);
#else
	DialogRef outAlert;
	
	if ((err = CreateStandardAlert(inAlertType, inError, inExplanation, inAlertParam, &outAlert)) == noErr)
	{
		err = RunStandardAlert(outAlert, NULL, outItemHit);
	}
#endif
	return err;
}

CF_INLINE bool SLIsEqualToString(CFStringRef theString1, CFStringRef theString2)
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
	return (CFStringCompare(theString1, theString2, 0) == kCFCompareEqualTo);
#pragma clang diagnostic pop
}

void MakeSymbolicLinkToDesktop(CFURLRef url)
{
	CFURLRef desktopFolderURL, symlinkURL;
	CFStringRef sourceFilename, symlinkFilename;
	char sourcePath[PATH_MAX], symlinkPath[PATH_MAX];

	// Set up the destination path...
	desktopFolderURL = CFBridgingRetain([[NSFileManager defaultManager] URLForDirectory:NSDesktopDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL]);
	if (!desktopFolderURL)	// if, for some reason, we fail to locate the user's desktop folder, then I'd rather have us silently fail than crash
	{
		return;
	}
	sourceFilename = CFURLCopyLastPathComponent(url);
	if (SLIsEqualToString(sourceFilename, CFSTR("/")))	// true if the user is making a symlink to the boot volume
	{
		CFRelease(sourceFilename);
		sourceFilename = CFURLCopyFileSystemPath(url, kCFURLHFSPathStyle);	// use CoreFoundation to figure out the boot volume's name
	}
	symlinkFilename = CFRetain(sourceFilename);
	symlinkURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, desktopFolderURL, symlinkFilename, false);
	CFURLGetFileSystemRepresentation(symlinkURL, true, (UInt8 *)symlinkPath, PATH_MAX);
	CFURLGetFileSystemRepresentation(url, false, (UInt8 *)sourcePath, PATH_MAX);
	
	// Now we make the link.
	if (symlink(sourcePath, symlinkPath) != noErr)
	{
		CFStringRef CFMyerror = CFCopyLocalizedStringFromTableInBundle(CFSTR("Could not make the symbolic link, because the following error occurred: %d (%s)"), CFSTR("Localizable"), SLOurBundle(), "Error message");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
		CFStringRef CFMyerrorFormatted = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFMyerror, errno, strerror(errno));
#pragma clang diagnostic pop
		SInt16 ignored;
		
		// An error occurred, so set up a standard alert box and run it...
		StandardAlertCF(kAlertCautionAlert, CFMyerrorFormatted, NULL, NULL, &ignored);
		CFRelease(CFMyerror);
		CFRelease(CFMyerrorFormatted);
	}
	CFRelease(desktopFolderURL);
	CFRelease(sourceFilename);
	CFRelease(symlinkFilename);
	CFRelease(symlinkURL);
}
