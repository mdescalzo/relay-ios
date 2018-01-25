//  Copyright © 2016 Open Whisper Systems. All rights reserved.

#import "OWSError.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSRelayServiceKitErrorDomain = @"OWSRelayServiceKitErrorDomain";

NSError *OWSErrorWithCodeDescription(OWSErrorCode code, NSString *description)
{
    return [NSError errorWithDomain:OWSRelayServiceKitErrorDomain
                               code:code
                           userInfo:@{ NSLocalizedDescriptionKey: description }];
}

NSError *OWSErrorMakeUnableToProcessServerResponseError()
{
    return OWSErrorWithCodeDescription(OWSErrorCodeUnableToProcessServerResponse,
        NSLocalizedString(@"ERROR_DESCRIPTION_SERVER_FAILURE", @"Generic server error"));
}

NSError *OWSErrorMakeFailedToSendOutgoingMessageError()
{
    return OWSErrorWithCodeDescription(OWSErrorCodeFailedToSendOutgoingMessage,
        NSLocalizedString(@"ERROR_DESCRIPTION_CLIENT_SENDING_FAILURE", @"Generic notice when message failed to send."));
}

NSError *OWSErrorMakeNoSuchSignalRecipientError()
{
    return OWSErrorWithCodeDescription(OWSErrorCodeFailedToSendOutgoingMessage,
        NSLocalizedString(
            @"ERROR_DESCRIPTION_UNREGISTERED_RECIPIENT", @"Error message when attempting to send message"));
}

NS_ASSUME_NONNULL_END
