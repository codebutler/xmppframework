//
// BOSHXMPPStream.m
//
// Copyright (C) 2009 Eric Butler
//
// Authors:
//   Eric Butler <eric@extremeboredom.net>

#import "BOSHXMPPStream.h"
#import "BOSHXMPPRequest.h"
#import "XMPPNamespaces.h"
#import "XMPPStreamDelegate.h"

@implementation BOSHXMPPStream

@synthesize requestThread;
@synthesize bindUrl;

- (void)setup {
	sendQueue = [[NSMutableArray alloc] init];
	requests = [[NSMutableArray alloc] init];
}

- (void)dealloc {
	[bindUrl release];
	[sid release];
	[authId release];
	[requests release];
	[sendQueue release];
	[super dealloc];
}

- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName {

	if (state != STATE_DISCONNECTED)
		return;
	
	[serverHostName autorelease];
	serverHostName = [hostName copy];
	
	[xmppHostName autorelease];
	xmppHostName = [vHostName copy];	
	
	[rootElement release];
	rootElement = [[NSXMLElement alloc] initWithName:@"root"];
		
	state = STATE_CONNECTING;
	
	NSString *route = [NSString stringWithFormat:@"xmpp:%@:%d", hostName, portNumber];
	
	NSXMLElement *element = [[NSXMLElement alloc] initWithName:@"body"];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  @"text/xml; charset=utf-8", @"content",
						  @"1",                       @"hold",
						  [[self getRid] retain],     @"rid",
						  xmppHostName,               @"to",
						  route,                      @"route",
						  @"1.6",                     @"ver",
						  @"60",                      @"wait",    
						  @"1",                       @"ack",
						  @"en",                      @"xml:lang",
						  NS_HTTPBIND,                @"xmlns",    
						  @"1.0",                     @"xmpp:version",
						  @"urn:xmpp:xbosh",          @"xmlns:xmpp",
						  nil];	
	[element setAttributesAsDictionary:dict];
	
	NSData *data = [[element XMLString] dataUsingEncoding:NSUTF8StringEncoding];
	
	[self queueData: data];
}

// FIXME: Add attach method (jid, sid, rid)

- (void)request:(BOSHXMPPRequest *)request didReceiveElement:(NSXMLElement *)element
{
	[requests removeObject:request];
	
	// FIXME: Handle this:
	// <body xmlns='http://jabber.org/protocol/httpbind' type='terminate' condition='remote-connection-failed'/>
	
	if ([[element children] count] > 0) {		
		// FIXME: Can we get rid of this crap?
		if(state == STATE_CONNECTING)
		{
			NSXMLElement *firstChild = [[element children] objectAtIndex:0];

			// The first thing we expect to receive is <stream:features>
			if (![[firstChild name] isEqualToString:@"stream:features"]) {
				
				NSString *errMsg = [NSString stringWithFormat:@"Expected <stream:features>, got: %@", [firstChild name]];
				NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
				NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
				
				[self onDidReceiveError:err];

				return;
			}
						
			state = STATE_NEGOTIATING;
			
			sid = [[[element attributeForName:@"sid"] stringValue] copy];
			authId = [[[element attributeForName:@"authid"] stringValue] copy];
			
			[rootElement addAttribute:[NSXMLNode attributeWithName:@"id" stringValue:authId]];
			
			[firstChild detach];
			[rootElement setChildren:[NSArray arrayWithObject:firstChild]];
			
			[super handleStreamFeatures];
			
		} else {
			
			if (state == STATE_OPENING)			
				state = STATE_NEGOTIATING;

			for (NSXMLElement *child in [element children])
				[super handleElement:child];

		}
	} else {
		// Received empty <body/> - This just means there's nothing to receive.
	}
	
	if ([sendQueue count] == 0) {
		if ([requests count] == 0) {
			// Start empty request to poll
			[self writeData:nil withTimeout:TIMEOUT_WRITE tag:TAG_WRITE_START];			
		}
	} else {
		// Send the next queued request
		NSData *data = [[sendQueue lastObject] retain];
		[sendQueue removeLastObject];
		
		[self startRequestWithData:data];
	}
}

- (void)disconnect 
{
	state = STATE_DISCONNECTED;
	
	isSecure = NO;
	isAuthenticated = NO;
	
	[rootElement release];
	rootElement = nil;
	
	[sid release];
	sid = nil;
	
	[authId release];
	authId = nil;
	
	rid = 0;
	
	// FIXME: Whoever started these requests will want to know they weren't sent.
	// Create a didNotSendElementWithTag:(long)tag error:(NSError*)err delegate method
	// and fire them off for everything here.
	[requests removeAllObjects];	
	[sendQueue removeAllObjects];
	
	// Notify delegate
	if([delegate respondsToSelector:@selector(xmppStreamDidClose:)]) {
		[delegate xmppStreamDidClose:self];
	} else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStreamDidClose:%p", self);
	}	
}

- (void)disconnectAfterSending {
	// FIXME: Implement this.
	[self doesNotRecognizeSelector:_cmd];
}

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag 
{
	// FIXME: We should do something with timeout
	
	NSString *bodyOpen = [NSString stringWithFormat:@"<body rid=\"%@\" sid=\"%@\" xmlns=\"%@\">", 
						  [self getRid], sid, NS_HTTPBIND, nil];
	NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSString *bodyClose = @"</body>";
	NSString *fullText = [[NSString alloc] initWithFormat:@"%@%@%@", bodyOpen, body, bodyClose];
	
	// FIXME: Create a BOSHXMPPRequest here sintead of later so we can keep track of the tag.
	
	NSData *fullData = [fullText dataUsingEncoding:NSUTF8StringEncoding];	
	[self queueData:fullData];
	
	[body release];
	[fullText release];
}


- (void)queueData:(NSData *)data {
	if ([requests count] < 2) {
		// Send request		
		[self startRequestWithData:data];
	} else {
		[sendQueue insertObject:data atIndex:0];
		// FIXME: I think the ref count on data is different for different code paths.
		// [data release];
	}
}

- (NSString *)getRid {
	rid++;
	return [[NSString alloc] initWithFormat:@"%d", rid];
}

- (void)sendOpeningNegotiation
{
	NSXMLElement *element = [[NSXMLElement alloc] initWithName:@"body"];
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
						  [self getRid],     @"rid",
						  sid,               @"sid",
						  xmppHostName,      @"to", 
						  @"en",             @"xml:lang",
						  @"true",           @"xmpp:restart",    						  
						  NS_HTTPBIND,       @"xmlns",    						  
						  @"urn:xmpp:xbosh", @"xmlns:xmpp",
						  nil];	
	[element setAttributesAsDictionary:dict];
		
	state = STATE_OPENING;
	
	NSData *data = [[element XMLString] dataUsingEncoding:NSUTF8StringEncoding];
	
	[self queueData:data];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)startRequestWithData:(NSData *)data
{	
	if (requestThread != nil)
		[self performSelector:@selector(startRequestWithDataForReals:) onThread:requestThread withObject:data waitUntilDone:NO];
}

- (void)startRequestWithDataForReals:(id)obj
{
	NSData *data = (NSData *)obj;
	BOSHXMPPRequest *request = [[BOSHXMPPRequest alloc] initWithStream:self bodyData:data];
	[requests addObject:request];
	[request release];
	[request start];
}

- (void)keepAlive:(NSTimer *)aTimer
{
	if(state == STATE_CONNECTED)
	{
		// FIXME: Do something here.
	}
}

- (void)onDidReceiveError:(NSError *)err
{
	if([delegate respondsToSelector:@selector(xmppStream:didReceiveError:)]) {
		[delegate xmppStream:self didReceiveError:err];
	}
	else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStream:%p didReceiveError:%@", self, err);
	}
	
	[self disconnect];	
}

@end