platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'
project './Forsta.xcodeproj'

use_frameworks!

abstract_target 'Common' do
    
    pod 'Fabric', :inhibit_warnings => true
    pod 'Crashlytics', :inhibit_warnings => true
    pod 'GRKOpenSSLFramework',         '~> 1.0.2.14'
    pod 'Curve25519Kit',               git: 'https://github.com/signalapp/Curve25519Kit', branch: 'mkirk/framework-friendly'
    pod 'HKDFKit',                     git: 'https://github.com/signalapp/HKDFKit.git', branch: 'mkirk/framework-friendly'
    pod 'PastelogKit',                 git: 'git@github.com:ForstaLabs/PastelogKit.git', branch: 'gitHubAuthToken'# , :inhibit_warnings => true
    pod 'FFCircularProgressView',      '~> 0.5', :inhibit_warnings => true
    pod 'SCWaveformView',              '~> 1.0', :inhibit_warnings => true
    pod 'ZXingObjC',                   '~> 3.2.2',  :inhibit_warnings => true
    pod 'JSQMessagesViewController',   git: 'git@github.com:ForstaLabs/JSQMessagesViewController.git', branch: 'forstaMaster', :inhibit_warnings => true
    pod 'CocoaLumberjack/Swift',             :inhibit_warnings => true
    pod 'AFNetworking',                '~> 3.2.0', :inhibit_warnings => true
    pod 'AxolotlKit',                  git: 'https://github.com/signalapp/SignalProtocolKit.git', commit: '54d5f90558578bb96ebfa9688b3905093b489e31', :inhibit_warnings => true
    pod 'Mantle',                      '~> 2.1.0', :inhibit_warnings => true
    pod 'YapDatabase/SQLCipher',       '~> 3.1', :inhibit_warnings => true
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git', :inhibit_warnings => true
    pod 'libPhoneNumber-iOS',          '~> 0.9.12', :inhibit_warnings => true
    pod 'SAMKeychain',                 '~> 1.5.2', :inhibit_warnings => true
    pod 'TwistedOakCollapsingFutures', '~> 1.0.0', :inhibit_warnings => true
    pod 'UIImageView+Extension',       '~> 0.2.5.1', :inhibit_warnings => true
    pod 'SmileTouchID',                '~> 0.1', :inhibit_warnings => true
    pod 'NSAttributedString-DDHTML',   git: 'git@github.com:ForstaLabs/NSAttributedString-DDHTML.git', branch: 'master', :inhibit_warnings => true
    pod 'iRate',                       '~> 1.12', :inhibit_warnings => true
    pod 'ReCaptcha',                   '~> 1.2', :inhibit_warnings => true
    pod 'PromiseKit',                  '~> 4.0', :inhibit_warnings => true
    pod 'FLAnimatedImage',             '~> 1.0', :inhibit_warnings => true
    
    target 'Relay' do
    end
    
    target 'RelayStage' do
    end
    
    target 'RelayDev' do
    end
    
    target 'SignalTests' do
    end
end
