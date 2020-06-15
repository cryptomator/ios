platform :ios, '11.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

def networking
	pod 'GRDB.swift', '~> 4.14'
	pod 'GTMAppAuth', '~> 1.0.0'
	pod 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
	pod 'AppAuth/ExternalUserAgent', '~> 1.0'
	pod 'ObjectiveDropboxOfficial', '~> 4.0'
end

pod 'CryptomatorCloudAccess', '~> 0.1.0'

target "CloudAccessPrivate" do
	networking
	target "CloudAccessPrivateTests" do
		inherit! :search_paths
	end
end

target "Cryptomator" do
	target "CryptomatorIntegrationTests" do
		#networking
		inherit! :search_paths
	end
end
