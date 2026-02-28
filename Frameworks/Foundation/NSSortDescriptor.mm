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

#import <Starboard.h>
#import <Foundation/NSSortDescriptor.h>

@implementation NSSortDescriptor

/**
 @Status Interoperable
*/
- (instancetype)initWithKey:(NSString*)key ascending:(BOOL)ascending {
    if (self = [super init]) {
        _selector = @selector(compare:);
        _key = [key copy];
        _ascending = ascending;
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithKey:(NSString*)key ascending:(BOOL)ascending selector:(SEL)selector {
    if (self = [self initWithKey:key ascending:ascending]) {
        if (selector != nullptr) {
            _selector = selector;
        }
    }
    return self;
}

/**
 @Status Interoperable
*/
- (instancetype)initWithKey:(NSString*)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr {
    if (self = [self initWithKey:key ascending:ascending]) {
        _selector = nullptr;
        _comparator = cmptr;
    }

    return self;
}

/**
 @Status Interoperable
*/
+ (instancetype)sortDescriptorWithKey:(NSString*)key ascending:(BOOL)ascending {
    return [[[self alloc] initWithKey:key ascending:ascending] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)sortDescriptorWithKey:(NSString*)key ascending:(BOOL)ascending selector:(SEL)selector {
    return [[[self alloc] initWithKey:key ascending:ascending selector:selector] autorelease];
}

/**
 @Status Interoperable
*/
+ (instancetype)sortDescriptorWithKey:(NSString*)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr {
    return [[[self alloc] initWithKey:key ascending:ascending comparator:cmptr] autorelease];
}

/**
 @Status Interoperable
*/
- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2 {
    id val1, val2;
    if (_key) {
        val1 = [object1 valueForKeyPath:_key];
        val2 = [object2 valueForKeyPath:_key];
    } else {
        // to support when key is nil;
        val1 = object1;
        val2 = object2;
    }

    NSComparisonResult result;

    if (_comparator) {
        result = (NSComparisonResult)_comparator(val1, val2);
    } else {
        result = (NSComparisonResult)[val1 performSelector:_selector withObject:val2];
    }

    if (!_ascending) {
        result = -result;
    }

    return result;
}

/**
 @Status Interoperable
*/
- (id)reversedSortDescriptor {
    if (_comparator) {
        return [NSSortDescriptor sortDescriptorWithKey:_key ascending:(!_ascending) comparator:_comparator];
    }
    return [NSSortDescriptor sortDescriptorWithKey:_key ascending:(!_ascending) selector:_selector];
}

/**
 @Status Interoperable
*/
- (id)copyWithZone:(NSZone*)zone {
    return [self retain];
}

/**
 @Status Interoperable
*/
+ (BOOL)supportsSecureCoding {
    return YES;
}

/**
 @Status Interoperable
*/
- (void)encodeWithCoder:(NSCoder*)encoder {
    if (_comparator) {
        THROW_NS_HR_MSG(E_FAIL, "NSSortDescriptor with a comparator cannot be encoded.");
    }
    [encoder encodeObject:_key forKey:@"key"];
    [encoder encodeBool:_ascending forKey:@"ascending"];
    [encoder encodeObject:NSStringFromSelector(_selector) forKey:@"selector"];
}

/**
 @Status Interoperable
*/
- (instancetype)initWithCoder:(NSCoder*)decoder {
    if (self == [self init]) {
        _key = [[decoder decodeObjectOfClass:[NSString class] forKey:@"key"] retain];
        _ascending = [decoder decodeBoolForKey:@"ascending"];
        _selector = NSSelectorFromString([decoder decodeObjectOfClass:[NSString class] forKey:@"selector"]);
    }
    return self;
}

/**
 @Status Interoperable
*/
- (void)dealloc {
    [_key release];
    [super dealloc];
}

/**
 @Status Stub
 @Notes
*/
- (void)allowEvaluation {
    UNIMPLEMENTED();
}

@end
