import Foundation
import MultipeerConnectivity
import Combine

struct TransferProgress: Identifiable {
    let id: String
    let fileName: String
    let fileSize: Int64
    let transferredBytes: Int64
    let progress: Double
    let speed: Double
    let estimatedTimeRemaining: TimeInterval
    let status: TransferStatus
}

enum TransferStatus {
    case pending
    case transferring
    case paused
    case completed
    case failed
}

class FileTransferManager: NSObject, ObservableObject {
    
    @Published var sendProgress: [TransferProgress] = []
    @Published var receiveProgress: [TransferProgress] = []
    @Published var isTransferring = false
    
    private let session: MCSession
    private let chunkSize = 64 * 1024
    private var activeTransfers: [String: ActiveTransfer] = [:]
    private var activeReceives: [String: ActiveReceive] = [:]
    
    init(session: MCSession) {
        self.session = session
        super.init()
    }
    
    func sendFiles(_ urls: [URL], to peer: MCPeerID) {
        isTransferring = true
        
        for url in urls {
            let fileID = UUID().uuidString
            let fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            
            let progress = TransferProgress(
                id: fileID,
                fileName: url.lastPathComponent,
                fileSize: fileSize ?? 0,
                transferredBytes: 0,
                progress: 0,
                speed: 0,
                estimatedTimeRemaining: 0,
                status: .pending
            )
            
            DispatchQueue.main.async {
                self.sendProgress.append(progress)
            }
            
            let transfer = ActiveTransfer(
                fileID: fileID,
                url: url,
                peer: peer,
                fileSize: fileSize ?? 0,
                chunkSize: chunkSize,
                session: session,
                progressUpdate: { [weak self] progressInfo in
                    self?.updateSendProgress(fileID: fileID, progressInfo: progressInfo)
                },
                completion: { [weak self] success in
                    self?.completeTransfer(fileID: fileID, success: success)
                }
            )
            
            activeTransfers[fileID] = transfer
            transfer.start()
        }
    }
    
    func handleReceivedData(_ data: Data, fromPeer peerID: MCPeerID) {
        do {
            let message = try FileMessage.decode(from: data)
            
            switch message.type {
            case .start:
                startReceive(message)
            case .chunk:
                handleChunk(message)
            case .end:
                endReceive(message)
            }
        } catch {
            print("Failed to decode file message: \(error)")
        }
    }
    
    private func updateSendProgress(fileID: String, progressInfo: (bytesSent: Int64, speed: Double, eta: TimeInterval)) {
        DispatchQueue.main.async {
            if let index = self.sendProgress.firstIndex(where: { $0.id == fileID }) {
                let current = self.sendProgress[index]
                let progress = Double(progressInfo.bytesSent) / Double(current.fileSize) * 100
                
                self.sendProgress[index] = TransferProgress(
                    id: fileID,
                    fileName: current.fileName,
                    fileSize: current.fileSize,
                    transferredBytes: progressInfo.bytesSent,
                    progress: progress,
                    speed: progressInfo.speed,
                    estimatedTimeRemaining: progressInfo.eta,
                    status: .transferring
                )
            }
        }
    }
    
    private func completeTransfer(fileID: String, success: Bool) {
        DispatchQueue.main.async {
            if let index = self.sendProgress.firstIndex(where: { $0.id == fileID }) {
                let current = self.sendProgress[index]
                self.sendProgress[index] = TransferProgress(
                    id: fileID,
                    fileName: current.fileName,
                    fileSize: current.fileSize,
                    transferredBytes: success ? current.fileSize : current.transferredBytes,
                    progress: success ? 100 : current.progress,
                    speed: 0,
                    estimatedTimeRemaining: 0,
                    status: success ? .completed : .failed
                )
            }
            
            self.activeTransfers.removeValue(forKey: fileID)
            
            if self.activeTransfers.isEmpty && self.activeReceives.isEmpty {
                self.isTransferring = false
            }
        }
    }
    
    private func handleChunk(_ message: FileMessage) {
        if let receive = activeReceives[message.fileID] {
            receive.addChunk(index: message.chunkIndex, data: message.data)
        }
    }
    
    private func startReceive(_ message: FileMessage) {
        if activeReceives[message.fileID] == nil {
            let receive = ActiveReceive(
                fileID: message.fileID,
                fileName: message.fileName,
                fileSize: message.fileSize,
                totalChunks: message.totalChunks,
                progressUpdate: { [weak self] progressInfo in
                    self?.updateReceiveProgress(fileID: message.fileID, progressInfo: progressInfo)
                },
                completion: { [weak self] url in
                    self?.completeReceive(fileID: message.fileID, url: url)
                }
            )
            
            activeReceives[message.fileID] = receive
            
            let progress = TransferProgress(
                id: message.fileID,
                fileName: message.fileName,
                fileSize: message.fileSize,
                transferredBytes: 0,
                progress: 0,
                speed: 0,
                estimatedTimeRemaining: 0,
                status: .transferring
            )
            
            DispatchQueue.main.async {
                self.receiveProgress.append(progress)
            }
        }
    }
    
    private func endReceive(_ message: FileMessage) {
        if let receive = activeReceives[message.fileID] {
            receive.assembleFile()
        }
    }
    
    private func updateReceiveProgress(fileID: String, progressInfo: (bytesReceived: Int64, speed: Double, eta: TimeInterval)) {
        DispatchQueue.main.async {
            if let index = self.receiveProgress.firstIndex(where: { $0.id == fileID }) {
                let current = self.receiveProgress[index]
                let progress = Double(progressInfo.bytesReceived) / Double(current.fileSize) * 100
                
                self.receiveProgress[index] = TransferProgress(
                    id: fileID,
                    fileName: current.fileName,
                    fileSize: current.fileSize,
                    transferredBytes: progressInfo.bytesReceived,
                    progress: progress,
                    speed: progressInfo.speed,
                    estimatedTimeRemaining: progressInfo.eta,
                    status: .transferring
                )
            }
        }
    }
    
    private func completeReceive(fileID: String, url: URL?) {
        DispatchQueue.main.async {
            if let index = self.receiveProgress.firstIndex(where: { $0.id == fileID }) {
                let current = self.receiveProgress[index]
                self.receiveProgress[index] = TransferProgress(
                    id: fileID,
                    fileName: current.fileName,
                    fileSize: current.fileSize,
                    transferredBytes: url != nil ? current.fileSize : current.transferredBytes,
                    progress: url != nil ? 100 : current.progress,
                    speed: 0,
                    estimatedTimeRemaining: 0,
                    status: url != nil ? .completed : .failed
                )
            }
            
            self.activeReceives.removeValue(forKey: fileID)
            
            if self.activeTransfers.isEmpty && self.activeReceives.isEmpty {
                self.isTransferring = false
            }
        }
    }
    
    func cancelTransfer(fileID: String) {
        if let transfer = activeTransfers[fileID] {
            transfer.cancel()
        }
    }
}

class ActiveTransfer {
    let fileID: String
    let url: URL
    let peer: MCPeerID
    let fileSize: Int64
    let chunkSize: Int
    let session: MCSession
    private var fileHandle: FileHandle?
    
    var bytesSent: Int64 = 0
    var startTime: TimeInterval = 0
    var isCancelled = false
    
    let progressUpdate: ((bytesSent: Int64, speed: Double, eta: TimeInterval)) -> Void
    let completion: (Bool) -> Void
    
    init(fileID: String, url: URL, peer: MCPeerID, fileSize: Int64, chunkSize: Int, session: MCSession,
         progressUpdate: @escaping ((bytesSent: Int64, speed: Double, eta: TimeInterval)) -> Void,
         completion: @escaping (Bool) -> Void) {
        self.fileID = fileID
        self.url = url
        self.peer = peer
        self.fileSize = fileSize
        self.chunkSize = chunkSize
        self.session = session
        self.progressUpdate = progressUpdate
        self.completion = completion
    }
    
    func start() {
        do {
            fileHandle = try FileHandle(forReadingFrom: url)
            startTime = Date().timeIntervalSince1970
            
            let totalChunks = Int((fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))
            let startMessage = FileMessage(
                type: .start,
                fileID: fileID,
                fileName: url.lastPathComponent,
                fileSize: fileSize,
                chunkIndex: 0,
                totalChunks: totalChunks,
                data: Data()
            )
            
            if let data = try? startMessage.encode() {
                session.send(data, toPeers: [peer], with: .reliable)
            }
            
            sendNextChunk(chunkIndex: 0)
        } catch {
            completion(false)
        }
    }
    
    private func sendNextChunk(chunkIndex: Int) {
        if isCancelled {
            closeFileHandle()
            completion(false)
            return
        }
        
        guard let fileHandle = fileHandle else {
            completion(false)
            return
        }
        
        let offset = Int64(chunkIndex) * Int64(chunkSize)
        if offset >= fileSize {
            closeFileHandle()
            
            let endMessage = FileMessage(
                type: .end,
                fileID: fileID,
                fileName: url.lastPathComponent,
                fileSize: fileSize,
                chunkIndex: 0,
                totalChunks: 0,
                data: Data()
            )
            
            if let data = try? endMessage.encode() {
                session.send(data, toPeers: [peer], with: .reliable)
            }
            
            completion(true)
            return
        }
        
        let bytesToRead = min(Int64(chunkSize), fileSize - offset)
        
        do {
            fileHandle.seek(toFileOffset: offset)
            let chunkData = fileHandle.readData(ofLength: Int(bytesToRead))
            
            let totalChunks = Int((fileSize + Int64(chunkSize) - 1) / Int64(chunkSize))
            let message = FileMessage(
                type: .chunk,
                fileID: fileID,
                fileName: url.lastPathComponent,
                fileSize: fileSize,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                data: chunkData
            )
            
            if let data = try? message.encode() {
                session.send(data, toPeers: [peer], with: .reliable)
            }
            
            bytesSent += bytesToRead
            
            let elapsed = Date().timeIntervalSince1970 - startTime
            let speed = elapsed > 0 ? Double(bytesSent) / elapsed / 1024 : 0
            let eta = speed > 0 ? Double(fileSize - bytesSent) / speed / 1024 : 0
            
            progressUpdate((bytesSent: bytesSent, speed: speed, eta: eta))
            
            sendNextChunk(chunkIndex: chunkIndex + 1)
            
        } catch {
            closeFileHandle()
            completion(false)
        }
    }
    
    private func closeFileHandle() {
        fileHandle?.closeFile()
        fileHandle = nil
    }
    
    func cancel() {
        isCancelled = true
    }
}

class ActiveReceive {
    let fileID: String
    let fileName: String
    let fileSize: Int64
    let totalChunks: Int
    var receivedChunks: [Int: Data] = [:]
    var startTime: TimeInterval = 0
    var bytesReceived: Int64 = 0
    
    let progressUpdate: ((bytesReceived: Int64, speed: Double, eta: TimeInterval)) -> Void
    let completion: (URL?) -> Void
    
    init(fileID: String, fileName: String, fileSize: Int64, totalChunks: Int,
         progressUpdate: @escaping ((bytesReceived: Int64, speed: Double, eta: TimeInterval)) -> Void,
         completion: @escaping (URL?) -> Void) {
        self.fileID = fileID
        self.fileName = fileName
        self.fileSize = fileSize
        self.totalChunks = totalChunks
        self.progressUpdate = progressUpdate
        self.completion = completion
        self.startTime = Date().timeIntervalSince1970
    }
    
    func addChunk(index: Int, data: Data) {
        receivedChunks[index] = data
        bytesReceived += Int64(data.count)
        
        if receivedChunks.count == totalChunks {
            assembleFile()
        } else {
            let elapsed = Date().timeIntervalSince1970 - startTime
            let speed = elapsed > 0 ? Double(bytesReceived) / elapsed / 1024 : 0
            let eta = speed > 0 ? Double(fileSize - bytesReceived) / speed / 1024 : 0
            progressUpdate((bytesReceived: bytesReceived, speed: speed, eta: eta))
        }
    }
    
    private func assembleFile() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDir.appendingPathComponent(fileName)
        let safeURL = getSafeFileURL(baseURL: documentsDir, fileName: fileName)
        
        do {
            try FileManager.default.createFile(atPath: safeURL.path, contents: nil)
            let fileHandle = try FileHandle(forWritingTo: safeURL)
            
            for i in 0..<totalChunks {
                if let chunkData = receivedChunks[i] {
                    fileHandle.write(chunkData)
                }
            }
            
            fileHandle.closeFile()
            completion(safeURL)
        } catch {
            completion(nil)
        }
    }
    
    private func getSafeFileURL(baseURL: URL, fileName: String) -> URL {
        let fileURL = baseURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return fileURL
        }
        
        let fileExtension = fileName.components(separatedBy: ".").last ?? ""
        let fileNameWithoutExtension = fileExtension.isEmpty ? fileName : fileName.dropLast(fileExtension.count + 1)
        
        var counter = 1
        while true {
            let newFileName: String
            if fileExtension.isEmpty {
                newFileName = "\(fileNameWithoutExtension) (\(counter))"
            } else {
                newFileName = "\(fileNameWithoutExtension) (\(counter)).\(fileExtension)"
            }
            let newURL = baseURL.appendingPathComponent(newFileName)
            if !FileManager.default.fileExists(atPath: newURL.path) {
                return newURL
            }
            counter += 1
        }
    }
}

enum FileMessageType: UInt8 {
    case start = 0x01
    case chunk = 0x02
    case end = 0x03
}

struct FileMessage {
    let type: FileMessageType
    let fileID: String
    let fileName: String
    let fileSize: Int64
    let chunkIndex: Int
    let totalChunks: Int
    let data: Data
    
    func encode() throws -> Data {
        var data = Data()
        
        data.append(type.rawValue)
        
        let fileIDData = fileID.data(using: .utf8)!
        let fileIDLength = UInt32(fileIDData.count).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: fileIDLength) { Array($0) })
        data.append(fileIDData)
        
        let fileNameData = fileName.data(using: .utf8)!
        let fileNameLength = UInt32(fileNameData.count).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: fileNameLength) { Array($0) })
        data.append(fileNameData)
        
        let fileSizeBE = fileSize.bigEndian
        data.append(contentsOf: withUnsafeBytes(of: fileSizeBE) { Array($0) })
        
        let chunkIndexBE = UInt32(chunkIndex).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: chunkIndexBE) { Array($0) })
        
        let totalChunksBE = UInt32(totalChunks).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: totalChunksBE) { Array($0) })
        
        let dataLength = UInt32(self.data.count).bigEndian
        data.append(contentsOf: withUnsafeBytes(of: dataLength) { Array($0) })
        data.append(self.data)
        
        return data
    }
    
    static func decode(from data: Data) throws -> FileMessage {
        var index = 0
        
        guard index < data.count else { throw DecodingError.dataCorrupted }
        
        let typeRaw = data[index]
        guard let type = FileMessageType(rawValue: typeRaw) else { throw DecodingError.typeInvalid }
        index += 1
        
        guard index + 4 <= data.count else { throw DecodingError.dataCorrupted }
        let fileIDLength = UInt32(bigEndian: data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        index += 4
        
        guard index + Int(fileIDLength) <= data.count else { throw DecodingError.dataCorrupted }
        let fileIDData = data.subdata(in: index..<index+Int(fileIDLength))
        guard let fileID = String(data: fileIDData, encoding: .utf8) else { throw DecodingError.stringInvalid }
        index += Int(fileIDLength)
        
        guard index + 4 <= data.count else { throw DecodingError.dataCorrupted }
        let fileNameLength = UInt32(bigEndian: data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        index += 4
        
        guard index + Int(fileNameLength) <= data.count else { throw DecodingError.dataCorrupted }
        let fileNameData = data.subdata(in: index..<index+Int(fileNameLength))
        guard let fileName = String(data: fileNameData, encoding: .utf8) else { throw DecodingError.stringInvalid }
        index += Int(fileNameLength)
        
        guard index + 8 <= data.count else { throw DecodingError.dataCorrupted }
        let fileSize = Int64(bigEndian: data.subdata(in: index..<index+8).withUnsafeBytes { $0.load(as: Int64.self) })
        index += 8
        
        guard index + 4 <= data.count else { throw DecodingError.dataCorrupted }
        let chunkIndex = UInt32(bigEndian: data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        index += 4
        
        guard index + 4 <= data.count else { throw DecodingError.dataCorrupted }
        let totalChunks = UInt32(bigEndian: data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        index += 4
        
        guard index + 4 <= data.count else { throw DecodingError.dataCorrupted }
        let dataLength = UInt32(bigEndian: data.subdata(in: index..<index+4).withUnsafeBytes { $0.load(as: UInt32.self) })
        index += 4
        
        guard index + Int(dataLength) <= data.count else { throw DecodingError.dataCorrupted }
        let messageData = data.subdata(in: index..<index+Int(dataLength))
        
        return FileMessage(
            type: type,
            fileID: fileID,
            fileName: fileName,
            fileSize: fileSize,
            chunkIndex: Int(chunkIndex),
            totalChunks: Int(totalChunks),
            data: messageData
        )
    }
    
    enum DecodingError: Error {
        case dataCorrupted
        case typeInvalid
        case stringInvalid
    }
}