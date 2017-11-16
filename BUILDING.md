## Building

1) Clone the repo to a working directory

2) [CocoaPods](http://cocoapods.org) is used to manage dependencies. Pods are setup easily and are distributed via a ruby gem. Follow the simple instructions on the website to setup. After setup, run the following command from the toplevel directory of relay-ios to download the dependencies for Signal-iOS:

```
pod install
```
If you are having build issues, first make sure your pods are up to date
```
pod update
pod install
```
occasionally, CocoaPods itself will need to be updated. Do this with
```
sudo gem update
```

3) Some dependencies are added via carthage. Run:
```
carthage update
```
If you don't have carthage, here are install instructions:
```
https://github.com/Carthage/Carthage#installing-carthage
```

4) Open the `Relay.xcworkspace` in Xcode.

```
open Relay.xcworkspace
```

5) In the Relay target on the General tab, change the Team drop down to your own. On the Capabilities tab turn off Push Notifications and Data Protection. Only Background Modes should remain on.

6) Some of our build scripts, like running tests, expect your Derived
Data directory to be `$(PROJECT_DIR)/build`. In Xcode, go to `Preferences-> Locations`,
and set the "Derived Data" dropdown to "Relative" and the text field
value to "build".

7) Build and Run and you are ready to go!

## Known issues

Features related to push notifications are known to be not working for third-party contributors since Apple's Push Notification service pushes will only work with Forsta Labs code signing certificate.


