//
//  MeshtasticLogo.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 10/6/22.
//
import SwiftUI

struct MeshtasticLogo: View {

	@Environment(\.colorScheme) var colorScheme
	@EnvironmentObject var router: Router

	private func showAbout() {
		router.selectedTab = .settings
		router.settingsPath = [.about]
	}

	var body: some View {
		#if targetEnvironment(macCatalyst)
			VStack {
				Button(action: showAbout) {
					if #available(iOS 26.0, macOS 26.0, *) {
						Image(colorScheme == .dark ? "logo-white" : "logo-black")
							.resizable()
							.foregroundColor(.accentColor)
							.scaledToFit()
					} else {
						Image("logo-white")
							.resizable()
							.foregroundColor(.accentColor)
							.scaledToFit()
					}
				}
				.buttonStyle(.plain)
			}
			.padding(.bottom, 5)
			.padding(.top, 5)
		#else
		if #available(iOS 26.0, macOS 26.0, *) {
			VStack {
				Button(action: showAbout) {
					Image(colorScheme == .dark ? "logo-white" : "logo-black")
						.resizable()
						.scaledToFit()
				}
				.buttonStyle(.plain)
			}
		} else {
			VStack {
				Button(action: showAbout) {
					Image(colorScheme == .dark ? "logo-white" : "logo-black")
						.resizable()
						.scaledToFit()
				}
				.buttonStyle(.plain)
			}
			.padding(.bottom, 5)
		}
		#endif
	}
}

#Preview {
	MeshtasticLogo()
		.frame(width: 200, height: 44)
		.environmentObject(Router())
}
