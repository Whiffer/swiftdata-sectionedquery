//
//  SectionedQuery.swift
//  swiftdata-sectionedquery
//
//  Created by Chuck Hartman on 6/13/23.
//

import SwiftUI
import SwiftData
import CoreData
import Algorithms

@MainActor @propertyWrapper public struct SectionedQuery<SectionIdentifier, Result> where SectionIdentifier : Hashable, Result : PersistentModel {

    @State private var configuration: Configuration
    private var animation: Animation?
    
    @State private var sections = [SectionedResults<SectionIdentifier, Result>.Section<Result>]()
    @State private var needsFetch = true
    @State private var notificationsTask: Task<Void, Never>?
    
    // As of macOS Sonoma Release Candidate, ModelContext.didSave Notifications are not being sent, so until they are,
    // Core Data's NSManagedObjectContext.didSaveObjectsNotification is being used instead
    
    // At some point this probably should be changed to the line below it
    private let didSave = NSManagedObjectContext.didSaveObjectsNotification
    // private let didSave = ModelContext.didSave

    @Environment(\.modelContext) private var modelContext

    @MainActor public init(sectionIdentifier: KeyPath<Result, SectionIdentifier>, sortDescriptors: [SortDescriptor<Result>], predicate: Predicate<Result>? = nil, animation: Animation? = nil) {
        
        let configuration = Configuration(sectionIdentifier: sectionIdentifier, sortDescriptors: sortDescriptors, predicate: predicate)
        self._configuration = State(initialValue: configuration)
        
        self.animation = animation
    }
    
    @MainActor public var wrappedValue: SectionedResults<SectionIdentifier, Result> {
        get { return  SectionedResults<SectionIdentifier, Result>(sections: self.sections, configuration: self.$configuration, needsFetch: self.$needsFetch) }
    }
    
    @MainActor public var projectedValue: Binding<Configuration> {
        Binding(get: { self.configuration },
                set: { self.configuration = $0 })
    }
    
    public struct Configuration {
        public var sectionIdentifier: KeyPath<Result, SectionIdentifier>
        public var sortDescriptors: [SortDescriptor<Result>]
        public var predicate: Predicate<Result>?
    }
}

extension SectionedQuery : DynamicProperty {
    
    @MainActor public func update() {
        Task {
            if self.needsFetch {
                self.setupNotificationsTask()
                
                withAnimation(self.animation) {
                    self.fetchSectionedResults()
                    self.needsFetch = false
                }
            }
        }
    }
    
    private func setupNotificationsTask() {
        
        if self.notificationsTask == nil {
            // Start a never ending Task to monitor when the ModelContext has saved changes
            self.notificationsTask = Task {
                //Workaround: https://developer.apple.com/forums/thread/718565
                for await /*name*/ _ in NotificationCenter.default.notifications(named: self.didSave).map( { $0.name } ) {
                    // print("Observed: \(name.rawValue)")
                    // Model Context has changes so need to reexecute the Fetch
                    self.needsFetch = true
                }
            }
        }
    }
    
    private func fetchSectionedResults() {
        
        let fetchDescriptor = FetchDescriptor<Result>(predicate: self.configuration.predicate, sortBy: self.configuration.sortDescriptors)
        
        guard let fetchResults = try? self.modelContext.fetch(fetchDescriptor) else {
            fatalError("Unresolved error")
        }
        
        let sectionIdentifiers = fetchResults.map { $0[keyPath: self.configuration.sectionIdentifier] }
        let uniqueSectionIdentifiers = Array(sectionIdentifiers.uniqued())

        let sections = uniqueSectionIdentifiers.map { sectionIdentifier in
            
            guard let firstIndex = fetchResults.firstIndex(where: { sectionIdentifier == $0[keyPath: self.configuration.sectionIdentifier] } ) else {
                fatalError("Unresolved error")
            }
            guard let lastIndex = fetchResults.lastIndex(where: { sectionIdentifier == $0[keyPath: self.configuration.sectionIdentifier] } ) else {
                fatalError("Unresolved error")
            }

            let sectionElements = Array(fetchResults[firstIndex...lastIndex])
            return SectionedResults<SectionIdentifier, Result>.Section(id: sectionIdentifier, elements: sectionElements )
        }
        
        self.sections = sections
    }

}

public struct SectionedResults<SectionIdentifier, Result> : RandomAccessCollection where SectionIdentifier : Hashable, Result : PersistentModel {
    
    // Bindings from Property Wrapper
    private var configuration: Binding<SectionedQuery<SectionIdentifier, Result>.Configuration>
    private var needsFetch: Binding<Bool>
    
    // For projectedValue
    public var sortDescriptors: [SortDescriptor<Result>] {
        get { return self.configuration.wrappedValue.sortDescriptors }
        nonmutating set {
            self.configuration.wrappedValue.sortDescriptors = newValue
            self.needsFetch.wrappedValue = true
        }
    }
    
    public var predicate: Predicate<Result>? {
        get { return self.configuration.wrappedValue.predicate }
        nonmutating set {
            self.configuration.wrappedValue.predicate = newValue
            self.needsFetch.wrappedValue = true
        }
    }

    public var sectionIdentifier: KeyPath<Result, SectionIdentifier> {
        get { return self.configuration.wrappedValue.sectionIdentifier }
        nonmutating set {
            self.configuration.wrappedValue.sectionIdentifier = newValue
            self.needsFetch.wrappedValue = true
        }
    }

    // For RandomAccessCollection
    public var startIndex = 0
    public var endIndex: Int { get { self.sections.count } }
    public subscript(position: Int) -> SectionedResults<SectionIdentifier, Result>.Section<Result> { get { self.sections[position] } }
    public typealias Element = SectionedResults<SectionIdentifier, Result>.Section
    public typealias Index = Int
    
    private var sections: [SectionedResults<SectionIdentifier, Result>.Section<Result>]

    init(sections: [SectionedResults<SectionIdentifier, Result>.Section<Result>], configuration: Binding<SectionedQuery<SectionIdentifier, Result>.Configuration>, needsFetch: Binding<Bool> ) {
        self.sections = sections
        self.configuration = configuration
        self.needsFetch = needsFetch
    }
    
    public struct Section<Element> : Identifiable, RandomAccessCollection where Element : PersistentModel {
        
        // For Identifiable
        public let id: SectionIdentifier
        
        // For RandomAccessCollection
        public var startIndex: Int = 0
        public var endIndex: Int { get { self.elements.count } }
        public subscript(position: Int) -> Element { get { self.elements[position] } }
        public typealias Element = Element
        public typealias Index = Int

        private var elements: [Element]
        
        init(id: SectionIdentifier, elements: [Element]) {
            self.id = id
            self.elements = elements
        }
    }

}
