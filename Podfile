platform :ios, '11.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

def networking
	pod 'GRDB.swift', '~> 4.14'
	pod 'GTMAppAuth', '~> 1.0.0'
	pod 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
	pod 'GoogleSignIn', '~> 5.0'
	pod 'SwiftyDropbox', '~> 5.1.0'
end

#OwnPods
pod 'CryptomatorCloudAccess', :git => 'https://github.com/cryptomator/cloud-access-swift.git', :branch => 'develop', commit: 'HEAD'

target "CloudAccessPrivate" do
	networking
end

target "Cryptomator" do
	target "CryptomatorIntegrationTests" do
		networking
		inherit! :search_paths
	end
end


