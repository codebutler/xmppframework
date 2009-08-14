#import "XMPPClient.h"
#import "AbstractXMPPStream.h"
#import "TCPXMPPStream.h"
#import "XMPPJID.h"
#import "XMPPIQ.h"
#import "XMPPMessage.h"
#import "XMPPPresence.h"
#import "XMPPRosterManager.h"
#import "XMPPPresenceManager.h"
#import "DDXMLElementAdditions.h"
#import "MulticastDelegate.h"

#ifndef TARGET_OS_IPHONE
#import "SCNotificationManager.h"
#endif

enum XMPPClientFlags
{
	kUsesOldStyleSSL      = 1 << 0,  // If set, TLS is established prior to any communication (no StartTLS)
	kAutoLogin            = 1 << 1,  // If set, client automatically attempts login after connection is established
	kAllowsPlaintextAuth  = 1 << 2,  // If set, client allows plaintext authentication
	kAutoRoster           = 1 << 3,  // If set, client automatically request roster after authentication
	kAutoPresence         = 1 << 4,  // If set, client automatically becaomes available after authentication
	kAutoReconnect        = 1 << 5,  // If set, client automatically attempts to reconnect after a disconnection
	kShouldReconnect      = 1 << 6,  // If set, disconnection was accidental, and autoReconnect may be used
	kHasRoster            = 1 << 7,  // If set, client has received the roster
};

@interface XMPPClient (PrivateAPI)

- (void)onConnecting;
- (void)onDidConnect;
- (void)onDidDisconnect;
- (void)onDidRegister;
- (void)onDidNotRegister:(NSXMLElement *)error;
- (void)onDidAuthenticate;
- (void)onDidNotAuthenticate:(NSXMLElement *)error;
- (void)onDidReceivePresence:(NSXMLElement *)presence;
- (void)onDidReceiveIQ:(XMPPIQ *)iq;
- (void)onDidReceiveMessage:(XMPPMessage *)message;
@end

@implementation XMPPClient

- (id)init
{
	if(self = [super init])
	{
		multicastDelegate = [[MulticastDelegate alloc] init];
		
		priority = 1;
		flags = 0;
		
		[self setAutoLogin:YES];
		[self setAllowsPlaintextAuth:YES];
		[self setAutoPresence:YES];
		[self setAutoRoster:YES];
		[self setAutoReconnect:YES];

		rosterManager = [[XMPPRosterManager alloc] initWithXMPPClient:self];		
		presenceManager = [[XMPPPresenceManager alloc] initWithXMPPClient:self];

#ifndef TARGET_OS_IPHONE
		scNotificationManager = [[SCNotificationManager alloc] init];
		
		// Register for network notifications from system configuration
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(networkStatusDidChange:) 
													 name:@"State:/Network/Global/IPv4" 
												   object:scNotificationManager];
#endif
	}
	return self;
}

- (void)dealloc
{
	[multicastDelegate release];
	
	[domain release];
	[myJID release];
	[password release];
	
	[xmppStream setDelegate:nil];
	[xmppStream disconnect];
	[xmppStream release];
	[streamError release];
	
	[rosterManager release];
	[presenceManager release];
	
#ifndef TARGET_OS_IPHONE
	[scNotificationManager release];
#endif
	
	[super dealloc];
}

- (void)setXmppStream:(AbstractXMPPStream *)stream
{
	[xmppStream autorelease];
	[stream setDelegate:self];
	xmppStream = [stream retain];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Configuration
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)addDelegate:(id)delegate
{
	[multicastDelegate addDelegate:delegate];
}

- (void)removeDelegate:(id)delegate
{
	[multicastDelegate removeDelegate:delegate];
}

- (NSString *)domain
{
	return domain;
}
- (void)setDomain:(NSString *)newDomain
{
	if(![domain isEqual:newDomain])
	{
		[domain release];
		domain = [newDomain copy];
	}
}

- (UInt16)port
{
	return port;
}
- (void)setPort:(UInt16)newPort
{
	port = newPort;
}

- (BOOL)usesOldStyleSSL
{
	return (flags & kUsesOldStyleSSL);
}
- (void)setUsesOldStyleSSL:(BOOL)flag
{
	if(flag)
		flags |= kUsesOldStyleSSL;
	else
		flags &= ~kUsesOldStyleSSL;
}

- (XMPPJID *)myJID
{
	return myJID;
}
- (void)setMyJID:(XMPPJID *)jid
{
	if(![myJID isEqual:jid])
	{
		[myJID release];
		myJID = [jid retain];
	}
}

- (NSString *)password
{
	return password;
}
- (void)setPassword:(NSString *)newPassword
{
	if(![password isEqual:newPassword])
	{
		[password release];
		password = [newPassword copy];
	}
}

- (int)priority
{
	return priority;
}
- (void)setPriority:(int)newPriority
{
	priority = newPriority;
}

- (BOOL)isDisconnected
{
	return [xmppStream isDisconnected];
}

- (BOOL)isConnected
{
	return [xmppStream isConnected];
}

- (BOOL)isSecure
{
	return [xmppStream isSecure];
}

- (BOOL)autoLogin
{
	return (flags & kAutoLogin);
}
- (void)setAutoLogin:(BOOL)flag
{
	if(flag)
		flags |= kAutoLogin;
	else
		flags &= ~kAutoLogin;
}

- (BOOL)autoRoster
{
	return (flags & kAutoRoster);
}
- (void)setAutoRoster:(BOOL)flag
{
	if(flag)
		flags |= kAutoRoster;
	else
		flags &= ~kAutoRoster;
}

- (BOOL)autoPresence
{
	return (flags & kAutoPresence);
}
- (void)setAutoPresence:(BOOL)flag
{
	if(flag)
		flags |= kAutoPresence;
	else
		flags &= ~kAutoPresence;
}

- (BOOL)autoReconnect
{
	return (flags & kAutoReconnect);
}
- (void)setAutoReconnect:(BOOL)flag
{
	if(flag)
		flags |= kAutoReconnect;
	else
		flags &= ~kAutoReconnect;
}

- (BOOL)shouldReconnect
{
	return (flags & kShouldReconnect);
}
- (void)setShouldReconnect:(BOOL)flag
{
	if(flag)
		flags |= kShouldReconnect;
	else
		flags &= ~kShouldReconnect;
}

- (BOOL)hasRoster
{
	return (flags & kHasRoster);
}
- (void)setHasRoster:(BOOL)flag
{
	if(flag)
		flags |= kHasRoster;
	else
		flags &= ~kHasRoster;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Connecting, Registering and Authenticating
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)connect
{
	[self onConnecting];
	
	if([self usesOldStyleSSL])
		[xmppStream connectToSecureHost:domain onPort:port withVirtualHost:[myJID domain]];
	else
		[xmppStream connectToHost:domain onPort:port withVirtualHost:[myJID domain]];
}

- (void)disconnect
{
	// Turn off the shouldReconnect flag.
	// This flag will tell us that we should not automatically attempt to reconnect when the connection closes.
	[self setShouldReconnect:NO];
	
	[xmppStream disconnect];
}

- (BOOL)supportsInBandRegistration
{
	return [xmppStream supportsInBandRegistration];
}

- (void)registerUser
{
	[xmppStream registerUser:[myJID user] withPassword:password];
}

- (BOOL)supportsPlainAuthentication
{
	return [xmppStream supportsPlainAuthentication];
}
- (BOOL)supportsDigestMD5Authentication
{
	return [xmppStream supportsDigestMD5Authentication];
}

- (BOOL)allowsPlaintextAuth
{
	return (flags & kAllowsPlaintextAuth);
}
- (void)setAllowsPlaintextAuth:(BOOL)flag
{
	if(flag)
		flags |= kAllowsPlaintextAuth;
	else
		flags &= ~kAllowsPlaintextAuth;
}

- (void)authenticateUser
{
	if(![self allowsPlaintextAuth])
	{
		if(![xmppStream isSecure] && ![xmppStream supportsDigestMD5Authentication])
		{
			// The only way to login is via plaintext!
			return;
		}
	}
	
	[xmppStream authenticateUser:[myJID user] withPassword:password resource:[myJID resource]];
}

- (BOOL)isAuthenticated
{
	return [xmppStream isAuthenticated];
}

- (NSError *)streamError
{
    return streamError;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Presence Managment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)goOnline
{
	NSString *priorityStr = [NSString stringWithFormat:@"%i", priority];
	
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addChild:[NSXMLElement elementWithName:@"priority" stringValue:priorityStr]];
	
	[xmppStream sendElement:presence];
}

- (void)goOffline
{
	// Send offline presence element
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"type" stringValue:@"unavailable"];
	
	[xmppStream sendElement:presence];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Roster Managment
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)fetchRoster
{
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"get"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
}

- (void)acceptBuddyRequest:(XMPPJID *)jid
{
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"subscribed"];
	
	[xmppStream sendElement:response];
	
	// Add user to our roster
	NSXMLElement *item = [NSXMLElement elementWithName:@"item"];
	[item addAttributeWithName:@"jid" stringValue:[jid bare]];
	
	NSXMLElement *query = [NSXMLElement elementWithName:@"query" xmlns:@"jabber:iq:roster"];
	[query addChild:item];
	
	NSXMLElement *iq = [NSXMLElement elementWithName:@"iq"];
	[iq addAttributeWithName:@"type" stringValue:@"set"];
	[iq addChild:query];
	
	[xmppStream sendElement:iq];
	
	// Subscribe to the user's presence
	NSXMLElement *presence = [NSXMLElement elementWithName:@"presence"];
	[presence addAttributeWithName:@"to" stringValue:[jid bare]];
	[presence addAttributeWithName:@"type" stringValue:@"subscribe"];
	
	[xmppStream sendElement:presence];
}

- (void)rejectBuddyRequest:(XMPPJID *)jid
{
	// Send presence response
	NSXMLElement *response = [NSXMLElement elementWithName:@"presence"];
	[response addAttributeWithName:@"to" stringValue:[jid bare]];
	[response addAttributeWithName:@"type" stringValue:@"unsubscribed"];
	
	[xmppStream sendElement:response];
}

- (XMPPRosterManager *)rosterManager
{
	return rosterManager;
}

- (XMPPPresenceManager *)presenceManager
{
	return presenceManager;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Sending Elements:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)sendElement:(NSXMLElement *)element
{
	[xmppStream sendElement:element];
}

- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag
{
	[xmppStream sendElement:element andNotifyMe:tag];
}

- (void)sendMessage:(NSString *)message toJID:(XMPPJID *)jid
{
	NSXMLElement *body = [NSXMLElement elementWithName:@"body"];
	[body setStringValue:message];

	NSXMLElement *element = [NSXMLElement elementWithName:@"message"];
	[element addAttributeWithName:@"type" stringValue:@"chat"];
	[element addAttributeWithName:@"to" stringValue:[jid full]];
	[element addChild:body];
	
	[self sendElement:element];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Delegate Helper Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)onConnecting
{
	[multicastDelegate xmppClientConnecting:self];
}

- (void)onDidConnect
{
	[multicastDelegate xmppClientDidConnect:self];
}

- (void)onDidDisconnect
{
	[multicastDelegate xmppClientDidDisconnect:self];
}

- (void)onDidRegister
{
	[multicastDelegate xmppClientDidRegister:self];
}

- (void)onDidNotRegister:(NSXMLElement *)error
{
	[multicastDelegate xmppClient:self didNotRegister:error];
}

- (void)onDidAuthenticate
{
	[multicastDelegate xmppClientDidAuthenticate:self];
}

- (void)onDidNotAuthenticate:(NSXMLElement *)error
{
	[multicastDelegate xmppClient:self didNotAuthenticate:error];
}

- (void)onDidReceivePresence:(NSXMLElement *)presence
{
	[multicastDelegate xmppClient:self didReceivePresence:presence];
}

- (void)onDidReceiveIQ:(XMPPIQ *)iq
{
	[multicastDelegate xmppClient:self didReceiveIQ:iq];
}

- (void)onDidReceiveMessage:(XMPPMessage *)message
{
	[multicastDelegate xmppClient:self didReceiveMessage:message];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XMPPStream Delegate Methods:
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)xmppStreamDidOpen:(AbstractXMPPStream *)sender
{
	[self onDidConnect];
	
	if([self autoLogin])
	{
		[self authenticateUser];
	}
}

- (void)xmppStreamDidRegister:(AbstractXMPPStream *)sender
{
	[self onDidRegister];
}

- (void)xmppStream:(AbstractXMPPStream *)sender didNotRegister:(NSXMLElement *)error
{
	[self onDidNotRegister:error];
}

- (void)xmppStreamDidAuthenticate:(AbstractXMPPStream *)sender
{
	// We're now connected and properly authenticated
	// Should we get accidentally disconnected we should automatically reconnect (if kAutoReconnect is set)
	[self setShouldReconnect:YES];
		
	// Note: Order matters in the calls below.
	// We request the roster FIRST, because we need the roster before we can process any presence notifications.
	// We shouldn't receive any presence notification until we've set our presence to available.
	// 
	// We notify the delegate(s) LAST because delegates may be sending their own custom
	// presence packets (and have set autoPresence to NO). The logical place for them to do so is in the
	// onDidAuthenticate method, so we try to request the roster before they start
	// sending any presence packets.
	// 
	// In the event that we do receive any presence elements prior to receiving our roster,
	// we'll be forced to store them in the earlyPresenceElements array, and process them after we finally
	// get our roster list.
	
	if([self autoRoster])
	{
		[self fetchRoster];
	}
	if([self autoPresence])
	{
		[self goOnline];
	}
	
	[self onDidAuthenticate];
}

- (void)xmppStream:(AbstractXMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error
{
	[self onDidNotAuthenticate:error];
}

- (void)xmppStream:(AbstractXMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq
{
	[self onDidReceiveIQ:iq];
}

- (void)xmppStream:(AbstractXMPPStream *)sender didReceiveMessage:(XMPPMessage *)message
{
	[self onDidReceiveMessage:message];
}

- (void)xmppStream:(AbstractXMPPStream *)sender didReceivePresence:(XMPPPresence *)presence
{
	[self onDidReceivePresence:presence];
}

/**
 * There are two types of errors: TCP errors and XMPP errors.
 * If a TCP error is encountered (failure to connect, broken connection, etc) a standard NSError object is passed.
 * If an XMPP error is encountered (<stream:error> for example) an NSXMLElement object is passed.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
**/
- (void)xmppStream:(AbstractXMPPStream *)xs didReceiveError:(id)error
{
	if([error isKindOfClass:[NSError class]])
	{
		[streamError autorelease];
		streamError = [(NSError *)error copy];
		
		if([xmppStream isAuthenticated])
		{
			// We were fully connected to the XMPP server, but we've been disconnected for some reason.
			// We will wait for a few seconds or so, and then attempt to reconnect if possible
			[self performSelector:@selector(attemptReconnect:) withObject:nil afterDelay:4.0];
		}
	}
}

- (void)xmppStreamDidClose:(AbstractXMPPStream *)sender
{
	[self onDidDisconnect];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Reconnecting
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * This method is invoked a few seconds after a disconnection from the server,
 * or after we receive notification that we may once again have a working internet connection.
 * If we are still disconnected, it will attempt to reconnect if the network connection appears to be online.
**/
- (void)attemptReconnect:(id)ignore
{
	NSLog(@"XMPPClient: attempReconnect method called...");
	
	if([xmppStream isDisconnected] && [self autoReconnect] && [self shouldReconnect])
	{
#ifndef TARGET_OS_IPHONE
		SCNetworkConnectionFlags reachabilityStatus;
		BOOL success = SCNetworkCheckReachabilityByName("www.deusty.com", &reachabilityStatus);
		
		if(success && (reachabilityStatus & kSCNetworkFlagsReachable)) 
		{
			[self connect];
		}
#endif
#ifdef TARGET_OS_IPHONE
		[self connect];
#endif
	}
}

- (void)networkStatusDidChange:(NSNotification *)notification
{
	// The following information needs to be tested using multiple interfaces
	
	// If this is a notification of a lost internet connection, there won't be a userInfo
	// Otherwise, there will be...I think...
	
	if([notification userInfo])
	{
		// We may have an internet connection now...
		// 
		// If we were accidentally disconnected (user didn't tell us to disconnect)
		// then now would be a good time to attempt to reconnect.
		if([self shouldReconnect])
		{
			// We will wait for a few seconds or so, and then attempt to reconnect if possible
			[self performSelector:@selector(attemptReconnect:) withObject:nil afterDelay:4.0];
		}
	}
}

@end
