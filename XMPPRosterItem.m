//
//  XMPPRoster.m
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPRosterItem.h"
#import "XMPPRosterGroup.h"

#import "XMPPJID.h"

@implementation XMPPRosterItem

+ (XMPPRosterItem *)rosterItemFromElement:(NSXMLElement *)element
{
	XMPPRosterItem *result = (XMPPRosterItem *)element;
	result->isa = [XMPPRosterItem class];
	return result;
}

- (XMPPJID *)jid 
{
	return [XMPPJID jidWithString: [[self attributeForName:@"jid"] stringValue]];
}

- (void)setJid:(XMPPJID *)jid
{
	NSXMLNode *attr = [self attributeForName:@"jid"];
	if (!attr) {
		attr = [NSXMLNode attributeWithName:@"jid" stringValue:[jid bare]];
		[self addChild:attr];
	} else {
		[attr setStringValue:[jid bare]];
	}
}

- (NSString *)nickName 
{
	return [[self attributeForName:@"name"] stringValue];
}

- (XMPPSubscription)subscription
{
	NSString *subscriptionStr = [[self attributeForName:@"subscription"] stringValue];
	if ([subscriptionStr isEqualToString:@"both"])
		return SUBSCRIPTION_BOTH;
	else if([subscriptionStr isEqualToString:@"from"])
		return SUBSCRIPTION_FROM;
	else if ([subscriptionStr isEqualToString:@"none"])
		return SUBSCRIPTION_NONE;
	else if ([subscriptionStr isEqualToString:@"remove"])
		return SUBSCRIPTION_REMOVE;
	else if ([subscriptionStr isEqualToString:@"to"])
		return SUBSCRIPTION_TO;
	else
		return SUBSCRIPTION_UNSPECIFIED;
}

- (void)setSubscription:(XMPPSubscription)subscription
{
	NSString *str = @"";
	switch (subscription) {
		case SUBSCRIPTION_BOTH:
			str = @"both";
			break;
		case SUBSCRIPTION_FROM:
			str = @"from";
			break;
		case SUBSCRIPTION_NONE:
			str = @"none";
			break;
		case SUBSCRIPTION_REMOVE:
			str = @"remove";
		case SUBSCRIPTION_TO:
			str = @"to";
	}
	
	NSXMLNode *attr = [self attributeForName:@"subscription"];
	if (!attr) {
		attr = [NSXMLNode attributeWithName:@"subscription" stringValue:str];
		[self addChild:attr];
	} else
		[attr setStringValue:str];
}

- (XMPPAsk)ask
{
	NSString *askStr = [[self attributeForName:@"ask"] stringValue];
	if ([askStr isEqualToString:@"subscribe"])
		return ASK_SUBSCRIBE;
	else if ([askStr isEqualToString:@"unsubscribe"])
		return ASK_UNSUBSCRIBE;
	else
		return ASK_NONE;
}

- (XMPPRosterGroup *)addGroup:(NSString *)name
{
	XMPPRosterGroup *group = [self getGroup:name];
	if (group == nil) {
		group = [[XMPPRosterGroup alloc] initWithGroupName:name];
		[self addChild:group];
		[group release];
	}
	return group;
}

- (void)removeGroup:(NSString *)name
{
	XMPPRosterGroup *group = [self getGroup:name];
	[self removeChild:group];
}

- (NSArray *)groups
{
	return [self children];
}

- (BOOL)hasGroup:(NSString *)name
{
	return [self getGroup:name] != nil;
}
	
- (XMPPRosterGroup *)getGroup:(NSString *)name
{
	for (NSXMLElement *child in [self children]) {
		XMPPRosterGroup *group = [XMPPRosterGroup rosterGroupForElement:child];
		if ([[group groupName] isEqualToString:name])
			return group;
	}
	return nil;
}

@end
