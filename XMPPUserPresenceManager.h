//
//  XMPPUserPresenceManager.h
//  XMPPStream
//
//  Created by Eric Butler on 8/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPJID.h"
#import "XMPPPresence.h"
#import "XMPPPresenceManager.h"

@interface XMPPUserPresenceManager : NSObject {
	XMPPPresenceManager *manager;
	NSMutableArray *all;
	XMPPJID *jid;
}

- (id)initWithJID:(NSString *)bareJid presenceManager:(XMPPPresenceManager *)manager;

- (NSInteger)count;

- (XMPPJID *)jid;

- (void)addPresence:(XMPPPresence *)presence;
- (void)removePresence:(XMPPPresence *)presence;

- (XMPPPresence *)presenceForResource:(NSString *)resource;

- (NSArray *)all;

@end
