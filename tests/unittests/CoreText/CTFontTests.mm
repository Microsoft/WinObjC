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

#import <TestFramework.h>
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#import <CoreTextInternal.h>
#import <Starboard/SmartTypes.h>
#import <vector>

static NSURL* __GetURLFromPathRelativeToModuleDirectory(NSString* relativePath) {
    static char fullPath[_MAX_PATH];
    static int unused = [](char* path) { return GetModuleFileNameA(NULL, path, _MAX_PATH); }(fullPath);
    return [NSURL fileURLWithPath:[[@(fullPath) stringByDeletingLastPathComponent] stringByAppendingPathComponent:relativePath]];
}

class FontCopyName : public ::testing::TestWithParam<::testing::tuple<CFStringRef, const NSString*>> {
public:
    FontCopyName() : _font(nullptr) {
    }

protected:
    virtual void SetUp() {
        auto fontName = woc::MakeAutoCF<CFStringRef>(CFSTR("Metadata Test"));
        _testFileURL = __GetURLFromPathRelativeToModuleDirectory(@"/data/MetadataTest-Regular.ttf");
        CFErrorRef error = nullptr;
        EXPECT_TRUE(CTFontManagerRegisterFontsForURL((__bridge CFURLRef)_testFileURL.get(), kCTFontManagerScopeSession, &error));
        EXPECT_EQ(nullptr, error);

        _font = woc::MakeAutoCF<CTFontRef>(CTFontCreateWithName(fontName, 20, nullptr));
        ASSERT_NE(nullptr, _font);
    }

    virtual void TearDown() {
        CFErrorRef error = nullptr;
        EXPECT_TRUE(CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)_testFileURL.get(), kCTFontManagerScopeSession, &error));
        EXPECT_EQ(nullptr, error);
    }

    woc::AutoCF<CTFontRef> _font;
    StrongId<NSURL> _testFileURL;
};

TEST_P(FontCopyName, VerifyProperties) {
    const CFStringRef propertyValue = CTFontCopyName(_font, ::testing::get<0>(GetParam()));
    EXPECT_OBJCEQ(static_cast<NSString*>(propertyValue), ::testing::get<1>(GetParam()));
    CFRelease(propertyValue);
}

const NSString* c_familyName = @"Metadata Test";
const NSString* c_subFamilyName = @"Regular";
const NSString* c_styleName = @"Regular";
const NSString* c_uniqueName = @"Metadata Test Regular";
const NSString* c_fullName = @"Metadata Test";

const NSString* c_postscriptName = @"MetadataTest-Regular";
const NSString* c_trademarkName = @"MetadataTest is not a trademark.";
const NSString* c_manufacturerName = @"Microsoft Corporation";
const NSString* c_designerName = nullptr;
const NSString* c_descriptionName = nullptr;
const NSString* c_vendorURLName = @"https://developer.microsoft.com/en-us/windows/bridges/ios";
const NSString* c_designerURLName = nullptr;
const NSString* c_licenseURLName = @"https://developer.microsoft.com/en-us/windows/bridges/ios";
const NSString* c_sampleTextName = nullptr;
const NSString* c_copyrightName = @"Copyright (c) Microsoft";
const NSString* c_versionName = @"Version 1.01 ";
const NSString* c_postscriptCIDName = nullptr;

INSTANTIATE_TEST_CASE_P(CTFont,
                        FontCopyName,
                        ::testing::Values(::testing::make_tuple(kCTFontFamilyNameKey, c_familyName),
                                          ::testing::make_tuple(kCTFontSubFamilyNameKey, c_subFamilyName),
                                          ::testing::make_tuple(kCTFontStyleNameKey, c_styleName),
                                          ::testing::make_tuple(kCTFontUniqueNameKey, c_uniqueName),
                                          ::testing::make_tuple(kCTFontFullNameKey, c_fullName),
                                          ::testing::make_tuple(kCTFontPostScriptNameKey, c_postscriptName),
                                          ::testing::make_tuple(kCTFontTrademarkNameKey, c_trademarkName),
                                          ::testing::make_tuple(kCTFontManufacturerNameKey, c_manufacturerName),
                                          ::testing::make_tuple(kCTFontDesignerNameKey, c_designerName),
                                          ::testing::make_tuple(kCTFontDescriptionNameKey, c_descriptionName),
                                          ::testing::make_tuple(kCTFontVendorURLNameKey, c_vendorURLName),
                                          ::testing::make_tuple(kCTFontDesignerURLNameKey, c_designerURLName),
                                          ::testing::make_tuple(kCTFontLicenseURLNameKey, c_licenseURLName),
                                          ::testing::make_tuple(kCTFontSampleTextNameKey, c_sampleTextName),
                                          ::testing::make_tuple(kCTFontCopyrightNameKey, c_copyrightName),
                                          ::testing::make_tuple(kCTFontVersionNameKey, c_versionName),
                                          ::testing::make_tuple(kCTFontPostScriptCIDNameKey, c_postscriptCIDName)));

TEST(CTFont, EqualHash) {
    CTFontRef font1 = CTFontCreateWithName(CFSTR("Times New Roman"), 12.0, NULL);
    CTFontRef font2 = CTFontCreateWithName(CFSTR("Times New Roman"), 12.0, NULL);
    CTFontRef font3 = CTFontCreateWithName(CFSTR("Times New Roman Bold"), 12.0, NULL);
    CTFontRef font4 = CTFontCreateWithName(CFSTR("Times New Roman"), 14.0, NULL);
    CFAutorelease(font1);
    CFAutorelease(font2);
    CFAutorelease(font3);
    CFAutorelease(font4);

    EXPECT_TRUE(CFEqual(font1, font2));
    EXPECT_FALSE(CFEqual(font1, font3));
    EXPECT_FALSE(CFEqual(font1, font4));

    EXPECT_EQ(CFHash(font1), CFHash(font2));
    EXPECT_NE(CFHash(font1), CFHash(font3));
    EXPECT_NE(CFHash(font1), CFHash(font4));
}

TEST(CTFont, Description) {
    CTFontRef font1 = CTFontCreateWithName(CFSTR("Arial"), 10.0, NULL);
    CFAutorelease(font1);

    EXPECT_NE(nullptr, CFAutorelease(CFCopyDescription(font1)));
}

TEST(CTFont, CopyNameHelpers) {
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial Italic"), 15.0, NULL);
    CFAutorelease(font);

    EXPECT_OBJCEQ(@"Arial-ItalicMT", (id)CFAutorelease(CTFontCopyPostScriptName(font)));
    EXPECT_OBJCEQ(@"Arial", (id)CFAutorelease(CTFontCopyFamilyName(font)));
    EXPECT_OBJCEQ(@"Arial Italic", (id)CFAutorelease(CTFontCopyFullName(font)));
    EXPECT_OBJCEQ(@"Arial Italic", (id)CFAutorelease(CTFontCopyDisplayName(font)));

    font = CTFontCreateWithName(CFSTR("Courier New Bold Italic"), 15.0, NULL);
    CFAutorelease(font);

    EXPECT_OBJCEQ(@"CourierNewPS-BoldItalicMT", (id)CFAutorelease(CTFontCopyPostScriptName(font)));
    EXPECT_OBJCEQ(@"Courier New", (id)CFAutorelease(CTFontCopyFamilyName(font)));
    EXPECT_OBJCEQ(@"Courier New Bold Italic", (id)CFAutorelease(CTFontCopyFullName(font)));
    EXPECT_OBJCEQ(@"Courier New Bold Italic", (id)CFAutorelease(CTFontCopyDisplayName(font)));

    EXPECT_OBJCEQ(@"CourierNewPS-BoldItalicMT", (id)CFAutorelease(CTFontCopyAttribute(font, kCTFontNameAttribute)));
    EXPECT_OBJCEQ(@"Courier New Bold Italic", (id)CFAutorelease(CTFontCopyAttribute(font, kCTFontDisplayNameAttribute)));
}

TEST(CTFont, Metrics) {
    CTFontRef font = CTFontCreateWithName(CFSTR("Courier New Bold Italic"), 15.0, NULL);
    CFAutorelease(font);

    EXPECT_OBJCEQ(@"Courier New Bold Italic", (id)CFAutorelease(CTFontCopyFullName(font)));

    EXPECT_NE(0, CTFontGetAscent(font));
    EXPECT_NE(0, CTFontGetDescent(font));
    EXPECT_NE(0, CTFontGetUnitsPerEm(font));
    EXPECT_NE(0, CTFontGetUnderlinePosition(font));
    EXPECT_NE(0, CTFontGetUnderlineThickness(font));
    EXPECT_NE(0, CTFontGetCapHeight(font));
    EXPECT_NE(0, CTFontGetXHeight(font));
    EXPECT_EQ(0, CTFontGetLeading(font));
}

TEST(CTFont, GlyphCount) {
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial"), 15.0, NULL);
    CFAutorelease(font);
    // Test for reasonable bounds on number of unique glyphs in a font
    EXPECT_LE(3000, CTFontGetGlyphCount(font));
    EXPECT_GE(8000, CTFontGetGlyphCount(font));

    font = CTFontCreateWithName(CFSTR("Courier New"), 9.0, NULL);
    CFAutorelease(font);
    // Test for reasonable bounds on number of unique glyphs in a font
    EXPECT_LE(3000, CTFontGetGlyphCount(font));
    EXPECT_GE(8000, CTFontGetGlyphCount(font));
}

// OSX returns a default font, but iOS returns nullptr
// TODO #1250: A default font is currently returned as a short-term fix for another issue
// Return this test to OSX_DISABLED_TEST when #1250 is completed.
DISABLED_TEST(CTFont, UnknownName) {
    EXPECT_EQ(nullptr, CFAutorelease(CTFontCreateWithName(CFSTR("DoesNotExistFont"), 12.0, NULL)));
}

TEST(CTFont, CaseInsensitive) {
    CTFontRef font1 = CTFontCreateWithName(CFSTR("Arial"), 12.0, NULL);
    CTFontRef font2 = CTFontCreateWithName(CFSTR("ARIAL"), 12.0, NULL);
    CTFontRef font3 = CTFontCreateWithName(CFSTR("arial"), 12.0, NULL);
    CTFontRef font4 = CTFontCreateWithName(CFSTR("aRiAL"), 12.0, NULL);
    CFAutorelease(font1);
    CFAutorelease(font2);
    CFAutorelease(font3);
    CFAutorelease(font4);

    EXPECT_TRUE(CFEqual(font1, font2));
    EXPECT_TRUE(CFEqual(font1, font3));
    EXPECT_TRUE(CFEqual(font1, font4));
}

TEST(CTFont, CreateWithPostScriptName) {
    CTFontRef font1 = CTFontCreateWithName(CFSTR("Times New Roman"), 12.0, NULL);
    CTFontRef font2 = CTFontCreateWithName(CFSTR("TimesNewRomanPSMT"), 12.0, NULL);
    CFAutorelease(font1);
    CFAutorelease(font2);

    EXPECT_NE(nullptr, font1);
    EXPECT_NE(nullptr, font2);

    EXPECT_TRUE(CFEqual(font1, font2));
}

static const CFStringRef c_arialBoldItalicName = CFSTR("Arial-BoldItalicMT");
static const CFStringRef c_arialItalicName = CFSTR("Arial-ItalicMT");
static const CFStringRef c_courierNewItalicName = CFSTR("CourierNewPS-ItalicMT");
static const CFStringRef c_courierNewBoldName = CFSTR("CourierNewPS-BoldMT");
static const CFStringRef c_courierNewBoldItalicName = CFSTR("CourierNewPS-BoldItalicMT");
static const CFStringRef c_trebuchetMSItalicName = CFSTR("TrebuchetMS-Italic");
static const CFStringRef c_timesNewRomanName = CFSTR("TimesNewRomanPSMT");

static const float c_errorMargin = 0.001f;

TEST(CTFont, Traits) {
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial Bold"), 12.0, NULL);
    CFAutorelease(font);

    CFDictionaryRef traits = CTFontCopyTraits(font);
    CFAutorelease(traits);

    EXPECT_NEAR(0.4f, [(NSNumber*)CFDictionaryGetValue(traits, kCTFontWeightTrait) floatValue], c_errorMargin); // UIFontWeightBold
    EXPECT_OBJCEQ(@0, (id)CFDictionaryGetValue(traits, kCTFontWidthTrait));
    EXPECT_OBJCEQ(@0, (id)CFDictionaryGetValue(traits, kCTFontSlantTrait));

    // Mask to only the lower 16 bits - the upper 16 are currently not supported on windows
    EXPECT_EQ(kCTFontBoldTrait, 0xFFFF & CTFontGetSymbolicTraits(font));

// Use a slightly different font on Windows and OSX, since the platforms have different default fonts
#if TARGET_OS_WIN32
    font = CTFontCreateWithName(CFSTR("Courier New Bold Italic"), 10.0, NULL);
#else
    font = CTFontCreateWithName(CFSTR("Courier-BoldOblique"), 10.0, NULL);
#endif
    CFAutorelease(font);

    traits = CTFontCopyTraits(font);
    CFAutorelease(traits);

    EXPECT_NEAR(0.4f, [(NSNumber*)CFDictionaryGetValue(traits, kCTFontWeightTrait) floatValue], c_errorMargin); // UIFontWeightBold
    EXPECT_OBJCEQ(@0, (id)CFDictionaryGetValue(traits, kCTFontWidthTrait));
    EXPECT_NEAR(0.066666f, [(NSNumber*)CFDictionaryGetValue(traits, kCTFontSlantTrait) floatValue], c_errorMargin);

    // Mask to only the lower 16 bits - the upper 16 are currently not supported on windows
    EXPECT_EQ(kCTFontBoldTrait | kCTFontItalicTrait | kCTFontMonoSpaceTrait, 0xFFFF & CTFontGetSymbolicTraits(font));
}

TEST(CTFont, SymbolicTraits) {
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial"), 12.0, NULL);
    CFAutorelease(font);

    CFDictionaryRef traits = CTFontCopyTraits(font);
    CFAutorelease(traits);
    EXPECT_EQ(CTFontGetSymbolicTraits(font), [(__bridge NSNumber*)CFDictionaryGetValue(traits, kCTFontSymbolicTrait) unsignedIntValue]);
}

TEST(CTFont, CreateWithFontDescriptor) {
    CFMutableDictionaryRef attributes =
        CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAutorelease(attributes);

    CFStringRef fontFamilyName = CFSTR("Courier New");
    CGFloat size = 10.0f;

    CFDictionaryAddValue(attributes, kCTFontFamilyNameAttribute, fontFamilyName);

    // No interesting attributes should just create the base font
    CTFontDescriptorRef descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    CTFontRef font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(fontFamilyName, size, nullptr))));

    // Adding size to attributes, but size parameter in create function should take priority
    CFDictionaryAddValue(attributes, kCTFontSizeAttribute, (__bridge CFNumberRef)[NSNumber numberWithFloat:1000.0f]);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(fontFamilyName, size, nullptr))));

    // Adding something to traits...
    CFMutableDictionaryRef traits =
        CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFAutorelease(traits);
    CFDictionaryAddValue(traits, kCTFontWeightTrait, (__bridge CFNumberRef) @0.4f);
    CFDictionaryAddValue(attributes, kCTFontTraitsAttribute, traits);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(c_courierNewBoldName, size, nullptr))));

    // Set the weight trait to 'narrow' (no matching font in Courier) - should then return the default font in the family
    CFDictionarySetValue(traits, kCTFontWeightTrait, (__bridge CFNumberRef) @-0.4f);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(fontFamilyName, size, nullptr))));

    // Set the weight trait to 'heavy' (no exact matching font in Courier)
    CFDictionarySetValue(traits, kCTFontWeightTrait, (__bridge CFNumberRef) @0.56f);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
// DWrite diverges from iOS here - DWrite tries to do a 'best match' and returns the bold font
// iOS is more stringent and just returns nullptr
#if TARGET_OS_WIN32
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(c_courierNewBoldName, size, nullptr))));
#else
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(fontFamilyName, size, nullptr))));
#endif

    // Set the weight back to 'normal'
    CFDictionarySetValue(traits, kCTFontWeightTrait, (__bridge CFNumberRef) @0.0f);
    // Set symbolic traits with the 'bold' flag
    CFDictionarySetValue(traits, kCTFontSymbolicTrait, (__bridge CFNumberRef)[NSNumber numberWithUnsignedInt:kCTFontBoldTrait]);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    // Seems that the explicit weight overrides the symbolic trait
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(fontFamilyName, size, nullptr))));

    // Remove the weight trait - should now return the bold font
    CFDictionaryRemoveValue(traits, kCTFontWeightTrait);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(c_courierNewBoldName, size, nullptr))));

    // Add the italic flag to symbolic traits
    CFDictionarySetValue(traits,
                         kCTFontSymbolicTrait,
                         (__bridge CFNumberRef)[NSNumber numberWithUnsignedInt:kCTFontBoldTrait | kCTFontItalicTrait]);
    descriptor = static_cast<CTFontDescriptorRef>(CFAutorelease(CTFontDescriptorCreateWithAttributes(attributes)));
    font = static_cast<CTFontRef>(CFAutorelease(CTFontCreateWithFontDescriptor(descriptor, size, nullptr)));
    ASSERT_NE(nullptr, font);
    ASSERT_TRUE(CFEqual(font, CFAutorelease(CTFontCreateWithName(c_courierNewBoldItalicName, size, nullptr))));
}

TEST(CTFont, CreateCopyWith) {
    CTFontRef baseFont = CTFontCreateWithName(CFSTR("Arial"), 11.0f, nullptr);
    CFAutorelease(baseFont);

    // Create a new font with the 'italic' trait
    CGFloat newSize = 100.0f;
    CTFontRef italicFont = CTFontCreateCopyWithSymbolicTraits(baseFont, newSize, nullptr, kCTFontItalicTrait, 0xFF);
    CFAutorelease(italicFont);

    ASSERT_NE(nullptr, italicFont);
    ASSERT_TRUE(CFEqual(italicFont, CFAutorelease(CTFontCreateWithName(c_arialItalicName, newSize, nullptr))));

    // Create a new font with the same traits but in the 'Trebuchet MS' family
    CGFloat newSize2 = 105.4f;
    CTFontRef italicFont2 = CTFontCreateCopyWithFamily(italicFont, newSize2, nullptr, CFSTR("Trebuchet MS"));
    CFAutorelease(italicFont2);
    ASSERT_NE(nullptr, italicFont2);
    ASSERT_TRUE(CFEqual(italicFont2, CFAutorelease(CTFontCreateWithName(c_trebuchetMSItalicName, newSize2, nullptr))));

    // Create a new font in a nonexistent family
    CTFontRef doesNotExistFont = CTFontCreateCopyWithFamily(italicFont, newSize, nullptr, CFSTR("DoesNotExistFamily"));
    ASSERT_EQ(nullptr, doesNotExistFont);
}

TEST(CTFont, GetMatrix) {
    CGAffineTransform matrix = CGAffineTransformMakeRotation(1415.0f);
    CTFontRef font = CTFontCreateWithName(CFSTR("Arial"), 10.0f, &matrix);
    CFAutorelease(font);

    CGAffineTransform getMatrix = CTFontGetMatrix(font);
    ASSERT_TRUE(CGAffineTransformEqualToTransform(matrix, getMatrix));
}

TEST(CTFont, GetSlantAngle) {
    CTFontRef font = CTFontCreateWithName(c_courierNewItalicName, 10.0f, nullptr);
    CFAutorelease(font);
    CTFontRef font2 = CTFontCreateWithName(c_trebuchetMSItalicName, 10.0f, nullptr);
    CFAutorelease(font2);

    // Reference platform appears to round the angle to the nearest degree
    // Allow a greater error margin here
    EXPECT_NEAR(-12.0f, CTFontGetSlantAngle(font), 0.05);
    EXPECT_NEAR(-10.0f, CTFontGetSlantAngle(font2), 0.05);
}

TEST(CTFont, GetAdvancesForGlyphs) {
    CTFontRef font = CTFontCreateWithName(c_trebuchetMSItalicName, 10.0f, nullptr);
    CFAutorelease(font);

    const size_t count = 26;
    UniChar characters[count] = { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
                                  '*', '&', '^', '6', '3', '#', '`', '~', '%', 'Z', '>', ' ', ';' }; // 26 chars
    CGGlyph glyphs[count];
    CGGlyph expectedGlyphs[count] = { 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 13, 9, 65, 25, 22, 6, 67, 97, 8, 61, 33, 3, 30 };

    ASSERT_TRUE(CTFontGetGlyphsForCharacters(font, characters, glyphs, count));
    ASSERT_EQ(0, memcmp(expectedGlyphs, glyphs, count * sizeof(CGGlyph)));

    CGSize advances[count];
    CGSize horAdvances[count];
    CGSize verAdvances[count];

    CGFloat expectedWidths[count] = { 5.25391f, 5.57129f, 4.59961f, 5.57129f, 5.37109f, 4.01367f, 5.01953f, 5.57129f, 3.06641f,
                                      3.66699f, 5.04395f, 3.20312f, 8.30078f, 3.67188f, 7.06055f, 5.24414f, 5.24414f, 5.24414f,
                                      5.24414f, 5.24414f, 5.24414f, 6.00098f, 5.50293f, 5.24414f, 3.0127f,  3.67188f };
    CGFloat expectedVerWidths[count] = { 6.4209f,  8.4668f,  6.4209f, 8.46191f, 6.4209f,  10.3613f, 8.52051f, 8.36914f, 8.27637f,
                                         10.3027f, 8.36914f, 8.4668f, 6.32324f, 4.00879f, 8.37402f, 3.76953f, 8.39844f, 8.37402f,
                                         8.35449f, 2.62207f, 2.3877f, 8.37402f, 8.14941f, 5.07324f, 3.0127f,  7.86133f };

    ASSERT_NEAR(129.882812f, CTFontGetAdvancesForGlyphs(font, kCTFontDefaultOrientation, glyphs, advances, count), c_errorMargin);
    for (size_t i = 0; i < count; i++) {
        EXPECT_NEAR(expectedWidths[i], advances[i].width, c_errorMargin);
        EXPECT_EQ(0, advances[i].height); // Yes actually!
    }

    // Try in other orientations - horizontal ought to be same as default
    ASSERT_NEAR(129.882812f, CTFontGetAdvancesForGlyphs(font, kCTFontHorizontalOrientation, glyphs, horAdvances, count), c_errorMargin);
    ASSERT_EQ(0, memcmp(advances, horAdvances, count * sizeof(CGSize)));

// Vertical orientation
// DWrite appears to not support this precisely, as it returns an equal value no matter the glyph
#if !TARGET_OS_WIN32
    ASSERT_NEAR(183.940429f, CTFontGetAdvancesForGlyphs(font, kCTFontVerticalOrientation, glyphs, verAdvances, count), c_errorMargin);
    for (size_t i = 0; i < count; i++) {
        EXPECT_NEAR(expectedVerWidths[i], verAdvances[i].width, c_errorMargin);
        EXPECT_EQ(0, verAdvances[i].height); // Yes actually!
    }
#else
    ASSERT_LE(180.0f, CTFontGetAdvancesForGlyphs(font, kCTFontVerticalOrientation, glyphs, verAdvances, count));
    for (size_t i = 0; i < count; i++) {
        EXPECT_NEAR(9.423828f, verAdvances[i].width, c_errorMargin);
        EXPECT_EQ(0, verAdvances[i].height); // Yes actually!
    }
#endif
}

TEST(CTFont, GetBoundingBox) {
// Windows may have slightly different versions of the same fonts compared to the reference platform
#if TARGET_OS_WIN32
    CGRect expectedBox = { { -36.9264, -23.188 }, { 133.967, 94.4256 } };
#else
    CGRect expectedBox = { { -36.9264, -23.188 }, { 135.432, 94.4256 } };
#endif

    CTFontRef font = CTFontCreateWithName(c_arialItalicName, 71.412f, nullptr);
    CFAutorelease(font);

    CGRect box = CTFontGetBoundingBox(font);
    EXPECT_NEAR(expectedBox.origin.x, box.origin.x, c_errorMargin);
    EXPECT_NEAR(expectedBox.origin.y, box.origin.y, c_errorMargin);
    EXPECT_NEAR(expectedBox.size.width, box.size.width, c_errorMargin);
    EXPECT_NEAR(expectedBox.size.height, box.size.height, c_errorMargin);
}

TEST(CTFont, GetBoundingBoxes) {
    CTFontRef font = CTFontCreateWithName(c_arialBoldItalicName, 585.45f, nullptr);
    CFAutorelease(font);

    const size_t count = 3;
    CGGlyph glyphs[count] = { 68, 40, 22 };
    CGRect boxes[count];

    // Default/horizontal orientation
    CGRect expectedBoxes[count] = {
        { { 26.2995, -7.14661 }, { 285.864, 317.881 } },
        { { 24.0126, 0 }, { 398.209, 419.077 } },
        { { 29.7299, -7.14661 }, { 298.156, 427.939 } },
    };

    CGRect expectedTotalBox = { { 24.0126, -7.14661 }, { 398.209, 427.939 } };

    CGRect totalBox = CTFontGetBoundingRectsForGlyphs(font, kCTFontDefaultOrientation, glyphs, boxes, count);
    EXPECT_NEAR(expectedTotalBox.origin.x, totalBox.origin.x, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.origin.y, totalBox.origin.y, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.width, totalBox.size.width, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.height, totalBox.size.height, c_errorMargin);

    for (size_t i = 0; i < count; ++i) {
        EXPECT_NEAR(expectedBoxes[i].origin.x, boxes[i].origin.x, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].origin.y, boxes[i].origin.y, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].size.width, boxes[i].size.width, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].size.height, boxes[i].size.height, c_errorMargin);
    }

    totalBox = CTFontGetBoundingRectsForGlyphs(font, kCTFontHorizontalOrientation, glyphs, boxes, count);
    EXPECT_NEAR(expectedTotalBox.origin.x, totalBox.origin.x, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.origin.y, totalBox.origin.y, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.width, totalBox.size.width, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.height, totalBox.size.height, c_errorMargin);
    for (size_t i = 0; i < count; ++i) {
        EXPECT_NEAR(expectedBoxes[i].origin.x, boxes[i].origin.x, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].origin.y, boxes[i].origin.y, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].size.width, boxes[i].size.width, c_errorMargin);
        EXPECT_NEAR(expectedBoxes[i].size.height, boxes[i].size.height, c_errorMargin);
    }

    // Null outpointer for boxes should evaluate just the total box
    totalBox = CTFontGetBoundingRectsForGlyphs(font, kCTFontHorizontalOrientation, glyphs, nullptr, count);
    EXPECT_NEAR(expectedTotalBox.origin.x, totalBox.origin.x, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.origin.y, totalBox.origin.y, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.width, totalBox.size.width, c_errorMargin);
    EXPECT_NEAR(expectedTotalBox.size.height, totalBox.size.height, c_errorMargin);

// DWrite seems to not respect orientation
#if !TARGET_OS_WIN32
    // Vertical orientation
    CGRect expectedBoxesVert[count] = {
        { { 29.158, -136.357 }, { 317.881, 285.864 } },
        { { 29.158, -171.233 }, { 419.077, 398.209 } },
        { { 29.158, -132.927 }, { 427.939, 298.156 } },
    };
    CGRect expectedTotalBoxVert = { { 29.158, -171.233 }, { 427.939, 398.209 } };

    totalBox = CTFontGetBoundingRectsForGlyphs(font, kCTFontVerticalOrientation, glyphs, boxes, count);
    EXPECT_NEAR(expectedTotalBoxVert.origin.x, totalBox.origin.x, c_errorMargin);
    EXPECT_NEAR(expectedTotalBoxVert.origin.y, totalBox.origin.y, c_errorMargin);
    EXPECT_NEAR(expectedTotalBoxVert.size.width, totalBox.size.width, c_errorMargin);
    EXPECT_NEAR(expectedTotalBoxVert.size.height, totalBox.size.height, c_errorMargin);
    for (size_t i = 0; i < count; ++i) {
        EXPECT_NEAR(expectedBoxesVert[i].origin.x, boxes[i].origin.x, c_errorMargin);
        EXPECT_NEAR(expectedBoxesVert[i].origin.y, boxes[i].origin.y, c_errorMargin);
        EXPECT_NEAR(expectedBoxesVert[i].size.width, boxes[i].size.width, c_errorMargin);
        EXPECT_NEAR(expectedBoxesVert[i].size.height, boxes[i].size.height, c_errorMargin);
    }
#endif
}

DISABLED_TEST(CTFont, CreatePathForGlyph) {
    // Some background on Bezier curves:
    // A quadratic Bezier curve is specified by 3 points:     a start point, a control point, and an end point
    // A cubic Bezier curve is instead specified by 4 points: a start point, TWO control points, and an end point
    // As a generalization, most "older" fonts specify quadratic curves, and "newer" ones can use cubic curves
    // Times New Roman's curves are all quadratic

    // CGPath has support for both orders of Bezier curve,
    // but DWrite's GeometrySink only supports cubic Bezier curves, and approximates any quadratic curves in terms of a cubic curve
    // Eg: Reference platform quadratic curve:  (previous endpoint),              (512, 632),              (480, 632)
    //     DWrite approximate cubic curve:      (previous endpoint), (529, 632.666626), (501.333313, 632), (480, 632)

    // As such, for curves, this test will only check that the endpoint is correct

    // Struct for expected values to get out of a CGPath
    // Because of the previously-noted only-comparing-endpoint, and because CGPathElement uses a C-style raw array to store its points
    // It's neater to declare a new struct for expected values than reuse CGPathElement
    struct ExpectedCGPathElement {
        CGPathElementType type;
        CGPoint point;
    };

    // Times New Roman has a units-per-em of 2048. Use this as its point size to make numbers particularly nice below.
    const CGFloat unitsPerEm = 2048;
    CTFontRef font = CTFontCreateWithName(c_timesNewRomanName, unitsPerEm, nullptr);
    CFAutorelease(font);

    // Get the glyph for 'R' - interesting combination of straight lines & curves, inside and outside
    UniChar capitalRChar = 'R';
    CGGlyph capitalRGlyph;

    ASSERT_TRUE(CTFontGetGlyphsForCharacters(font, &capitalRChar, &capitalRGlyph, 1)); // Treat capitalRGlyph & Char as size-1 "arrays"
    EXPECT_EQ(53, capitalRGlyph); // CGGlyph value for 'R' in Times New Roman

    CGPathRef unscaledPath = CTFontCreatePathForGlyph(font, capitalRGlyph, nullptr);
    CFAutorelease(unscaledPath);

#if TARGET_OS_WIN32
    static const CGPathElementType c_CGPathElementCurveType = kCGPathElementAddCurveToPoint; // Cubic
#else
    static const CGPathElementType c_CGPathElementCurveType = kCGPathElementAddQuadCurveToPoint; // Quadratic
#endif

    std::vector<ExpectedCGPathElement> expectedElements({ { kCGPathElementMoveToPoint, { 1384, 0 } },
                                                          { kCGPathElementAddLineToPoint, { 1022, 0 } },
                                                          { kCGPathElementAddLineToPoint, { 563, 634 } },
                                                          { c_CGPathElementCurveType, { 480, 632 } },
                                                          { c_CGPathElementCurveType, { 452, 632.5 } },
                                                          { c_CGPathElementCurveType, { 421, 634 } },
                                                          { kCGPathElementAddLineToPoint, { 421, 240 } },
                                                          { c_CGPathElementCurveType, { 449, 81 } },
                                                          { c_CGPathElementCurveType, { 563, 37 } },
                                                          { kCGPathElementAddLineToPoint, { 616, 37 } },
                                                          { kCGPathElementAddLineToPoint, { 616, 0 } },
                                                          { kCGPathElementAddLineToPoint, { 35, 0 } },
                                                          { kCGPathElementAddLineToPoint, { 35, 37 } },
                                                          { kCGPathElementAddLineToPoint, { 86, 37 } },
                                                          { c_CGPathElementCurveType, { 209, 93 } },
                                                          { c_CGPathElementCurveType, { 230, 240 } },
                                                          { kCGPathElementAddLineToPoint, { 230, 1116 } },
                                                          { c_CGPathElementCurveType, { 202, 1275 } },
                                                          { c_CGPathElementCurveType, { 86, 1319 } },
                                                          { kCGPathElementAddLineToPoint, { 35, 1319 } },
                                                          { kCGPathElementAddLineToPoint, { 35, 1356 } },
                                                          { kCGPathElementAddLineToPoint, { 529, 1356 } },
                                                          { c_CGPathElementCurveType, { 847.5, 1324.5 } },
                                                          { c_CGPathElementCurveType, { 1021.5, 1208.5 } },
                                                          { c_CGPathElementCurveType, { 1093, 1007 } },
                                                          { c_CGPathElementCurveType, { 1011.5, 790 } },
                                                          { c_CGPathElementCurveType, { 759, 660 } },
                                                          { kCGPathElementAddLineToPoint, { 1039, 271 } },
                                                          { c_CGPathElementCurveType, { 1204, 93 } },
                                                          { c_CGPathElementCurveType, { 1384, 37 } },
                                                          { kCGPathElementCloseSubpath, {} },
                                                          { kCGPathElementMoveToPoint, { 421, 697 } },
                                                          { c_CGPathElementCurveType, { 454, 696.5 } },
                                                          { c_CGPathElementCurveType, { 477, 696 } },
                                                          { c_CGPathElementCurveType, { 769.5, 780 } },
                                                          { c_CGPathElementCurveType, { 868, 994 } },
                                                          { c_CGPathElementCurveType, { 788.5, 1200.5 } },
                                                          { c_CGPathElementCurveType, { 578, 1280 } },
                                                          { c_CGPathElementCurveType, { 421, 1261 } },
                                                          { kCGPathElementCloseSubpath, {} } });

    // Struct of external variables to pass to CGPathApplyFunction (which does not support lambdacaptures)
    struct ComparePathContext {
        size_t count;
        std::vector<ExpectedCGPathElement> expectedElements;
    };

    ComparePathContext comparePathContext = { 0, expectedElements };

    CGPathApplierFunction comparePathToExpected = [](void* context, const CGPathElement* element) {
        ComparePathContext* comparePathContext = reinterpret_cast<ComparePathContext*>(context);
        EXPECT_EQ(comparePathContext->expectedElements[comparePathContext->count].type, element->type);

        // Error margin is slightly higher for this test
        static const float c_comparePathErrorMargin = 0.002f;

        switch (element->type) {
            case kCGPathElementMoveToPoint:
            case kCGPathElementAddLineToPoint:
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.x,
                            element->points[0].x,
                            c_comparePathErrorMargin);
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.y,
                            element->points[0].y,
                            c_comparePathErrorMargin);
                break;

            case kCGPathElementAddQuadCurveToPoint:
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.x,
                            element->points[1].x,
                            c_comparePathErrorMargin);
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.y,
                            element->points[1].y,
                            c_comparePathErrorMargin);
                break;

            case kCGPathElementAddCurveToPoint:
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.x,
                            element->points[2].x,
                            c_comparePathErrorMargin);
                EXPECT_NEAR(comparePathContext->expectedElements[comparePathContext->count].point.y,
                            element->points[2].y,
                            c_comparePathErrorMargin);
                break;

            case kCGPathElementCloseSubpath:
                // No-op, CloseSubpath has no associated point
                break;

            default:
                FAIL() << "An invalid CGPathElementType was returned from CTFontCreatePathForGlyph";
                break;
        }
        ++(comparePathContext->count);
    };

    // Iterate through all elements in the path, check against expected elements
    CGPathApply(unscaledPath, &comparePathContext, comparePathToExpected);

    // Make sure that all of expectedElements has been iterated over
    ASSERT_EQ(expectedElements.size(), comparePathContext.count);

    // Introduce font size
    CGFloat fontSize = 13;
    const CGAffineTransform scaleByFontSize = CGAffineTransformMakeScale(fontSize / unitsPerEm, fontSize / unitsPerEm);

    font = CTFontCreateWithName(c_timesNewRomanName, fontSize, nullptr);
    CFAutorelease(font);

    CGPathRef pathWithFontSize = CTFontCreatePathForGlyph(font, capitalRGlyph, nullptr);
    CFAutorelease(pathWithFontSize);

    // Compare against a transformed version of expectedElements
    comparePathContext = { 0, std::vector<ExpectedCGPathElement>(expectedElements.size()) };
    std::transform(expectedElements.begin(),
                   expectedElements.end(),
                   comparePathContext.expectedElements.begin(),
                   [scaleByFontSize](ExpectedCGPathElement element) {
                       return ExpectedCGPathElement{ element.type, CGPointApplyAffineTransform(element.point, scaleByFontSize) };
                   });
    CGPathApply(pathWithFontSize, &comparePathContext, comparePathToExpected);
    ASSERT_EQ(expectedElements.size(), comparePathContext.count);

    // Introduce a transform on the font
    const CGAffineTransform fontTransform =
        CGAffineTransformTranslate(CGAffineTransformScale(CGAffineTransformMakeRotation(0.5), 6, -3), 10, 20); // Arbitrary transform

    font = CTFontCreateWithName(c_timesNewRomanName, fontSize, &fontTransform);
    CFAutorelease(font);

    CGPathRef pathWithFontSizeAndFontTransform = CTFontCreatePathForGlyph(font, capitalRGlyph, nullptr);
    CFAutorelease(pathWithFontSizeAndFontTransform);

    // Concat the font size matrix and the non-translation portions of the fontTransform to get the expected path
    CGAffineTransform fontTransformWithoutTranslate = fontTransform;
    fontTransformWithoutTranslate.tx = 0;
    fontTransformWithoutTranslate.ty = 0;
    CGAffineTransform totalTransform = CGAffineTransformConcat(fontTransformWithoutTranslate, scaleByFontSize);

    // Compare against a transformed version of expectedElements
    comparePathContext = { 0, std::vector<ExpectedCGPathElement>(expectedElements.size()) };
    std::transform(expectedElements.begin(),
                   expectedElements.end(),
                   comparePathContext.expectedElements.begin(),
                   [totalTransform](ExpectedCGPathElement element) {
                       return ExpectedCGPathElement{ element.type, CGPointApplyAffineTransform(element.point, totalTransform) };
                   });
    CGPathApply(pathWithFontSizeAndFontTransform, &comparePathContext, comparePathToExpected);
    ASSERT_EQ(expectedElements.size(), comparePathContext.count);

    // Introduce a transform on the path
    const CGAffineTransform pathTransform = CGAffineTransformMake(234, -432.24, 79, -0.3424, 14135, -32); // Arbitrary transform

    CGPathRef pathWithFontSizeAndTransforms = CTFontCreatePathForGlyph(font, capitalRGlyph, &pathTransform);
    CFAutorelease(pathWithFontSizeAndTransforms);

    totalTransform = CGAffineTransformConcat(totalTransform, pathTransform);

    // Compare against a transformed version of expectedElements
    comparePathContext = { 0, std::vector<ExpectedCGPathElement>(expectedElements.size()) };
    std::transform(expectedElements.begin(),
                   expectedElements.end(),
                   comparePathContext.expectedElements.begin(),
                   [totalTransform](ExpectedCGPathElement element) {
                       return ExpectedCGPathElement{ element.type, CGPointApplyAffineTransform(element.point, totalTransform) };
                   });
    CGPathApply(pathWithFontSizeAndTransforms, &comparePathContext, comparePathToExpected);
    ASSERT_EQ(expectedElements.size(), comparePathContext.count);
}

static const NSString* sc_localeName = @"en-us";
TEST(CTFont, CopyLocalizedName) {
    auto fontName = woc::MakeAutoCF<CFStringRef>(CFSTR("Metadata Test"));
    StrongId<NSURL> testFileURL = __GetURLFromPathRelativeToModuleDirectory(@"/data/MetadataTest-Regular.ttf");
    CFErrorRef error = nullptr;
    EXPECT_TRUE(CTFontManagerRegisterFontsForURL((__bridge CFURLRef)testFileURL.get(), kCTFontManagerScopeSession, &error));
    EXPECT_EQ(nullptr, error);

    auto font = woc::MakeAutoCF<CTFontRef>(CTFontCreateWithName(fontName, 20, nullptr));
    ASSERT_NE(nullptr, font);

    // Actual language out-param should be optional
    auto copyrightNameWithoutLang = woc::MakeAutoCF<CFStringRef>(CTFontCopyLocalizedName(font, kCTFontCopyrightNameKey, nullptr));
    EXPECT_OBJCEQ(c_copyrightName, (__bridge NSString*)copyrightNameWithoutLang.get());

    CFStringRef actualLanguage = nullptr;
    auto copyrightName = woc::MakeAutoCF<CFStringRef>(CTFontCopyLocalizedName(font, kCTFontCopyrightNameKey, &actualLanguage));
    EXPECT_OBJCEQ(c_copyrightName, (__bridge NSString*)copyrightName.get());
    ASSERT_NE(nullptr, actualLanguage);
    ASSERT_EQ(5, CFStringGetLength(actualLanguage));
    EXPECT_OBJCEQ(sc_localeName, (__bridge NSString*)actualLanguage);

    EXPECT_TRUE(CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)testFileURL.get(), kCTFontManagerScopeSession, &error));
    EXPECT_EQ(nullptr, error);
}

TEST(CTFont, CopyAvailableTables) {
    auto font = woc::MakeAutoCF<CTFontRef>(CTFontCreateWithName(CFSTR("Arial"), 20, nullptr));
    auto availableTables = woc::MakeAutoCF<CFArrayRef>(CTFontCopyAvailableTables(font, kCTFontTableOptionNoOptions));
    ASSERT_NE(nullptr, availableTables);
    CFIndex count = CFArrayGetCount(availableTables);
    EXPECT_LT(0, count);

    // There are 55 supported font tables
    EXPECT_GE(55, count);

    // Don't want to make test too precise so that it may fail should fonts change, but 'cmap' is a required font table
    // So it should be safe to always test that this value is available
    EXPECT_TRUE(CFArrayContainsValue(availableTables, { 0, count }, (const void*)kCTFontTableCmap));
}

TEST(CTFont, GetCompatibleFamilyName) {
    CFStringRef fontName = CFSTR("WinObjC");
    NSURL* testFileURL = __GetURLFromPathRelativeToModuleDirectory(@"/data/WinObjC.ttf");
    CFErrorRef error = nullptr;
    EXPECT_TRUE(CTFontManagerRegisterFontsForURL((__bridge CFURLRef)testFileURL, kCTFontManagerScopeSession, &error));
    EXPECT_EQ(nullptr, error);

    auto font = woc::MakeAutoCF<CTFontRef>(CTFontCreateWithName(fontName, 20, nullptr));
    EXPECT_NE(nullptr, font);

    CFStringRef familyName = _CTFontGetXamlCompatibleFamilyName(font);
    EXPECT_NE(nullptr, familyName);

    // CompatibleFamilyName returns an absolute path, so can only check prefix and suffix
    EXPECT_TRUE([static_cast<NSString*>(familyName) hasPrefix:@"ms-appx:///"]);
    EXPECT_TRUE([static_cast<NSString*>(familyName) hasSuffix:@"/data/WinObjC.ttf#WinObjC"]);

    EXPECT_TRUE(CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)testFileURL, kCTFontManagerScopeSession, &error));
    EXPECT_EQ(nullptr, error);
}
