//
//  booklet.swift
//  Lectionary
//
//  Created by Damiaan on 15/02/2020.
//  Copyright © 2020 Devian. All rights reserved.
//

import Foundation
import Evangelizo

func createBooklet(for date: Date) {
	downloadLiturgicalInfo(session: session, priority: .normal, language: .english) { (result) in
		switch result {
		case .success(let info):
			createBooklet(from: info)
		case .failure(let error):
			print(error)
		}
	}
}

func createBooklet(from entry: DayContainer.Entry) {
	let readings = entry.readings.map {Reading(from: $0)}
	let firstReading = readings.first(where: {$0.kind == .reading})
	let psalms = readings.first(where: {$0.kind == .psalm})
	let gospel = readings.first(where: {$0.kind == .gospel})

	if let reading = firstReading {
		print("First reading:", reading.readableReference)
//		print(reading.verses)
	}
	if let psalms = psalms { print("Psalms:", psalms.readableReference) }
	if let gospel = gospel { print("Gospel:", gospel.readableReference) }
}
