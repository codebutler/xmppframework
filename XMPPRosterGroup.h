//
//  XMPPRosterGroup.h
//  XMPPStream
//
//  Created by Eric Butler on 8/7/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "XMPPElement.h"

@interface XMPPRosterGroup : XMPPElement {

}

+ (XMPPRosterGroup *)rosterGroupForElement:(NSXMLElement *)element;
- (id)initWithGroupName:(NSString *)groupName;
- (NSString *)groupName;
@end
