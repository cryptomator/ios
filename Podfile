platform :ios, '11.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static





#Change abstract_target name to something more meaningful
abstract_target 'MainApp' do
	#OwnPods
	pod 'CryptomatorCloudAccess', :git => 'https://github.com/cryptomator/cloud-access-swift.git', :branch => 'develop', commit: 'HEAD'
	
	
	target "CloudAccessPrivate" do
		pod 'GRDB.swift'
		pod 'GTMAppAuth', '~> 1.0.0'
		pod 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
		pod 'GoogleSignIn', '~> 5.0'
	end
	
	target "Cryptomator" do
		target "CryptomatorIntegrationTests" do
			inherit! :search_paths
		end
	end
end
