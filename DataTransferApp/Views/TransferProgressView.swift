import SwiftUI

struct TransferProgressView: View {
    @ObservedObject var transferManager: FileTransferManager
    
    var body: some View {
        VStack(spacing: 0) {
            TabView {
                VStack {
                    if transferManager.sendProgress.isEmpty {
                        Text("暂无发送任务")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List {
                            ForEach(transferManager.sendProgress) { progress in
                                ProgressRow(progress: progress, direction: .send)
                            }
                        }
                    }
                }
                .tabItem {
                    Image(systemName: "arrow.up")
                    Text("发送中")
                }
                
                VStack {
                    if transferManager.receiveProgress.isEmpty {
                        Text("暂无接收任务")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List {
                            ForEach(transferManager.receiveProgress) { progress in
                                ProgressRow(progress: progress, direction: .receive)
                            }
                        }
                    }
                }
                .tabItem {
                    Image(systemName: "arrow.down")
                    Text("接收中")
                }
            }
        }
        .navigationTitle("传输进度")
    }
}

enum TransferDirection {
    case send
    case receive
}

struct ProgressRow: View {
    let progress: TransferProgress
    let direction: TransferDirection
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: fileIcon)
                    .font(.title)
                    .foregroundColor(iconColor)
                
                VStack(alignment: .leading) {
                    Text(progress.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(FileUtils.formatFileSize(progress.transferredBytes)) / \(FileUtils.formatFileSize(progress.fileSize))")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            
            ProgressView(value: progress.progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle())
                .accentColor(progressColor)
            
            HStack {
                if progress.status == .transferring {
                    Text("\(String(format: "%.1f", progress.progress))%")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", progress.speed)) KB/s")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if progress.estimatedTimeRemaining > 0 {
                        Text("剩余 \(FileUtils.formatTime(progress.estimatedTimeRemaining))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
    }
    
    private var fileIcon: String {
        switch progress.status {
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        default:
            return "file"
        }
    }
    
    private var iconColor: Color {
        switch progress.status {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return direction == .send ? .blue : .orange
        }
    }
    
    private var statusText: String {
        switch progress.status {
        case .pending:
            return "等待中"
        case .transferring:
            return "传输中"
        case .paused:
            return "已暂停"
        case .completed:
            return "已完成"
        case .failed:
            return "失败"
        }
    }
    
    private var statusColor: Color {
        switch progress.status {
        case .completed:
            return .green
        case .failed:
            return .red
        case .paused:
            return .orange
        default:
            return .blue
        }
    }
    
    private var progressColor: Color {
        switch progress.status {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return direction == .send ? .blue : .orange
        }
    }
    
}