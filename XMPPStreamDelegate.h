#import <Foundation/Foundation.h>

#import "XMPPMessage.h"
#import "XMPPIQ.h"
#import "XMPPPresence.h"
#import "AbstractXMPPStream.h"

@interface NSObject (XMPPStreamDelegate)

/**
 * This method is called after an XML stream has been opened.
 * More precisely, this method is called after an opening <xml/> and <stream:stream/> tag have been sent and received,
 * and after the stream features have been received, and any required features have been fullfilled.
 * At this point it's safe to begin communication with the server.
 **/
- (void)xmppStreamDidOpen:(AbstractXMPPStream *)sender;

/**
 * This method is called after registration of a new user has successfully finished.
 * If registration fails for some reason, the xmppStream:didNotRegister: method will be called instead.
 **/
- (void)xmppStreamDidRegister:(AbstractXMPPStream *)sender;

/**
 * This method is called if registration fails.
 **/
- (void)xmppStream:(AbstractXMPPStream *)sender didNotRegister:(NSXMLElement *)error;

/**
 * This method is called after authentication has successfully finished.
 * If authentication fails for some reason, the xmppStream:didNotAuthenticate: method will be called instead.
 **/
- (void)xmppStreamDidAuthenticate:(AbstractXMPPStream *)sender;

/**
 * This method is called if authentication fails.
 **/
- (void)xmppStream:(AbstractXMPPStream *)sender didNotAuthenticate:(NSXMLElement *)error;

/**
 * These methods are called after their respective XML elements are received on the stream.
 **/
- (void)xmppStream:(AbstractXMPPStream *)sender didReceiveIQ:(XMPPIQ *)iq;
- (void)xmppStream:(AbstractXMPPStream *)sender didReceiveMessage:(XMPPMessage *)message;
- (void)xmppStream:(AbstractXMPPStream *)sender didReceivePresence:(XMPPPresence *)presence;

/**
 * There are two types of errors: TCP errors and XMPP errors.
 * If a TCP error is encountered (failure to connect, broken connection, etc) a standard NSError object is passed.
 * If an XMPP error is encountered (<stream:error> for example) an NSXMLElement object is passed.
 * 
 * Note that standard errors (<iq type='error'/> for example) are delivered normally,
 * via the other didReceive...: methods.
 **/
- (void)xmppStream:(AbstractXMPPStream *)sender didReceiveError:(id)error;

/**
 * This method is called for every sendElement:andNotifyMe: method.
 **/
- (void)xmppStream:(AbstractXMPPStream *)sender didSendElementWithTag:(long)tag;

/**
 * This method is called after the stream is closed.
 **/
- (void)xmppStreamDidClose:(AbstractXMPPStream *)sender;

@end
