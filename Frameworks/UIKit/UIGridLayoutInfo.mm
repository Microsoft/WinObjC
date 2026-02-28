//******************************************************************************
//
// UIGridLayoutInfo.m
// PSPDFKit
//
// Copyright (c) 2012-2013 Peter Steinberger. All rights reserved.
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

#import "AssertARCEnabled.h"
#import <UIKit/UIKit.h>
#import "UIGridLayoutInfo.h"
#import "UIGridLayoutSection.h"
#import "UIGridLayoutItem.h"

@interface UIGridLayoutInfo () {
    NSMutableArray* _sections;
    CGRect _visibleBounds;
    CGSize _layoutSize;
    BOOL _isValid;
}
@property (nonatomic, strong) NSMutableArray* sections;
@end

@implementation UIGridLayoutInfo

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSObject

- (instancetype)init {
    if ((self = [super init])) {
        _sections = [NSMutableArray new];
    }
    return self;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%@: %p dimension:%.1f horizontal:%d contentSize:%@ sections:%@>",
                                      NSStringFromClass(self.class),
                                      self,
                                      self.dimension,
                                      self.horizontal,
                                      NSStringFromCGSize(self.contentSize),
                                      self.sections];
}

///////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Public

- (UIGridLayoutInfo*)snapshot {
    UIGridLayoutInfo* layoutInfo = [self.class new];
    layoutInfo.sections = [self.sections mutableCopy];
    layoutInfo.rowAlignmentOptions = self.rowAlignmentOptions;
    layoutInfo.usesFloatingHeaderFooter = self.usesFloatingHeaderFooter;
    layoutInfo.dimension = self.dimension;
    layoutInfo.horizontal = self.horizontal;
    layoutInfo.leftToRight = self.leftToRight;
    layoutInfo.contentSize = self.contentSize;
    return layoutInfo;
}

- (CGRect)frameForItemAtIndexPath:(NSIndexPath*)indexPath {
    UIGridLayoutSection* section = self.sections[(NSUInteger)indexPath.section];
    CGRect itemFrame;
    if (section.fixedItemSize) {
        itemFrame = (CGRect){.size = section.itemSize };
    } else {
        itemFrame = [section.items[(NSUInteger)indexPath.item] itemFrame];
    }
    return itemFrame;
}

- (id)addSection {
    UIGridLayoutSection* section = [UIGridLayoutSection new];
    section.rowAlignmentOptions = self.rowAlignmentOptions;
    section.layoutInfo = self;
    [_sections addObject:section];
    [self invalidate:NO];
    return section;
}

- (void)invalidate:(BOOL)arg {
    _isValid = NO;
}

@end
