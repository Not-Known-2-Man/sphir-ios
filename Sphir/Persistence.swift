//
//  Persistence.swift
//  Sphir
//
//  CoreData stack. The model is defined programmatically (so it doesn't
//  depend on the .xcdatamodeld), and the store lives in the App Group
//  container so it persists across launches and shares a location with the
//  share extension's data.
//

import CoreData

final class PersistenceController {
    /// Shared instance. Uses an in-memory store during UI tests so runs start
    /// from a clean, deterministic state.
    static let shared = PersistenceController(
        inMemory: ProcessInfo.processInfo.arguments.contains("UITEST")
    )

    let container: NSPersistentContainer

    private static let appGroupID = "group.com.sphir.shared"
    private static let storeName = "Sphir.sqlite"

    init(inMemory: Bool = false, storeURL: URL? = nil) {
        container = NSPersistentContainer(
            name: "SphirStore",
            managedObjectModel: PersistenceController.model
        )

        let description = NSPersistentStoreDescription()
        if inMemory {
            description.type = NSInMemoryStoreType
        } else if let storeURL {
            description.url = storeURL
        } else if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            description.url = groupURL.appendingPathComponent(Self.storeName)
        }
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                // Don't crash the app; log so the issue is visible in dev.
                print("Sphir CoreData store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// Delete all collections and cards from the store.
    func wipeAllData() {
        let context = container.viewContext
        for entity in ["CDCard", "CDCollection"] {
            let request = NSFetchRequest<NSManagedObject>(entityName: entity)
            if let objects = try? context.fetch(request) {
                for object in objects {
                    context.delete(object)
                }
            }
        }
        try? context.save()
    }

    // MARK: - Programmatic model

    static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        func attribute(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = true,
            external: Bool = false
        ) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            if external { attr.allowsExternalBinaryDataStorage = true }
            return attr
        }

        let collection = NSEntityDescription()
        collection.name = "CDCollection"
        collection.managedObjectClassName = "NSManagedObject"
        collection.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("name", .stringAttributeType),
            attribute("collectionDescription", .stringAttributeType),
            attribute("privacy", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("serverID", .stringAttributeType),
            // Added after v1: optional, so the store migrates automatically (lightweight).
            attribute("isDefault", .booleanAttributeType)
        ]

        let card = NSEntityDescription()
        card.name = "CDCard"
        card.managedObjectClassName = "NSManagedObject"
        card.properties = [
            attribute("id", .UUIDAttributeType, optional: false),
            attribute("title", .stringAttributeType),
            attribute("cardDescription", .stringAttributeType),
            attribute("content", .stringAttributeType),
            attribute("cardType", .stringAttributeType),
            attribute("sourceApp", .stringAttributeType),
            attribute("imageURL", .stringAttributeType),
            attribute("imageData", .binaryDataAttributeType, external: true),
            attribute("tagsJSON", .stringAttributeType),
            attribute("syncStatus", .stringAttributeType),
            attribute("createdAt", .dateAttributeType),
            attribute("collectionID", .UUIDAttributeType),
            attribute("serverID", .stringAttributeType),
            attribute("price", .stringAttributeType),
            attribute("folderIDsJSON", .stringAttributeType)
        ]

        model.entities = [collection, card]
        return model
    }()
}
