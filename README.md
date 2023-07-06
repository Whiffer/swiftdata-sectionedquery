# swiftdata-sectionedquery

I created this package for several reasons.  I needed this capability sooner rather than later to make progress converting my Apps from Core Data to SwiftData, I wanted to learn a few new things about Swift and SwiftData, I viewed the project as a challenge to see if I could do it, and I had some free time to make it so.

It is fully expected that this package will become obsolete at some point when Apple supplys an official property wrapper with the same or similar capabilities.  At that point, this package may only be useful as an example of how to create a SwiftData based custom property wrapper.

In any case, this is a custom property wrapper type that retrieves entities, grouped into sections, from a SwiftData Model Context and was inspired by the SwiftUI @SectionedFetchRequest property wrapper that is used with a Core Data persistent store.

## Why use @SectionedQuery?

Use a `SectionedQuery` property wrapper to declare a ``SectionedResults`` property that provides a grouped collection of SwiftData PersistentModel objects to a SwiftUI view. If you don't need sectioning, use the ``Query`` property wrapper instead.

## Example

Configure a sectioned query with optional sort descriptors and predicate, and include a `sectionIdentifier` parameter to indicate how to group the query results. Be sure that you choose sorting and sectioning that work together to avoid discontiguous sections. 

The following example demonstrates how to use the `@SectionedQuery` property wrapper:

```swift
struct ContentView: View {
    @SectionedQuery(sectionIdentifier: \Attribute.item.name,
                    sortDescriptors: [SortDescriptor(\Attribute.item.order, order: .forward),
                                      SortDescriptor(\Attribute.order, order: .forward)],
                    predicate: nil,
                    animation: .default)
    private var sections
    
    var body: some View {
        List {
            ForEach(self.sections) { section in
                Section(header: Text("Section for Item '\(section.id)'")) {
                    ForEach(section, id: \.self) { attribute in
                        Text("Item[\(attribute.item.order)] '\(attribute.item.name)' Attribute[\(attribute.order)]")
                    }
                }
            }
        }
    }
}
```

A complete project that demonstrates how to use this property wrapper is available at: https://github.com/Whiffer/SampleSectionedQuery

## Usage Notes

Always declare properties that have a sectioned query wrapper as private. This lets the compiler help you avoid accidentally setting the property from the memberwise initializer of the enclosing view.

The query infers the entity type from the `Result` type that you specify, which is `Attribute` in the example above. Indicate a `SectionIdentifier` type to declare the type found at the fetched object's `sectionIdentifier` key path. The section identifier type must conform to the `Hashable` protocol.

The sectioned query and its results use the model context stored in the environment, which you can access using the ``EnvironmentValues/modelContext`` environment value.

