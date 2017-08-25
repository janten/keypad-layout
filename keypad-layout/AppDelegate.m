//
//  AppDelegate.m
//  window-key
//
//  Created by Jan-Gerd Tenberge on 14.03.17.
//  Copyright © 2017 Jan-Gerd Tenberge. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()
@property NSTimer *trustTimer;
@property NSStatusItem *statusItem;
@property NSRect rect;
@property NSRect wildcardRect;
@end

@implementation AppDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self installStatusBarIcon];
	self.wildcardRect = [self rectFromCenterW:false H:false];
	self.trustTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
													   target:self
													 selector:@selector(installHotkeys)
													 userInfo:nil
													  repeats:YES];
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
	static Boolean firstCall;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		firstCall = YES;
	});
	
	NSDictionary *options = @{(__bridge id)kAXTrustedCheckOptionPrompt: @(firstCall)};
	Boolean trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
	firstCall = NO;
	
	if (trusted) {
		CGEventMask interestedEvents = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged);
		CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, interestedEvents, hotkeyCallback, (__bridge void * _Nullable)(self));
		CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
		CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
		[self.trustTimer invalidate];
	}
		
}

CGEventRef hotkeyCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
  const CGEventFlags ignoredFlags = NX_NUMERICPADMASK | NX_NONCOALSESCEDMASK;
  const CGEventFlags neededFlags = NX_CONTROLMASK | 0x00000001;
  CGEventFlags flags = CGEventGetFlags(event) & ~ignoredFlags;
	AppDelegate *self = (__bridge AppDelegate *)refcon;

	if ((type == NX_KEYDOWN) && (flags == neededFlags)) {
		UniChar characters[2];
		UniCharCount actualLength;
		UniCharCount outputLength = 1;
		CGEventKeyboardGetUnicodeString(event, outputLength, &actualLength, characters);
		char chars[2] = {characters[0], 0};
		
		if (strstr("0123456789", chars)) {
			[self handleHotkeyChar:chars[0]];
			return NULL;
		}
		
    }

    self.rect = NSZeroRect;
	return event;
}

- (NSRect)rectForCoordinateX:(CGFloat)x Y:(CGFloat)y {
	NSScreen *primaryScreen = [NSScreen screens][0];
	NSScreen *screen = [NSScreen mainScreen];
	CGFloat statusBarHeight = [[[NSApplication sharedApplication] mainMenu] menuBarHeight];
	CGFloat dockHeight = (screen.frame.size.height - screen.visibleFrame.size.height) - statusBarHeight;
	NSRect rect = screen.frame;
	rect.origin.y = -screen.frame.origin.y + (primaryScreen.frame.size.height - screen.frame.size.height) ;
	rect.origin.y += statusBarHeight;
	rect.size.height -= statusBarHeight + dockHeight;
	rect.size.width = rect.size.width / 3.0;
	rect.size.height = rect.size.height / 3.0;
	rect.origin.x += x * rect.size.width;
	rect.origin.y += y * rect.size.height;
	return rect;
}

// Create a centered rect, if w or h are true, the rect will span the full width or height
// if they are false the default size will be 1 px
- (NSRect)rectFromCenterW:(BOOL)w H:(BOOL)h {
	NSScreen *screen = [NSScreen mainScreen];
	CGFloat statusBarHeight = [[[NSApplication sharedApplication] mainMenu] menuBarHeight];
	CGFloat dockHeight = (screen.frame.size.height - screen.visibleFrame.size.height) - statusBarHeight;
	NSRect rect = [self rectForCoordinateX:1.5 Y:1.5];
	rect.size.width = w ? screen.frame.size.width : 1;
	rect.origin.x -= rect.size.width / 2;
	rect.size.height = h ? (screen.frame.size.height - statusBarHeight - dockHeight) : 1;
	rect.origin.y -= rect.size.height / 2;
	return rect;
}

- (void)handleHotkeyChar:(char)c {
	NSRect rect = NSZeroRect;
	
	switch (c) {
		case '7':
			rect = [self rectForCoordinateX:0 Y:0];
			break;
		case '8':
			rect = [self rectForCoordinateX:1 Y:0];
			break;
		case '9':
			rect = [self rectForCoordinateX:2 Y:0];
			break;
		case '4':
			rect = [self rectForCoordinateX:0 Y:1];
			break;
		case '5':
			rect = [self rectForCoordinateX:1 Y:1];
			break;
		case '6':
			rect = [self rectForCoordinateX:2 Y:1];
			break;
		case '1':
			rect = [self rectForCoordinateX:0 Y:2];
			break;
		case '2':
			rect = [self rectForCoordinateX:1 Y:2];
			break;
		case '3':
			rect = [self rectForCoordinateX:2 Y:2];
			break;
		case '0':
			rect = self.wildcardRect;
		default:
			break;
	}
	
	if (NSEqualRects(self.rect, self.wildcardRect)) {
		// The first button pressed was 0
		switch (c) {
			case '7':
			case '9':
			case '3':
			case '1':
				// if the rectangle is one of the corner rectangles it is enough to perform
				// the union with a small rectangle in the center of the screen
				self.rect = [self rectFromCenterW:false H:false];
				break;
			case '4':
			case '6':
				// top or bottom center rectangles become a full width centered rectangle
				self.rect = [self rectFromCenterW:false H:true];
				break;
			case '8':
			case '2':
				// left or right center rectangles become a full height centered rectangle
				self.rect = [self rectFromCenterW:true H:false];
				break;
			case '5':
				self.rect = [self rectFromCenterW:true H:true];
				break;
			default:
				break;
		}
	}
	
	if (NSEqualRects(NSZeroRect, self.rect)) {
		self.rect = rect;
	} else if (NSEqualRects(self.wildcardRect, rect)) {
		// Zero pressed as second character, just abort the combination
		self.rect = NSZeroRect;
	} else {
		rect = NSUnionRect(self.rect, rect);
		rect = NSInsetRect(rect, 1, 1);
		self.rect = NSZeroRect;
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

	AXValueRef positionValue = AXValueCreate(kAXValueTypeCGPoint, &frame.origin);
	AXUIElementSetAttributeValue(window, kAXPositionAttribute, positionValue);
	CFRelease(positionValue);
	
	AXValueRef sizeValue = AXValueCreate(kAXValueTypeCGSize, &frame.size);
	AXUIElementSetAttributeValue(window, kAXSizeAttribute, sizeValue);
	CFRelease(sizeValue);
	
	CFRelease(window);
	CFRelease(appElem);
}

@end
