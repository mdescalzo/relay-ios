platform :ios, '8.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'Relay' do
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git'
    pod 'RelayServiceKit',            :git => 'git@github.com:forstaathletics/RelayServiceKit.git'
    pod 'OpenSSL-Universal',		      '~> 1.0'
    pod 'PastelogKit',                '~> 1.3'
    pod 'FFCircularProgressView',     '~> 0.5'
    pod 'SCWaveformView',             '~> 1.0'
    pod 'ZXingObjC'
    pod 'DJWActionSheet'
    #pod 'JSQMessagesViewController'
    pod 'JSQMessagesViewController', git: 'https://github.com/WhisperSystems/JSQMessagesViewController.git', branch: 'fix-intermittent-crash-on-delete'
    target 'SignalTests' do
        inherit! :search_paths
    end
end
