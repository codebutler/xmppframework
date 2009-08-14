//
//  XMPPRosterManager.h
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPClient.h"
#import "XMPPRosterItem.h"

@interface XMPPRosterManager : NSObject<NSFastEnumeration> {
	XMPPClient *client;
	NSMutableDictionary *items;
	NSLock *lock;
	id delegate;
}

@property (retain) id delegate;

- (id)initWithXMPPClient:(XMPPClient *)client;

- (XMPPRosterItem *)getItem:(XMPPJID *)jid;
- (NSInteger)count;

- (void)remove:(XMPPJID *)jid;
- (void)modify:(XMPPRosterItem *)item;
//- (void)setNickname:(NSString *)nickname forBuddy:(XMPPJID *)jid;

- (XMPPClient *)client;
@end

@interface NSObject (XMPPRosterManagerDelegate)
- (void)xmppRosterManagerDidReceiveRosterStart:(XMPPRosterManager *)manager;
- (void)xmppRosterManager:(XMPPRosterManager *)manager didChangeRosterItem:(XMPPRosterItem *)item;
- (void)xmppRosterManagerDidReceiveRosterEnd:(XMPPRosterManager *)manager;
- (void)xmppRosterManager:(XMPPRosterManager *)manager receivedSubscription:(XMPPRosterItem *)item presence:(XMPPPresence *)presence;
- (void)xmppRosterManager:(XMPPRosterManager *)manager receivedUnsubscription:(XMPPRosterItem *)item presence:(XMPPPresence *)presence;
@end