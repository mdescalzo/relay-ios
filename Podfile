platform :ios, '8.0'
source 'https://github.com/CocoaPods/Specs.git'
project './Forsta.xcodeproj'

abstract_target 'Common' do
    
    pod 'Fabric'
    pod 'Crashlytics'
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git', :commit => '877ac7438be3ad0b45ef5ca3969574e4b97112bf'
    pod 'RelayServiceKit',            :git => 'git@github.com:mdescalzo/RelayServiceKit.git', branch: 'new-msg-handling'
    pod 'OpenSSL', '~> 1.0.210'
    pod 'PastelogKit',                '~> 1.3'
    pod 'FFCircularProgressView',     '~> 0.5'
    pod 'SCWaveformView',             '~> 1.0'
    pod 'ZXingObjC', '~> 3.1.0'
    pod 'DJWActionSheet', '~> 1.0.4'
    pod 'JSQMessagesViewController', git: 'git@github.com:ForstaLabs/JSQMessagesViewController.git', branch: '7.3.4-attributedText'
    pod 'SlackTextViewController', git: 'git@github.com:ForstaLabs/SlackTextViewController.git', branch: 'master'
    
    target 'Relay' do
    end
    
    target 'RelayStage' do
    end
    
    target 'RelayDev' do
    end
    
    target 'SignalTests' do
    end
end
