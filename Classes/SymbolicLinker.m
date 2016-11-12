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


static void SLCreateSymbolicLinkOnDesktop(NSURL *sourceURL) {
	if (sourceURL) {
		@autoreleasepool {
			NSFileManager *fileManager = [NSFileManager defaultManager];
			NSURL *desktopFolderURL = [fileManager URLForDirectory: NSDesktopDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: NO error: NULL];
			if (desktopFolderURL) {
				NSString *filename = [sourceURL lastPathComponent];
				if ([filename isEqualToString: @"/"]) {
					filename = [[fileManager componentsToDisplayForPath: filename] firstObject];
				}
				if ([filename length]>0) {
					const char *sourcePath = [sourceURL fileSystemRepresentation];
					const char *symlinkPath = [[desktopFolderURL URLByAppendingPathComponent: filename] fileSystemRepresentation];
					if ((sourcePath) && (symlinkPath) && (symlink(sourcePath, symlinkPath)!=noErr)) {
						[NSApp activateIgnoringOtherApps: YES];
						NSAlert *theAlert = [[NSAlert alloc] init];
						[theAlert setMessageText: [NSString stringWithFormat: NSLocalizedString(@"Could not make the symbolic link, because the following error occurred: %d (%s)", @"Error message"), errno, strerror(errno)]];
						[theAlert runModal];
						[theAlert release];
					}
				}
			}
		}
	}
}


@implementation SymbolicLinker

	- (void)applicationDidFinishLaunching: (NSNotification*)notification {
		NSUpdateDynamicServices();
		[NSApp setServicesProvider: self];
		[NSApp performSelector: @selector(showPreferences:) withObject: nil afterDelay: 1.0];
	}

	- (void)makeSymbolicLink: (NSPasteboard*)pasteboard userData: (NSString*)userData error: (NSString**)error {
		NSArray *fileURLs = [pasteboard readObjectsForClasses: @[[NSURL class]] options: @{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
		if ([fileURLs count]>0) {
			for (NSURL *fileURL in fileURLs) {
				SLCreateSymbolicLinkOnDesktop(fileURL);
			}
		} else {
			for (NSString *path in [pasteboard propertyListForType: NSFilenamesPboardType]) {
				SLCreateSymbolicLinkOnDesktop([NSURL fileURLWithPath: path]);	// backward compatibility for when public.url doesn't work, but NSFilenamesPboardType does
			}
		}
		if (![self.preferencesWindow isVisible]) {
			[NSObject cancelPreviousPerformRequestsWithTarget: self];
			[NSApp terminate: nil];
		}
	}

	- (void)showPreferences: (id)sender {
		[NSApp terminate: nil];	// to do: show preferences window instead of terminating
	}

	- (void)windowWillClose: (NSNotification*)notification {
		if ([notification object]==self.preferencesWindow) {
			[NSApp terminate: nil];
		}
	}

	- (void)dealloc {
		[_preferencesWindow release];
		[super dealloc];
	}

@end


int main(int argc, const char *argv[]) {
	return NSApplicationMain(argc, argv);
}
