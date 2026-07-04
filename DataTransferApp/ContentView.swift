import SwiftUI
import MultipeerConnectivity
import UIKit

struct ContentView: View {
    @StateObject private var peerDiscovery = PeerDiscovery()
    @State private var selectedPeer: MCPeerID?
    @State private var showFilePicker = false
    @State private var showAirDrop = false
    @State private var airDropUrls: [URL] = []
    
    var body: some View {
        TabView {
            DeviceListView(
                peerDiscovery: peerDiscovery,
                selectedPeer: $selectedPeer,
                showFilePicker: $showFilePicker
            )
            .tabItem {
                Image(systemName: "devices")
                Text("设备")
            }
            
            TransferProgressView(transferManager: peerDiscovery.transferManager)
                .tabItem {
                    Image(systemName: "arrow.left.right")
                    Text("传输")
                }
            
            AirDropView(
                showAirDrop: $showAirDrop,
                airDropUrls: $airDropUrls
            )
            .tabItem {
                Image(systemName: "airdrop")
                Text("AirDrop")
            }
        }
        .sheet(isPresented: $showFilePicker) {
            if let peer = selectedPeer {
                FilePickerView(
                    transferManager: peerDiscovery.transferManager,
                    peer: peer,
                    isPresented: $showFilePicker
                )
            }
        }
        .sheet(isPresented: $showAirDrop) {
            if !airDropUrls.isEmpty {
                ActivityViewController(activityItems: airDropUrls, completion: { _ in
                    airDropUrls.removeAll()
                    showAirDrop = false
                })
            }
        }
    }
}

struct AirDropView: View {
    @Binding var showAirDrop: Bool
    @Binding var airDropUrls: [URL]
    
    @State private var selectedUrls: [URL] = []
    
    var body: some View {
        VStack(spacing: 20) {
            Text("快速共享")
                .font(.title)
                .padding()
            
            Text("使用AirDrop快速分享文件到附近设备")
                .foregroundColor(.gray)
                .padding(.horizontal)
            
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
                airDropUrls = selectedUrls
                showAirDrop = true
            }) {
                Text("通过AirDrop发送")
                    .padding()
                    .background(selectedUrls.isEmpty ? Color.gray : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding()
            .disabled(selectedUrls.isEmpty)
        }
        .navigationTitle("AirDrop")
    }
    
    private func openFilePicker() {
        let picker = DocumentPickerForAirDrop(selectedUrls: $selectedUrls)
        if let rootVC = UIApplication.shared.rootViewController {
            rootVC.present(picker, animated: true)
        }
    }
    
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [URL]
    let completion: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class DocumentPickerForAirDrop: UIDocumentPickerViewController {
    private var delegate: DocumentPickerForAirDropDelegate
    
    init(selectedUrls: Binding<[URL]>) {
        delegate = DocumentPickerForAirDropDelegate(selectedUrls: selectedUrls)
        super.init(documentTypes: [UTType.item as String], in: .import)
        allowsMultipleSelection = true
        super.delegate = delegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class DocumentPickerForAirDropDelegate: NSObject, UIDocumentPickerDelegate {
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