#import <Foundation/Foundation.h>
#import "DDXML.h"

#import "AbstractXMPPStream.h"

@class AsyncSocket;
@class XMPPIQ;
@class XMPPMessage;
@class XMPPPresence;


@interface TCPXMPPStream : AbstractXMPPStream
{
	AsyncSocket *asyncSocket;
	
	NSMutableData *buffer;
	
	NSData *terminator;
}

- (void)setup;

- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;

- (void)disconnect;
- (void)disconnectAfterSending;

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
@end