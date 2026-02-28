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

#include <TestFramework.h>
#include <CoreFoundation/CoreFoundation.h>
#include "CFCppBase.h"
#include <Starboard/SmartTypes.h>

// Make a ref-counted CF type.
struct __CFTestClass : public CoreFoundation::CppBase<__CFTestClass> {};

typedef const struct __CFTestClass* CFTestClassRef;

CFTypeID CFTestClassGetTypeID() {
    return __CFTestClass::GetTypeID();
}

CFTestClassRef CFTestClassCreate(CFAllocatorRef allocator) {
    return __CFTestClass::CreateInstance(allocator);
}

using namespace woc;

TEST(AutoCF, Basic) {
    auto testObject = MakeAutoCF(CFTestClassCreate(nullptr));
    ASSERT_TRUE(testObject);
    ASSERT_NE(nullptr, testObject);
    ASSERT_EQ((testObject.get() != nullptr), static_cast<bool>(testObject));
    EXPECT_EQ(1, CFGetRetainCount(testObject));
}

TEST(AutoCF, ShareOwnership) {
    CFTestClassRef testObject = CFTestClassCreate(nullptr);
    AutoCF<CFTestClassRef> sharedOwner{ testObject };
    EXPECT_EQ(2, CFGetRetainCount(testObject));
    CFRelease(testObject);
}

TEST(AutoCF, Copying) {
    auto testObject = MakeAutoCF(CFTestClassCreate(nullptr));
    ASSERT_EQ(1, CFGetRetainCount(testObject));

    {
        // Retain from a Retain
        StrongCF<CFTestClassRef> copy1{ testObject };
        ASSERT_EQ(2, CFGetRetainCount(copy1));

        // Assign from a Retain
        UnsafeCF<CFTestClassRef> copy2{ copy1 };
        ASSERT_EQ(2, CFGetRetainCount(copy2)); // unchanged

        // Retain from an Assign
        StrongCF<CFTestClassRef> copy3{ copy2 };
        ASSERT_EQ(3, CFGetRetainCount(copy3)); // unchanged
    }

    ASSERT_EQ(1, CFGetRetainCount(testObject));
}

TEST(AutoCF, Assignment) {
    auto testObject = MakeAutoCF(CFTestClassCreate(nullptr));
    ASSERT_EQ(1, CFGetRetainCount(testObject));

    {
        StrongCF<CFTestClassRef> copy1;
        UnsafeCF<CFTestClassRef> copy2;
        StrongCF<CFTestClassRef> copy3;

        // Retain from a Retain
        copy1 = testObject;
        ASSERT_EQ(2, CFGetRetainCount(copy1));

        // Assign from a Retain
        copy2 = copy1;
        ASSERT_EQ(2, CFGetRetainCount(copy2)); // unchanged

        // Retain from an Assign
        copy3 = copy2;
        ASSERT_EQ(3, CFGetRetainCount(copy3));
    }

    ASSERT_EQ(1, CFGetRetainCount(testObject));
}

TEST(AutoCF, Attach) {
    CFTestClassRef testObject = CFTestClassCreate(nullptr);
    CFRetain(testObject);
    ASSERT_EQ(2, CFGetRetainCount(testObject));

    {
        AutoCF<CFTestClassRef> inheritingOwner;
        inheritingOwner.attach(testObject);
        ASSERT_EQ(2, CFGetRetainCount(testObject));
    }

    ASSERT_EQ(1, CFGetRetainCount(testObject));
    CFRelease(testObject);
}

TEST(AutoCF, Moving) {
    CFTestClassRef testObject = CFTestClassCreate(nullptr);

    AutoCF<CFTestClassRef> sharedOwner{ testObject };
    ASSERT_EQ(2, CFGetRetainCount(testObject));

    {
        // Retain from a Retain
        StrongCF<CFTestClassRef> copy1{ std::move(sharedOwner) };
        ASSERT_EQ(2, CFGetRetainCount(copy1));

        // Exiting this block should decrement the retain count.
        // sharedOwner is no longer valid.
    }

    // AutoCF is designed to disallow moves across different lifetimes, so we cannot UT them.

    ASSERT_EQ(1, CFGetRetainCount(testObject));
    CFRelease(testObject);
}

static void _ReturnCFThingThroughOutPointer(CFTestClassRef* pObject) {
    if (pObject) {
        *pObject = CFTestClassCreate(nullptr);
    }
}

TEST(AutoCF, SetThroughReference) {
    CFTestClassRef testObject = CFTestClassCreate(nullptr);

    AutoCF<CFTestClassRef> sharedOwner{ testObject };
    ASSERT_EQ(2, CFGetRetainCount(testObject));

    _ReturnCFThingThroughOutPointer(&sharedOwner);
    ASSERT_EQ(1, CFGetRetainCount(testObject));
    ASSERT_NE(testObject, sharedOwner);
    ASSERT_EQ(1, CFGetRetainCount(sharedOwner));

    CFRelease(testObject);
}

TEST(AutoCF, LegacyUniqueCF) {
    woc::unique_cf<CFTestClassRef> testObject{ CFTestClassCreate(nullptr) };

    // Only one retain, even though the default ctor is being used.
    ASSERT_EQ(1, CFGetRetainCount(testObject));
}

TEST(AutoCF, LegacyUniqueCFMove) {
    woc::unique_cf<CFTestClassRef> testObject{ CFTestClassCreate(nullptr) };

    // Only one retain, even though the default ctor is being used.
    ASSERT_EQ(1, CFGetRetainCount(testObject));

    woc::unique_cf<CFTestClassRef> testMovedObject{ std::move(testObject) };

    // Still only one retain.
    ASSERT_EQ(1, CFGetRetainCount(testMovedObject));
}

TEST(AutoCF, LegacyUniqueCFMoveAssignment) {
    woc::unique_cf<CFTestClassRef> testMovedObject{};

    {
        woc::unique_cf<CFTestClassRef> testObject{ CFTestClassCreate(nullptr) };

        // Only one retain, even though the default ctor is being used.
        ASSERT_EQ(1, CFGetRetainCount(testObject));

        testMovedObject = std::move(testObject);
    }

    // Still only one retain.
    ASSERT_EQ(1, CFGetRetainCount(testMovedObject));
}