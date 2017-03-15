//
//  AppDelegate.m
//  window-key
//
//  Created by Jan-Gerd Tenberge on 14.03.17.
//  Copyright © 2017 Jan-Gerd Tenberge. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property NSStatusItem *statusItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
	Boolean trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);

	if (trusted) {
		[self installHotkeys];
	}

	[self installStatusBarIcon];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	// Insert code here to tear down your application
}

- (void)installStatusBarIcon {
	NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
	self.statusItem = [statusBar statusItemWithLength:NSSquareStatusItemLength];
	NSImage *image = [NSImage imageNamed:@"StatusBarImage"];
	image.size = NSMakeSize(30, 30);
	self.statusItem.image = image;
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Window Layouts"];
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Quit Keypad Layout" action:@selector(terminate:) keyEquivalent:@"q"];
	item.target = [NSApplication sharedApplication];
	[menu addItem:item];
	self.statusItem.menu = menu;
	self.statusItem.enabled = YES;
	self.statusItem.highlightMode = YES;
}

- (void)installHotkeys {
	CGEventMask interestedEvents = CGEventMaskBit(kCGEventKeyDown);
	CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, interestedEvents, hotkeyCallback, (__bridge void * _Nullable)(self));
	CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
}

CGEventRef hotkeyCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
	CGEventFlags flags = CGEventGetFlags(event);
	
	if (!(flags & kCGEventFlagMaskControl)) {
		return event;
	}
	
	if (type == NX_KEYDOWN) {
		// we convert our event into plain unicode
		UniChar characters[2];
		UniCharCount actualLength;
		UniCharCount outputLength = 1;
		CGEventKeyboardGetUnicodeString(event, outputLength, &actualLength, characters);
		char chars[2] = {characters[0], 0};
		
		if (strstr("123456789", chars)) {
			[(__bridge id)refcon handleHotkeyChar:chars[0]];
			return NULL;
		}
		
	}
	
	// send event to next application
	return event;
}

- (void)handleHotkeyChar:(char)c {
	NSScreen *screen = [NSScreen mainScreen];
	NSRect workingRect = screen.frame;
	workingRect.size = screen.visibleFrame.size;
	workingRect.origin.y = screen.frame.origin.y + (screen.frame.size.height - screen.visibleFrame.size.height);
	CGFloat w = floor(workingRect.size.width/3.0);
	CGFloat h = floor(workingRect.size.height/3.0);
	CGFloat x = floor(workingRect.origin.x);
	CGFloat y = floor(workingRect.origin.y);
	NSRect rect = NSZeroRect;
	
	switch (c) {
		case '7':
			rect = NSMakeRect(x + 0 * 2, y + 0 * h, w, h);
			break;
		case '8':
			rect = NSMakeRect(x + 1 * w, y + 0 * h, w, h);
			break;
		case '9':
			rect = NSMakeRect(x + 2 * w, y + 0 * h, w, h);
			break;
		case '4':
			rect = NSMakeRect(x + 0 * 2, y + 1 * h, w, h);
			break;
		case '5':
			rect = NSMakeRect(x + 1 * w, y + 1 * h, w, h);
			break;
		case '6':
			rect = NSMakeRect(x + 2 * w, y + 1 * h, w, h);
			break;
		case '1':
			rect = NSMakeRect(x + 0 * 2, y + 2 * h, w, h);
			break;
		case '2':
			rect = NSMakeRect(x + 1 * w, y + 2 * h, w, h);
			break;
		case '3':
			rect = NSMakeRect(x + 2 * w, y + 2 * h, w, h);
			break;
		default:
			break;
	}
	
	static NSRect firstRect;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		firstRect = NSZeroRect;
	});

	if (NSEqualRects(NSZeroRect, firstRect)) {
		firstRect = rect;
	} else {
		rect = NSUnionRect(firstRect, rect);
		firstRect = NSZeroRect;
		[self setFrontmostWindowFrame:rect];
	}

}

- (void)setFrontmostWindowFrame:(CGRect)frame {
	NSRunningApplication* app = [[NSWorkspace sharedWorkspace] frontmostApplication];
	pid_t pid = [app processIdentifier];
	AXUIElementRef appElem = AXUIElementCreateApplication(pid);
	AXUIElementRef window = NULL;
	
	if (AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute, (CFTypeRef*)&window) != kAXErrorSuccess) {
		CFRelease(appElem);
		return;
	}
	
	AXValueRef sizeValue = AXValueCreate(kAXValueTypeCGSize, &frame.size);
	AXUIElementSetAttributeValue(window, kAXSizeAttribute, sizeValue);
	CFRelease(sizeValue);
	
	AXValueRef positionValue = AXValueCreate(kAXValueTypeCGPoint, &frame.origin);
	AXUIElementSetAttributeValue(window, kAXPositionAttribute, positionValue);
	CFRelease(positionValue);
	
	CFRelease(window);
	CFRelease(appElem);
}

@end
