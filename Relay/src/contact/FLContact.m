//
//  FLContact.m
//  Forsta
//
//  Created by Mark on 6/26/17.
//  Copyright © 2017 Forsta. All rights reserved.
//

#import "FLContact.h"

@implementation FLContact

-(NSString *)fullName
{
    if (self.firstName && self.lastName)
        return [NSString stringWithFormat:@"%@ %@", self.firstName, self.lastName];
    else if (self.lastName)
        return self.lastName;
    else if (self.firstName)
        return self.firstName;
    else
        return nil;
}

@end
