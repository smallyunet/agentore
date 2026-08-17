#!/usr/bin/env swift

import Foundation

struct IconRepresentation {
    let type: String
    let filename: String
}

let representations = [
    IconRepresentation(type: "icp4", filename: "icon_16x16.png"),
    IconRepresentation(type: "ic11", filename: "icon_16x16@2x.png"),
    IconRepresentation(type: "icp5", filename: "icon_32x32.png"),
    IconRepresentation(type: "ic12", filename: "icon_32x32@2x.png"),
    IconRepresentation(type: "ic07", filename: "icon_128x128.png"),
    IconRepresentation(type: "ic13", filename: "icon_128x128@2x.png"),
    IconRepresentation(type: "ic08", filename: "icon_256x256.png"),
    IconRepresentation(type: "ic14", filename: "icon_256x256@2x.png"),
    IconRepresentation(type: "ic09", filename: "icon_512x512.png"),
    IconRepresentation(type: "ic10", filename: "icon_512x512@2x.png")
]

func bigEndianData(_ value: UInt32) -> Data {
    var encoded = value.bigEndian
    return Data(bytes: &encoded, count: MemoryLayout<UInt32>.size)
}

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: make-icns.swift <iconset> <output.icns>\n".utf8))
    exit(64)
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
var body = Data()

for representation in representations {
    let png = try Data(contentsOf: iconset.appendingPathComponent(representation.filename))
    guard let type = representation.type.data(using: .ascii), type.count == 4 else {
        throw CocoaError(.fileWriteUnknown)
    }
    body.append(type)
    body.append(bigEndianData(UInt32(png.count + 8)))
    body.append(png)
}

var container = Data("icns".utf8)
container.append(bigEndianData(UInt32(body.count + 8)))
container.append(body)
try container.write(to: output, options: .atomic)
