platform :ios, '11.0'
inhibit_all_warnings!
use_frameworks! :linkage => :static

def own_pods
	pod 'CryptomatorCloudAccess', '0.1.0-alpha.7'
end

def networking_pods
	pod 'GTMAppAuth', '~> 1.0.0'
	pod 'GoogleAPIClientForREST/Drive', '~> 1.3.0'
	pod 'GoogleSignIn', '~> 5.0'
	pod 'Alamofire', '~> 5.1'
end

target "Cryptomator" do
	own_pods
end

target "CloudAccessPrivate" do
	own_pods
	networking_pods	
end

