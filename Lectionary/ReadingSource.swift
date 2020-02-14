//
//  ReadingSource.swift
//  Lectionary
//
//  Created by Damiaan on 14/02/2020.
//  Copyright © 2020 Devian. All rights reserved.
//

import Evangelizo

enum ReadingSource: Int, CaseIterable, CustomStringConvertible {
	case evangelizo
	case dionysius
	case usccb

	var description: String {
		switch self {
		case .evangelizo: return "Evangelizo.org"
		case .dionysius: return "Dionysiusparochie.nl"
		case .usccb: return "USCCB.org"
		}
	}

	var availableLanguages: [String] {
		switch self {
		case .evangelizo: return Array(Evangelizo.languageTags.keys)
		case .dionysius: return ["nl"]
		case .usccb: return ["en"]
		}
	}
}
