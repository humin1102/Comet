//
//  Path.swift
//  Comet
//
//  Created by Harley.xk on 16/6/27.
//
//

import Foundation
import MobileCoreServices

// MARK: - 文件路径，快速获取各种文件路径

open class Path {
    
    /// 使用路径字符串构建实例
    public init(_ path: String) {
        url = URL(fileURLWithPath: path)
    }
    
    /// 包装 URL 路径
    public init(_ path: URL) {
        url = path
    }
    
    public init(directory: FileManager.SearchPathDirectory, create: Bool = false) throws {
        url = try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: create)
    }
    
    /// 完整路径字符串
    open var string: String {
        return url.relativePath
    }
    
    /// URL 实例
    open var url: URL
    
    /// 获取沙盒 Documents 路
    open class func documents() -> Path {
        return try! Path(directory: .documentDirectory)
    }
    
    /// 获取沙盒 Library 路径
    open class func library() -> Path {
        return try! Path(directory: .libraryDirectory)
    }
    
    /// 获取沙盒 Cache 路径
    open class func cache() -> Path {
        return try! Path(directory: .cachesDirectory)
    }
    
    /// 获取沙盒 Temp 路径
    open class func temp() -> Path {
        return Path(NSTemporaryDirectory())
    }
    
    /// 获取沙盒 Application Support 路径，不存在时会自动创建
    open class func applicationSupport(autoCreate: Bool = true) throws -> Path {
        let path = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: autoCreate)
        return Path(path)
    }
    
    /// 获取当前目录下的资源文件路径
    ///
    /// - Parameter name: 资源文件名（含扩展名）
    open func resource(_ name: String) -> Path {
        let res = url.appendingPathComponent(name, isDirectory: false)
        return Path(res)
    }
    
    /// 获取当前目录下的子目录
    ///
    /// - Parameter name: 资源文件名（含扩展名）
    open func folder(_ name: String) -> Path {
        let res = url.appendingPathComponent(name, isDirectory: true)
        return Path(res)
    }
    
    // MARK: - Path Utils
    /// 文件管理器
    open var fileManager: FileManager {
        return FileManager.default
    }
    
    /// 路径是否存在，无论文件或者文件夹
    open var exist: Bool {
        return fileManager.fileExists(atPath: string)
    }
    
    /// 文件是否存在, 返回是否存在，以及是否是文件
    open var fileExist: (exist: Bool, isFile: Bool) {
        var isDirectory = ObjCBool(false)
        let exist = fileManager.fileExists(atPath: string, isDirectory: &isDirectory)
        return (exist, !isDirectory.boolValue)
    }
    
    /// 文件夹是否存在, 返回是否存在，(以及必须是文件夹)
    open var folderExist: Bool {
        let info = fileExist
        return info.exist && !info.isFile
    }
    
    /// 文件扩展名
    open var pathExtension: String? {
        return url.pathExtension
    }
    
    /// 创建路径
    open func createDirectory() throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    /// 删除当前路径指向的物理文件(夹)
    open func removeFromDisk() throws {
        try fileManager.removeItem(at: url)
    }
    
    /// 获取文件夹子目录
    open func getChildren(skipsHiddenFiles: Bool = true) throws -> [Path] {
        guard folderExist else {
            return []
        }
        var options = FileManager.DirectoryEnumerationOptions()
        if skipsHiddenFiles {
            options = options.union(.skipsHiddenFiles)
        }
        let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: options)
        return contents.map { Path($0) }
    }
    
    open var attributes: FileAttribute? {
        if let attributes = try? fileManager.attributesOfItem(atPath: string) {
            return FileAttribute(attributes: attributes)
        }
        return nil
    }
    
    /// 获取文件 mime type
    open var mimeType: String? {
        if let ext = pathExtension as NSString? {
            if let UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, ext, nil)?.takeUnretainedValue() {
                if let MIMEType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType) {
                    let mimeTypeCFString = MIMEType.takeUnretainedValue() as CFString
                    return mimeTypeCFString as String
                }
            }
        }
        return nil
    }
    
    /// 对该目录禁用 iCloud 自动备份
    open func disableAutoBackup() {
        let existInfo = fileExist
        guard existInfo.exist, !existInfo.isFile else {
            return
        }
        var url = self.url
        url.setTemporaryResourceValue(true, forKey: .isExcludedFromBackupKey)
    }
    
    /// 获取文件大小，如果是文件夹，会遍历整个目录及子目录计算所有文件大小
    open var size: UInt64 {
        let fileExist = self.fileExist
        if fileExist.exist {
            if fileExist.isFile {
                return fileSize()
            }else {
                return folderSize()
            }
        }
        return 0
    }
    
    /// 获取文件夹大小，并且格式化为可读字符串
    open var sizeString: String {
        return Path.string(fromBytes: size)
    }
    
    /// 转换字节数为最大单位可读字符串
    open class func string(fromBytes bytes: UInt64) -> String {
        let kb = Double(bytes)/1024;
        if (kb < 1) {
            return "\(bytes)B"
        }
        let mb = kb/1024.0;
        if (mb < 1) {
            return String(format: "%.0fKB", kb)
        }
        let gb = mb/1024.0;
        if (gb < 1) {
            return String(format: "%.1fMB", mb)
        }
        let tb = gb/1024.0;
        if (tb < 1) {
            return String(format: "%.1fG", gb)
        } else {
            return String(format: "%.1fT", tb)
        }
    }
    
    // MARK: - Datas
    open func readData(options: Data.ReadingOptions = []) throws -> Data {
        return try Data(contentsOf: url, options: options)
    }
    
    // MARK: - Private
    internal func fileSize() -> UInt64 {
        let fileExist = self.fileExist
        if fileExist.exist && fileExist.isFile {
            if let attributes = try? fileManager.attributesOfItem(atPath: string) as NSDictionary {
                return attributes.fileSize()
            }
        }
        return 0
    }
    
    internal func folderSize() -> UInt64 {
        var folderSize: UInt64 = 0
        
        let fileExist = self.fileExist
        if fileExist.exist && !fileExist.isFile {
            if let contents = try? fileManager.contentsOfDirectory(atPath: string) {
                for file in contents {
                    let path = resource(file)
                    let subFileExist = path.fileExist
                    if subFileExist.exist {
                        if subFileExist.isFile {
                            folderSize += path.fileSize()
                        }else {
                            folderSize += path.folderSize()
                        }
                    }
                }
            }
        }
        return folderSize
    }
}