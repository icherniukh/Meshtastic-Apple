import SwiftUI

struct ShareLocationButton: View {
	let action: () -> Void
	var compact: Bool = false

	var body: some View {
		Button(action: action) {
			Image(systemName: "location.fill")
				.accessibilityLabel("Share my location".localized)
				.symbolRenderingMode(.hierarchical)
				.imageScale(compact ? .medium : .large)
				.foregroundColor(compact ? .primary : .accentColor)
		}
		.frame(minWidth: compact ? 36 : nil, minHeight: compact ? 36 : nil)
	}
}

struct ShareLocationButtonPreview: PreviewProvider {
	static var previews: some View {
		ShareLocationButton {}
	}
}
