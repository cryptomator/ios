platform :ios, '11.0'
inhibit_all_warnings!

def own_pods
	use_modular_headers!
	pod 'CryptomatorCloudAccess', '0.1.0-alpha.3'
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
