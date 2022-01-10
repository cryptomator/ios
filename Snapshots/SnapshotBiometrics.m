//
//  SnapshotBiometrics.m
//  Snapshots
//
//  Created by Philipp Schmid on 27.12.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "notify.h"
#import "SnapshotBiometrics.h"

// Taken from: https://github.com/KaneCheshire/BiometricAutomationDemo/blob/main/BiometricsAutomationDemoUITests/Biometrics.m
@implementation SnapshotBiometrics

+ (void)enrolled {
	int token;
	notify_register_check("com.apple.BiometricKit.enrollmentChanged", &token);
	notify_set_state(token, 1);
	notify_post("com.apple.BiometricKit.enrollmentChanged");
}

@end
