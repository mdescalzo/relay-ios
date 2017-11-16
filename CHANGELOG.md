# Change Log

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

[1.1.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.1.0
[1.0.3]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.3
[1.0.2]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.2
[1.0.1]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.1
[1.0.0]: https://github.com/ForstaLabs/relay-ios/releases/tag/v1.0.0
