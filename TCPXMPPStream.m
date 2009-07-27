#import "AbstractXMPPStream.h"
#import "TCPXMPPStream.h"
#import "AsyncSocket.h"
#import "XMPPStreamDelegate.h"
#import "NSXMLElementAdditions.h"
#import "NSDataAdditions.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "XMPPDigestAuthentication.h"

#if TARGET_OS_IPHONE
// Note: You may need to add the CFNetwork Framework to your project
#import <CFNetwork/CFNetwork.h>
#endif

@implementation TCPXMPPStream

/**
 * Initializes an XMPPStream with the given delegate.
 * After creating an object, you'll need to connect to a host using one of the connect...::: methods.
**/
- (void)setup
{
		// Initialize socket
		asyncSocket = [[AsyncSocket alloc] initWithDelegate:self];
		
		// Enable pre-buffering on the socket to improve readDataToData performance
		[asyncSocket enablePreBuffering];
		
		// We initialize an empty buffer of data to store data as it arrives
		buffer = [[NSMutableData alloc] initWithCapacity:100];
		
		// Initialize the standard terminator to listen for
		// We try to parse the data everytime we encouter an XML ending tag character
		terminator = [[@">" dataUsingEncoding:NSUTF8StringEncoding] retain];
}

/**
 * The standard deallocation method.
 * Every object variable declared in the header file should be released here.
**/
- (void)dealloc
{
	[asyncSocket setDelegate:nil];
	[asyncSocket disconnect];
	[asyncSocket release];
	[buffer release];
	[terminator release];
	[super dealloc];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connectToHost:(NSString *)hostName
               onPort:(UInt16)portNumber
      withVirtualHost:(NSString *)vHostName
               secure:(BOOL)secure
{    
	if(state == STATE_DISCONNECTED)
	{
		// Store configuration information
		isSecure = secure;
		isAuthenticated = NO;
		
		[serverHostName autorelease];
		serverHostName = [hostName copy];
		[xmppHostName autorelease];
		xmppHostName = [vHostName copy];
		
		// Update state
		// Note that we do this before connecting to the host,
		// because the delegate methods will be called before the method returns
		state = STATE_CONNECTING;
		
		// If the given port number is zero, use the default port number for XMPP communication
		UInt16 myPortNumber = (portNumber > 0) ? portNumber : (secure ? 5223 : 5222);
		
		// Connect to the host
		[asyncSocket connectToHost:hostName onPort:myPortNumber error:nil];
	}
}

- (void)connectToHost:(NSString *)hostName
			   onPort:(UInt16)portNumber
	  withVirtualHost:(NSString *)vHostName
{
	[self connectToHost:hostName onPort:portNumber withVirtualHost:vHostName secure:NO];
}

- (void)disconnect
{
	[asyncSocket disconnect];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

- (void)disconnectAfterSending
{
	[asyncSocket disconnectAfterWriting];
	
	// Note: The state is updated automatically in the onSocketDidDisconnect: method.
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method handles sending the opening <stream:stream ...> element which is needed in several situations.
**/
- (void)sendOpeningNegotiation
{
	if(state == STATE_CONNECTING)
	{
		// TCP connection was just opened - We need to include the opening XML stanza
		NSString *s1 = @"<?xml version='1.0'?>";
		
		if(DEBUG_SEND) {
			NSLog(@"SEND: %@", s1);
		}
		[asyncSocket writeData:[s1 dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_START];
	}
	
	NSString *xmlns = @"jabber:client";
	NSString *xmlns_stream = @"http://etherx.jabber.org/streams";
	
	NSString *temp, *s2;
	if([xmppHostName length] > 0)
	{
		temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0' to='%@'>";
		s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream, xmppHostName];
	}
	else
	{
		temp = @"<stream:stream xmlns='%@' xmlns:stream='%@' version='1.0'>";
		s2 = [NSString stringWithFormat:temp, xmlns, xmlns_stream];
	}
	
	if(DEBUG_SEND) {
		NSLog(@"SEND: %@", s2);
	}
	[asyncSocket writeData:[s2 dataUsingEncoding:NSUTF8StringEncoding]
			   withTimeout:TIMEOUT_WRITE
					   tag:TAG_WRITE_START];
	
	// Update status
	state = STATE_OPENING;
}

/**
 * This method is called anytime we receive the server's stream features.
 * This method looks at the stream features, and handles any requirements so communication can continue.
**/
- (void)handleStreamFeatures
{
	// Extract the stream features
	NSXMLElement *features = [rootElement elementForName:@"stream:features"];
	
	// Check to see if TLS is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_starttls = [features elementForName:@"starttls" xmlns:@"urn:ietf:params:xml:ns:xmpp-tls"];
	
	if(f_starttls)
	{
		if([f_starttls elementForName:@"required"])
		{
			// TLS is required for this connection
			state = STATE_STARTTLS;
			
			NSString *starttls = @"<starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>";
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", starttls);
			}
			[asyncSocket writeData:[starttls dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// We're already listening for the response...
			return;
		}
	}
	
	// Check to see if resource binding is required
	// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
	NSXMLElement *f_bind = [features elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	
	if(f_bind)
	{
		// Binding is required for this connection
		state = STATE_BINDING;
		
		if([authResource length] > 0)
		{
			// Ask the server to bind the user specified resource
			
			NSXMLElement *resource = [NSXMLElement elementWithName:@"resource"];
			[resource setStringValue:authResource];
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			[bind addChild:resource];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", iq);
			}
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
		}
		else
		{
			// The user didn't specify a resource, so we ask the server to bind one for us
			
			NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:bind];
						
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", iq);
			}
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
		}
		
		// We're already listening for the response...
		return;
	}
	
	// It looks like all has gone well, and the connection should be ready to use now
	state = STATE_CONNECTED;
	
	if(!isAuthenticated)
	{
		// Setup keep alive timer
		[keepAliveTimer invalidate];
		[keepAliveTimer release];
		keepAliveTimer = [[NSTimer scheduledTimerWithTimeInterval:300
														   target:self
														 selector:@selector(keepAlive:)
														 userInfo:nil
														  repeats:YES] retain];
		
		// Notify delegate
		if([delegate respondsToSelector:@selector(xmppStreamDidOpen:)]) {
			[delegate xmppStreamDidOpen:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidOpen:%p", self);
		}
	}
}

- (void)handleStartTLSResponse:(NSXMLElement *)response
{
	// We're expecting a proceed response
	// If we get anything else we can safely assume it's the equivalent of a failure response
	if(![[response name] isEqualToString:@"proceed"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The onSocketDidDisconnect: method will handle everything else
		return;
	}
	
	// Connecting to a secure server
	NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
	
	// Use the highest possible security
	[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
				 forKey:(NSString *)kCFStreamSSLLevel];
	
	// Set the peer name
	if([xmppHostName length] > 0)
		[settings setObject:xmppHostName forKey:(NSString *)kCFStreamSSLPeerName];
	else
		[settings setObject:serverHostName forKey:(NSString *)kCFStreamSSLPeerName];
	
	// Allow self-signed certificates if needed
	if(allowsSelfSignedCertificates)
	{
		[settings setObject:[NSNumber numberWithBool:YES]
					 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
	}
	
	CFReadStreamSetProperty([asyncSocket getCFReadStream],
							kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
	CFWriteStreamSetProperty([asyncSocket getCFWriteStream],
							 kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
	
	// Make a note of the switch to TLS
	isSecure = YES;
	
	// Now we start our negotiation over again...
	[self sendOpeningNegotiation];
}

/**
 * After the registerUser:withPassword: method is invoked, a registration message is sent to the server.
 * We're waiting for the result from this registration request.
**/
- (void)handleRegistration:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotRegister:)]) {
			[delegate xmppStream:self didNotRegister:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotRegister:%@", self, [response XMLString]);
		}
	}
	else
	{
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStreamDidRegister:)]) {
			[delegate xmppStreamDidRegister:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidRegister:%p", self);
		}
	}
}

/**
 * After the authenticateUser:withPassword:resource method is invoked, a authentication message is sent to the server.
 * If the server supports digest-md5 sasl authentication, it is used.  Otherwise plain sasl authentication is used,
 * assuming the server supports it.
 * 
 * Now if digest-md5 was used, we sent a challenge request, and we're waiting for a challenge response.
 * If plain sasl was used, we sent our authentication information, and we're waiting for a success response.
**/
- (void)handleAuth1:(NSXMLElement *)response
{
	if([self supportsDigestMD5Authentication])
	{
		// We're expecting a challenge response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"challenge"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// Create authentication object from the given challenge
			// We'll release this object at the end of this else block
			XMPPDigestAuthentication *auth = [[XMPPDigestAuthentication alloc] initWithChallenge:response];
			
			// Sometimes the realm isn't specified
			// In this case I believe the realm is implied as the virtual host name
			if(![auth realm])
			{
				if([xmppHostName length] > 0)
					[auth setRealm:xmppHostName];
				else
					[auth setRealm:serverHostName];
			}
			
			// Set digest-uri
			if([xmppHostName length] > 0)
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", xmppHostName]];
			else
				[auth setDigestURI:[NSString stringWithFormat:@"xmpp/%@", serverHostName]];
			
			// Set username and password
			[auth setUsername:authUsername password:tempPassword];
			
			// Create and send challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[cr setStringValue:[auth base64EncodedFullResponse]];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", [cr XMLString]);
			}
			[asyncSocket writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Release unneeded resources
			[auth release];
			[tempPassword release]; tempPassword = nil;
			
			// Update state
			state = STATE_AUTH_2;
		}
	}
	else if([self supportsPlainAuthentication])
	{
		// We're expecting a success response
		// If we get anything else we can safely assume it's the equivalent of a failure response
		if(![[response name] isEqualToString:@"success"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We are successfully authenticated (via sasl:plain)
			isAuthenticated = YES;
			
			// Now we start our negotiation over again...
			[self sendOpeningNegotiation];
		}
	}
	else
	{
		// We used the old fashioned jabber:iq:auth mechanism
		
		if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"error"])
		{
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We are successfully authenticated (via non-sasl:digest)
			// And we've binded our resource as well
			isAuthenticated = YES;
			
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
				[delegate xmppStreamDidAuthenticate:self];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStreamDidAuthenticate:%p", self);
			}
		}
	}
}

/**
 * This method handles the result of our challenge response we sent in handleAuth1 using digest-md5 sasl.
**/
- (void)handleAuth2:(NSXMLElement *)response
{
	if([[response name] isEqualToString:@"challenge"])
	{
		XMPPDigestAuthentication *auth = [[[XMPPDigestAuthentication alloc] initWithChallenge:response] autorelease];
		
		if(![auth rspauth])
		{
			// We're getting another challenge???
			// I'm not sure what this could possibly be, so for now I'll assume it's a failure
			
			// Revert back to connected state (from authenticating state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
				[delegate xmppStream:self didNotAuthenticate:response];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
			}
		}
		else
		{
			// We received another challenge, but it's really just an rspauth
			// This is supposed to be included in the success element (according to the updated RFC)
			// but many implementations incorrectly send it inside a second challenge request.
			
			// Create and send empty challenge response element
			NSXMLElement *cr = [NSXMLElement elementWithName:@"response" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", [cr XMLString]);
			}
			[asyncSocket writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// The state remains in STATE_AUTH_2
		}
	}
	else if([[response name] isEqualToString:@"success"])
	{
		// We are successfully authenticated (via sasl:digest-md5)
		isAuthenticated = YES;
		
		// Now we start our negotiation over again...
		[self sendOpeningNegotiation];
	}
	else
	{
		// We received some kind of <failure/> element
		
		// Revert back to connected state (from authenticating state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
			[delegate xmppStream:self didNotAuthenticate:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
		}
	}
}

- (void)handleBinding:(NSXMLElement *)response
{
	NSXMLElement *r_bind = [response elementForName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
	NSXMLElement *r_jid = [r_bind elementForName:@"jid"];
	
	if(r_jid)
	{
		// We're properly binded to a resource now
		// Extract and save our resource (it may not be what we originally requested)
		NSString *fullJID = [r_jid stringValue];
		
		[authResource release];
		authResource = [[fullJID lastPathComponent] copy];
		
		// And we may now have to do one last thing before we're ready - start an IM session
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		
		// Check to see if a session is required
		// Don't forget about that NSXMLElement bug you reported to apple (xmlns is required or element won't be found)
		NSXMLElement *f_session = [features elementForName:@"session" xmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
		
		if(f_session)
		{
			NSXMLElement *session = [NSXMLElement elementWithName:@"session"];
			[session setXmlns:@"urn:ietf:params:xml:ns:xmpp-session"];
			
			NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
			[iq addAttributeWithName:@"type" stringValue:@"set"];
			[iq addChild:session];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", iq);
			}
			[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Update state
			state = STATE_START_SESSION;
		}
		else
		{
			// Revert back to connected state (from binding state)
			state = STATE_CONNECTED;
			
			if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
				[delegate xmppStreamDidAuthenticate:self];
			}
			else if(DEBUG_DELEGATE) {
				NSLog(@"xmppStreamDidAuthenticate:%p", self);
			}
		}
	}
	else
	{
		// It appears the server didn't allow our resource choice
		// We'll simply let the server choose then
		
		NSXMLElement *bind = [NSXMLElement elementWithName:@"bind" xmlns:@"urn:ietf:params:xml:ns:xmpp-bind"];
		
		NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
		[iq addAttributeWithName:@"type" stringValue:@"set"];
		[iq addChild:bind];
		
		if(DEBUG_SEND) {
			NSLog(@"SEND: %@", iq);
		}
		[asyncSocket writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
		
		// The state remains in STATE_BINDING
	}
}

- (void)handleStartSessionResponse:(NSXMLElement *)response
{
	if([[[response attributeForName:@"type"] stringValue] isEqualToString:@"result"])
	{
		// Revert back to connected state (from start session state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStreamDidAuthenticate:)]) {
			[delegate xmppStreamDidAuthenticate:self];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStreamDidAuthenticate:%p", self);
		}
	}
	else
	{
		// Revert back to connected state (from start session state)
		state = STATE_CONNECTED;
		
		if([delegate respondsToSelector:@selector(xmppStream:didNotAuthenticate:)]) {
			[delegate xmppStream:self didNotAuthenticate:response];
		}
		else if(DEBUG_DELEGATE) {
			NSLog(@"xmppStream:%p didNotAuthenticate:%@", self, [response XMLString]);
		}
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AsyncSocket Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Called when a socket is about to connect. This method should return YES to continue, or NO to abort.
 * If aborted, will result in AsyncSocketCanceledError.
**/
- (BOOL)onSocketWillConnect:(AsyncSocket *)sock
{
	if(isSecure)
	{
		// Connecting to a secure server
		NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
		
		// Use the highest possible security
		[settings setObject:(NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
					 forKey:(NSString *)kCFStreamSSLLevel];
		
		// Set the peer name
		if([xmppHostName length] > 0)
			[settings setObject:xmppHostName forKey:(NSString *)kCFStreamSSLPeerName];
		else
			[settings setObject:serverHostName forKey:(NSString *)kCFStreamSSLPeerName];
		
		// Allow self-signed certificates if needed
		if(allowsSelfSignedCertificates)
		{
			[settings setObject:[NSNumber numberWithBool:YES]
						 forKey:(NSString *)kCFStreamSSLAllowsAnyRoot];
		}
		
		CFReadStreamSetProperty([asyncSocket getCFReadStream],
								kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
		CFWriteStreamSetProperty([asyncSocket getCFWriteStream],
								 kCFStreamPropertySSLSettings, (CFDictionaryRef)settings);
	}
	return YES;
}

/**
 * Called when a socket connects and is ready for reading and writing. "host" will be an IP address, not a DNS name.
**/
- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
	// We're now connected with a TCP stream, so it's time to initialize the XML stream
	[self sendOpeningNegotiation];
	
	// Now start reading in the server's XML stream
	[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
}

/**
 * Called when a socket has completed reading the requested data. Not called if there is an error.
**/
- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData*)data withTag:(long)tag
{
	NSString *dataAsStr = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
	
	if(DEBUG_RECV) {
		NSLog(@"RECV: %@", dataAsStr);
	}
	
	if(state == STATE_OPENING)
	{
		// Could be either one of the following:
		// <?xml ...>
		// <stream:stream ...>
		
		[buffer appendData:data];
		
		if([dataAsStr hasSuffix:@"?>"])
		{
			// We read in the <?xml version='1.0'?> line
			// We need to keep reading for the <stream:stream ...> line
			[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_START tag:TAG_READ_START];
		}
		else
		{
			// At this point we've sent our XML stream header, and we've received the response XML stream header.
			// We save the root element of our stream for future reference.
			// We've kept everything up to this point in our buffer, so all we need to do is close the stream:stream
			// tag to allow us to parse the data as a valid XML document.
			// Digest Access authentication requires us to know the ID attribute from the <stream:stream/> element.
			
			[buffer appendData:[@"</stream:stream>" dataUsingEncoding:NSUTF8StringEncoding]];
			
			NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:buffer options:0 error:nil] autorelease];
			
			[rootElement release];
			rootElement = [[xmlDoc rootElement] retain];
			
			[buffer setLength:0];
			
			// Check for RFC compliance
			if([self serverXmppStreamVersionNumber] >= 1.0)
			{
				// Update state - we're now onto stream negotiations
				state = STATE_NEGOTIATING;
				
				// We need to read in the stream features now
				[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
			}
			else
			{
				// The server isn't RFC comliant, and won't be sending any stream features
				
				// Update state - we're connected now
				state = STATE_CONNECTED;
				
				// Continue reading for XML fragments
				[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
				
				// Notify delegate
				if([delegate respondsToSelector:@selector(xmppStreamDidOpen:)]) {
					[delegate xmppStreamDidOpen:self];
				}
				else if(DEBUG_DELEGATE) {
					NSLog(@"xmppStreamDidOpen:%p", self);
				}
			}
		}
		return;
	}
	
	// We encountered the end of some tag. IE - we found a ">" character.
	
	// Is it the end of the stream?
	if([dataAsStr hasSuffix:@"</stream:stream>"])
	{
		// We can close our TCP connection now
		[self disconnect];
		
		// The onSocketDidDisconnect: method will handle everything else
		return;
	}
	
	// Add the given data to our buffer, and try parsing the data
	// If the parsing works, we have found an entire XML message fragment.
	
	// Work-around for problem in NSXMLDocument parsing
	// The parser doesn't like <stream:X> tags unless they're properly namespaced
	// This namespacing is declared in the opening <stream:stream> tag, but we only parse individual elements
	if([dataAsStr isEqualToString:@"<stream:features>"])
	{
		NSString *fix = @"<stream:features xmlns:stream='http://etherx.jabber.org/streams'>";
		[buffer appendData:[fix dataUsingEncoding:NSUTF8StringEncoding]];
	}
	else if([dataAsStr isEqualToString:@"<stream:error>"])
	{
		NSString *fix = @"<stream:error xmlns:stream='http://etherx.jabber.org/streams'>";
		[buffer appendData:[fix dataUsingEncoding:NSUTF8StringEncoding]];
	}
	else
	{
		[buffer appendData:data];
	}
	
	NSXMLDocument *xmlDoc = [[[NSXMLDocument alloc] initWithData:buffer options:0 error:nil] autorelease];
	
	if(!xmlDoc)
	{
		// We don't have a full XML message fragment yet
		// Keep reading data from the stream until we get a full fragment
		[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
		return;
	}
	
	NSXMLElement *element = [xmlDoc rootElement];
	
	if(state == STATE_NEGOTIATING)
	{
		// We've just read in the stream features
		// We considered part of the root element, so we'll add it (replacing any previously sent features)
		[element detach];
		[rootElement setChildren:[NSArray arrayWithObject:element]];
		
		// Call a method to handle any requirements set forth in the features
		[self handleStreamFeatures];
	}
	else if(state == STATE_STARTTLS)
	{
		// The response from our starttls message
		[self handleStartTLSResponse:element];
	}
	else if(state == STATE_REGISTERING)
	{
		// The iq response from our registration request
		[self handleRegistration:element];
	}
	else if(state == STATE_AUTH_1)
	{
		// The challenge response from our auth message
		[self handleAuth1:element];
	}
	else if(state == STATE_AUTH_2)
	{
		// The response from our challenge response
		[self handleAuth2:element];
	}
	else if(state == STATE_BINDING)
	{
		// The response from our binding request
		[self handleBinding:element];
	}
	else if(state == STATE_START_SESSION)
	{
		// The response from our start session request
		[self handleStartSessionResponse:element];
	}
	else if([[element name] isEqualToString:@"iq"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveIQ:)])
		{
			[delegate xmppStream:self didReceiveIQ:[XMPPIQ iqFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveIQ:%@", self, [element XMLString]);
		}
	}
	else if([[element name] isEqualToString:@"message"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveMessage:)])
		{
			[delegate xmppStream:self didReceiveMessage:[XMPPMessage messageFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveMessage:%@", self, [element XMLString]);
		}
	}
	else if([[element name] isEqualToString:@"presence"])
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceivePresence:)])
		{
			[delegate xmppStream:self didReceivePresence:[XMPPPresence presenceFromElement:element]];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceivePresence:%@", self, [element XMLString]);
		}
	}
	else
	{
		if([delegate respondsToSelector:@selector(xmppStream:didReceiveError:)])
		{
			[delegate xmppStream:self didReceiveError:element];
		}
		else if(DEBUG_DELEGATE)
		{
			NSLog(@"xmppStream:%p didReceiveError:%@", self, [element XMLString]);
		}
	}
	
	// Clear the buffer
	[buffer setLength:0];
	
	// Continue reading for XML fragments
	// Double-check to make sure we're still connected first though - the delegate could have called disconnect
	if([asyncSocket isConnected])
	{
		[asyncSocket readDataToData:terminator withTimeout:TIMEOUT_READ_STREAM tag:TAG_READ_STREAM];
	}
}

/**
 * Called after data with the given tag has been successfully sent.
**/
- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	if((tag != TAG_WRITE_STREAM) && (tag != TAG_WRITE_START))
	{
		if([delegate respondsToSelector:@selector(xmppStream:didSendElementWithTag:)])
		{
			[delegate xmppStream:self didSendElementWithTag:tag];
		}
	}
}

/**
 * In the event of an error, the socket is closed.  You may call "readDataWithTimeout:tag:" during this call-back to
 * get the last bit of data off the socket.  When connecting, this delegate method may be called
 * before onSocket:didConnectToHost:
**/
- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if([delegate respondsToSelector:@selector(xmppStream:didReceiveError:)]) {
		[delegate xmppStream:self didReceiveError:err];
	}
	else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStream:%p didReceiveError:%@", self, err);
	}
}

/**
 * Called when a socket disconnects with or without error.  If you want to release a socket after it disconnects,
 * do so here. It is not safe to do that during "onSocket:willDisconnectWithError:".
**/
- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	// Update state
	state = STATE_DISCONNECTED;
	
	// Update configuration
	isSecure = NO;
	isAuthenticated = NO;
	
	// Clear the buffer
	[buffer setLength:0];
	
	// Clear the root element
	[rootElement release]; rootElement = nil;
	
	// Clear any saved authentication information
	[authUsername release]; authUsername = nil;
	[authResource release]; authResource = nil;
	[tempPassword release]; tempPassword = nil;
	
	// Stop the keep alive timer
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	keepAliveTimer = nil;
	
	// Notify delegate
	if([delegate respondsToSelector:@selector(xmppStreamDidClose:)]) {
		[delegate xmppStreamDidClose:self];
	}
	else if(DEBUG_DELEGATE) {
		NSLog(@"xmppStreamDidClose:%p", self);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)keepAlive:(NSTimer *)aTimer
{
	if(state == STATE_CONNECTED)
	{
		[asyncSocket writeData:[@" " dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag
{
	[asyncSocket writeData:data withTimeout:timeout tag:tag];
}

@end