//
//  SchemaVersioning.swift
//  WriteVibe
//

import SwiftData

enum WriteVibeSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self]
    }
}

enum WriteVibeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WriteVibeSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        [] // No migrations yet — V1 is the baseline
    }
}
