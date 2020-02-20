//
//  ViewModel.swift
//  Lectionary
//
//  Created by Damiaan on 14/02/2020.
//  Copyright © 2020 Devian. All rights reserved.
//

import Foundation
import LectionaryScraper

class ViewModel: ObservableObject {
	@Published var date = Date()
	@Published var source = ReadingSource.evangelizo {
		willSet {
			if newValue.availableLanguages.count < 2, let language = newValue.availableLanguages.first {
				self.language = language
			}
		}
	}
	@Published var language = "en"

	var readingsModel: ReadingsModel {
		ReadingsModel(source: source, language: language, date: date)
	}
}

import DionysiusParochieReadings
import Evangelizo
import UsccbReadings

let dionysiusCalendar: Result<[DateTuple:[ReadingsLocation]], Error> = {
	do {
		return .success(try DionysiusParochieReadings.downloadCalendar())
	} catch {
		return .failure(error)
	}
}()

let session = URLSession(configuration: .default)

class ReadingsModel: ObservableObject {
	var isLoading = true
	@Published var readings = [StyledTextSegment]()

	init(source: ReadingSource, language: String, date: Date) {
		let dateTuple = try! DateTuple(from: date.components)
		switch source {
		case .evangelizo:
			Evangelizo.downloadLiturgicalInfo(of: dateTuple, session: session, priority: .normal, language: Evangelizo.languageTags[language]!) { result in
				DispatchQueue.main.sync {
					self.isLoading = false
					switch result {
					case .failure(let error):
						self.readings = [
							.text("Could not download the readings from evangelizo"),
							.lineBreak,
							.text(error.localizedDescription)
						]
					case .success(let day):
						self.readings = day.readingsWithCommentary
					}
				}
			}
		case .dionysius:
			switch dionysiusCalendar {
			case .success(let calendar):
				if let readings = calendar[dateTuple] {
					DispatchQueue.global().async {
						let text: [[StyledTextSegment]] = readings.map {
							do { return try $0.download().styledText() }
							catch { return [StyledTextSegment.text(error.localizedDescription)] }
						}
						DispatchQueue.main.sync {
							self.isLoading = false
							self.readings = text.flatMap {$0}
						}
					}
				} else {
					isLoading = false
					self.readings = [.text("Could not find a reading for \(date) on Dionysiusparochie.nl")]
				}
			case .failure(let error):
				isLoading = false
				readings = [
					.text("Could not find a reading for \(date) on Dionysiusparochie.nl"),
					.lineBreak,
					.text(error.localizedDescription)
				]
			}
		case .usccb:
			DispatchQueue.global().async {
				do {
					let readings = try UsccbReadings.downloadReadings(for: dateTuple)
					DispatchQueue.main.sync {
						self.isLoading = false
						self.readings = readings
					}
				} catch {
					DispatchQueue.main.sync {
						self.isLoading = false
						self.readings = [
							.text("Could not find a reading for \(date) on Dionysiusparochie.nl"),
							.lineBreak,
							.text(error.localizedDescription)
						]
					}
				}
			}
		}
	}
}
