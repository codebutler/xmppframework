//
//  XMPPUserPresenceManager.m
//  XMPPStream
//
//  Created by Eric Butler on 8/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPUserPresenceManager.h"

#import "XMPPPresence.h"
#import "XMPPPresenceManager.h"

@implementation XMPPUserPresenceManager

- (id)initWithJID:(NSString *)bareJid presenceManager:(XMPPPresenceManager *)aManager
{
	if (self = [super init]) {
		all = [[NSMutableArray alloc] init];		
		manager = [aManager retain];
		jid = [bareJid retain];
	}
	return self;
}

- (void)dealloc
{
	[all dealloc];
	[manager release];
	[jid release];
	[super dealloc];
}

- (XMPPJID *)jid
{
	return jid;
}

- (XMPPPresence *)find:(NSString *)resource
{
	for (XMPPPresence *p in all) {
		if ([resource isEqualToString:[[p from] resource]])
			return p;
	}
	return nil;
}

- (void)primary:(XMPPPresence *)presence
{
	/*
	if (presence == nil || [presence priority] < 0) {
		[NSException raise:@"Invalid presence" format:@"presence must be non-nil and non-negative"];
		return;
	}
	 */
		
	[manager onPrimarySessionDidChange:jid];
}

- (void)addPresence:(XMPPPresence *)presence 
{
	XMPPJID *from = [presence from];
	NSString *resource = [from resource];
	
	if (![[presence type] isEqualToString:@"available"]) {
		[NSException raise:@"Invalid presence" format:@"presence type must be available, was %@", [presence type]];
		return;
	}
	
	XMPPPresence *p = [self find:resource];
	if (p != nil) 
	{
		[p retain];
		[all removeObject:p];
	}
	
	int x;
	for (x = 0; x < [all count]; x++) {
		XMPPPresence *this = [all objectAtIndex:x];
		int p1 = [p priority];
		int p2 = [this priority];
		if (p1 < p2) {
		//if ([p priority] < [this priority]) {
			[all insertObject:presence atIndex:x];
			return;
		}
	}
	
	[all addObject:presence];
	
	if ([presence priority] >= 0)
		[self primary:presence];
	
	[p release];
}

- (void)removePresence:(XMPPPresence *)presence
{
	XMPPJID *from = [presence from];
	NSString *res = [from resource];
	if ([presence type] == @"unavailable") {
		[NSException raise:@"Invalid presence" format:@"presence must unavailable, was %@", [presence type]];
		return;
	}
	
	XMPPPresence *p = [self find:res];
	if (p == nil)
		return;
	
	XMPPPresence *last = [[all lastObject] retain];
	[all removeObject:p];
	
	if (last == p) {
		// current high-priority
		if (([all lastObject] != nil) && ([[all lastObject] priority] >= 0))
			[self primary:[all lastObject]];
		else
		{
			// last non-negative presence went away
			if ([p priority] >= 0)
				[self primary:nil];
		}			
	}
}

- (NSInteger)count
{
	return [all count];
}

- (XMPPPresence *)presenceForResource:(NSString *)resource
{
	XMPPPresence *n;
	
	if (resource == nil) 
	{
		// get highest non-negative for this bare JID.
		n = [all lastObject];
		
		if ((n != nil) && ([n priority] >= 0)) 
			return n;
	}
	else
	{
		n = [self find:resource];
		if (n != nil)
			return n;
	}
	return nil;
}

- (NSArray *)all
{
	return [all copy];
}
@end
