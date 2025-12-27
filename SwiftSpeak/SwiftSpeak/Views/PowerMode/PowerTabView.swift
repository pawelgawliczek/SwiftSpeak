//
//  PowerTabView.swift
//  SwiftSpeak
//
//  Phase 4: Power Tab with segmented control for Modes and Contexts
//

import SwiftUI

struct PowerTabView: View {
    enum Tab: String, CaseIterable {
        case modes = "Modes"
        case contexts = "Contexts"
    }

    @State private var selectedTab: Tab = .modes

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header subtitle
                Text("Power tools")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Content based on selection
                switch selectedTab {
                case .modes:
                    PowerModeListContent()
                case .contexts:
                    ContextsListContent()
                }
            }
            .background(AppTheme.darkBase.ignoresSafeArea())
            .navigationTitle("Power")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview

#Preview {
    PowerTabView()
        .environmentObject(SharedSettings.shared)
        .preferredColorScheme(.dark)
}
