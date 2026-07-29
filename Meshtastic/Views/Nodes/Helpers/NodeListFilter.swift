//
//  NodeListFilter.swift
//  Meshtastic
//
//  Created by Garth Vander Houwen on 3/25/24.
//

import Foundation
import SwiftData
import SwiftUI

struct NodeListFilter: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var context
	@State var editMode = EditMode.active
	var filterTitle = "Node Filters"
	@ObservedObject var filters: NodeFilterParameters

	/// Node Watch (meshtastic-apple-1ei.10/.26): ids/suffixes that are actively subscribed but
	/// have no `NodeInfoEntity` yet, so they'd otherwise be invisible -- they never show up in
	/// the node list itself (there's nothing to show), and the "Subscribed" filter above only
	/// filters *existing* rows. This is their only visibility until one of them is heard.
	@State private var pendingSuffixWatches: [String] = []
	@State private var pendingExactWatches: [Int64] = []

	private func refreshPendingWatches() {
		pendingSuffixWatches = UserDefaults.watchedNodeIdSuffixes.sorted()
		let nums = Array(UserDefaults.watchedNodeNums)
		guard !nums.isEmpty else {
			pendingExactWatches = []
			return
		}
		let descriptor = FetchDescriptor<NodeInfoEntity>(
			predicate: #Predicate<NodeInfoEntity> { nums.contains($0.num) }
		)
		let known = Set((try? context.fetch(descriptor))?.map(\.num) ?? [])
		pendingExactWatches = nums.filter { !known.contains($0) }.sorted()
	}

	var body: some View {
		NavigationStack {
			Form {
				if !pendingExactWatches.isEmpty || !pendingSuffixWatches.isEmpty {
					Section {
						ForEach(pendingExactWatches, id: \.self) { num in
							HStack {
								Label(num.toHex(), systemImage: "person.fill.questionmark")
								Spacer()
								Button {
									NodeWatchIdentifier.unwatch(num)
									pendingExactWatches.removeAll { $0 == num }
								} label: {
									Text("Unsubscribe")
								}
								.buttonStyle(.borderless)
							}
						}
						ForEach(pendingSuffixWatches, id: \.self) { suffix in
							HStack {
								Label(suffix.uppercased(), systemImage: "person.fill.questionmark")
								Spacer()
								Button {
									NodeWatchIdentifier.unwatchSuffix(suffix)
									pendingSuffixWatches.removeAll { $0 == suffix }
								} label: {
									Text("Unsubscribe")
								}
								.buttonStyle(.borderless)
							}
						}
					} header: {
						Text("Subscribed, Not Yet Seen")
					} footer: {
						Text("You'll be notified the moment one of these appears on the mesh. They won't show in the node list until then.")
					}
				}
				Section {
					Toggle(isOn: $filters.viaLora) {
						Label("Via Lora", systemImage: "dot.radiowaves.left.and.right")
					}
					.labelStyle(.titleAndIcon)
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))

					Toggle(isOn: $filters.viaMqtt) {
						Label("Via Mqtt", systemImage: "dot.radiowaves.up.forward")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					Toggle(isOn: $filters.isOnline) {
						Label("Online", systemImage: "checkmark.circle.fill")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					Toggle(isOn: $filters.isPkiEncrypted) {
						Label("Encrypted", systemImage: "lock.fill")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					Toggle(isOn: $filters.isFavorite) {
						Label("Favorites", systemImage: "star.fill")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					Toggle(isOn: $filters.isSubscribed) {
						Label("Subscribed", systemImage: "eye.fill")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					Toggle(isOn: $filters.isUnsubscribed) {
						Label("Unsubscribed", systemImage: "eye.slash")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.listRowSeparator(.visible)

					if filterTitle == "Node Filters" {
						Toggle(isOn: $filters.isIgnored) {
							Label("Ignored", systemImage: "minus.circle.fill")
						}
						.toggleStyle(SwitchToggleStyle(tint: .accentColor))
						.listRowSeparator(.visible)

						Toggle(isOn: $filters.isEnvironment) {
							Label("Environment", systemImage: "cloud.sun")
						}
						.toggleStyle(SwitchToggleStyle(tint: .accentColor))
						.listRowSeparator(.visible)
					}

					Toggle(isOn: $filters.distanceFilter) {
						Label("Distance", systemImage: "map")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))
					.disabled(LocationsHandler.currentLocation == nil && filters.fallbackLocation == nil)
					.listRowSeparator(filters.distanceFilter ? .hidden : .visible)

					if filters.distanceFilter {
						if LocationsHandler.currentLocation == nil && filters.fallbackLocation == nil {
							Text("Requires a precise GPS fix from your phone")
								.font(.caption)
								.foregroundStyle(.secondary)
						} else {
							if LocationsHandler.currentLocation == nil {
								Text("Using your connected device's position")
									.font(.caption)
									.foregroundStyle(.secondary)
							}
							HStack {
								Label("Show nodes", systemImage: "lines.measurement.horizontal")
								Picker("", selection: $filters.maxDistance) {
									ForEach(MeshMapDistances.allCases) { di in
										Text(di.description)
											.tag(di.id)
									}
								}
								.pickerStyle(DefaultPickerStyle())
							}
						}
					}

					VStack(alignment: .leading) {
						Label("Hops Away", systemImage: "hare")
						Slider(
							value: $filters.hopsAway,
							in: -1...7,
							step: 1
						) {
							Text("Hops Away")
						} minimumValueLabel: {
							Text("All")
						} maximumValueLabel: {
							Text("7")
						}
						.accessibilityValue(
							filters.hopsAway < 0
								? String(localized: "All", comment: "VoiceOver: hops-away filter set to no limit")
								: filters.hopsAway == 0
									? String(localized: "Direct", comment: "VoiceOver: hops-away filter set to direct connections only")
									: filters.hopsAway == 1
										? String(localized: "1 hop away", comment: "VoiceOver: hops-away filter set to 1 hop")
										: String(localized: "\(Int(filters.hopsAway)) hops away", comment: "VoiceOver: hops-away filter value")
						)

						if filters.hopsAway >= 0 {
							if filters.hopsAway == 0 {
								Text("Direct")
							} else if filters.hopsAway == 1 {
								Text("1 hop away")
							} else {
								Text("\(Int(filters.hopsAway)) or less hops away")
							}
						}
					}

					Toggle(isOn: $filters.roleFilter) {
						Label("Roles", systemImage: "apps.iphone")
					}
					.toggleStyle(SwitchToggleStyle(tint: .accentColor))

					if filters.roleFilter {
						VStack {
							List(DeviceRoles.allCases, selection: $filters.deviceRoles) { dr in
								Label {
									Text(dr.name)
								} icon: {
									Image(systemName: dr.systemName)
								}
							}
							.listStyle(.plain)
							.environment(\.editMode, $editMode)
							.frame(minHeight: 510, maxHeight: .infinity)
						}
					}
				}
			}
			.listStyle(.insetGrouped)
			.navigationTitle(filterTitle)
			.navigationBarTitleDisplayMode(.inline)
			.task {
				refreshPendingWatches()
			}
		}
		#if targetEnvironment(macCatalyst)
		.overlay(alignment: .topLeading) {
			Button {
				dismiss()
			} label: {
				Image(systemName: "xmark.circle.fill")
					.font(.system(size: 34))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, Color(.systemGray3))
			}
			.accessibilityLabel(String(localized: "Close", comment: "VoiceOver: dismiss this sheet"))
			.buttonStyle(.plain)
			.padding(.top, 12)
			.padding(.leading, 14)
		}
		#endif
		.presentationDetents([.large])
		.presentationContentInteraction(.scrolls)
		#if !targetEnvironment(macCatalyst)
		.presentationDragIndicator(.visible)
		#endif
		.presentationBackgroundInteraction(.enabled(upThrough: .large))
	}
}

#Preview {
	NodeListFilter(filters: NodeFilterParameters())
}
