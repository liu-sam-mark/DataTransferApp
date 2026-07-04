import Foundation
import MultipeerConnectivity
import Combine
import UIKit

class PeerDiscovery: NSObject, ObservableObject {
    
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var pendingInvitation: PendingInvitation?
    
    let transferManager: FileTransferManager
    
    private let serviceType = "datatransfer"
    private let myPeerId: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    
    override init() {
        let deviceName = UIDevice.current.name
        myPeerId = MCPeerID(displayName: deviceName)
        
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        
        transferManager = FileTransferManager(session: session)
        
        super.init()
        
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
    }
    
    deinit {
        stopAdvertising()
        stopBrowsing()
        session.disconnect()
    }
    
    func startBrowsing() {
        if !isBrowsing {
            browser.startBrowsingForPeers()
            isBrowsing = true
        }
    }
    
    func stopBrowsing() {
        if isBrowsing {
            browser.stopBrowsingForPeers()
            isBrowsing = false
        }
    }
    
    func startAdvertising() {
        if !isAdvertising {
            advertiser.startAdvertisingPeer()
            isAdvertising = true
        }
    }
    
    func stopAdvertising() {
        if isAdvertising {
            advertiser.stopAdvertisingPeer()
            isAdvertising = false
        }
    }
    
    func invitePeer(_ peer: MCPeerID) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    func getSession() -> MCSession {
        return session
    }
    
    func getMyPeerId() -> MCPeerID {
        return myPeerId
    }
}

extension PeerDiscovery: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
            case .disconnected, .notConnected:
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        transferManager.handleReceivedData(data, fromPeer: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerDiscovery: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            if let index = self.discoveredPeers.firstIndex(of: peerID) {
                self.discoveredPeers.remove(at: index)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Browser error: \(error.localizedDescription)")
    }
}

struct PendingInvitation {
    let peerID: MCPeerID
    let invitationHandler: (Bool, MCSession?) -> Void
}

extension PeerDiscovery: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        pendingInvitation = PendingInvitation(peerID: peerID, invitationHandler: invitationHandler)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Advertiser error: \(error.localizedDescription)")
    }
    
    func acceptInvitation() {
        if let invitation = pendingInvitation {
            invitation.invitationHandler(true, session)
            pendingInvitation = nil
        }
    }
    
    func declineInvitation() {
        if let invitation = pendingInvitation {
            invitation.invitationHandler(false, nil)
            pendingInvitation = nil
        }
    }
}