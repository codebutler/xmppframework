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
	[stream release];
	[super dealloc];
}

- (void)start
{
	if (DEBUG_SEND) {
		NSString *dataString = [[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding];
		NSLog(@"SEND: %@", dataString);
		[dataString release];
	}
	
	[connection start];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if ([response expectedContentLength] != buffer.length) 
	{
		NSString *errMsg = [NSString stringWithFormat:@"Connection lost before all data was received. Expected %d, Got: %d", 
							[response expectedContentLength],
							buffer.length];
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
		
		[stream onDidReceiveError:err];		
	}		
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[stream onDidReceiveError:error];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)resp
{
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)resp;
	
	if ([httpResponse statusCode] != 200 &&
		[httpResponse expectedContentLength] == 0)
	{
		// We're not going to receive any data, so fire the error here (otherwise it happens in didReceiveData)
				
		NSString *errMsg = [NSString stringWithFormat:@"HTTP Error %d", [httpResponse statusCode]];
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
		
		[stream onDidReceiveError:err];
	}
	
	buffer = [[NSMutableData dataWithCapacity:[httpResponse expectedContentLength]] retain];
	
	response = [resp retain];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	if ((buffer.length + data.length) > [response expectedContentLength]) 
	{
		NSString *errMsg = [NSString stringWithFormat:@"Received too much data. Expected: %d, Got: %d",
							[response expectedContentLength],
							(buffer.length + data.length)];
		NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
		NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
		
		[stream onDidReceiveError:err];			
		
		return;
	}

	[buffer appendData:data];
	
	if ([buffer length] == [response expectedContentLength]) {	
		NSString *body = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];

		if (DEBUG_RECV) {
			NSLog(@"RECV: %@", body);
		}
		
		if ([response statusCode] != 200) 
		{			
			NSString *errMsg = [NSString stringWithFormat:@"HTTP Error %d: %@", [response statusCode], body];
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
			
			[stream onDidReceiveError:err];			
			
			return;
		}
		
		NSError *error = nil;	
		NSXMLElement *element = [[NSXMLElement alloc] initWithXMLString:body error:&error];
		
		[body release];
		
		// FIXME: throw an error
		if (![[element name] isEqualToString:@"body"]) 
		{
			NSString *errMsg = [NSString stringWithFormat:@"Bad wrapper element! Expected <body>, Got: %@", 
								[element name]];
			NSDictionary *info = [NSDictionary dictionaryWithObject:errMsg forKey:NSLocalizedDescriptionKey];
			NSError *err = [NSError errorWithDomain:@"XMPP" code:-1 userInfo:info];
			
			[stream onDidReceiveError:err];			
			
			return;
		}

		[stream request:self didReceiveElement:element];
		
		[element release];
	} else {
		// We're waiting for more data - this method will be called again.
	}
}

@end
