#import <Foundation/Foundation.h>

// Define the various states we'll use to track our progress
#define STATE_DISCONNECTED     0
#define STATE_CONNECTING       1
#define STATE_OPENING          2
#define STATE_NEGOTIATING      3
#define STATE_STARTTLS         4
#define STATE_REGISTERING      5
#define STATE_AUTH_1           6
#define STATE_AUTH_2           7
#define STATE_BINDING          8
#define STATE_START_SESSION    9
#define STATE_CONNECTED       10

// Define the debugging state
#define DEBUG_SEND      YES
#define DEBUG_RECV      YES
#define DEBUG_DELEGATE  YES


// Define the various timeouts (in seconds) for retreiving various parts of the XML stream
#define TIMEOUT_WRITE         10
#define TIMEOUT_READ_START    10
#define TIMEOUT_READ_STREAM   -1

// Define the various tags we'll use to differentiate what it is we're currently reading or writing
#define TAG_WRITE_START      100
#define TAG_WRITE_STREAM     101

#define TAG_READ_START       200
#define TAG_READ_STREAM      201

@interface AbstractXMPPStream : NSObject 
{
	id delegate;
	
	int state;

	NSXMLElement *rootElement;

	BOOL isSecure;
	BOOL isAuthenticated;
	BOOL allowsSelfSignedCertificates;
	NSString *serverHostName;
	NSString *xmppHostName;
	
	NSString *authUsername;
	NSString *authResource;
	NSString *tempPassword;
	
	NSTimer *keepAliveTimer;	
}

- (id)init;
- (id)initWithDelegate:(id)delegate;

// FIXME: This is private...and not great...
- (void)setup;

- (id)delegate;
- (void)setDelegate:(id)delegate;

- (BOOL)allowsSelfSignedCertificates;
- (void)setAllowsSelfSignedCertificates:(BOOL)flag;

- (BOOL)isDisconnected;
- (BOOL)isConnected;
- (BOOL)isSecure;
- (void)connectToHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;
- (void)connectToSecureHost:(NSString *)hostName onPort:(UInt16)portNumber withVirtualHost:(NSString *)vHostName;

- (void)disconnect;
- (void)disconnectAfterSending;

- (BOOL)supportsInBandRegistration;
- (void)registerUser:(NSString *)username withPassword:(NSString *)password;

- (BOOL)supportsPlainAuthentication;
- (BOOL)supportsDigestMD5Authentication;
- (void)authenticateUser:(NSString *)username withPassword:(NSString *)password resource:(NSString *)resource;

- (BOOL)isAuthenticated;
- (NSString *)authenticatedUsername;
- (NSString *)authenticatedResource;

- (NSXMLElement *)rootElement;
- (float)serverXmppStreamVersionNumber;

- (void)sendElement:(NSXMLElement *)element;
- (void)sendElement:(NSXMLElement *)element andNotifyMe:(long)tag;

- (void)writeData:(NSData *)data withTimeout:(NSTimeInterval)timeout tag:(long)tag;

@end
