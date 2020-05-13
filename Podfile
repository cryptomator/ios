platform :ios, '11.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

def own_pods
	pod 'CryptomatorCloudAccess', :git => 'https://github.com/cryptomator/cloud-access-swift.git', :branch => 'develop', commit: 'HEAD'
end

def networking_pods
	pod 'GTMAppAuth', '~> 1.0.0'
	pod 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
	pod 'GRDB.swift'
	pod 'GoogleSignIn', '~> 5.0'	
end

target "CloudAccessPrivate" do
	own_pods
	networking_pods	
end

