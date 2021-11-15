//
//  EditableDataSource.swift
//  Cryptomator
//
//  Created by Philipp Schmid on 15.11.21.
//  Copyright © 2021 Skymatic GmbH. All rights reserved.
//

import UIKit

// swiftlint:disable:next generic_type_name
class EditableDataSource<SectionIdentifierType, ItemIdentifierType>: UITableViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType> where SectionIdentifierType: Hashable, ItemIdentifierType: Hashable {
	var moveRowAction: ((UITableView, _ sourceIndexPath: IndexPath, _ destinationIndexPath: IndexPath) -> Void)?
	var deleteRowAction: ((UITableView, UITableViewCell.EditingStyle, IndexPath) -> Void)?

	override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		moveRowAction?(tableView, sourceIndexPath, destinationIndexPath)
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		deleteRowAction?(tableView, editingStyle, indexPath)
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return true
	}
}
