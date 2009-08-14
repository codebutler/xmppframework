//
//  XMPPRoster.m
//  XMPPStream
//
//  Created by Eric Butler on 8/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPRoster.h"


@implementation XMPPRoster

+ (XMPPRoster *)rosterFromElement:(NSXMLElement *)element
{
	XMPPRoster *result = (XMPPRoster *)element;
	result->isa = [XMPPRoster class];
	return result;	
}

- (NSArray *)items
{
	return [self children];
}

- (void)addItem:(XMPPRosterItem *)item
{
	[self addChild:item];
}

@end
