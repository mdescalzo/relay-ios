//
//  FLMessage.m
//  Forsta
//
//  Created by Mark on 7/24/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLMessage.h"

@implementation FLMessage

@synthesize body;

-(void)setBody:(NSString *)value {
    if (![body isEqualToString:value] ) {
        body = value;
        self.plainBody = nil;
        self.attributedBody = nil;
        [self plainBody];
        [self attributedBody];
    }
}

-(NSString *)body {
    return body;
}

-(NSString *)plainBody {
    if (_plainBody == nil) {

        NSArray *bodyArray = [self arrayFromMessageBody:self.body];
        
        if (bodyArray == nil) {
            if (self.body) {
                _plainBody = self.body;
            }
        } else {
            _plainBody = [self plainBodyStringFromBlob:bodyArray];
        }
    }
    return _plainBody;
}

-(NSAttributedString *)attributedBody {
    if (_attributedBody == nil) {
        NSArray *bodyArray = [self arrayFromMessageBody:self.body];
        
        if (bodyArray == nil) {
            _attributedBody = [[NSAttributedString alloc] initWithString:self.body
                                                              attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }];
        } else {
            
            NSString *plainString = [self plainBodyStringFromBlob:bodyArray];
            NSString *htmlString = [self htmlBodyStringFromBlob:bodyArray];

            if (htmlString.length > 0) {

                NSData *data = [htmlString dataUsingEncoding:NSUTF8StringEncoding];
            
                NSError *error = nil;
                //            NSDictionary *attributes;
                
                NSAttributedString *atrString = [[NSAttributedString alloc] initWithData:data
                                                                                 options: @{ NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType,
                                                                                             NSCharacterEncodingDocumentAttribute: [NSNumber numberWithInt:NSUTF8StringEncoding] }
                                                                      documentAttributes:nil
                                                                                   error:&error];
                if (error) {
                    DDLogError(@"%@", error.description);
                }
                
                // hack to deal with appended newline on attributedStrings
                NSString *lastChar = [atrString.string substringWithRange:NSMakeRange(atrString.string.length-1, 1)];
                if ([lastChar isEqualToString:[NSString stringWithFormat:@"\n"]]) {
                    atrString = [atrString attributedSubstringFromRange:NSMakeRange(0, atrString.string.length-1)];
                }
                _attributedBody = atrString;

            } else {
                _attributedBody = [[NSAttributedString alloc] initWithString:plainString
                                                                  attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }];
            }
        }
    }
    return _attributedBody;
}

-(nullable NSArray *)arrayFromMessageBody:(NSString *)body
{
    // Checks passed message body to see if it is JSON,
    //    If it is, return the array of contents
    //    else, return nil.
    NSError *error =  nil;
    NSData *data = [body dataUsingEncoding:NSUTF8StringEncoding];
    
    if (data == nil) { // Not parseable.  Bounce out.
        return nil;
    }
    
    NSArray *output = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (error) {
        return nil;
    } else {
        return output;
    }
}

-(NSString *)plainBodyStringFromBlob:(NSArray *)blob
{
    if ([blob count] > 0) {
        NSDictionary *tmpDict = (NSDictionary *)[blob lastObject];
        NSDictionary *data = [tmpDict objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/plain"]) {
                return (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return @"";
}

-(NSString *)htmlBodyStringFromBlob:(NSArray *)blob
{
    if ([blob count] > 0) {
        NSDictionary *tmpDict = (NSDictionary *)[blob lastObject];
        NSDictionary *data = [tmpDict objectForKey:@"data"];
        NSArray *body = [data objectForKey:@"body"];
        for (NSDictionary *dict in body) {
            if ([(NSString *)[dict objectForKey:@"type"] isEqualToString:@"text/html"]) {
                return (NSString *)[dict objectForKey:@"value"];
            }
        }
    }
    return @"";
}


@end
