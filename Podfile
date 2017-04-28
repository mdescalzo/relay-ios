platform :ios, '8.0'
source 'https://github.com/CocoaPods/Specs.git'

target 'Relay' do
    pod 'SocketRocket',               :git => 'https://github.com/facebook/SocketRocket.git', :commit => '877ac7438be3ad0b45ef5ca3969574e4b97112bf'
    pod 'RelayServiceKit',            :git => 'https://github.com/forstalabs/RelayServiceKit.git', :commit => 'be4812b'
    pod 'OpenSSL', '~> 1.0.210'
    pod 'PastelogKit',                '~> 1.3'
    pod 'FFCircularProgressView',     '~> 0.5'
    pod 'SCWaveformView',             '~> 1.0'
    pod 'ZXingObjC', '~> 3.1.0'
    pod 'DJWActionSheet', '~> 1.0.4'
    pod 'JSQMessagesViewController', git: 'https://github.com/WhisperSystems/JSQMessagesViewController.git', branch: 'fix-intermittent-crash-on-delete'
    target 'SignalTests' do
        inherit! :search_paths
    end
end
