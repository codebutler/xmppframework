//
//  XMPPPresenceManager.h
//  XMPPStream
//
//  Created by Eric Butler on 8/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPClient.h"

@interface XMPPPresenceManager : NSObject {
	NSMutableDictionary *items;
	XMPPClient *client;
	NSLock *lock;
}

- (id)initWithXMPPClient:(XMPPClient *)aClient;

- (BOOL)isAvailable:(XMPPJID *)jid;
- (NSArray *)allPresences:(XMPPJID *)jid;

// FIXME: Should not be in public API
- (void)onPrimarySessionDidChange:(XMPPJID *)jid;

@end
