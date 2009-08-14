#import "XMPPIQ.h"
#import "DDXMLElementAdditions.h"


@implementation XMPPIQ

+ (XMPPIQ *)iq
{
	XMPPIQ *iq = [[XMPPIQ alloc] init];
	return [iq autorelease];
}

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element
{
	XMPPIQ *result = (XMPPIQ *)element;
	result->isa = [XMPPIQ class];
	return result;
}

- (XMPPIQType)type
{
	NSString *typeStr = [[self attributeForName:@"type"] stringValue];
	if ([typeStr isEqualToString:@"get"])
		return IQTYPE_GET;
	else if ([typeStr isEqualToString:@"set"])
		return IQTYPE_SET;
	else if ([typeStr isEqualToString:@"result"])
		return IQTYPE_RESULT;
	else if ([typeStr isEqualToString:@"error"])
		return IQTYPE_ERROR;
	else
		return -1;
}

- (void)setType:(XMPPIQType)type
{
	NSString *typeStr = @"";
	switch (type) {
		case IQTYPE_GET:
			typeStr = @"get";
			break;
		case IQTYPE_SET:
			typeStr = @"set";
			break;
		case IQTYPE_RESULT:
			typeStr = @"result";
			break;
		case IQTYPE_ERROR:
			typeStr = @"error";
	}
	
	NSXMLNode *attr = [self attributeForName:@"type"];
	if (!attr) {
		[self addAttributeWithName:@"type" stringValue:typeStr];
	} else
		[attr setStringValue:typeStr];
}

/**
 * For some bizarre reason (in my opinion), when you request your roster,
 * the server will return JID's NOT in your roster. These are the JID's of users who have requested
 * to be alerted to our presence.  After we sign in, we'll again be notified, via the normal presence request objects.
 * It's redundant, and annoying, and just plain incorrect to include these JID's when we request our personal roster.
 * So now, we have to go to the extra effort to filter out these JID's, which is exactly what this method does.
**/
+ (BOOL)isRosterItem:(NSXMLElement *)item
{
	NSXMLNode *subscription = [item attributeForName:@"subscription"];
	if([[subscription stringValue] isEqualToString:@"none"])
	{
		NSXMLNode *ask = [item attributeForName:@"ask"];
		if([[ask stringValue] isEqualToString:@"subscribe"])
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	return YES;
}

/**
 * Returns whether or not the IQ element is in the "jabber:iq:roster" namespace,
 * and thus represents a roster update.
**/
- (BOOL)isRosterQuery
{
	// Note: Some jabber servers send an iq element with a xmlns.
	// Because of the bug in Apple's NSXML (documented in our elementForName method),
	// it is important we specify the xmlns for the query.
	
	NSXMLElement *query = [self elementForName:@"query" xmlns:@"jabber:iq:roster"];
	
	return (query != nil);
}

- (NSXMLElement *)query
{
	return [self elementForName:@"query"];
}

- (void)setQuery:(NSXMLElement *)query
{
	[self setStringValue:@""];
	[self addChild:query];
}

@end
