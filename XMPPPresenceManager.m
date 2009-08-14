//
//  XMPPPresenceManager.m
//  XMPPStream
//
//  Created by Eric Butler on 8/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPPresenceManager.h"

#import "XMPPJID.h"
#import "XMPPClient.h"
#import "XMPPPresence.h"
#import "XMPPUserPresenceManager.h"

@implementation XMPPPresenceManager

- (id)initWithXMPPClient:(XMPPClient *)aClient
{
	if (self = [super init]) {
		client = [aClient retain];
		[client addDelegate:self];
		
		items = [[NSMutableDictionary alloc] init];
		lock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[client release];
	[items dealloc];
	[lock dealloc];
	[super dealloc];
}

- (void)xmppClient:(XMPPClient *)sender didReceivePresence:(XMPPPresence *)presence
{
	if (![[presence type] isEqualToString:@"available"] &&
		![[presence type] isEqualToString:@"unavailable"])
		return;
	
	XMPPJID *f = [presence from];
	
	[lock lock];
	
	XMPPUserPresenceManager *upm = [items objectForKey:[f bare]];
	
	if ([[presence type] isEqualToString:@"available"])
	{
		if (upm == nil)
		{
			upm = [[XMPPUserPresenceManager alloc] initWithJID:[f bare] presenceManager:self];
			[items setObject:upm forKey:[f bare]];
		}
		[upm addPresence:presence];
	}
	else
	{
		if (upm != nil)
		{
			[upm removePresence:presence];
			if ([upm count] == 0)
			{
				[items removeObjectForKey:[f bare]];
			}
		}
	}
	
	[lock unlock];
}

- (void)xmppClientDidDisconnect:(XMPPClient *)sender
{
	[items removeAllObjects];
}

- (BOOL)isAvailable:(XMPPJID *)jid
{
	[lock lock];
	BOOL a = ([items objectForKey:[jid bare]] != nil);
	[lock unlock];
	return a;
}

- (XMPPPresence *)primaryPresenceForJid:(XMPPJID *)jid
{
	[lock lock];
	
	XMPPPresence *p = nil;
	
	XMPPUserPresenceManager *upm = [items objectForKey:[jid bare]];
	if (upm != nil)
		p = [upm presenceForResource:[jid resource]];
	
	[lock unlock];

	return p;
}

- (NSArray *)allPresences:(XMPPJID *)jid
{
	XMPPUserPresenceManager *upm = [items objectForKey:[jid bare]];
	if (upm == nil)
		return [NSArray array];
	return [upm all];
}

- (void)onPrimarySessionDidChange:(XMPPJID *)jid
{
	// FIXME: fire delegate method
}

@end
