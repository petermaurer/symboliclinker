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

#import <Cocoa/Cocoa.h>


#define USER_DEFAULT_IGNORE_MODIFIER_FLAGS @"SLIgnoreModifierFlags"
#define USER_DEFAULT_PREFER_DESKTOP_TARGET @"SLPreferDesktopTarget"


static void SLServicesMenuLocalizationDummy(void) {
	NSLocalizedStringFromTable(@"Make Symbolic Link", @"ServicesMenu", @"Service Menu Item Title");	// => genstrings
}

static NSString *SLRelativeFileURLPath(NSURL *baseURL, NSURL *targetURL) {
	NSString *relativePath = nil;
	@autoreleasepool {
		NSArray *basePathComponents = [baseURL pathComponents];
		NSArray *targetPathComponents = [targetURL pathComponents];
		NSUInteger numberOfBasePathComponents = [basePathComponents count];
		NSUInteger numberOfTargetPathComponents = [targetPathComponents count];
		if ((numberOfBasePathComponents>0) && (numberOfTargetPathComponents>0)) {
			NSUInteger numberOfCommonPathComponents = ((numberOfBasePathComponents<numberOfTargetPathComponents) ? numberOfBasePathComponents : numberOfTargetPathComponents);
			NSUInteger index;
			for (index = 0; index<numberOfCommonPathComponents; index++) {
				if (![[basePathComponents objectAtIndex: index] isEqualToString: [targetPathComponents objectAtIndex: index]]) {
					numberOfCommonPathComponents = index;
					break;
				}
			}
			if (numberOfCommonPathComponents>0) {
				NSMutableArray *relativePathComponents = [NSMutableArray array];
				numberOfBasePathComponents -= numberOfCommonPathComponents;
				for (index = 0; index<numberOfBasePathComponents; index++) {
					[relativePathComponents addObject: @".."];
				}
				if (numberOfCommonPathComponents==numberOfTargetPathComponents) {
					if (numberOfBasePathComponents==0) {
						[relativePathComponents addObject: @"."];
					}
				} else {
					[relativePathComponents addObjectsFromArray: [targetPathComponents subarrayWithRange: NSMakeRange(numberOfCommonPathComponents, numberOfTargetPathComponents - numberOfCommonPathComponents)]];
				}
				relativePath = [[NSString pathWithComponents: relativePathComponents] retain];
			}
		}
	}
	return [relativePath autorelease];
}

static OSErr SLMakeSymlink(const char *linkedPath, NSURL *targetURL, NSString *name, BOOL appendSuffix, NSMutableArray *symlinkURLs) {
	@autoreleasepool {
		long attempt = (appendSuffix ? 0 : -1);
		do {
			NSString *symlinkName;
			switch (attempt) {
				case -1:
					symlinkName = name;
					break;
				case 0:
					symlinkName = [name stringByAppendingString: @" Symlink"];
					break;
				default:
					symlinkName = [NSString stringWithFormat: @"%@ Symlink %ld", name, attempt];
					break;
			}
			NSURL *symlinkURL = [targetURL URLByAppendingPathComponent: symlinkName];
			const char *symlinkPath = [symlinkURL fileSystemRepresentation];
			if (!symlinkPath) {
				return EINVAL;
			}
			if (symlink(linkedPath, symlinkPath)==0) {
				[symlinkURLs addObject: symlinkURL];
				return noErr;
			}
			if (errno!=EEXIST) {
				return errno;
			}
			attempt++;
		} while (attempt<LONG_MAX);
	}
	return EEXIST;
}

static void SLMakeSymlinks(NSArray *fileURLs) {
	NSURL *relativeSymlinkParentURL;
	NSURL *desktopURL;
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSUInteger modifierFlags = ([userDefaults boolForKey: USER_DEFAULT_IGNORE_MODIFIER_FLAGS] ? 0 : [NSEvent modifierFlags]);
	if ((modifierFlags & NSControlKeyMask)==0) {
		relativeSymlinkParentURL = nil;
		desktopURL = [[NSFileManager defaultManager] URLForDirectory: NSDesktopDirectory inDomain: NSUserDomainMask appropriateForURL: nil create: NO error: NULL];
	} else {
		NSString *prompt = (([fileURLs count]==1) ? NSLocalizedString(@"Make Relative Symbolic Link", @"Relative Symbolic Link Prompt (Single File)") : NSLocalizedString(@"Make Relative Symbolic Links", @"Relative Symbolic Link Prompt (Multiple Files)"));
		NSOpenPanel *openPanel = [NSOpenPanel openPanel];
		[openPanel setTitle: prompt];
		[openPanel setPrompt: prompt];
		[openPanel setCanChooseFiles: NO];
		[openPanel setCanChooseDirectories: YES];
		[openPanel setAllowsMultipleSelection: NO];
		[openPanel setCanCreateDirectories: YES];
		if ([openPanel runModal]!=NSFileHandlingPanelOKButton) {
			return;
		}
		relativeSymlinkParentURL = [openPanel URL];
		desktopURL = nil;
	}
	BOOL makeSymlinksInParentFolder = ((!relativeSymlinkParentURL) && ((!desktopURL) || (((modifierFlags & NSAlternateKeyMask)==0) ^ [userDefaults boolForKey: USER_DEFAULT_PREFER_DESKTOP_TARGET])));
	NSMutableArray *fileViewerURLs = (makeSymlinksInParentFolder ? [NSMutableArray array] : nil);
	for (NSURL *fileURL in fileURLs) {
		OSErr result = EINVAL;
		NSString *name = [fileURL lastPathComponent];
		if ([name isEqualToString: @"/"]) {
			name = [[[NSFileManager defaultManager] componentsToDisplayForPath: [fileURL path]] firstObject];
		}
		if ([name length]>0) {
			if (relativeSymlinkParentURL) {
				const char *relativeLinkedPath = [SLRelativeFileURLPath(relativeSymlinkParentURL, fileURL) fileSystemRepresentation];
				if (relativeLinkedPath) {
					result = SLMakeSymlink(relativeLinkedPath, relativeSymlinkParentURL, name, NO, fileViewerURLs);
				}
			} else {
				const char *absoluteLinkedPath = [fileURL fileSystemRepresentation];
				if (absoluteLinkedPath) {
					NSURL *parentURL = [fileURL URLByDeletingLastPathComponent];
					if (makeSymlinksInParentFolder && (parentURL)) {
						result = SLMakeSymlink(absoluteLinkedPath, parentURL, name, YES, fileViewerURLs);
					}
					if ((result!=noErr) && (desktopURL)) {
						result = SLMakeSymlink(absoluteLinkedPath, desktopURL, name, [parentURL isEqual: desktopURL], fileViewerURLs);
					}
				}
			}
		}
		if (result!=noErr) {
			NSAlert *alert = [[NSAlert alloc] init];
			[alert setMessageText: [NSString stringWithFormat: NSLocalizedString(@"Could not make the symbolic link, because the following error occurred: %d (%s)", @"Error Message"), result, strerror(result)]];
			[alert runModal];
			[alert release];
			break;
		}
	}
	if ([fileViewerURLs count]>0) {
		[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: fileViewerURLs];
	}
}


@interface SymbolicLinker: NSObject <NSApplicationDelegate, NSWindowDelegate>

	@property (nonatomic, retain) NSWindow *preferencesWindow;

@end

@implementation SymbolicLinker

	- (void)makeSymbolicLink: (NSPasteboard*)pasteboard userData: (NSString*)userData error: (NSString**)error {
		NSArray *fileURLs = [pasteboard readObjectsForClasses: @[[NSURL class]] options: @{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];
		if ([fileURLs count]>0) {
			SLMakeSymlinks(fileURLs);
		} else {
			NSMutableArray *fallbackFileURLs = [NSMutableArray array];
			for (NSString *path in [pasteboard propertyListForType: NSFilenamesPboardType]) {
				[fallbackFileURLs addObject: [NSURL fileURLWithPath: path]];
			}
			if ([fallbackFileURLs count]>0) {
				SLMakeSymlinks(fallbackFileURLs);
			} else {
				NSLog(@"cannot read files from pasteboard");
				NSBeep();
			}
		}
		if (![self.preferencesWindow isVisible]) {
			[NSObject cancelPreviousPerformRequestsWithTarget: self];
			[NSApp terminate: nil];
		}
	}

	- (void)showPreferences {
		NSWindow *preferencesWindow = self.preferencesWindow;
		if (!preferencesWindow) {
			NSButton *targetSwitch = [[NSButton alloc] initWithFrame: NSZeroRect];
			[targetSwitch setButtonType: NSSwitchButton];
			[[targetSwitch cell] setControlSize: NSControlSizeRegular];
			[targetSwitch setFont: [NSFont systemFontOfSize: [NSFont systemFontSizeForControlSize: NSControlSizeRegular]]];
			[targetSwitch setState: ([[NSUserDefaults standardUserDefaults] boolForKey: USER_DEFAULT_PREFER_DESKTOP_TARGET] ? NSOnState : NSOffState)];
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
		[[NSUserDefaults standardUserDefaults] setBool: ([sender state]==NSOnState) forKey: USER_DEFAULT_PREFER_DESKTOP_TARGET];
	}

	- (void)applicationDidFinishLaunching: (NSNotification*)notification {
		NSUpdateDynamicServices();
		[NSApp setServicesProvider: self];
		[self performSelector: @selector(showPreferences) withObject: nil afterDelay: 1.0];
	}

	- (void)windowWillClose: (NSNotification*)notification {
		if ([notification object]==self.preferencesWindow) {
			[NSApp terminate: nil];
		}
	}

@end


int main(int argc, const char *argv[]) {
	return NSApplicationMain(argc, argv);
}
