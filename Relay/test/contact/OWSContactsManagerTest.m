#import <XCTest/XCTest.h>
#import "TestUtil.h"
#import "FLContactsManager.h"

@interface FLContactsManagerTest : XCTestCase

@end


@implementation FLContactsManagerTest

- (void)testQueryMatching {
    test([FLContactsManager name:@"big dave" matchesQuery:@"big dave"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"dave big"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"dave"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"big"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"big "]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"      big       "]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"dav"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"bi dav"]);
    test([FLContactsManager name:@"big dave" matchesQuery:@"big big big big big big big big big big dave dave dave dave dave"]);

    test(![FLContactsManager name:@"big dave" matchesQuery:@"ave"]);
    test(![FLContactsManager name:@"big dave" matchesQuery:@"dare"]);
    test(![FLContactsManager name:@"big dave" matchesQuery:@"mike"]);
    test(![FLContactsManager name:@"big dave" matchesQuery:@"mike"]);
    test(![FLContactsManager name:@"dave" matchesQuery:@"big"]);
}

@end
