//******************************************************************************
//
// Copyright (c) 2015 Microsoft Corporation. All rights reserved.
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

#import "Starboard.h"
#import "Foundation/NSMutableDictionary.h"
#import "Foundation/NSMutableArray.h"
#import "Foundation/NSMutableData.h"
#import "Foundation/NSString.h"
#import "Foundation/NSNumber.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSPropertyListSerialization.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSAutoreleasePool.h"
#import "ForFoundationOnly.h"
#import "Etc.h"
#import "NSLogging.h"
#import "Hash.h"

static const wchar_t* TAG = L"NSKeyedArchiver";

typedef HashMap<id, unsigned> o2uHash;
typedef HashMap<id, id> o2oHash;

NSString* const NSInvalidArchiveOperationException = @"NSInvalidArchiveOperationException";

NSString* const NSKeyedArchiveRootObjectKey = @"NSKeyedArchiveRootObjectKey";
static HashMap<Class, StrongId<NSString>> s_clsMap;
struct NSKeyedArchiverPriv {
    HashMap<Class, StrongId<NSString>> clsMap; /* Map classes to names.    */
    o2uHash cIdMap; /* Conditionally coded.     */
    o2uHash uIdMap; /* Unconditionally coded.   */
    o2oHash repMap; /* Mappings for objects.    */
};

void printContents(int level, id obj);

static inline void _checkKey(NSString* aKey, NSMutableDictionary* _enc) {
    if (![aKey isKindOfClass:[NSString class]]) {
        NSTraceCritical(TAG, @"Key is not an NSString\n");
        assert(0);
    }
    if ([aKey hasPrefix:@"$"]) {
        aKey = [@"$" stringByAppendingString:aKey];
    }
    if ([_enc objectForKey:aKey] != nil) {
        NSTraceCritical(TAG, @"Key not found:%s\n", [aKey UTF8String]);
        assert(0);
    }
}

/*
* Make a dictionary referring to the object at objectId in the array of all objects.
*/
static id makeReference(unsigned objectId) {
    return [static_cast<id>(_CFKeyedArchiverUIDCreate(kCFAllocatorDefault, objectId)) autorelease];
}

@implementation NSKeyedArchiver {
    NSMutableData* _data;

    unsigned _keyNum;
    NSMutableDictionary* _enc;
    NSMutableArray* _obj;
    NSMutableArray* _retainList;

    struct NSKeyedArchiverPriv* _priv;
}

- (void)_encodeArrayOfObjects:(NSArray*)anArray forKey:(NSString*)aKey {
    id o;
    _checkKey(aKey, _enc);

    if (anArray == nil) {
        o = makeReference(0);
    } else {
        unsigned c = [anArray count];
        NSMutableArray* m = [NSMutableArray arrayWithCapacity:c];

        for (unsigned i = 0; i < c; i++) {
            o = [self _encodeObject:[anArray objectAtIndex:i] conditional:NO];
            [m addObject:o];
        }
        o = m;
    }
    [_enc setObject:o forKey:aKey];
}

- (void)_encodeRawObject:(NSObject*)object forKey:(NSString*)key {
    _checkKey(key, _enc);
    [_enc setObject:object forKey:key];
}

/**
 @Status Interoperable
*/
- (void)encodeInt:(int)anInteger forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithInt:anInteger] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeInteger:(int)anInteger forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithInt:anInteger] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeInt32:(int32_t)anInteger forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithLong:anInteger] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeInt64:(int64_t)anInteger forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithLongLong:anInteger] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeBool:(BOOL)aBool forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithBool:aBool] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeFloat:(float)aFloat forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithFloat:aFloat] forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeDouble:(double)aDouble forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSNumber numberWithDouble:aDouble] forKey:aKey];
}


/**
 @Status Interoperable
*/
- (void)encodeBytes:(const uint8_t*)aPointer length:(NSUInteger)length forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    [_enc setObject:[NSData dataWithBytes:aPointer length:length] forKey:aKey];
}

/**
 @Status Interoperable
*/
+ (NSData*)archivedDataWithRootObject:(id)anObject {
    NSMutableData* m = [[NSMutableData alloc] initWithCapacity:10240];
    NSKeyedArchiver* a = [[NSKeyedArchiver alloc] initForWritingWithMutableData:m];
    [a encodeObject:anObject forKey:@"root"];
    [a finishEncoding];
    NSMutableData* d = [m copy];
    [m release];
    [a release];
    return [d autorelease];
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    [_enc release];
    [_obj release];
    [_data release];
    [_retainList release];
    delete _priv;

    [super dealloc];
}

/**
 @Status Interoperable
*/
- (void)finishEncoding {
    id error;

    [_delegate archiverWillFinish:self];

    NSMutableDictionary* final = [NSMutableDictionary new];
    [final setObject:NSStringFromClass([self class]) forKey:@"$archiver"];
    [final setObject:[NSNumber numberWithInt:100000] forKey:@"$version"];
    [final setObject:_enc forKey:@"$top"];
    [final setObject:_obj forKey:@"$objects"];
    id data = [NSPropertyListSerialization dataFromPropertyList:final format:_outputFormat errorDescription:&error];
    [final release];
    [_data setData:data];
    [_delegate archiverDidFinish:self];
}

/**
 @Status Interoperable
*/
+ (BOOL)archiveRootObject:(id)anObject toFile:(NSString*)aPath {
    id pool = [NSAutoreleasePool new];
    id d;
    BOOL result;

    d = [self archivedDataWithRootObject:anObject];
    result = [d writeToFile:aPath atomically:YES];
    [pool release];
    return result;
}

/**
 @Status Interoperable
*/
- (instancetype)initForWritingWithMutableData:(NSMutableData*)data {
    self = [super init];
    if (self) {
        _priv = new NSKeyedArchiverPriv;

        _keyNum = 0;
        _data = [data retain];

        _enc = [NSMutableDictionary new]; // Top level mapping dict
        _obj = [NSMutableArray new]; // Array of objects.
        _retainList = [NSMutableArray new];
        [_obj addObject:@"$null"]; // Placeholder.

        _outputFormat = NSPropertyListBinaryFormat_v1_0;
    }
    return self;
}

/**
 @Status Interoperable
*/
- (void)encodeObject:(id)anObject forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    anObject = [self _encodeObject:anObject conditional:NO];
    [_enc setObject:anObject forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeObject:(id)anObject {
    NSString* aKey = [NSString stringWithFormat:@"$%u", _keyNum++];

    anObject = [self _encodeObject:anObject conditional:NO];
    [_enc setObject:anObject forKey:aKey];
}

/**
 @Status Interoperable
*/
- (void)encodeConditionalObject:(id)anObject forKey:(NSString*)aKey {
    _checkKey(aKey, _enc);
    anObject = [self _encodeObject:anObject conditional:YES];
    [_enc setObject:anObject forKey:aKey];
}

/*
* The real workhorse of the archiving process ... this deals with all
* archiving of objects. It returns the object to be stored in the
* mapping dictionary (_enc).
*/
- (NSDictionary*)_encodeObject:(id)anObject conditional:(BOOL)conditional {
    id original = anObject;
    id m = nil;

    if (anObject != nil) {
        // Obtain replacement object for the value being encoded.
        // Notify delegate of progress and set up new mapping if necessary.

        id* tempObj;
        if (_priv->repMap.get(anObject, tempObj)) {
            // If the object has a replacement, use it.
            anObject = *tempObj;
        } else {
            anObject = [original replacementObjectForKeyedArchiver:self];
            if (_delegate != nil) {
                if (anObject != nil)
                    anObject = [_delegate archiver:self willEncodeObject:anObject];
                if (original != anObject)
                    [_delegate archiver:self willReplaceObject:original withObject:anObject];
            }
            _priv->repMap.insert(original, anObject);

            //  Retain the original object
            [_retainList addObject:anObject];
        }
    }

    id objectInfo = nil; // Encoded object
    unsigned objectId = 0;
    unsigned* existingObjectId;

    if (anObject != nil) {
        if (_priv->uIdMap.get(anObject, existingObjectId)) {
            objectId = *existingObjectId;
        } else {
            if (conditional) {
                if (_priv->cIdMap.get(anObject, existingObjectId)) {
                    objectId = [_obj count];
                    _priv->cIdMap.insert(anObject, objectId);

                    // Use the null object as a placeholder for a conditionally encoded object.
                    [_obj addObject:[_obj objectAtIndex:0]];
                } else {
                    // This object has already been conditionally encoded.
                    objectId = *existingObjectId;
                }
            } else {
                id c = [anObject classForKeyedArchiver];

                // FIXME ... exactly what classes are stored directly???
                if (c == [NSString class] || c == [NSNumber class] || c == [NSData class]) {
                    objectInfo = anObject;
                } else {
                    // We store a dictionary describing the object.
                    m = [NSMutableDictionary new];
                    objectInfo = m;
                }

                if (_priv->cIdMap.get(anObject, existingObjectId)) {
                    // Conditionally encoded ... replace with actual value.
                    objectId = *existingObjectId;
                    _priv->uIdMap.insert(anObject, objectId);
                    _priv->cIdMap.remove(anObject);
                    [_obj replaceObjectAtIndex:objectId withObject:objectInfo];
                } else {
                    // Not encoded ... create dictionary for it.
                    objectId = [_obj count];
                    _priv->uIdMap.insert(anObject, objectId);
                    [_obj addObject:objectInfo];
                }
                [m release];
            }
        }
    }

    // Build an object to reference the encoded value of anObject
    id refObject = makeReference(objectId);

    // objectInfo is a dictionary describing the object.
    if (objectInfo != nil && m == objectInfo) {
        id savedEnc = _enc;
        unsigned savedKeyNum = _keyNum;
        id c = [anObject class];
        id classname;
        id mapped;

        /*
        * Map the class of the object to the actual class it is encoded as.
        * First ask the object, then apply any name mappings to that value.
        */
        mapped = [anObject classForKeyedArchiver];
        if (mapped != nil) {
            c = mapped;
        }

        classname = [self classNameForClass:c];
        if (classname == nil) {
            classname = [[self class] classNameForClass:c];
        }
        if (classname == nil) {
            classname = NSStringFromClass(c);
        } else {
            c = NSClassFromString(classname);
        }

        /*
        * At last, get the object to encode itself.  Save and restore the
        * current object scope of course.
        */
        _enc = m;
        _keyNum = 0;
        [anObject encodeWithCoder:self];
        _keyNum = savedKeyNum;
        _enc = savedEnc;

        /*
        * This is ugly, but it seems to be the way MacOS-X does it ...
        * We create class information by storing it directly into the
        * table of all objects, and making a reference so we can look
        * up the table entry by class pointer.
        * A much cleaner way to do it would be by encoding the class
        * normally, but we are trying to be compatible.
        *
        * Also ... we encode the class *after* encoding the instance,
        * simply because that seems to be the way MacOS-X does it and
        * we want to maximise compatibility (perhaps they had good reason?)
        */
        if (_priv->uIdMap.get(c, existingObjectId)) {
            objectId = *existingObjectId;
        } else {
            id cDict;
            id hierarchy;

            objectId = [_obj count];
            _priv->uIdMap.insert(c, objectId);
            cDict = [[NSMutableDictionary alloc] initWithCapacity:2];

            // Record class name
            [cDict setObject:classname forKey:@"$classname"];

            // Record the class hierarchy for this object.
            hierarchy = [NSMutableArray new];
            while (c != 0) {
                id next = [c superclass];

                [hierarchy addObject:NSStringFromClass(c)];
                if (next == c) {
                    break;
                }
                c = next;
            }
            [cDict setObject:hierarchy forKey:@"$classes"];
            [hierarchy release];
            [_obj addObject:cDict];
            [cDict release];
        }

        /*
        * Now create a reference to the class information and store it
        * in the object description dictionary for the object we just encoded.
        */
        [m setObject:makeReference(objectId) forKey:@"$class"];
    }

    // If we have encoded the object information, tell the delegate.
    if (objectInfo != nil && _delegate != nil) {
        [_delegate archiver:self didEncodeObject:anObject];
    }

    // Return the dictionary identifying the encoded object.
    return refObject;
}

/**
 @Status Interoperable
*/
+ (NSString*)classNameForClass:(Class)aClass {
    auto className = s_clsMap.get(aClass);
    return className ? className->get() : nil;
}

/**
 @Status Interoperable
*/
+ (void)setClassName:(NSString*)codedName forClass:(Class)aClass {
    if (!codedName) {
        s_clsMap.remove(aClass);
        return;
    }
    s_clsMap.insert(aClass, codedName);
}

/**
 @Status Interoperable
*/
- (NSString*)classNameForClass:(Class)aClass {
    auto className = _priv->clsMap.get(aClass);
    return className ? className->get() : nil;
}

/**
 @Status Interoperable
*/
- (void)setClassName:(NSString*)codedName forClass:(Class)aClass {
    if (!codedName) {
        _priv->clsMap.remove(aClass);
        return;
    }
    _priv->clsMap.insert(aClass, codedName);
}

/**
 @Status Interoperable
*/
- (BOOL)allowsKeyedCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (void)encodeConditionalObject:(id)object {
    [self encodeObject:object];
}

@end
