//
//  DeviceModel.swift
//  DeviceKit
//
//  Created by AnhPT on 02/07/2026.
//

import Foundation

/// Maps raw hardware identifiers to marketing names and capability groups.
/// Intentionally lean: a curated table of recent hardware with a graceful
/// fallback to the raw identifier for anything newer.
enum DeviceModel {
    static func marketingName(for identifier: String) -> String {
        names[identifier] ?? identifier
    }

    /// Devices that ship with a Dynamic Island.
    static let dynamicIslandIdentifiers: Set<String> = [
        "iPhone15,2", "iPhone15,3",            // 14 Pro / Pro Max
        "iPhone16,1", "iPhone16,2",            // 15 Pro / Pro Max
        "iPhone17,3", "iPhone17,4",            // 16 / 16 Plus
        "iPhone17,1", "iPhone17,2",            // 16 Pro / Pro Max
        "iPhone15,4", "iPhone15,5",            // 15 / 15 Plus
    ]

    /// Face ID devices with a notch (no Dynamic Island).
    static let notchIdentifiers: Set<String> = [
        "iPhone10,3", "iPhone10,6",            // X
        "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8", // XS/XS Max/XR
        "iPhone12,1", "iPhone12,3", "iPhone12,5",               // 11 / 11 Pro / Max
        "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4", // 12 line
        "iPhone14,2", "iPhone14,3", "iPhone14,4", "iPhone14,5", // 13 line
        "iPhone14,7", "iPhone14,8",            // 14 / 14 Plus
    ]

    private static let names: [String: String] = [
        // iPhone
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        // iPad (recent)
        "iPad13,1": "iPad Air (4th generation)",
        "iPad13,16": "iPad Air (5th generation)",
        "iPad14,3": "iPad Pro 11-inch (4th generation)",
        "iPad14,5": "iPad Pro 12.9-inch (6th generation)",
        "iPad16,3": "iPad Pro 11-inch (M4)",
        "iPad16,5": "iPad Pro 13-inch (M4)",
        // iPod
        "iPod9,1": "iPod touch (7th generation)",
        // Simulator
        "Simulator": "Simulator",
    ]
}
