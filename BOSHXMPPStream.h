//
//  BOSHXMPPStream.h
//  XMPPStream
//
//  Created by Eric Butler on 7/27/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AbstractXMPPStream.h"
#import "BOSHXMPPRequest.h"

@class BOSHXMPPRequest;

@interface BOSHXMPPStream : AbstractXMPPStream {
	NSString *bindUrl;
	NSString *sid;
	NSString *authId;
	uint rid;
	NSMutableArray *requests;
	NSMutableArray *sendQueue;
}

@property (copy) NSString* bindUrl;

- (void)setup;

- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;

- (void)disconnect;
- (void)disconnectAfterSending;

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;

- (NSString *)getRid;

- (void)request:(BOSHXMPPRequest *)request didReceiveElement:(NSXMLElement *)element;

- (void)queueData:(NSData *)data;

@end
