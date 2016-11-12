//
//  SymbolicLinker.m
//  SymbolicLinker
//
//  Created by Nick Zitzmann on 8/23/09.
//  Copyright 2009 Nick Zitzmann. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "SymbolicLinker.h"


static void SLCreateSymbolicLinkOnDesktop(CFURLRef sourceURL) {
	if (sourceURL) {
		CFURLRef desktopFolderURL = CFBridgingRetain([[NSFileManager defaultManager] URLForDirectory: NSDesktopDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: NO error: NULL]);
		if (desktopFolderURL) {
			CFStringRef filename = CFURLCopyLastPathComponent(sourceURL);
			if (CFStringCompare(filename, CFSTR("/"), kCFCompareCaseInsensitive)==kCFCompareEqualTo) {
				CFRelease(filename);
				filename = CFURLCopyFileSystemPath(sourceURL, kCFURLHFSPathStyle);	// use volume name
			}
			CFURLRef symlinkURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, desktopFolderURL, filename, false);
			char sourcePath[PATH_MAX], symlinkPath[PATH_MAX];
			CFURLGetFileSystemRepresentation(sourceURL, false, (UInt8*)sourcePath, PATH_MAX);
			CFURLGetFileSystemRepresentation(symlinkURL, true, (UInt8*)symlinkPath, PATH_MAX);
			if (symlink(sourcePath, symlinkPath)!=noErr) {
				CFStringRef errorFormat = CFCopyLocalizedStringFromTableInBundle(CFSTR("Could not make the symbolic link, because the following error occurred: %d (%s)"), CFSTR("Localizable"), CFBundleGetMainBundle(), "Error message");
				#pragma clang diagnostic push
				#pragma clang diagnostic ignored "-Wformat-nonliteral"
				CFStringRef errorMessage = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, errorFormat, errno, strerror(errno), NULL, NULL);
				#pragma clang diagnostic pop
				CFUserNotificationDisplayAlert(0.0, kCFUserNotificationPlainAlertLevel, NULL, NULL, NULL, errorMessage, NULL, NULL, NULL, NULL, NULL);
				CFRelease(errorMessage);
				CFRelease(errorFormat);
			}
			CFRelease(symlinkURL);
			CFRelease(filename);
			CFRelease(desktopFolderURL);
		}
	}
}


@implementation SymbolicLinker

	- (void)applicationDidFinishLaunching: (NSNotification*)notification {
		NSUpdateDynamicServices();
		[NSApp setServicesProvider: self];
		[NSApp performSelector: @selector(terminate:) withObject: nil afterDelay: 5.0];
	}

	- (void)makeSymbolicLink: (NSPasteboard*)pasteboard userData: (NSString*)userData error: (NSString*__autoreleasing*)error {
		NSArray *fileURLs = [pasteboard readObjectsForClasses: @[[NSURL class]] options: @{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
		if ([fileURLs count]>0) {
			for (NSURL *fileURL in fileURLs) {
				SLCreateSymbolicLinkOnDesktop((__bridge CFURLRef)fileURL);
			}
		} else {
			for (NSString *path in [pasteboard propertyListForType: NSFilenamesPboardType]) {
				SLCreateSymbolicLinkOnDesktop((__bridge CFURLRef)[NSURL fileURLWithPath: path]);	// backward compatibility for when public.url doesn't work, but NSFilenamesPboardType does
			}
		}
	}

@end


int main(int argc, const char *argv[]) {
	return NSApplicationMain(argc, argv);
}
