//
//  ContentView.swift
//  Lectionary
//
//  Created by Damiaan on 14/02/2020.
//  Copyright © 2020 Devian. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var model = ViewModel()

    var body: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading) {
				HStack {
					Picker(selection: $model.source, label: Text("Source:")) {
						ForEach(ReadingSource.allCases, id: \.self) {
							Text($0.description)
						}
					}.fixedSize()
					Picker(selection: $model.language, label: EmptyView()) {
						ForEach(model.source.availableLanguages, id: \.self) {
							Text($0)
						}
					}.fixedSize().disabled(model.source.availableLanguages.count < 2)
				}.frame(maxWidth: .infinity, alignment: .leading)
				ScrollView(.vertical) {
					ReadingsView(model: model.readingsModel)
				}
			}
			VStack {
				Text("Date")
				DatePicker(selection: $model.date, displayedComponents: .date) {EmptyView()}
				DatePicker(selection: $model.date, displayedComponents: .date) {EmptyView()}
					.datePickerStyle(GraphicalDatePickerStyle())
			}.fixedSize()
		}.padding()
	}
}

import HMassTexts

struct ReadingsView: View {
	@ObservedObject var model: ReadingsModel

	var body: some View {
		VStack(alignment: .leading) {
			if model.isLoading {
				Text("Loading")
			} else {
				ForEach(Array(model.readings.enumerated()), id: \.offset) {
					self.view(for: $0.element)
				}
			}
		}.frame(maxWidth: .infinity)
	}

	func view(for element: StyledTextSegment) -> AnyView {
		switch element {
		case .title(let text):
			return AnyView(Text(text).font(.title))
		case .liturgicalDate(let text):
			return AnyView(Text(text))
		case .text(let text):
			return AnyView(Text(text))
		case .bibleVerse(let text, _):
			return AnyView(Text(text))
		case .source(let text):
			return AnyView(Text(text))
		case .responseTitle:
			return AnyView(Text("Response").foregroundColor(.red))
		case .paragraphBreak:
			return AnyView(Rectangle().frame(height: 0).foregroundColor(.clear))
		case .lineBreak:
			return AnyView(EmptyView())
		}
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
		ContentView().frame(maxWidth: 300)
    }
}
