#import <Foundation/Foundation.h>
#import "XMPPElement.h"

typedef enum {
	IQTYPE_GET,
	IQTYPE_SET,
	IQTYPE_RESULT,
	IQTYPE_ERROR
} XMPPIQType;

@interface XMPPIQ : XMPPElement

+ (XMPPIQ *)iqFromElement:(NSXMLElement *)element;

+ (BOOL)isRosterItem:(NSXMLElement *)item;

- (BOOL)isRosterQuery;

- (XMPPIQType)type;
- (void)setType:(XMPPIQType)type;

- (NSXMLElement *)query;
- (void)setQuery:(NSXMLElement *)query;

@end
