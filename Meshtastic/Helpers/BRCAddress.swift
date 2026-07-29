//
//  BRCAddress.swift
//  Meshtastic
//
//  Black Rock City address translation for the Meshtastic Apple fork.
//  Translates a coordinate to a "radial street" address (e.g. "7:15 F",
//  "4:30 Esplanade") when the point lies inside the BRC street grid, or
//  nil otherwise (inner playa, center camp, deep playa, suburbs, off-grid).
//
//  Geometry derived from the official 2026 BRC GIS street centerlines
//  (burningmantech/innovate-GIS-data, 2026/GeoJSON/street_lines.geojson).
//  The Golden Spike and street layout shift slightly each year; refresh
//  these constants each July season.
//

import Foundation
import CoreLocation

enum BRCAddress {

	// MARK: 2026 geometry constants

	/// Golden Spike (city center), 2026.
	static let center = CLLocationCoordinate2D(latitude: 40.7832440, longitude: -119.2078810)

	/// Clock 12:00 points to compass bearing 45° (NE), so a point's clock
	/// angle equals (bearingFromCenter - 45), modulo 360.
	static let clockBearingOffsetDegrees: Double = 45.0

	/// Radial avenues are quantized to 15-minute (7.5°) steps.
	static let radialStepDegrees: Double = 7.5

	/// Addressable clock arc: 2:00 to 10:00 (clock angle 60° to 300°).
	static let minClockAngle: Double = 60.0
	static let maxClockAngle: Double = 300.0

	/// Annular roads, innermost (Esplanade) to outermost (K), with their
	/// distance from the Golden Spike in meters.
	static let roads: [(name: String, radius: Double)] = [
		("Esplanade", 761.5),
		("A", 893.8),
		("B", 979.2),
		("C", 1064.5),
		("D", 1149.8),
		("E", 1236.6),
		("F", 1384.3),
		("G", 1469.6),
		("H", 1554.9),
		("I", 1640.3),
		("J", 1695.1),
		("K", 1753.0)
	]

	// MARK: Address

	/// Returns a BRC street address for `coordinate`, or nil when the point
	/// is outside the city grid.
	static func address(for coordinate: CLLocationCoordinate2D) -> String? {
		guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
		let distance = coordinate.distance(from: center)
		guard let road = nearestRoad(distance: distance) else { return nil }
		let clockAngle = clockAngle(for: coordinate)
		guard let radial = radialLabel(forClockAngle: clockAngle) else { return nil }
		return "\(radial) \(road)"
	}

	// MARK: Reverse lookup

	/// Returns the approximate coordinate for a BRC address string like
	/// "7:15 F" or "4:30 Esplanade", or nil if the string is not a valid
	/// address within the city grid.
	static func coordinate(forAddress address: String) -> CLLocationCoordinate2D? {
		let parts = address.split(separator: " ", maxSplits: 1)
		guard parts.count == 2 else { return nil }
		let timeStr = parts[0]
		let roadName = String(parts[1])
		let timeParts = timeStr.split(separator: ":")
		guard timeParts.count == 2,
		      let hour = Int(timeParts[0]),
		      let minute = Int(timeParts[1]) else { return nil }
		let clockAngle = Double(hour) * 30.0 + Double(minute) * 0.5
		guard clockAngle >= minClockAngle, clockAngle <= maxClockAngle else { return nil }
		guard let road = roads.first(where: { $0.name == roadName }) else { return nil }
		let bearing = clockAngle + clockBearingOffsetDegrees
		return coordinate(at: bearing, distance: road.radius, from: center)
	}

	// MARK: Helpers

	private static func coordinate(at bearing: Double, distance: Double, from origin: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
		let toRad = Double.pi / 180.0
		let toDeg = 180.0 / Double.pi
		let R = 6371000.0
		let lat1 = origin.latitude * toRad
		let lon1 = origin.longitude * toRad
		let theta = bearing * toRad
		let d = distance / R
		let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(theta))
		let lon2 = lon1 + atan2(sin(theta) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))
		return CLLocationCoordinate2D(latitude: lat2 * toDeg, longitude: lon2 * toDeg)
	}

	private static func nearestRoad(distance: Double) -> String? {
		guard roads.count >= 2 else { return nil }
		let lowerEdge = roads[0].radius - (roads[1].radius - roads[0].radius) / 2
		let upperEdge = roads[roads.count - 1].radius
			+ (roads[roads.count - 1].radius - roads[roads.count - 2].radius) / 2
		guard distance >= lowerEdge, distance <= upperEdge else { return nil }
		return roads.min(by: { abs($0.radius - distance) < abs($1.radius - distance) })?.name
	}

	private static func clockAngle(for coordinate: CLLocationCoordinate2D) -> Double {
		var angle = bearing(from: center, to: coordinate) - clockBearingOffsetDegrees
		angle.formTruncatingRemainder(dividingBy: 360)
		if angle < 0 { angle += 360 }
		return angle
	}

	private static func radialLabel(forClockAngle clockAngle: Double) -> String? {
		let step = (clockAngle / radialStepDegrees).rounded() * radialStepDegrees
		guard step >= minClockAngle, step <= maxClockAngle else { return nil }
		let hours = step / 30.0
		var hour = Int(hours)
		var minute = Int(((hours - Double(hour)) * 60).rounded())
		if minute == 60 { hour += 1; minute = 0 }
		hour = hour % 12
		return "\(hour):\(String(format: "%02d", minute))"
	}

	private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
		let toRad = Double.pi / 180.0
		let toDeg = 180.0 / Double.pi
		let phi1 = start.latitude * toRad
		let phi2 = end.latitude * toRad
		let deltaLambda = (end.longitude - start.longitude) * toRad
		let y = sin(deltaLambda) * cos(phi2)
		let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
		var theta = atan2(y, x) * toDeg
		if theta < 0 { theta += 360 }
		return theta
	}
}
