//
//  booklet.swift
//  Lectionary
//
//  Created by Damiaan on 15/02/2020.
//  Copyright © 2020 Devian. All rights reserved.
//

import Foundation
import Evangelizo
import UsccbReadings
import LectionaryScraper
import DionysiusParochieReadings

struct Readings: Encodable {
	var readings: [Reading]
	var psalm: Reading?
	var psalmResponse: String?
	var verseBeforeGospel: String?
	var verseBeforeGospelReference: String?
	var gospel: Reading?

	enum CodingKeys: String, CodingKey {
		case readings, psalm, psalmResponse, verseBeforeGospel, verseBeforeGospelReference, gospel
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(readings.map(ReadingJSON.init(withoutBreaks:)), forKey: .readings)
		if let psalm = psalm { try container.encode(ReadingJSON(withBreaks: psalm), forKey: .psalm) }
		if let psalmResponse = psalmResponse { try container.encode(psalmResponse, forKey: .psalmResponse) }
		if let verseBeforeGospel = verseBeforeGospel { try container.encode(verseBeforeGospel, forKey: .verseBeforeGospel) }
		if let verseBeforeGospelReference = verseBeforeGospelReference { try container.encode(verseBeforeGospelReference, forKey: .verseBeforeGospelReference) }
		if let gospel = gospel { try container.encode(ReadingJSON(withoutBreaks: gospel), forKey: .gospel) }
	}

	static let none = Readings(readings: [], psalm: nil, psalmResponse: nil, verseBeforeGospel: nil, verseBeforeGospelReference: nil, gospel: nil)
}

class BookletInfo: NSObject, NSItemProviderWriting, Encodable {
	static let writableTypeIdentifiersForItemProvider = [kUTTypeJSON as String, kUTTypeUTF8PlainText as String]

	let date: Date
	var dutch = Readings.none
	var english = Readings.none
	let type = "com.devian.nightfever-booklet-generation.readings"

	init(for date: Date) {
		self.date = date
	}

	func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
		let dateTuple = try! DateTuple(from: date.components)

		let progress = Progress(totalUnitCount: 3)
		let downloads = DispatchGroup()

		for language in [LanguageTag.english, .dutch] {
			downloads.enter()
			Evangelizo.downloadLiturgicalInfo(of: dateTuple, session: session, priority: .normal, language: language) { (result) in
				switch result {
				case .success(let info):
					let triple = getBasicInfo(from: info)
					serialQueue.sync {
						self[language].readings = triple.readings
						self[language].psalm = triple.psalm
						self[language].gospel = triple.gospel
					}
				case .failure(let error):
					print(error)
					Thread.callStackSymbols.forEach{print($0)}
				}
				progress.completedUnitCount += 1
				downloads.leave()
			}
		}

		concurrentQueue.async {
			downloads.enter()
			do {
				let text = try UsccbReadings.rawContent(for: dateTuple)
				serialQueue.sync {
					let (verse, reference) = text.verseBeforeGospel()
					if let psalmResponse = text.psalmResponse() { self.english.psalmResponse = psalmResponse }
					if let verse = verse { self.english.verseBeforeGospel = verse }
					if let reference = reference { self.english.verseBeforeGospelReference = reference }
				}
			} catch {
				print(error)
				Thread.callStackSymbols.forEach{print($0)}
			}
			progress.completedUnitCount += 1
			downloads.leave()
		}

		concurrentQueue.async {
			downloads.enter()
			do {
				if case .success(let calendar) = dionysiusCalendar, let text = try calendar[dateTuple]?.first?.download() {
					serialQueue.sync {
						let (verse, reference) = text.verseBeforeGospel()
						if let psalmResponse = text.psalmResponse() { self.dutch.psalmResponse = psalmResponse }
						if let verse = verse { self.dutch.verseBeforeGospel = verse }
						if let reference = reference { self.dutch.verseBeforeGospelReference = reference }
					}
				}
			} catch {
				print(error)
				Thread.callStackSymbols.forEach{print($0)}
			}
			progress.completedUnitCount += 1
			downloads.leave()
		}

		downloads.notify(queue: concurrentQueue) {
			do {
				let json = try JSONEncoder().encode(self)
				completionHandler(json, nil)
			} catch {
				completionHandler(nil, error)
			}
		}

		return progress
	}

	subscript (_ language: LanguageTag) -> Readings {
		get { return language == .dutch ? dutch : english }
		set { if language == .dutch { dutch = newValue } else { english = newValue } }
	}
}

struct ReadingJSON: Encodable {
	let text: String
	let reference: String

	init(withBreaks reading: Reading) {
		text = html(for: reading).replacingOccurrences(of: "\n", with: "<br>")
		reference = reading.readableReference
	}

	init(withoutBreaks reading: Reading) {
		text = html(for: reading).replacingOccurrences(of: "\n", with: "")
		reference = reading.readableReference
	}
}

func html(for reading: Reading) -> String {
	reading.verses.map{ $0.content }
		.joined(separator: "")
		.replacingOccurrences(of: "\r", with: "")
		.components(separatedBy: "\n\n")
		.map{"<p>\($0)</p>"}
		.joined(separator: "")
}

fileprivate let serialQueue = DispatchQueue(label: "booklet synchronisation")
fileprivate let concurrentQueue = DispatchQueue(label: "booklet downloader", attributes: .concurrent)

func getBasicInfo(from entry: DayContainer.Entry) -> (readings: [Reading], psalm: Reading?, gospel: Reading?) {
	let readings = entry.readings.map {Reading(from: $0)}
	return (
		readings: readings.filter {$0.kind == .reading},
		psalm: readings.first(where: {$0.kind == .psalm}),
		gospel: readings.first(where: {$0.kind == .gospel})
	)
}
