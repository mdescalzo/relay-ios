platform :ios, '8.0'
source 'https://github.com/CocoaPods/Specs.git'
project './Forsta.xcodeproj'

abstract_target 'Common' do
    
    pod 'Fabric', :inhibit_warnings => true
    pod 'Crashlytics', :inhibit_warnings => true
#    pod 'OpenSSL',                     '~> 1.0.210', :inhibit_warnings => true
    pod 'GRKOpenSSLFramework',         '~> 1.0.2.14'
    pod 'PastelogKit',                 git: 'git@github.com:ForstaLabs/PastelogKit.git', branch: 'gitHubAuthToken'# , :inhibit_warnings => true
    pod 'FFCircularProgressView',      '~> 0.5', :inhibit_warnings => true
    pod 'SCWaveformView',              '~> 1.0', :inhibit_warnings => true
    pod 'ZXingObjC',                   '~> 3.2.2',  :inhibit_warnings => true
    pod 'JSQMessagesViewController',   git: 'git@github.com:ForstaLabs/JSQMessagesViewController.git', branch: 'forstaMaster', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift',             :inhibit_warnings => true
    pod 'AFNetworking',                '~> 3.2.0', :inhibit_warnings => true
    pod 'AxolotlKit',                  git: 'https://github.com/signalapp/SignalProtocolKit.git'
    pod 'Mantle',                      '~> 2.1.0', :inhibit_warnings => true
    pod 'YapDatabase/SQLCipher',       '~> 3.1', :inhibit_warnings => true
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git', :commit => '877ac7438be3ad0b45ef5ca3969574e4b97112bf', :inhibit_warnings => true
    pod 'libPhoneNumber-iOS',          '~> 0.9.12', :inhibit_warnings => true
    pod 'SAMKeychain',                 '~> 1.5.2', :inhibit_warnings => true
    pod 'TwistedOakCollapsingFutures', '~> 1.0.0', :inhibit_warnings => true
    pod 'UIImageView+Extension',       '~> 0.2.5.1', :inhibit_warnings => true
    pod 'SmileTouchID', :inhibit_warnings => true
    pod 'NSAttributedString-DDHTML', git: 'git@github.com:ForstaLabs/NSAttributedString-DDHTML.git', branch: 'master', :inhibit_warnings => true
    pod 'iRate', '~> 1.12', :inhibit_warnings => true
    pod 'ReCaptcha'
    pod 'GoogleWebRTC'
    
    target 'Relay' do
    end
    
    target 'RelayStage' do
    end
    
    target 'RelayDev' do
    end
    
    target 'SignalTests' do
    end
end
