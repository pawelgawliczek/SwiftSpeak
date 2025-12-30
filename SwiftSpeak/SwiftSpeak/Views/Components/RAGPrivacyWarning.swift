//
//  RAGPrivacyWarning.swift
//  SwiftSpeak
//
//  Privacy warning components for RAG document uploads
//  Shows security information to users
//

import SwiftUI

// MARK: - Inline Privacy Banner

/// Always-visible privacy warning for document upload views
struct RAGPrivacyBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)

            VStack(alignment: .leading, spacing: 4) {
                Text("Privacy & Security")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Documents are processed locally and embedded using OpenAI. Content is sent to AI when you use Power Mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - First Document Popup

/// Full-screen privacy information shown on first document upload
struct RAGPrivacySheet: View {
    @Binding var isPresented: Bool
    var onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection

                    Divider()

                    // How it works
                    howItWorksSection

                    // Security measures
                    securitySection

                    // Data handling
                    dataHandlingSection

                    // Whitelisted domains
                    whitelistedDomainsSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Knowledge Base Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                acceptButton
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundStyle(AppTheme.accentGradient)

                Text("Before You Add Documents")
                    .font(.title2.weight(.bold))
            }

            Text("Please review how your documents are processed and stored in the Knowledge Base.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "gearshape.2.fill", title: "How It Works")

            PrivacyInfoRow(
                icon: "arrow.down.doc.fill",
                iconColor: .blue,
                title: "Document Parsing",
                description: "PDFs, text files, and markdown are parsed locally on your device."
            )

            PrivacyInfoRow(
                icon: "rectangle.split.3x3.fill",
                iconColor: .purple,
                title: "Text Chunking",
                description: "Documents are split into smaller chunks for efficient retrieval."
            )

            PrivacyInfoRow(
                icon: "brain.head.profile",
                iconColor: .orange,
                title: "Embedding Generation",
                description: "Chunks are sent to OpenAI to generate searchable embeddings."
            )

            PrivacyInfoRow(
                icon: "internaldrive.fill",
                iconColor: .green,
                title: "Local Storage",
                description: "Embeddings are stored locally in an encrypted database."
            )
        }
    }

    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "lock.shield.fill", title: "Security Measures")

            PrivacyInfoRow(
                icon: "checkmark.shield.fill",
                iconColor: .green,
                title: "Content Validation",
                description: "All documents are scanned for suspicious content before processing."
            )

            PrivacyInfoRow(
                icon: "globe.badge.chevron.backward",
                iconColor: .blue,
                title: "Domain Whitelist",
                description: "Remote URLs are only allowed from trusted domains."
            )

            PrivacyInfoRow(
                icon: "arrow.triangle.2.circlepath",
                iconColor: .orange,
                title: "Prompt Injection Protection",
                description: "Documents are sanitized to prevent prompt manipulation attacks."
            )
        }
    }

    private var dataHandlingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "externaldrive.fill", title: "Your Data")

            PrivacyInfoRow(
                icon: "iphone",
                iconColor: .blue,
                title: "Stored Locally",
                description: "Document content and embeddings stay on your device."
            )

            PrivacyInfoRow(
                icon: "arrow.up.circle.fill",
                iconColor: .purple,
                title: "Sent to AI",
                description: "When you query, relevant chunks are included in the AI prompt."
            )

            PrivacyInfoRow(
                icon: "trash.fill",
                iconColor: .red,
                title: "Full Control",
                description: "Delete any document at any time to remove all associated data."
            )
        }
    }

    private var whitelistedDomainsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "globe", title: "Allowed Remote Sources")

            Text("For security, remote documents can only be fetched from these trusted domains:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(sampleDomains, id: \.self) { domain in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text(domain)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private var acceptButton: some View {
        Button {
            onAccept()
            isPresented = false
        } label: {
            Text("I Understand, Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accentGradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous))
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var sampleDomains: [String] {
        ["docs.google.com", "github.com", "notion.so", "dropbox.com",
         "wikipedia.org", "medium.com", "developer.apple.com", "notion.site"]
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .foregroundStyle(.primary)
    }
}

private struct PrivacyInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Compact Warning

/// Smaller warning for inline display
struct RAGPrivacyCompactWarning: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            Text("Document content will be sent to AI for processing")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - URL Validation Warning

/// Warning shown when URL is not whitelisted
struct RAGURLWarning: View {
    let domain: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.shield.fill")
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("Domain not allowed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)

                Text("\(domain) is not in the trusted domain list.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium, style: .continuous)
                .fill(Color.red.opacity(0.1))
        )
    }
}

// MARK: - Previews

#Preview("Privacy Banner") {
    VStack {
        RAGPrivacyBanner()
        Spacer()
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Privacy Sheet") {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            RAGPrivacySheet(isPresented: .constant(true)) {
                // Preview: User accepted privacy notice
            }
        }
}

#Preview("Compact Warning") {
    RAGPrivacyCompactWarning()
        .padding()
}

#Preview("URL Warning") {
    RAGURLWarning(domain: "suspicious-site.com")
        .padding()
}
