//******************************************************************************
//
// Copyright (c) Microsoft. All rights reserved.
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
#import <StubReturn.h>
#import <Foundation/NSRunLoop.h>
#import "_NSUndoManagerInternal.h"
#import <objc/objc-arc.h>

@implementation _NSUndoBasicAction {
    StrongId<id> _object;
    id _target;
    SEL _undoAction;
    StrongId<NSArray<NSString*>*> _modes;
}

- (id)_initWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject modes:(NSArray<NSString*>*)runLoopModes {
    if (self = [super init]) {
        _undoAction = aSelector;
        objc_storeWeak(&_target, target);
        _object = anObject;
        _modes = [runLoopModes copy];
    }
    return self;
}

- (void)undo:(BOOL)undoAll {
    [objc_loadWeak(&_target) performSelector:_undoAction withObject:_object];
}

- (void)dealloc {
    objc_destroyWeak(&_target);
    [super dealloc];
}

- (BOOL)isClosed {
    return YES;
}

- (BOOL)targets:(id)target {
    return objc_loadWeak(&_target) == target;
}

- (void)removeAllWithTarget:(id)target {
    // Nothing more to remove
}

- (NSUInteger)count {
    return 1;
}

- (NSUInteger)getNumberOfOpenGroups {
    return 0;
}

@end