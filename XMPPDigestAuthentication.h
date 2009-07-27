#import <Foundation/Foundation.h>

@interface XMPPDigestAuthentication : NSObject
{
	NSString *rspauth;
	NSString *realm;
	NSString *nonce;
	NSString *qop;
	NSString *username;
	NSString *password;
	NSString *cnonce;
	NSString *nc;
	NSString *digestURI;
}

- (id)initWithChallenge:(NSXMLElement *)challenge;

- (NSString *)rspauth;

- (NSString *)realm;
- (void)setRealm:(NSString *)realm;

- (void)setDigestURI:(NSString *)digestURI;

- (void)setUsername:(NSString *)username password:(NSString *)password;

- (NSString *)response;
- (NSString *)base64EncodedFullResponse;

@end
