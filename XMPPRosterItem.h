//
//  XMPPRoster.h
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPElement.h"
#import "XMPPRosterGroup.h"

typedef enum {
	ASK_NONE = -1,
	ASK_SUBSCRIBE,
	ASK_UNSUBSCRIBE
} XMPPAsk;

typedef enum {
	SUBSCRIPTION_UNSPECIFIED = -1,
	SUBSCRIPTION_TO,
	SUBSCRIPTION_FROM,
	SUBSCRIPTION_BOTH,
	SUBSCRIPTION_NONE,
	SUBSCRIPTION_REMOVE
} XMPPSubscription;

@interface XMPPRosterItem : XMPPElement {
	
}

+ (XMPPRosterItem *)rosterItemFromElement:(NSXMLElement *)element;

- (XMPPJID *)jid;
- (void)setJid:(XMPPJID *)jid;

- (NSString *)nickName;

- (XMPPSubscription)subscription;
- (void)setSubscription:(XMPPSubscription)subscription;

- (XMPPAsk)ask;

- (XMPPRosterGroup *)addGroup:(NSString *)name;
- (void)removeGroup:(NSString *)name;
- (NSArray*)groups;
- (BOOL)hasGroup:(NSString *)name;
- (XMPPRosterGroup *)getGroup:(NSString *)name;

@end
