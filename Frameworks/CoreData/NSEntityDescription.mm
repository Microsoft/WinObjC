//******************************************************************************
//
// Copyright (c) 2016 Microsoft Corporation. All rights reserved.
//
// This code is licensed under the MIT License (MIT).
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//******************************************************************************

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>
#import <StubReturn.h>

#import <CoreData/NSManagedObjectModel-XMLParsing.h>

@interface NSEntityDescription () {
    NSManagedObjectModel* _managedObjectModel;
    // GH#2862
    // https://bugs.llvm.org/show_bug.cgi?id=25343
    // New template rules in Clang >= 6.0.0 combined with a _lack_ of
    // new mangling rules for Objective-C generics causes this to emit
    // a spurious "definition with same mangled name as another definition"
    // in SmartTypes.h.
    StrongId<NSArray/*<NSPropertyDescription*>*/> _properties;
    StrongId<NSArray/*<NSEntityDescription*>*/> _subentities;
    StrongId<NSMutableArray/*<NSPropertyDescription*>*/> _unresolvedProperties;
}
@property (readwrite, assign) NSEntityDescription* superentity;
@property (readwrite, copy) NSDictionary* subentitiesByName;
@property (readwrite, copy) NSDictionary* propertiesByName;
@property (readwrite, copy) NSDictionary* attributesByName;
@property (readwrite, copy) NSDictionary* relationshipsByName;
@end

@implementation NSEntityDescription
- (instancetype)_initWithXMLElementName:(NSString*)entityName attributes:(NSDictionary<NSString*, NSString*>*)attributes {
    if (self = [super init]) {
        // Properties not herein set are set via child entity parsing.
        _unresolvedProperties = [NSMutableArray new];
        _name = [attributes[@"name"] copy];
        _managedObjectClassName = [attributes[@"representedClassName"] copy];
        _renamingIdentifier = [attributes[@"elementID"] copy];
        _versionHashModifier = [attributes[@"versionHashModifier"] copy];
        _abstract = [attributes[@"isAbstract"] isEqualToString:@"YES"];
    }
    return self;
}

- (void)dealloc {
    [_name release];
    [_managedObjectClassName release];
    [_renamingIdentifier release];
    [_userInfo release];
    [_compoundIndexes release];
    [_uniquenessConstraints release];
    [_versionHash release];
    [_versionHashModifier release];

    // derived properties
    [_subentitiesByName release];
    [_propertiesByName release];
    [_attributesByName release];
    [_relationshipsByName release];

    [super dealloc];
}

- (NSManagedObjectModel*)managedObjectModel {
    @synchronized(self) {
        return _managedObjectModel;
    }
}

- (void)setManagedObjectModel:(NSManagedObjectModel*)model {
    @synchronized(self) {
        _managedObjectModel = model;
    }
}

- (bool)_insertChildElement:(id<_NSCDXMLCoding>)childElement {
    if ([childElement isKindOfClass:[NSPropertyDescription class]]) {
        [_unresolvedProperties addObject:static_cast<NSPropertyDescription*>(childElement)];
        return YES;
    }
    return NO;
}

- (NSArray<NSPropertyDescription*>*)properties {
    @synchronized(self) {
        return _properties;
    }
}

- (void)setProperties:(NSArray*)properties {
    @synchronized(self) {
        _properties.attach([properties copy]);

        NSMutableDictionary* propertiesByName = [NSMutableDictionary dictionary];
        NSMutableDictionary* attributesByName = [NSMutableDictionary dictionary];
        NSMutableDictionary* relationshipsByName = [NSMutableDictionary dictionary];
        for (NSPropertyDescription* prop in (id)_properties) {
            [prop setEntity:self];
            propertiesByName[prop.name] = prop;
            if ([prop isKindOfClass:[NSAttributeDescription class]]) {
                attributesByName[prop.name] = prop;
            } else if ([prop isKindOfClass:[NSRelationshipDescription class]]) {
                relationshipsByName[prop.name] = prop;
            }
        }

        self.propertiesByName = propertiesByName;
        self.attributesByName = attributesByName;
        self.relationshipsByName = relationshipsByName;
    }
}

- (NSArray<NSEntityDescription*>*)subentities {
    @synchronized(self) {
        return _subentities;
    }
}

- (void)setSubentities:(NSArray*)subentities {
    @synchronized(self) {
        _subentities.attach([subentities copy]);

        NSMutableDictionary* subentitiesByName = [NSMutableDictionary dictionary];
        for (NSEntityDescription* subentity in (id)_subentities) {
            subentitiesByName[subentity.name] = subentity;
            subentity.managedObjectModel = _managedObjectModel;
            subentity.superentity = self;
        }

        self.subentitiesByName = subentitiesByName;
    }
}

- (void)_awakeFromXML {
    self.properties = _unresolvedProperties;
    for (NSPropertyDescription* prop in (id)_unresolvedProperties) {
        [prop _awakeFromXML];
    }
    _unresolvedProperties = nil;
}

- (void)_resolveRelationships {
    // This should only be done once the model above us is stabilized.
    for (NSRelationshipDescription* relationship in [_relationshipsByName allValues]) {
        relationship.destinationEntity = [_managedObjectModel.entitiesByName objectForKey:relationship._destinationEntityName];

        NSEntityDescription* inverseEntity = [_managedObjectModel.entitiesByName objectForKey:relationship._inverseEntityName];

        relationship.inverseRelationship = [inverseEntity.relationshipsByName objectForKey:relationship._inverseRelationshipName];
        if (relationship._inverseEntityName != nil && relationship.inverseRelationship == nil) {
            FAIL_FAST_MSG("NSRelationshipDescription has an inverse entity, but no inverse relationship. Broken model?");
        }
    }
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@ %p: %@; attrs=%@ userInfo=%@ indexes=%@ constraints=%@ subentities=%@>",
                                      object_getClass(self),
                                      self,
                                      _name,
                                      _propertiesByName,
                                      _userInfo,
                                      _compoundIndexes,
                                      _uniquenessConstraints,
                                      _subentitiesByName];
}

/**
@Status Stub
@Notes
*/
- (BOOL)isKindOfEntity:(NSEntityDescription*)entity {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
- (NSArray*)relationshipsWithDestinationEntity:(NSEntityDescription*)entity {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
+ (NSEntityDescription*)entityForName:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)context {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
+ (NSManagedObject*)insertNewObjectForEntityForName:(NSString*)entityName inManagedObjectContext:(NSManagedObjectContext*)context {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
- (id)copy {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
- (instancetype)initWithCoder:(NSCoder*)decoder {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    UNIMPLEMENTED();
}

/**
@Status Stub
@Notes
*/
- (id)copyWithZone:(NSZone*)zone {
    UNIMPLEMENTED();
    return StubReturn();
}

/**
@Status Stub
@Notes
*/
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState*)state objects:(id _Nonnull[])stackbuf count:(NSUInteger)len {
    UNIMPLEMENTED();
    return StubReturn();
}

@end
