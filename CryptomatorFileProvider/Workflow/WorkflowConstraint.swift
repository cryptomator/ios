//
//  WorkflowConstraint.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 10.06.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

enum WorkflowConstraint {
	case unconstrained
	case downloadConstrained
	case uploadConstrained
}
