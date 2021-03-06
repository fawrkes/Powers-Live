//
//  NSURLImageProtocol.m
//  WebViewLocalFiles
//
//  Adapted by Garrett Parrish on 11/6/13.
//

#import "NSURLImageProtocol.h"

@implementation NSURLImageProtocol

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
    if ([request.URL.scheme caseInsensitiveCompare:kProtocolImageUrl] == NSOrderedSame)
    {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *) canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void) startLoading
{
    NSString *extension;
    NSString *imageName;
    [self extractImageName:&imageName extension:&extension];

    NSURLResponse *response =[[NSURLResponse alloc]initWithURL:self.request.URL
                                                      MIMEType:nil expectedContentLength:-1
                                              textEncodingName:nil];
    
    // Load image stored in documents directory (that was previously downloaded)
    NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);

    NSString  *documentsDirectory = [paths objectAtIndex:0];
    
    NSString *imagePath = [NSString stringWithFormat:@"%@/%@.%@", documentsDirectory, imageName, extension];

    NSData *data = [NSData dataWithContentsOfFile:imagePath];

    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
}

/**
 * Extracts the image file name and path extension
 */
- (void) extractImageName:(NSString**)imageName extension:(NSString**)extension
{
    NSString *urlString = self.request.URL.absoluteString;
    *extension = [urlString pathExtension];
    urlString = [urlString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@://",kProtocolImageUrl]
                                                     withString:@""];
    *imageName = [urlString stringByDeletingPathExtension];
}

- (void) stopLoading
{
    
}

@end