//
//  XMPPRosterManager.m
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPRosterManager.h"
#import "XMPPPresence.h"
#import "XMPPIQ.h"
#import "XMPPRoster.h"

@implementation XMPPRosterManager

@synthesize delegate;

- (id)initWithXMPPClient:(XMPPClient *)aClient
{
	if (self = [super init]) {
		lock = [[NSLock alloc] init];
		client = [aClient retain];
		[aClient addDelegate:self];
		items = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[items release];
	[client release];
	[super dealloc];
}

- (void)xmppClientDidDisconnect:(XMPPClient *)client
{
	[lock lock];
	[items removeAllObjects];
	[lock unlock];
}

- (void)xmppClient:(XMPPClient *)sender didReceivePresence:(XMPPPresence *)presence
{
	if ([[presence type] isEqualToString:@"avaliable"] ||
		[[presence type] isEqualToString:@"unavaliable"] ||
		[[presence type] isEqualToString:@"error"] ||
		[[presence type] isEqualToString:@"probe"])
	{
		return;
	} 
	else if ([[presence type] isEqualToString:@"subscribe"]) 
	{
		// FIXME: Call onSubscription delegate method!
	} 
	else if ([[presence type] isEqualToString:@"subscribed"])
	{
		XMPPPresence *ack = [[XMPPPresence alloc] initWithType:@"subscribe" to:[presence from]];
		[client sendElement:ack];		
	}
	else if ([[presence type] isEqualToString:@"unsubscribe"])
	{
		XMPPPresence *ack = [[XMPPPresence alloc] initWithType:@"unsubscribed" to:[presence from]];
		[client sendElement:ack];
	}
	else if ([[presence type] isEqualToString:@"unsubscribed"])
	{
		// FIXME: Call onUnsubscribed delegate method!
	}
}

- (void)xmppClient:(XMPPClient *)sender didReceiveIQ:(XMPPIQ *)iq
{
	if ([iq query] == nil ||
		![[[iq query] URI] isEqualToString:@"jabber:iq:roster"] ||
		([iq type] != IQTYPE_RESULT) && ([iq type] != IQTYPE_SET))
		return;
	
	XMPPRoster *roster = [XMPPRoster rosterFromElement:[iq query]];
	
	if ([iq type] == IQTYPE_RESULT) {
		if (delegate && [delegate respondsToSelector:@selector(xmppRosterManagerDidReceiveRosterStart:)]) 
			[delegate xmppRosterManagerDidReceiveRosterStart:self];
	}
	
	for (DDXMLElement *child in [roster items]) 
	{
		XMPPRosterItem *item = [XMPPRosterItem rosterItemFromElement:child];
		
		[lock lock];
		
		if ([item subscription] == SUBSCRIPTION_REMOVE) 
		{
			[items removeObjectForKey:[item jid]];
		}
		else
		{
			if ([items objectForKey:[item jid]] != nil)
				[items removeObjectForKey:[item jid]];
			
			[items setObject:item forKey:[item jid]];
		}
		
		if (delegate && [delegate respondsToSelector:@selector(xmppRosterManager:didChangeRosterItem:)])
			[delegate xmppRosterManager:self didChangeRosterItem:item];
		
		[lock unlock];		
	}	
	if ([iq type] == IQTYPE_RESULT) {
		if (delegate && [delegate respondsToSelector:@selector(xmppRosterManagerDidReceiveRosterEnd:)])
			[delegate xmppRosterManagerDidReceiveRosterEnd:self];
	}
}

- (NSInteger)count
{
	return [items count];
}

- (XMPPRosterItem *)getItem:(XMPPJID*)jid
{
	return [items objectForKey:jid];	
}

- (void)remove:(XMPPJID *)jid
{
	XMPPIQ *iq = [[XMPPIQ alloc] init];
	[iq setType:IQTYPE_SET];
	
	XMPPRoster *roster = [[XMPPRoster alloc] init];
	[iq setQuery:roster];
	
	XMPPRosterItem *item = [[XMPPRosterItem alloc] init];
	[roster addItem:item];
	[item setJid:jid];
	[item setSubscription:SUBSCRIPTION_REMOVE];
	
	[client sendElement:iq];
}

- (void)modify:(XMPPRosterItem *)item
{
	/*
	 RosterIQ iq = new RosterIQ(m_stream.Document);
	 iq.Type = IQType.set;
	 Roster r = iq.Instruction;
	 if (item.OwnerDocument != m_stream.Document)
	 r.AppendChild(item.CloneNode(true, m_stream.Document));
	 else
	 r.AppendChild(item);
	 Write(iq);  // ignore response
	 */
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
	return [[items objectEnumerator] countByEnumeratingWithState:state objects:stackbuf count:len];
}

- (XMPPClient *)client
{
	return client;
}
@end
