//
//  Promise+AllIgnoringResult.swift
//  CryptomatorFileProvider
//
//  Created by Philipp Schmid on 31.03.22.
//  Copyright © 2022 Skymatic GmbH. All rights reserved.
//

import Foundation
import Promises

func all<Value, Container: Sequence>(ignoringResult promises: Container) -> Promise<Void> where Container.Element == Promise<Value> {
	return any(promises).then { _ -> Void in
		// discard result
	}.recover { _ -> Void in
		// discard result
	}
}
