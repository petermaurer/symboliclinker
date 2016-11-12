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


#define DESKTOP_TARGET_KEY @"SymbolicLinkerPrefersDesktop"


static OSErr SLSymlink(const char *sourcePath, NSURL *targetURL, NSString *name, BOOL appendSuffix) {
	@autoreleasepool {
		NSInteger attempt = (appendSuffix ? 0 : -1);
		NSString *symlinkName;
		const char *symlinkPath;
		OSErr result;
		do {
			switch (attempt) {
				case -1:
					symlinkName = name;
					break;
				case 0:
					symlinkName = [name stringByAppendingString: @" symlink"];
					break;
				default:
					symlinkName = [NSString stringWithFormat: @"%@ symlink %ld", name, (long)attempt];
					break;
			}
			symlinkPath = [[targetURL URLByAppendingPathComponent: symlinkName] fileSystemRepresentation];
			if (!symlinkPath) {
				return EINVAL;
			}
			if (symlink(sourcePath, symlinkPath)==0) {
				return noErr;
			}
			if (errno!=EEXIST) {
				return errno;
			}
			attempt++;
		} while (attempt<NSIntegerMax);
	}
	return EEXIST;
}


@interface SymbolicLinker () <NSWindowDelegate>

	@property (nonatomic, retain) NSWindow *preferencesWindow;

@end

@implementation SymbolicLinker

	- (void)makeSymbolicLink: (NSPasteboard*)pasteboard userData: (NSString*)userData error: (NSString**)error {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		NSURL *desktopURL = [fileManager URLForDirectory: NSDesktopDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: NO error: NULL];
		BOOL defaultToParent = ((!desktopURL) || (![[NSUserDefaults standardUserDefaults] boolForKey: DESKTOP_TARGET_KEY]));
		void (^MakeSymbolicLink)(NSURL *) = ^(NSURL *sourceURL) {
			OSErr result = EINVAL;
			const char *sourcePath = [sourceURL fileSystemRepresentation];
			if (sourcePath) {
				NSString *name = [sourceURL lastPathComponent];
				if ([name isEqualToString: @"/"]) {
					name = [[fileManager componentsToDisplayForPath: [sourceURL path]] firstObject];
				}
				if ([name length]>0) {
					NSURL *parentURL = [sourceURL URLByDeletingLastPathComponent];
					if (defaultToParent && (parentURL)) {
						result = SLSymlink(sourcePath, parentURL, name, YES);
					}
					if ((result!=noErr) && (desktopURL)) {
						result = SLSymlink(sourcePath, desktopURL, name, [parentURL isEqual: desktopURL]);
					}
				}
			}
			if (result!=noErr) {
				NSAlert *alert = [[NSAlert alloc] init];
				[alert setMessageText: [NSString stringWithFormat: NSLocalizedString(@"Could not make the symbolic link, because the following error occurred: %d (%s)", @"Error Message"), result, strerror(result)]];
				[alert runModal];
				[alert release];
			}
		};
		NSArray *fileURLs = [pasteboard readObjectsForClasses: @[[NSURL class]] options: @{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
		if ([fileURLs count]>0) {
			for (NSURL *fileURL in fileURLs) {
				MakeSymbolicLink(fileURL);
			}
		} else {
			for (NSString *path in [pasteboard propertyListForType: NSFilenamesPboardType]) {
				MakeSymbolicLink([NSURL fileURLWithPath: path]);	// backward compatibility for when public.url doesn't work, but NSFilenamesPboardType does
			}
		}
		if (![self.preferencesWindow isVisible]) {
			[NSObject cancelPreviousPerformRequestsWithTarget: self];
			[NSApp terminate: nil];
		}
	}

	- (void)showPreferences: (id)sender {
		NSWindow *preferencesWindow = self.preferencesWindow;
		if (!preferencesWindow) {
			NSButton *targetSwitch = [[NSButton alloc] initWithFrame: NSZeroRect];
			[targetSwitch setButtonType: NSSwitchButton];
			[[targetSwitch cell] setControlSize: NSControlSizeRegular];
			[targetSwitch setFont: [NSFont systemFontOfSize: [NSFont systemFontSizeForControlSize: NSControlSizeRegular]]];
			[targetSwitch setState: ([[NSUserDefaults standardUserDefaults] boolForKey: DESKTOP_TARGET_KEY] ? NSOnState : NSOffState)];
			[targetSwitch setTarget: self];
			[targetSwitch setAction: @selector(toggleDesktopTarget:)];
			[targetSwitch setTitle: NSLocalizedString(@"Create symbolic links on Desktop", @"Target Preference")];
			[targetSwitch sizeToFit];
			const CGFloat padding = 20.0;
			NSRect targetSwitchFrame = [targetSwitch frame];
			targetSwitchFrame.origin = NSMakePoint(padding, padding);
			[targetSwitch setFrame: targetSwitchFrame];
			preferencesWindow = [[NSWindow alloc] initWithContentRect: NSInsetRect(targetSwitchFrame, -padding, -padding) styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: YES];
			self.preferencesWindow = preferencesWindow;
			[preferencesWindow release];
			[preferencesWindow setDelegate: self];
			[preferencesWindow setTitle: [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"]];
			[[preferencesWindow contentView] addSubview: targetSwitch];
			[targetSwitch release];
		}
		if (![preferencesWindow isVisible]) {
			[preferencesWindow center];
		}
		[preferencesWindow makeKeyAndOrderFront: nil];
		[NSApp activateIgnoringOtherApps: YES];
	}

	- (void)toggleDesktopTarget: (id)sender {
		[[NSUserDefaults standardUserDefaults] setBool: ([sender state]==NSOnState) forKey: DESKTOP_TARGET_KEY];
	}

	- (void)applicationDidFinishLaunching: (NSNotification*)notification {
		NSUpdateDynamicServices();
		[NSApp setServicesProvider: self];
		[self performSelector: @selector(showPreferences:) withObject: nil afterDelay: 1.0];
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
