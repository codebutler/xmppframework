//
//  XMPPRoster.h
//  XMPPStream
//
//  Created by Eric Butler on 8/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPElement.h"
#import "XMPPRosterItem.h"

@interface XMPPRoster : XMPPElement {

}

+ (XMPPRoster *)rosterFromElement:(NSXMLElement *)element;

- (NSArray *)items;
- (void)addItem:(XMPPRosterItem *)item;

@end
