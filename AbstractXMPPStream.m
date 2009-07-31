#import "DDXML.h"
#import "NSXMLElementAdditions.h"
#import "NSDataAdditions.h"

#import "XMPPStreamDelegate.h"
#import "XMPPDigestAuthentication.h"

#import "AbstractXMPPStream.h"

@implementation AbstractXMPPStream

/**
 * Initializes an XMPPStream with no delegate.
 * Note that this class will most likely require a delegate to be useful at all.
 **/
- (id)init
{
	return [self initWithDelegate:nil];
}

/**
 * Initializes an XMPPStream with the given delegate.
 * After creating an object, you'll need to connect to a host using one of the connect...::: methods.
 **/
- (id)initWithDelegate:(id)aDelegate
{
	if(self = [super init])
	{
		// Store reference to delegate
		delegate = aDelegate;
		
		// Initialize state
		state = STATE_DISCONNECTED;
		
		// Initialize configuration
		isSecure = NO;
		isAuthenticated = NO;
		allowsSelfSignedCertificates = NO;
		
		[self setup];
	}
	return self;
}

- (void)setup
{
	[self doesNotRecognizeSelector:_cmd];
}

/**
 * The standard deallocation method.
 * Every object variable declared in the header file should be released here.
 **/
- (void)dealloc
{
	[xmppHostName release];
	[rootElement release];
	[authUsername release];
	[authResource release];
	[tempPassword release];
	[keepAliveTimer invalidate];
	[keepAliveTimer release];
	[super dealloc];
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * The standard delegate methods.
 **/
- (id)delegate {
	return delegate;
}
- (void)setDelegate:(id)newDelegate {
	[delegate autorelease];
	delegate = [newDelegate retain];
}

/**
 * If connecting to a secure server, Mac OS X will automatically verify the authenticity of the TLS certificate.
 * If the certificate is self-signed, a dialog box will automatically pop up,
 * warning the user that the authenticity could not be verified, and prompting them to see if it should continue.
 * If you are connecting to a server with a self-signed certificate, and you would like to automatically accept it,
 * then call set this value to YES method prior to connecting.  The default value is NO.
 **/
- (BOOL)allowsSelfSignedCertificates {
	return allowsSelfSignedCertificates;
}
- (void)setAllowsSelfSignedCertificates:(BOOL)flag {
	allowsSelfSignedCertificates = flag;
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connection Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns YES if the connection is closed, and thus no stream is open.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
 **/
- (BOOL)isDisconnected
{
	return (state == STATE_DISCONNECTED);
}

/**
 * Returns YES if the connection is open, and the stream has been properly established.
 * If the stream is neither disconnected, nor connected, then a connection is currently being established.
 **/
- (BOOL)isConnected
{
	return (state == STATE_CONNECTED);
}

/**
 * Returns YES if SSL/TLS was used to establish a connection to the server.
 * Some servers may require an "upgrade to TLS" in order to start communication,
 * so even if the connectToHost:onPort:withVirtualHost: method was used, an ugrade to TLS may have occured.
 **/
- (BOOL)isSecure
{
	return isSecure;
}

- (void)connectToHost:(NSString *)hostName
               onPort:(UInt16)portNumber
      withVirtualHost:(NSString *)vHostName
               secure:(BOOL)secure
{
	[self doesNotRecognizeSelector:_cmd];
}

/**
 * Connects to the given host on the given port number.
 * If you pass a port number of 0, the default port number for XMPP traffic (5222) is used.
 * The virtual host name is the name of the XMPP host at the given address that we should communicate with.
 * This is generally the domain identifier of the JID. IE: "gmail.com"
 * 
 * If the virtual host name is nil, or an empty string, a virtual host will not be specified in the XML stream
 * connection. This may be OK in some cases, but some servers require it to start a connection.
 **/
- (void)connectToHost:(NSString *)hostName
			   onPort:(UInt16)portNumber
	  withVirtualHost:(NSString *)vHostName
{
	[self doesNotRecognizeSelector:_cmd];
}

/**
 * Connects to the given host on the given port number, using a secure SSL/TLS connection.
 * If you pass a port number of 0, the default port number for secure XMPP traffic (5223) is used.
 * The virtual host name is the name of the XMPP host at the given address that we should communicate with.
 * This is generally the domain identifier of the JID. IE: "gmail.com"
 * 
 * If the virtual host name is nil, or an empty string, a virtual host will not be specified in the XML stream
 * connection. This may be OK in some cases, but some servers require it to start a connection.
 **/
- (void)connectToSecureHost:(NSString *)hostName
					 onPort:(UInt16)portNumber
			withVirtualHost:(NSString *)vHostName
{
	[self connectToHost:hostName onPort:portNumber withVirtualHost:vHostName secure:YES];
}

/**
 * Closes the connection to the remote host.
 **/
- (void)disconnect 
{
	[self doesNotRecognizeSelector:_cmd];
}

- (void)disconnectAfterSending
{
	[self doesNotRecognizeSelector:_cmd];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Stream Negotiation:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendOpeningNegotiation
{
	[self doesNotRecognizeSelector:_cmd];	
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
			[self writeData:[starttls dataUsingEncoding:NSUTF8StringEncoding]
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
			[self writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
			[self writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
			[self writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
			[self writeData:[[cr XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
			[self writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
		[self writeData:[[iq XMLString] dataUsingEncoding:NSUTF8StringEncoding]
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
#pragma mark User Registration:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if in-band registartion is supported.
 * If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsInBandRegistration
{
	if(state == STATE_CONNECTED)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *reg = [features elementForName:@"register" xmlns:@"http://jabber.org/features/iq-register"];
		
		return (reg != nil);
	}
	return NO;
}

/**
 * This method attempts to register a new user on the server using the given username and password.
 * The result of this action will be returned via the delegate method xmppStream:didReceiveIQ:
 * 
 * If the XMPPStream is not connected, or the server doesn't support in-band registration, this method does nothing.
 **/
- (void)registerUser:(NSString *)username withPassword:(NSString *)password
{
	// The only proper time to call this method is after we've connected to the server,
	// and exchanged the opening XML stream headers
	if(state == STATE_CONNECTED)
	{
		if([self supportsInBandRegistration])
		{
			NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:register"];
			[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
			[queryElement addChild:[NSXMLElement elementWithName:@"password" stringValue:password]];
			
			NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:queryElement];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", [iqElement XMLString]);
			}
			[self writeData:[[iqElement XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Update state
			state = STATE_REGISTERING;
		}
	}
}


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark User Authentication:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method checks the stream features of the connected server to determine if plain authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsPlainAuthentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the stream:features
	// are received, and TLS has been setup (if needed/required)
	if(state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		int i;
		for(i = 0; i < [mechanisms count]; i++)
		{
			if([[[mechanisms objectAtIndex:i] stringValue] isEqualToString:@"PLAIN"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method checks the stream features of the connected server to determine if digest authentication is supported.
 * If we are not connected to a server, this method simply returns NO.
 **/
- (BOOL)supportsDigestMD5Authentication
{
	// The root element can be properly queried for authentication mechanisms anytime after the stream:features
	// are received, and TLS has been setup (if needed/required)
	if(state > STATE_STARTTLS)
	{
		NSXMLElement *features = [rootElement elementForName:@"stream:features"];
		NSXMLElement *mech = [features elementForName:@"mechanisms" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
		
		NSArray *mechanisms = [mech elementsForName:@"mechanism"];
		
		int i;
		for(i = 0; i < [mechanisms count]; i++)
		{
			if([[[mechanisms objectAtIndex:i] stringValue] isEqualToString:@"DIGEST-MD5"])
			{
				return YES;
			}
		}
	}
	return NO;
}

/**
 * This method attempts to sign-in to the server using the given username and password.
 * The result of this action will be returned via the delegate method xmppStream:didReceiveIQ:
 *
 * If the XMPPStream is not connected, this method does nothing.
 **/
- (void)authenticateUser:(NSString *)username
			withPassword:(NSString *)password
				resource:(NSString *)resource
{
	// The only proper time to call this method is after we've connected to the server,
	// and exchanged the opening XML stream headers
	if(state == STATE_CONNECTED)
	{
		if([self supportsDigestMD5Authentication])
		{
			NSString *auth = @"<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='DIGEST-MD5'/>";
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", auth);
			}
			[self writeData:[auth dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
			[tempPassword release];
			
			authUsername = [username copy];
			authResource = [resource copy];
			tempPassword = [password copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
		else if([self supportsPlainAuthentication])
		{
			// From RFC 4616 - PLAIN SASL Mechanism:
			// [authzid] UTF8NUL authcid UTF8NUL passwd
			// 
			// authzid: authorization identity
			// authcid: authentication identity (username)
			// passwd : password for authcid
			
			NSString *payload = [NSString stringWithFormat:@"%C%@%C%@", 0, username, 0, password];
			NSString *base64 = [[payload dataUsingEncoding:NSUTF8StringEncoding] base64Encoded];
			
			NSXMLElement *auth = [NSXMLElement elementWithName:@"auth" xmlns:@"urn:ietf:params:xml:ns:xmpp-sasl"];
			[auth addAttributeWithName:@"mechanism" stringValue:@"PLAIN"];
			[auth setStringValue:base64];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", [auth XMLString]);
			}
			[self writeData:[[auth XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
			
			authUsername = [username copy];
			authResource = [resource copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
		else
		{
			// The server does not appear to support SASL authentication (at least any type we can use)
			// So we'll revert back to the old fashioned jabber:iq:auth mechanism
			
			NSString *rootID = [[[self rootElement] attributeForName:@"id"] stringValue];
			NSString *digestStr = [NSString stringWithFormat:@"%@%@", rootID, password];
			NSData *digestData = [digestStr dataUsingEncoding:NSUTF8StringEncoding];
			
			NSString *digest = [[digestData sha1Digest] hexStringValue];
			
			NSXMLElement *queryElement = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:auth"];
			[queryElement addChild:[NSXMLElement elementWithName:@"username" stringValue:username]];
			[queryElement addChild:[NSXMLElement elementWithName:@"digest" stringValue:digest]];
			[queryElement addChild:[NSXMLElement elementWithName:@"resource" stringValue:resource]];
			
			NSXMLElement *iqElement = [NSXMLElement elementWithName:@"iq"];
			[iqElement addAttributeWithName:@"type" stringValue:@"set"];
			[iqElement addChild:queryElement];
			
			if(DEBUG_SEND) {
				NSLog(@"SEND: %@", [iqElement XMLString]);
			}
			[self writeData:[[iqElement XMLString] dataUsingEncoding:NSUTF8StringEncoding]
					   withTimeout:TIMEOUT_WRITE
							   tag:TAG_WRITE_STREAM];
			
			// Save authentication information
			[authUsername release];
			[authResource release];
			
			authUsername = [username copy];
			authResource = [resource copy];
			
			// Update state
			state = STATE_AUTH_1;
		}
	}
}

- (BOOL)isAuthenticated
{
	return isAuthenticated;
}

- (NSString *)authenticatedUsername
{
	return [[authUsername copy] autorelease];
}

- (NSString *)authenticatedResource
{
	return [[authResource copy] autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark General Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method will return the root element of the document.
 * This element contains the opening <stream:stream/> and <stream:features/> tags received from the server
 * when the XML stream was opened.
 * 
 * Note: The rootElement is empty, and does not contain all the XML elements the stream has received during it's
 * connection.  This is done for performance reasons and for the obvious benefit of being more memory efficient.
 **/
- (NSXMLElement *)rootElement
{
	return rootElement;
}

/**
 * Returns the version attribute from the servers's <stream:stream/> element.
 * This should be at least 1.0 to be RFC 3920 compliant.
 * If no version number was set, the server is not RFC compliant, and 0 is returned.
 **/
- (float)serverXmppStreamVersionNumber
{
	return [[[rootElement attributeForName:@"version"] stringValue] floatValue];
}

/**
 * This methods handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
 **/
- (void)sendElement:(NSXMLElement *)element
{
	if(state == STATE_CONNECTED)
	{
		NSString *elementStr = [element XMLString];
		
		if(DEBUG_SEND) {
			NSLog(@"SEND: %@", elementStr);
		}
		[self writeData:[elementStr dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:TAG_WRITE_STREAM];
	}
}

/**
 * This method handles sending an XML fragment.
 * If the XMPPStream is not connected, this method does nothing.
 * 
 * After the element has been successfully sent, the xmppStream:didSendElementWithTag: delegate method is called.
 **/
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag
{
	if(state == STATE_CONNECTED)
	{
		NSString *elementStr = [element XMLString];
		
		if(DEBUG_SEND) {
			NSLog(@"SEND: %@", elementStr);
		}
		[self writeData:[elementStr dataUsingEncoding:NSUTF8StringEncoding]
				   withTimeout:TIMEOUT_WRITE
						   tag:tag];
	}
}

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;
{
	[self doesNotRecognizeSelector:_cmd];	
}

- (void)handleElement:(NSXMLElement *)element
{	
	if(state == STATE_NEGOTIATING)
	{
		// We've just read in the stream features
		// We considered part of the root element, so we'll add it (replacing any previously sent features)
		[element detach];
		[rootElement setChildren:[NSArray arrayWithObject:element]];
		
		// Call a method to handle any requirements set forth in the features
		[self handleStreamFeatures];
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
}	

@end
