//
//  XMPPRosterGroup.m
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "XMPPRosterGroup.h"


@implementation XMPPRosterGroup

+ (XMPPRosterGroup *)rosterGroupForElement:(NSXMLElement *)element
{
	XMPPRosterGroup *result = (XMPPRosterGroup *)element;
	result->isa = [XMPPRosterGroup class];
	return result;
}

- (id)initWithGroupName:(NSString *)groupName
{
	if(self = [super initWithName:@"group"])
	{
		[self setStringValue:groupName];
	}
	return self;
}


- (NSString *)groupName 
{
	return [self stringValue];
}

@end
