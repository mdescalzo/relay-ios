# Change Log


## [1.4.6]
### Fixed
- Empty message bubbles from certain web client messages
- Resend of failed messages
- User dropped from converstaion following certain control messages
- Several deadlock bugs
### Updated
- JSQMessages pod
- New notification sound
- AxolotlKit pod
### Added
- Invisible Recaptcha robot checkout on new account creation

## [1.4.5]
### Fixed
- Giphys failing to render (removed HTMLPurifier)
- Fixed debug log submission
## Added
- Ability to force device provisioning

## [1.4.4]
### Fixed
- Intermittent crash on superscript/subscript tags
### Added
- Implemented HTMLPurifier

## [1.4.3]
### Fixed
- Broken ratings link
- Broken downloads link
### Updated
- iRate pod

## [1.4.2]
### Fixed
- Incorrect bubble color for sent giphys
- Removed async preferences lookup causing improper fallback to default settings.

## [1.4.1]
### Fixed
- Fix for conversations displaying as announcements from archive view.
- Crash due to improper notification handling the threadCreationView.

## [1.4.0]
### Fixed
- Crash when added to conversation with non-org user.
- Fixed giphy display in conversations.
### Added
- Support for Announcement mesages.
- Sections in ThreadCreationView consistent with web client.
- Support for provisioning control messages.  Allows multiple mobile devices for a single user.
### Update
- Updated YapDatabase to 3.0.2.

## [1.3.1]
### Fixed
- More graceful handling of bad recipient data.  Prevents crash.
### Update
- Update to match protocol update on server side.

## [1.3.0]
### Added
- App-specific privacy PIN/TouchID support.
### Fixed
- Malformed attachment messages.  Caused them to be dumped by other clients.
- Fixed PushKit notifications.  Will name receive messages reliably when app is in background or not running.
- New users getting kicked back to first login view.
### Updated
- Improved html string parser for generated NSAttributedStrings

## [1.2.0]
### Added
- Conversation pinning.
- Conversation archiving.
- Appearance settings view.
- Optional Gravatar support in appearance.
- Selectable colors for incoming and outgoing message bubbles.
- Avatar and app preference caching for better table performance and fewer db hits.
### Fixed
- PushNotification registration bug preventing consistent receipt of push notifications.
- Vanishing input text when new message received.

## [1.1.1]
### Fixed
- Fixed font size irregularity in conversation view.  Occasionally cause message truncation.
- Fixed disappearing sync messages.
- Fixed empty bubble for unrenderabe markup messages from web client.
- Fixed Edit Conversation and Leave Conversation implementing control message sends for them.

## [1.1.0]
### Added
- Support for sending and receiving document attachments.
### Fixed
- Fixed socket connections closing unepectedly due to calling the fromBackground method where fromForeground should have been called.
- Fix for notification flood when connections are restored.  Notifications don't post a sound/vibration if they occur within 1 second of receipt of the last message.

## [1.0.3]
### Fixed
- Fixed control message handling to play nicer with the web client.
### Update
- Updated invitation URL.

## [1.0.2]
### Fixed
- Fixed broken debug log submission.
### Added
- TagMath lookup for threads to help eliminate 'Unnamed Conversation' from appearing.

## [1.0.1]
### Fixed
- Infinite loop bug in main thread view threadMapping accessor.
- Block control @tags from appearing in the UI.
- Fixed some avatars appear with "#" instead of initials.
### Added
- F.A.B. for message/conversation creation.
- Merged RelayServiceKit repo into Relay-iOS.
- Organization-define Off-the-record handling.

## [1.0.0]
- Initial release

[1.4.6]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.6
[1.4.5]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.5
[1.4.4]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.4
[1.4.3]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.3
[1.4.2]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.2
[1.4.1]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.1
[1.4.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.4.0
[1.3.1]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.3.1
[1.3.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.3.0
[1.2.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.2.0
[1.1.1]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.1.1
[1.1.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.1.0
[1.0.3]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.3
[1.0.2]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.2
[1.0.1]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.1
[1.0.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.0
