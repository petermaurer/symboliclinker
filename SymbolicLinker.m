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
#import <stdio.h>
#import <unistd.h>


void MakeSymbolicLink(CFURLRef url)
{
	// Set up the destination path...
	CFURLRef desktopFolderURL = CFBridgingRetain([[NSFileManager defaultManager] URLForDirectory:NSDesktopDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:NULL]);
	if (!desktopFolderURL)	// if, for some reason, we fail to locate the user's desktop folder, then I'd rather have us silently fail than crash
	{
		return;
	}
	CFStringRef filename = CFURLCopyLastPathComponent(url);
	if (CFStringCompare(filename, CFSTR("/"), kCFCompareCaseInsensitive) == kCFCompareEqualTo)	// true if the user is making a symlink to the boot volume
	{
		CFRelease(filename);
		filename = CFURLCopyFileSystemPath(url, kCFURLHFSPathStyle);	// use CoreFoundation to figure out the boot volume's name
	}
	CFURLRef symlinkURL = CFURLCreateCopyAppendingPathComponent(kCFAllocatorDefault, desktopFolderURL, filename, false);
	char sourcePath[PATH_MAX], symlinkPath[PATH_MAX];
	CFURLGetFileSystemRepresentation(symlinkURL, true, (UInt8 *)symlinkPath, PATH_MAX);
	CFURLGetFileSystemRepresentation(url, false, (UInt8 *)sourcePath, PATH_MAX);
	
	// Now we make the link.
	if (symlink(sourcePath, symlinkPath) != noErr)
	{
		CFStringRef CFMyerror = CFCopyLocalizedStringFromTableInBundle(CFSTR("Could not make the symbolic link, because the following error occurred: %d (%s)"), CFSTR("Localizable"), CFBundleGetMainBundle(), "Error message");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wformat-nonliteral"
		CFStringRef CFMyerrorFormatted = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFMyerror, errno, strerror(errno), NULL, NULL);
#pragma clang diagnostic pop

		// An error occurred, so set up a standard alert box and run it...
		CFUserNotificationDisplayAlert(0.0, kCFUserNotificationPlainAlertLevel, NULL, NULL, NULL, CFMyerrorFormatted, NULL, NULL, NULL, NULL, NULL);
		CFRelease(CFMyerror);
		CFRelease(CFMyerrorFormatted);
	}
	CFRelease(desktopFolderURL);
	CFRelease(filename);
	CFRelease(symlinkURL);
}


@implementation SymbolicLinker

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString *dummy = NSLocalizedStringFromTable(@"Make Symbolic Link", @"ServicesMenu", @"Localized title of the symbolic link service (for Snow Leopard & later users)");	// this is here just so genstrings will pick up the localized service name
	
#pragma unused(dummy)
	NSUpdateDynamicServices();	// force a reload of the user's services
	[NSApp setServicesProvider:self];	// this class will provide the services
#ifndef DEBUG
	[NSTimer scheduledTimerWithTimeInterval:5.0 target:NSApp selector:@selector(terminate:) userInfo:nil repeats:NO];	// stay resident for a while, then self-destruct
#endif
}

- (void)makeSymbolicLink:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString *__autoreleasing *)error
{
	NSArray *fileURLs = [pboard readObjectsForClasses:@[[NSURL class]] options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
	
	if (fileURLs && fileURLs.count)
	{
		[fileURLs enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger i, BOOL *stop) {
			MakeSymbolicLink((__bridge CFURLRef)fileURL);
		}];
	}
	else	// backward compatibility for the situation where public.url didn't work but NSFilenamesPboardType did
	{
		NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
		
		for (NSString *filename in filenames)
		{
			NSURL *fileURL = [NSURL fileURLWithPath:filename];
			
			if (fileURL)
				MakeSymbolicLink((__bridge CFURLRef)fileURL);
		}
	}
}

@end


int main(int argc, const char *argv[])
{
	return NSApplicationMain(argc, argv);
}
