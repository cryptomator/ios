//
//  TableViewModel.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 17.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import Foundation

class TableViewModel<SectionType: Hashable> {
	var title: String? {
		return nil
	}

	var sections: [Section<SectionType>] {
		return []
	}

	func getHeaderTitle(for section: Int) -> String? {
		return nil
	}

	func getFooterTitle(for section: Int) -> String? {
		return nil
	}
}

struct Section<T: Hashable> {
	let id: T
	let elements: [TableViewCellViewModel]
}

class SingleSectionTableViewModel: TableViewModel<SingleSection> {
	var cells: [TableViewCellViewModel] {
		return []
	}

	override var sections: [Section<SingleSection>] {
		return [Section(id: .main, elements: cells)]
	}
}

enum SingleSection {
	case main
}
