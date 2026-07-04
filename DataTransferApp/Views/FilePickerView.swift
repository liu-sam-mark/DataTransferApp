import SwiftUI
import UniformTypeIdentifiers
import MultipeerConnectivity
import UIKit

struct FilePickerView: View {
    @ObservedObject var transferManager: FileTransferManager
    let peer: MCPeerID
    @Binding var isPresented: Bool
    
    @State private var selectedUrls: [URL] = []
    @State private var isSending = false
    
    var body: some View {
        NavigationView {
            VStack {
                Text("选择要发送的文件")
                    .font(.title)
                    .padding()
                
                List {
                    ForEach(selectedUrls, id: \.self) { url in
                        HStack {
                            Image(systemName: "file")
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.headline)
                                
                                Text(FileUtils.formatFileSize(FileUtils.getFileSize(url)))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                if let index = selectedUrls.firstIndex(of: url) {
                                    selectedUrls.remove(at: index)
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    if selectedUrls.isEmpty {
                        Text("点击下方按钮选择文件")
                            .foregroundColor(.gray)
                    }
                }
                
                Button(action: {
                    openFilePicker()
                }) {
                    Text("选择文件")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                
                Button(action: {
                    sendFiles()
                }) {
                    Text(isSending ? "发送中..." : "发送文件")
                        .padding()
                        .background(selectedUrls.isEmpty || isSending ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .disabled(selectedUrls.isEmpty || isSending)
            }
            .navigationBarTitle("文件选择")
            .navigationBarItems(trailing: Button("关闭") {
                isPresented = false
            })
        }
    }
    
    private func openFilePicker() {
        let picker = DocumentPicker(selectedUrls: $selectedUrls)
        if let rootVC = UIApplication.shared.rootViewController {
            rootVC.present(picker, animated: true)
        }
    }
    
    private func sendFiles() {
        isSending = true
        transferManager.sendFiles(selectedUrls, to: peer)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isSending = false
            isPresented = false
        }
    }
    
}

class DocumentPicker: UIDocumentPickerViewController {
    private var delegate: DocumentPickerDelegate
    
    init(selectedUrls: Binding<[URL]>) {
        delegate = DocumentPickerDelegate(selectedUrls: selectedUrls)
        super.init(documentTypes: [UTType.item as String], in: .import)
        allowsMultipleSelection = true
        super.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DocumentPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let selectedUrls: Binding<[URL]>
    
    init(selectedUrls: Binding<[URL]>) {
        self.selectedUrls = selectedUrls
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        selectedUrls.wrappedValue.append(contentsOf: urls)
        controller.dismiss(animated: true)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true)
    }
}