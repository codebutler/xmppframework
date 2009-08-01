//  BOSHXMPPRequest.m
//  XMPPStream
//
//  Created by Eric Butler on 7/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "BOSHXMPPRequest.h"

#import "BOSHXMPPStream.h"

@implementation BOSHXMPPRequest

- (id)initWithStream:(BOSHXMPPStream *)theStream bodyData:(NSData *)theData
{
	if (self = [super init]) {
		NSURL *url = [NSURL URLWithString:[theStream bindUrl]];
		
		stream = [theStream retain];
		request = [[NSMutableURLRequest alloc] initWithURL:url];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:theData];

		NSData *data = [request HTTPBody];
		
		NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
		NSLog(@"Will send: %@", dataString);
		[dataString release];

		connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	}
	return self;
}

- (void)dealloc
{
	[request release];
	[connection release];
	[buffer release];
	[response release];
	[super dealloc];
}

- (void)start
{
	NSString *dataString = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
	NSLog(@"Going to send: %@", dataString);
	[dataString release];
	
	[connection start];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSLog(@"Connection did finish loading!");
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSLog(@"connection did fail with error! %@", error);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)resp
{
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)resp;
	
	NSLog(@"connection did receive response!");
	NSLog(@"status: %d", [httpResponse statusCode]);
	NSLog(@"content-length: %d", [httpResponse expectedContentLength]);
	
	// FIXME: Handle this better.
	if ([httpResponse expectedContentLength] == 0)
		return;
	
	buffer = [[NSMutableData dataWithCapacity:[httpResponse expectedContentLength]] retain];
	
	response = [resp retain];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	// FIXME: throw an error
	if ([response expectedContentLength] == 0) {
		NSLog(@"We didn't want any data!! Got: %d", [data length]);
		return;
	} else if (buffer.length + data.length > [response expectedContentLength]) {
		NSLog(@"TOO MUCH AAHH!!! Have: %d Got: %d Expected %d", [buffer length], [data length], [response expectedContentLength]);
		return;
	}

	[buffer appendData:data];
	
	if ([buffer length] == [response expectedContentLength]) {	
		NSString *body = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];

		NSLog(@"Did receive data! %@", body);
		
		NSError *error = nil;	
		NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:body error:&error];
		
		[body release];
		
		// FIXME: throw an error
		if (![[element name] isEqualToString:@"body"]) {
			NSLog(@"aack1!! %@", [element name]);
			return;
		}
				
		if ([stream respondsToSelector:@selector(request:didReceiveElement:)]) {
			[stream request:self didReceiveElement:element];
		}
		
		[element release];
	} else {
		NSLog(@"Still waiting for %d bytes", [response expectedContentLength] - [buffer length]);
	}
}

@end
