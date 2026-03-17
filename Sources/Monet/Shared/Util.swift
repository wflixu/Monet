//
//  Util.swift
//  Monet
//
//  Created by 李旭 on 2024/9/5.
//

import Foundation
import ObjectiveC
import SwiftUI

// MARK: - AssociationPolicy

enum AssociationPolicy {
    case assign
    case copy
    case copyNonatomic
    case retain
    case retainNonatomic

    fileprivate var objcValue: objc_AssociationPolicy {
        switch self {
        case .assign:
            return .OBJC_ASSOCIATION_ASSIGN
        case .copy:
            return .OBJC_ASSOCIATION_COPY
        case .copyNonatomic:
            return .OBJC_ASSOCIATION_COPY_NONATOMIC
        case .retain:
            return .OBJC_ASSOCIATION_RETAIN
        case .retainNonatomic:
            return .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        }
    }
}

// MARK: - ObjectAssociation

final class ObjectAssociation<Value> {
    private let policy: AssociationPolicy

    private var key: UnsafeRawPointer {
        UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    }

    init(policy: AssociationPolicy = .retainNonatomic) {
        self.policy = policy
    }

    subscript(object: AnyObject) -> Value? {
        get { objc_getAssociatedObject(object, key) as? Value }
        set { objc_setAssociatedObject(object, key, newValue, policy.objcValue) }
    }
}


/// A type that produces a view representing an icon.
enum IconResource: Hashable {
    /// A resource derived from a system symbol.
    case systemSymbol(_ name: String)

    /// A resource derived from an asset catalog.
    case assetCatalog(_ resource: ImageResource)

    /// The view produced by the resource.
    var view: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
    }

    private var image: Image {
        switch self {
        case .systemSymbol(let name):
            Image(systemName: name)
        case .assetCatalog(let resource):
            Image(resource)
        }
    }
}



extension Bundle {
    /// The bundle's version string.
    ///
    /// This accessor looks for an associated value for either `CFBundleShortVersionString`
    /// or `CFBundleVersion` in the bundle's information property list (`Info.plist`)
    /// file. If a string value cannot be found for one of these keys, this accessor
    /// returns `nil`.
    var versionString: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ??
        object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
    var copyrightString: String? {
           object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
       }
}


struct PermissionDir: Identifiable {
    let url: URL
    let id = UUID()
    var path: String {
        url.path
    }
}
