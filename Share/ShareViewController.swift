//
//  ShareViewController.swift
//  Share
//
//  Created by Justin Xin on 2026/10/04.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Copies a shared sysdiagnose into the App Group inbox. PowerView imports it the next time it opens.
class ShareViewController: UIViewController {

    private static let appGroup = "group.com.tsubuzaki.PowerView"
    private let status = ShareStatus()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareStatusView(status: status) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [])
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)

        Task { await copySharedFile() }
    }

    private func copySharedFile() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.data.identifier) }) else {
            status.state = .failed("There's no file to import.")
            return
        }
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else {
            status.state = .failed("PowerView's shared storage isn't available.")
            return
        }
        let inbox = container.appending(path: "Inbox", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
            let name = try await copy(from: provider, to: inbox)
            status.state = .done(name)
        } catch {
            status.state = .failed(error.localizedDescription)
        }
    }

    /// The provider's file is only valid inside the completion handler, so it's moved there.
    private func copy(from provider: NSItemProvider, to inbox: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(for: .data, openInPlace: false) { url, _, error in
                guard let url else {
                    continuation.resume(throwing: error ?? CocoaError(.fileReadUnknown))
                    return
                }
                // A timestamp prefix keeps imports in order and avoids name clashes.
                let name = url.lastPathComponent
                let destination = inbox.appending(path: "\(Int(Date().timeIntervalSince1970))-\(name)")
                do {
                    try FileManager.default.moveItem(at: url, to: destination)
                    continuation.resume(returning: name)
                } catch {
                    do {
                        try FileManager.default.copyItem(at: url, to: destination)
                        continuation.resume(returning: name)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}

@Observable
final class ShareStatus {
    enum State {
        case copying
        case done(String)
        case failed(String)
    }

    var state = State.copying
}

struct ShareStatusView: View {
    let status: ShareStatus
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            switch status.state {
            case .copying:
                ProgressView()
                    .controlSize(.large)
                Text("Copying to PowerView…")
                    .font(.headline)
            case .done(let name):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Ready to Import")
                    .font(.headline)
                Text("Open PowerView to see the report for \(name).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Done", action: dismiss)
                    .buttonStyle(.borderedProminent)
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Couldn't Copy File")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Close", action: dismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
