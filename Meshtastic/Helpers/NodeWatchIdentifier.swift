//
//  NodeWatchIdentifier.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 2026.
//

import Foundation

/// Parses a user-entered node identifier for Node Watch (meshtastic-apple-1ei.10) into a
/// node num. Accepts a full hex node id ("!74dc9f79" or "74dc9f79") or a plain decimal node
/// num -- both are numerically resolvable without the node ever having appeared in NodeDB.
/// A short *name* (e.g. "IVAN") is not handled here: names are arbitrary strings with no
/// numeric relationship to the node num, so they can only be resolved by matching against a
/// node already present in NodeDB (e.g. by tapping it in the node list). A short *id*
/// (the last 4 hex characters of the node id -- also Meshtastic's default short name before a
/// node's owner picks their own) is different: it's a real suffix of the id, so it can be
/// matched against nodes heard later even if none have been seen yet. See `normalizedSuffix`.
enum NodeWatchIdentifier {
	static func parse(_ raw: String) -> Int64? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }

		var hex = trimmed
		if hex.hasPrefix("!") {
			hex.removeFirst()
		}
		if hex.count == 8, let value = UInt32(hex, radix: 16) {
			return Int64(value)
		}
		// A bare decimal string is ambiguous with a 4-hex-digit short id that happens to be
		// all-digits (e.g. "1234") -- callers should try `normalizedSuffix` first and only
		// fall back to decimal node-num parsing once that's been ruled out.
		if trimmed.count != 4, let decimal = Int64(trimmed), decimal > 0 {
			return decimal
		}
		return nil
	}

	/// Normalizes a raw short-id query into a 4-lowercase-hex-character suffix, or nil if it
	/// isn't a plausible short id. Use `hexIdMatches` to test it against a node's id.
	static func normalizedSuffix(_ raw: String) -> String? {
		let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
		guard trimmed.count == 4, trimmed.allSatisfy(\.isHexDigit) else { return nil }
		return trimmed
	}

	/// True if `nodeNum`'s hex id (e.g. "!74dc9f79") ends with `suffix`, a value already
	/// normalized by `normalizedSuffix`.
	static func hexIdMatches(nodeNum: Int64, suffix: String) -> Bool {
		nodeNum.toHex().hasSuffix(suffix)
	}

	/// True if `nodeNum` matches anything on the Node Watch list: an exact id/decimal watch
	/// or a short-id suffix watch. Single source of truth for both notification trigger sites
	/// in UpdateSwiftData and for reflecting match state in the Node Watch UI.
	static func isWatched(_ nodeNum: Int64) -> Bool {
		if UserDefaults.watchedNodeNums.contains(nodeNum) {
			return true
		}
		let suffixes = UserDefaults.watchedNodeIdSuffixes
		guard !suffixes.isEmpty else { return false }
		return suffixes.contains { hexIdMatches(nodeNum: nodeNum, suffix: $0) }
	}

	/// Once a short-id suffix watch resolves to a concrete node, promote it to an exact watch
	/// on that node num. Without this, the suffix keeps matching every future node that shares
	/// the same 4 hex characters (rare but possible), and a later online→offline→online cycle
	/// for the *wrong* node would fire a Node Watch notification. No-op if nothing matched.
	static func promoteSuffixMatch(for nodeNum: Int64) {
		let suffixes = UserDefaults.watchedNodeIdSuffixes
		let matched = suffixes.filter { hexIdMatches(nodeNum: nodeNum, suffix: $0) }
		guard !matched.isEmpty else { return }
		UserDefaults.watchedNodeIdSuffixes = suffixes.subtracting(matched)
		var nums = UserDefaults.watchedNodeNums
		nums.insert(nodeNum)
		UserDefaults.watchedNodeNums = nums
	}

	// MARK: - Subscribe / non-destructive unsubscribe

	/// An identifier the user asked to watch, resolved to either an exact node num (full id or
	/// decimal) or a not-yet-resolved short-id suffix. See `watchTarget(for:)`.
	enum WatchTarget: Equatable {
		case exact(Int64)
		case suffix(String)
	}

	/// Resolves raw user input (e.g. from the Nodes search bar's blind-subscribe empty state):
	/// try a full/decimal id first, then a 4-character short-id suffix. Nil if unparseable.
	static func watchTarget(for raw: String) -> WatchTarget? {
		if let num = parse(raw) {
			return .exact(num)
		}
		if let suffix = normalizedSuffix(raw) {
			return .suffix(suffix)
		}
		return nil
	}

	static func isActive(target: WatchTarget) -> Bool {
		switch target {
		case .exact(let num): return UserDefaults.watchedNodeNums.contains(num)
		case .suffix(let suffix): return UserDefaults.watchedNodeIdSuffixes.contains(suffix)
		}
	}

	static func watch(target: WatchTarget) {
		switch target {
		case .exact(let num): watch(num)
		case .suffix(let suffix): watchSuffix(suffix)
		}
	}

	static func unwatch(target: WatchTarget) {
		switch target {
		case .exact(let num): unwatch(num)
		case .suffix(let suffix): unwatchSuffix(suffix)
		}
	}

	/// Adds `nodeNum` to the active watch list, removing it from history if it was there.
	static func watch(_ nodeNum: Int64) {
		var history = UserDefaults.watchedNodeNumsHistory
		history.remove(nodeNum)
		UserDefaults.watchedNodeNumsHistory = history
		var active = UserDefaults.watchedNodeNums
		active.insert(nodeNum)
		UserDefaults.watchedNodeNums = active
	}

	/// Non-destructively removes `nodeNum` from the active watch list, moving it to history
	/// instead of deleting it. `watch(_:)` moves it back in one step -- no re-typing an id.
	static func unwatch(_ nodeNum: Int64) {
		var active = UserDefaults.watchedNodeNums
		guard active.remove(nodeNum) != nil else { return }
		UserDefaults.watchedNodeNums = active
		var history = UserDefaults.watchedNodeNumsHistory
		history.insert(nodeNum)
		UserDefaults.watchedNodeNumsHistory = history
	}

	/// Adds a short-id suffix to the active watch list, removing it from history if present.
	static func watchSuffix(_ suffix: String) {
		var history = UserDefaults.watchedNodeIdSuffixesHistory
		history.remove(suffix)
		UserDefaults.watchedNodeIdSuffixesHistory = history
		var active = UserDefaults.watchedNodeIdSuffixes
		active.insert(suffix)
		UserDefaults.watchedNodeIdSuffixes = active
	}

	/// See `unwatch(_:)` -- moves the suffix to history rather than deleting it.
	static func unwatchSuffix(_ suffix: String) {
		var active = UserDefaults.watchedNodeIdSuffixes
		guard active.remove(suffix) != nil else { return }
		UserDefaults.watchedNodeIdSuffixes = active
		var history = UserDefaults.watchedNodeIdSuffixesHistory
		history.insert(suffix)
		UserDefaults.watchedNodeIdSuffixesHistory = history
	}

	static func isInHistory(_ nodeNum: Int64) -> Bool {
		UserDefaults.watchedNodeNumsHistory.contains(nodeNum)
	}
}
