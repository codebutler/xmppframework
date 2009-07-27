#import "NSXMLElementAdditions.h"
#import "NSDataAdditions.h"

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
	delegate = newDelegate;
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

@end
