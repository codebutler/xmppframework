//
//  BOSHXMPPRequest.h
//  XMPPStream
//
//  Created by Eric Butler on 7/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BOSHXMPPStream.h"

@class BOSHXMPPStream;

@interface BOSHXMPPRequest : NSObject {
	BOSHXMPPStream *stream;
	NSMutableURLRequest *request;
	NSURLConnection *connection;
	NSHTTPURLResponse *response;
	NSMutableData *buffer;
}

- (id)initWithStream:(BOSHXMPPStream *)theStream bodyData:(NSData *)theData;
- (void)start;
@end
