//
//  DataManager.swift
//  Corona
//
//  Created by Mohammad on 3/4/20.
//  Copyright © 2020 Samabox. All rights reserved.
//

import Foundation

import Disk

public class DataManager {
	private static let dataFileName = "data.json"

	public static let instance = DataManager()

	public var world: Region = .world

	public var topCountries: [Region] {
		[Region](regions(of: .country).sorted().reversed().prefix(6))
	}

	public func regions(of level: Region.Level) -> [Region] {
		switch level {
		case .world: return [world]
		case .country: return world.subRegions
		case .province:
			var regions = [Region]()
			for country in world.subRegions {
				if (country.subRegions.isEmpty) {
					regions.append(country)
				} else {
					regions.append(contentsOf: country.subRegions)
				}
			}
			return regions
		}
	}

	public func load(completion: @escaping (Bool) -> ()) {
		DispatchQueue.global().async {

			var result: Bool
			do {
				self.world = try Disk.retrieve(Self.dataFileName, from: .caches, as: Region.self)
				result = true
			}
			catch {
				print("Unexpected error: \(error).")
				try? Disk.clear(.caches)
				result = false
			}

			DispatchQueue.main.async {
				completion(result);
			}
		}
	}
}

extension DataManager {
	public func download(completion: @escaping (Bool) -> ()) {
		JHUWebDataService.instance.fetchReports { (regions, error) in
			guard let regions = regions else {
				completion(false)
				return
			}

			JHURepoDataService.instance.fetchTimeSerieses { (timeSeriesRegions, error) in
				if let timeSeriesRegions = timeSeriesRegions {
					for timeSeriesRegion in timeSeriesRegions {
						regions.first { $0 == timeSeriesRegion }?.timeSeries = timeSeriesRegion.timeSeries
					}
				}

				/// Countries
				var countries = [Region]()
				countries.append(contentsOf: regions.filter({ !$0.isProvince }))
				Dictionary(grouping: regions.filter({ region in
					region.isProvince
				}), by: { region in
					region.parentName
				}).forEach { (key, value) in
					let countryRegion = Region(level: .country,
											   name: key ?? "N/A",
											   parentName: nil,
											   location: .center(of: value.map({ $0.location })))

					countryRegion.subRegions = value
					countries.append(countryRegion)
				}

				/// World
				let worldRegion = Region.world
				worldRegion.subRegions = countries

				self.world = worldRegion

				try? Disk.save(self.world, to: .caches, as: Self.dataFileName)

				completion(true)
			}
		}
	}
}
