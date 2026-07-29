import SwiftData
import OSLog
import SwiftUI

/// Alerts menu for a node: message mute/unmute (always) and, for a node other than the
/// connected device's own, Node Watch presence-subscribe (meshtastic-apple-1ei.10/.26) --
/// folded into this existing bell rather than a second per-node button, so subscribing reads
/// as "manage this node's alerts" instead of a separate, easy-to-miss feature.
struct NodeAlertsButton: View {
	var context: ModelContext

	@Bindable
	var node: NodeInfoEntity

	@Bindable
	var user: UserEntity

	/// Whether to offer the presence toggle alongside message alerts. False for the connected
	/// device's own node (you can't watch yourself) and when there's no connected device at all
	/// (Node Watch notifications depend on packets ingested over an active connection).
	var showsPresenceToggle = false

	@State private var isWatched = false

	private var messageAlertsBinding: Binding<Bool> {
		Binding(
			get: { !user.mute },
			set: { newValue in
				user.mute = !newValue
				do {
					try context.save()
				} catch {
					Logger.data.error("Save User Mute Error")
				}
			}
		)
	}

	private var presenceAlertsBinding: Binding<Bool> {
		Binding(
			get: { isWatched },
			set: { newValue in
				if newValue {
					NodeWatchIdentifier.watch(node.num)
				} else {
					NodeWatchIdentifier.unwatch(node.num)
				}
				isWatched = newValue
			}
		)
	}

	var body: some View {
		Menu {
			Toggle(isOn: messageAlertsBinding) {
				Label("Message alerts", systemImage: "message")
			}
			if showsPresenceToggle {
				Toggle(isOn: presenceAlertsBinding) {
					Label("Notify when online", systemImage: "eye")
				}
				.accessibilityHint("Sends a notification when this node reconnects to the mesh.".localized)
			}
		} label: {
			// A Label alone only makes its own icon+text bounds tappable when this row is
			// placed directly in a Form/List (NodeDetail's Actions section) -- it doesn't
			// pick up the row's full width the way a Button's label normally does. The
			// trailing Spacer + contentShape extend the tap target to the whole row.
			HStack {
				Label {
					Text("Alerts")
				} icon: {
					Image(systemName: (user.mute && !isWatched) ? "bell.slash" : "bell")
						.symbolRenderingMode(.hierarchical)
				}
				Spacer()
			}
			.contentShape(Rectangle())
		}
		.onAppear {
			isWatched = NodeWatchIdentifier.isWatched(node.num)
		}
	}
}

// TODO: Fix preview for SwiftData
/*
#Preview {
	let node = NodeInfoEntity()
	node.num = 123456789
	let user = UserEntity()
	user.longName = "Test Node"
	user.shortName = "TN"
	node.user = user
	NodeAlertsButton(context: context, node: node, user: user)
}
*/
