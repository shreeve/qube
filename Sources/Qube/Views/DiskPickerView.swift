import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DiskPickerView: View {
    @Environment(\.dismiss) var dismiss

    let vmName: String
    let onSelected: (String) -> Void

    @State private var directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("VMs")
    @State private var filename: String = ""
    @State private var sizeGB: Int = 32
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let sizes = [16, 32, 64, 128, 256]

    init(vmName: String, currentPath: String = "", onSelected: @escaping (String) -> Void) {
        self.vmName = vmName
        self.onSelected = onSelected

        // Initialize filename from VM name or current path
        if !currentPath.isEmpty {
            let url = URL(fileURLWithPath: currentPath)
            _directory = State(initialValue: url.deletingLastPathComponent())
            _filename = State(initialValue: url.deletingPathExtension().lastPathComponent)
        } else {
            let safeName = vmName.isEmpty ? "disk" : vmName.replacingOccurrences(of: " ", with: "-").lowercased()
            _filename = State(initialValue: safeName)
        }
    }

    private var fullPath: String {
        directory.appendingPathComponent("\(filename).qcow2").path
    }

    private var fileExists: Bool {
        FileManager.default.fileExists(atPath: fullPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                Text("Disk Image")
                    .font(.headline)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            Divider()

            // Form
            Form {
                // Directory picker
                LabeledContent("Location") {
                    HStack {
                        Text(directory.path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose…") {
                            selectDirectory()
                        }
                    }
                }

                // Filename
                HStack {
                    TextField("Filename", text: $filename)
                        .textFieldStyle(.roundedBorder)
                    Text(".qcow2")
                        .foregroundStyle(.secondary)
                }

                // Size (only show if creating new)
                if !fileExists {
                    Picker("Size", selection: $sizeGB) {
                        ForEach(sizes, id: \.self) { size in
                            Text("\(size) GB").tag(size)
                        }
                    }
                }

                // Status
                if fileExists {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("File exists — will use existing disk")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("New file — will create \(sizeGB) GB disk")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)

            Divider()

            // Buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(fileExists ? "Open" : "Create") {
                    processSelection()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(filename.isEmpty || isProcessing)
            }
            .padding()
        }
        .frame(width: 450, height: fileExists ? 280 : 320)
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Location or Existing Disk"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        panel.allowedContentTypes = [.folder, UTType(filenameExtension: "qcow2")!]
        panel.message = "Select a folder to create a new disk, or select an existing .qcow2 file"

        if panel.runModal() == .OK, let url = panel.url {
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                // Selected a directory
                directory = url
            } else {
                // Selected a file - extract directory and filename
                directory = url.deletingLastPathComponent()
                filename = url.deletingPathExtension().lastPathComponent
            }
        }
    }

    private func processSelection() {
        errorMessage = nil

        if fileExists {
            // Just use existing file
            onSelected(fullPath)
            dismiss()
        } else {
            // Create new disk
            isProcessing = true

            // Ensure directory exists
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/qemu-img")
            process.arguments = ["create", "-f", "qcow2", fullPath, "\(sizeGB)G"]

            let pipe = Pipe()
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                if process.terminationStatus == 0 {
                    onSelected(fullPath)
                    dismiss()
                } else {
                    let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    errorMessage = "Failed: \(errorString)"
                }
            } catch {
                errorMessage = "Failed to run qemu-img: \(error.localizedDescription)"
            }

            isProcessing = false
        }
    }
}
