import SwiftUI
import MultipeerConnectivity

struct DeviceListView: View {
    @ObservedObject var peerDiscovery: PeerDiscovery
    @Binding var selectedPeer: MCPeerID?
    @Binding var showFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    if peerDiscovery.isBrowsing {
                        peerDiscovery.stopBrowsing()
                    } else {
                        peerDiscovery.startBrowsing()
                    }
                }) {
                    Text(peerDiscovery.isBrowsing ? "停止搜索" : "开始搜索")
                        .padding()
                        .background(peerDiscovery.isBrowsing ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    if peerDiscovery.isAdvertising {
                        peerDiscovery.stopAdvertising()
                    } else {
                        peerDiscovery.startAdvertising()
                    }
                }) {
                    Text(peerDiscovery.isAdvertising ? "停止广播" : "开启广播")
                        .padding()
                        .background(peerDiscovery.isAdvertising ? Color.orange : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            if peerDiscovery.isBrowsing {
                Text("正在搜索附近设备...")
                    .foregroundColor(.gray)
                    .padding(.bottom)
            }
            
            if peerDiscovery.isAdvertising {
                Text("设备已上线，等待连接")
                    .foregroundColor(.green)
                    .padding(.bottom)
            }
            
            if let invitation = peerDiscovery.pendingInvitation {
                VStack {
                    Text("收到连接请求")
                        .font(.title)
                        .padding()
                    
                    Text("\(invitation.peerID.displayName) 请求连接")
                        .font(.headline)
                        .padding()
                    
                    HStack {
                        Button(action: {
                            peerDiscovery.declineInvitation()
                        }) {
                            Text("拒绝")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            peerDiscovery.acceptInvitation()
                        }) {
                            Text("接受")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .background(Color.white)
                .cornerRadius(16)
                .padding()
            }
            
            List {
                Section(header: Text("已发现设备")) {
                    ForEach(peerDiscovery.discoveredPeers, id: \.self) { peer in
                        DeviceRow(
                            peer: peer,
                            isConnected: peerDiscovery.connectedPeers.contains(peer),
                            onConnect: {
                                connectToPeer(peer)
                            },
                            onSelect: {
                                selectedPeer = peer
                                showFilePicker = true
                            }
                        )
                    }
                    
                    if peerDiscovery.discoveredPeers.isEmpty {
                        Text("未发现设备")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("已连接设备")) {
                    ForEach(peerDiscovery.connectedPeers, id: \.self) { peer in
                        DeviceRow(
                            peer: peer,
                            isConnected: true,
                            onConnect: nil,
                            onSelect: {
                                selectedPeer = peer
                                showFilePicker = true
                            }
                        )
                    }
                    
                    if peerDiscovery.connectedPeers.isEmpty {
                        Text("暂无连接")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .navigationTitle("设备列表")
    }
    
    private func connectToPeer(_ peer: MCPeerID) {
        peerDiscovery.invitePeer(peer)
    }
}

struct DeviceRow: View {
    let peer: MCPeerID
    let isConnected: Bool
    let onConnect: (() -> Void)?
    let onSelect: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .font(.title)
                .foregroundColor(isConnected ? .green : .blue)
            
            VStack(alignment: .leading) {
                Text(peer.displayName)
                    .font(.headline)
                
                Text(isConnected ? "已连接" : "未连接")
                    .font(.subheadline)
                    .foregroundColor(isConnected ? .green : .gray)
            }
            
            Spacer()
            
            if !isConnected, let onConnect = onConnect {
                Button(action: onConnect) {
                    Text("连接")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Button(action: onSelect) {
                Text(isConnected ? "发送文件" : "选择")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }
}