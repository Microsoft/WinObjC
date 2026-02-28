//******************************************************************************
//
// Copyright (c) 2016 Intel Corporation. All rights reserved.
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

#import <GLKit/GLKit.h>

#include <math.h>

// (GKLit internal)
#include "ShaderGen.h"
#include "ShaderInfo.h"

#include <windows.h>

using namespace GLKitShader;

struct Dw32 {
    union {
        unsigned int u32;
        float f32;
    };
};

NSString* stripSource(NSString* s, NSString* searchStr) {
    NSRange r;
    while ((r = [s rangeOfString:searchStr]).location != NSNotFound) {
        NSRange searchRange;
        searchRange.location = r.location + r.length;
        searchRange.length = s.length - searchRange.location;
        NSRange endRange = [s rangeOfString:@"\n" options:static_cast<NSStringCompareOptions>(0) range:searchRange];

        if (endRange.location != NSNotFound) {
            r.length = endRange.location - r.location;
        } else {
            r.length = s.length - r.location;
        }
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    }

    return s;
}

int countOccurrences(NSString* s, NSString* searchStr) {
    int count = 0;

    NSRange r;
    r.location = 0;
    r.length = s.length;

    while ((r = [s rangeOfString:searchStr options:static_cast<NSStringCompareOptions>(0) range:r]).location != NSNotFound) {
        count++;

        r.location = r.location + r.length;
        r.length = s.length - r.location;
    }

    return count;
}

void printShader(GLKShaderPair* p) {
    LOG_INFO(
        "\n\n-[ VERTEX SHADER ]----------------------\n%s"
        "\n\n-[ PIXEL SHADER ]-----------------------\n%s\n\n",
        [p.vertexShader UTF8String],
        [p.pixelShader UTF8String]);
}

bool hasVariable(GLKShaderPair* p, const char* varName, bool checkVS = true, bool checkPS = true) {
    if (checkVS) {
        if ([p.vertexShader rangeOfString:[NSString stringWithCString:varName]].location != NSNotFound) {
            return true;
        }
    }

    if (checkPS) {
        if ([p.pixelShader rangeOfString:[NSString stringWithCString:varName]].location != NSNotFound) {
            return true;
        }
    }

    return false;
}

static void checkMatrixWithinTolerance(
    const char* pStr, const float* pM, const float* pMGolden, int dimension = 4, float tolerance = COMPARISON_EPSILON) {

    assert(dimension <= 4);

    int index = 0;

    for (int i = 0; i < dimension; i++) {
        for (int j = 0; j < dimension; j++) {
            // ASSERT_NEAR correctly marks +/- NaN values as not being identical, but we don't care
            // for that distinction.
            if (!isnan(pM[index]) && !isnan(pMGolden[index])) {
                ASSERT_NEAR_MSG(pM[index],
                                pMGolden[index],
                                tolerance,
                                "TEST FAILED: %s \n\tMatrix mismatch at M[%i][%i]\n\t\tGOLDEN: %f\n\t\tACTUAL: %f\n",
                                pStr,
                                i,
                                j,
                                pMGolden[index],
                                pM[index]);
            }

            index++;
        }
    }
}

static void checkMatrix(const char* pStr, const float* pM, const float* pMGolden, int dimension = 4) {
    checkMatrixWithinTolerance(pStr, pM, pMGolden, dimension, 0.0f);
}

TEST(GLKit, DeadCodeElimination) {
    GLKVector4 clr = GLKVector4White();

    // Simple shader.
    ShaderDef vsh(
        { { "output1",
            new ShaderAdditiveCombiner(
                { new ShaderVarRef("input1"), new ShaderVarRef("input2"), new ShaderVarRef("input3"), new ShaderVarRef("input4") }) } });
    ShaderDef psh({ { "gl_FragColor", new ShaderVarRef("output1") } });
    ShaderContext ctx(vsh, psh);

    // Some materials (nothing in m4).
    ShaderMaterial m, m2, m3, m4;
    m.addMaterialVar("input1", clr);
    m.addMaterialVar("input2", clr);
    m.addMaterialVar("input3", clr);
    m.addMaterialVar("input4", clr);

    m2.addMaterialVar("input2", clr);
    m2.addMaterialVar("input4", clr);

    m3.addMaterialVar("input3", clr);

    // Generate
    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);
    GLKShaderPair* p2 = [[GLKShaderPair alloc] init];
    ctx.generate(m2, p2);
    GLKShaderPair* p3 = [[GLKShaderPair alloc] init];
    ctx.generate(m3, p3);
    GLKShaderPair* p4 = [[GLKShaderPair alloc] init];
    ctx.generate(m4, p4);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    // Check results.
    EXPECT_TRUE_MSG(hasVariable(p, "input1"), "Variable must be present");
    EXPECT_TRUE_MSG(hasVariable(p, "input2"), "Variable must be present");
    EXPECT_TRUE_MSG(hasVariable(p, "input3"), "Variable must be present");
    EXPECT_TRUE_MSG(hasVariable(p, "input4"), "Variable must be present");

    EXPECT_FALSE_MSG(hasVariable(p2, "input1"), "Variable should be optimized away");
    EXPECT_TRUE_MSG(hasVariable(p2, "input2"), "Variable must be present");
    EXPECT_FALSE_MSG(hasVariable(p2, "input3"), "Variable should be optimized away");
    EXPECT_TRUE_MSG(hasVariable(p2, "input4"), "Variable must be present");

    EXPECT_FALSE_MSG(hasVariable(p3, "input1"), "Variable should be optimized away");
    EXPECT_FALSE_MSG(hasVariable(p3, "input2"), "Variable should be optimized away");
    EXPECT_TRUE_MSG(hasVariable(p3, "input3"), "Variable must be present");
    EXPECT_FALSE_MSG(hasVariable(p3, "input4"), "Variable should be optimized away");

    EXPECT_FALSE_MSG(hasVariable(p4, "input1"), "Variable should be optimized away");
    EXPECT_FALSE_MSG(hasVariable(p4, "input2"), "Variable should be optimized away");
    EXPECT_FALSE_MSG(hasVariable(p4, "input3"), "Variable should be optimized away");
    EXPECT_FALSE_MSG(hasVariable(p4, "input4"), "Variable should be optimized away");
}

TEST(GLKit, DeadCodeElimination2) {
    GLKVector4 clr = GLKVector4White();

    // Simple shader -- generates opName(input1, input2).
    ShaderDef vsh({ { "output1", new ShaderOp(new ShaderVarRef("input1"), new ShaderVarRef("input2"), "opName", false) } });
    ShaderDef psh({ { "gl_FragColor", new ShaderVarRef("output1") } });
    ShaderContext ctx(vsh, psh);

    ShaderMaterial m, m2, m3, m4;
    m.addMaterialVar("input1", clr);
    m.addMaterialVar("input2", clr);

    m2.addMaterialVar("input1", clr);

    m3.addMaterialVar("input2", clr);

    // add nothing to m4.

    // Generate
    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);
    GLKShaderPair* p2 = [[GLKShaderPair alloc] init];
    ctx.generate(m2, p2);
    GLKShaderPair* p3 = [[GLKShaderPair alloc] init];
    ctx.generate(m3, p3);
    GLKShaderPair* p4 = [[GLKShaderPair alloc] init];
    ctx.generate(m4, p4);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    EXPECT_TRUE_MSG(hasVariable(p, "opName"), "Operator must be present if both inputs are present");
    EXPECT_TRUE_MSG(hasVariable(p, "input1"), "Input must be present.");
    EXPECT_TRUE_MSG(hasVariable(p, "input2"), "Input must be present.");

    EXPECT_FALSE_MSG(hasVariable(p2, "opName"), "Operator must not be present if an input is missing");
    EXPECT_TRUE_MSG(hasVariable(p2, "input1"), "Input must be present.");
    EXPECT_FALSE_MSG(hasVariable(p2, "input2"), "Input is not used and must not be present.");

    EXPECT_FALSE_MSG(hasVariable(p3, "opName"), "Operator must not be present if an input is missing");
    EXPECT_FALSE_MSG(hasVariable(p3, "input1"), "Input is not used and must not be present.");
    EXPECT_TRUE_MSG(hasVariable(p3, "input2"), "Input must be present.");

    EXPECT_FALSE_MSG(hasVariable(p4, "opName"), "Operator must not be present if an input is missing");
    EXPECT_FALSE_MSG(hasVariable(p4, "input1"), "Input is not used and must not be present.");
    EXPECT_FALSE_MSG(hasVariable(p4, "input2"), "Input is not used and must not be present.");
}

TEST(GLKit, TextureCheck) {
    ShaderDef vsh({
        { "output1", new ShaderTexRef("tex1", "modeVar", new ShaderCustom("float2(1, 1"), new ShaderCustom("float4(1, 1, 1, 1)")) },
    });
    ShaderDef psh(
        { { "gl_FragColor", new ShaderTexRef("tex2", "modeVar", new ShaderCustom("float2(1, 1"), new ShaderVarRef("output1")) } });
    ShaderContext ctx(vsh, psh);

    // Textures should just pass through in vertex shader mode.
    ShaderMaterial m;
    m.addTexture("tex1", 1);
    m.addTexture("tex2", 2);

    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    EXPECT_FALSE_MSG(hasVariable(p, "texture2D", true, false), "Texturing call must not be in vertex shader");
    EXPECT_TRUE_MSG(hasVariable(p, "texture2D", false, true), "Texturing call expected in pixel shader");
}

TEST(GLKit, TextureCheckCube) {
    ShaderDef vsh({
        { "output1",
          new ShaderCubeRef("tex1",
                            "modeVar",
                            new ShaderCustom("float4(1, 1, 1, 1)"),
                            new ShaderCustom("float3(1, 1, 1)"),
                            new ShaderCustom("float4(1, 1, 1, 1)"),
                            new ShaderCustom("float4(1, 1, 1, 1)")) },
    });
    ShaderDef psh({ { "gl_FragColor",
                      new ShaderCubeRef("tex2",
                                        "modeVar",
                                        new ShaderCustom("float4(1, 1, 1, 1)"),
                                        new ShaderCustom("float3(1, 1, 1)"),
                                        new ShaderCustom("float4(1, 1, 1, 1)"),
                                        new ShaderVarRef("output1")) } });
    ShaderContext ctx(vsh, psh);

    // Textures should just pass through in vertex shader mode.
    ShaderMaterial m;
    m.addTexCube("tex1", 1);
    m.addTexCube("tex2", 2);

    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    EXPECT_FALSE_MSG(hasVariable(p, "textureCube", true, false), "Texturing call must not be in vertex shader");
    EXPECT_TRUE_MSG(hasVariable(p, "textureCube", false, true), "Texturing call expected in pixel shader");
}

TEST(GLKit, TextureCheckSpecular) {
    ShaderDef vsh({
        { "output1", new ShaderSpecularTex("tex1", new ShaderCustom("float2(1, 1"), new ShaderCustom("float4(1, 1, 1, 1)")) },
    });
    ShaderDef psh({ { "gl_FragColor", new ShaderSpecularTex("tex2", new ShaderCustom("float2(1, 1"), new ShaderVarRef("output1")) } });
    ShaderContext ctx(vsh, psh);

    // Textures should just pass through in vertex shader mode.
    ShaderMaterial m;
    m.addTexture("tex1", 1);
    m.addTexture("tex2", 2);

    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    EXPECT_FALSE_MSG(hasVariable(p, "texture2D", true, false), "Texturing call must not be in vertex shader");
    EXPECT_TRUE_MSG(hasVariable(p, "texture2D", false, true), "Texturing call expected in pixel shader");
}

TEST(GLKit, DeadCodeBackPropagation) {
    ShaderDef vsh({
        { "output1", new ShaderCustom("float4(1, 1, 1, 1)") },
        { "output2", new ShaderCustom("float4(1, 1, 1, 1)") },
        { "output3", new ShaderCustom("float4(1, 1, 1, 1)") },
        { "output4", new ShaderCustom("float4(1, 1, 1, 1)") },
    });
    ShaderDef psh({ { "gl_FragColor",
                      new ShaderAdditiveCombiner({
                          new ShaderVarRef("output1"), new ShaderVarRef("output3"),
                      }) } });
    ShaderContext ctx(vsh, psh);

    ShaderMaterial m;
    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    // Remove comments and intermediate variables.
    p.vertexShader = stripSource(stripSource(p.vertexShader, @"//"), @"varying");
    p.pixelShader = stripSource(stripSource(p.pixelShader, @"//"), @"varying");

    EXPECT_TRUE_MSG(hasVariable(p, "output1"), "Variable is used in pixel shader and must be present in vertex shader.");
    EXPECT_FALSE_MSG(hasVariable(p, "output2"), "Variable is not used in pixel shader and must be eliminated in vertex shader.");
    EXPECT_TRUE_MSG(hasVariable(p, "output3"), "Variable is used in pixel shader and must be present in vertex shader.");
    EXPECT_FALSE_MSG(hasVariable(p, "output4"), "Variable is not used in pixel shader and must be eliminated in vertex shader.");
}

TEST(GLKit, ConditionalShaderNodes) {
    ShaderDef vsh({ { "output1",
                      new ShaderAdditiveCombiner({ new ShaderPixelOnly(new ShaderCustom("pixelOnly")),
                                                   new ShaderVertexOnly(new ShaderCustom("vertexOnly")),
                                                   new ShaderCustom("float4(1, 1, 1, 1)"),
                                                   new ShaderInputVarCheck("generateThis", new ShaderCustom("inputVarOK")) }) } });

    ShaderDef psh({ { "gl_FragColor",
                      new ShaderAdditiveCombiner({ new ShaderVarRef("output1"),
                                                   new ShaderPixelOnly(new ShaderCustom("pixelOnly")),
                                                   new ShaderVertexOnly(new ShaderCustom("vertexOnly")),
                                                   new ShaderInputVarCheck("generateThis", new ShaderCustom("inputVarOK")) }) } });
    ShaderContext ctx(vsh, psh);

    ShaderMaterial m, m2;
    m.addInputVar("generateThis", 1);

    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);
    GLKShaderPair* p2 = [[GLKShaderPair alloc] init];
    ctx.generate(m2, p2);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    // Check input var.
    EXPECT_TRUE_MSG(hasVariable(p, "inputVarOK", true, false), "Input variable must be present in vertex shader");
    EXPECT_TRUE_MSG(hasVariable(p, "inputVarOK", false, true), "Input variable must be present in pixel shader");
    EXPECT_FALSE_MSG(hasVariable(p2, "inputVarOK", true, false), "Input variable should not be generated when disabled");
    EXPECT_FALSE_MSG(hasVariable(p2, "inputVarOK", false, true), "Input variable should not be generated when disabled");

    // Check VS/PS specific stuff.
    EXPECT_FALSE_MSG(hasVariable(p, "pixelOnly", true, false), "Pixel-only nodes must not appear in vertex shader");
    EXPECT_TRUE_MSG(hasVariable(p, "pixelOnly", false, true), "Pixel-only nodes must appear in pixel shader");
    EXPECT_TRUE_MSG(hasVariable(p, "vertexOnly", true, false), "Vertex-only nodes must appear in vertex shader");
    EXPECT_FALSE_MSG(hasVariable(p, "vertexOnly", false, true), "Vertex-only nodes must not appear in the pixel shader");
}

static bool fallbackContextTest(ShaderContext& ctx) {
    GLKVector4 clr = GLKVector4White();

    const int numVars = 4;
    const char* varNames[numVars] = { "var1", "var2", "var3", "var4" };

    for (int i = 0; i < numVars; i++) {
        ShaderMaterial m;
        m.addMaterialVar(varNames[i], clr);
        GLKShaderPair* p = [[GLKShaderPair alloc] init];
        ctx.generate(m, p);

        if (ctx.numVSTempFuncs() != 0 || ctx.numPSTempFuncs() != 0) {
            return false;
        }

        for (int j = 0; j < numVars; j++) {
            if (i == j) {
                if (!hasVariable(p, varNames[j])) {
                    return false;
                }
            } else {
                if (hasVariable(p, varNames[j])) {
                    return false;
                }
            }
        }
    }

    return true;
}

TEST(GLKit, FallbackShaderNodes) {
    ShaderDef vsh({ { "output1", new ShaderFallbackRef({ "var1", "var2", "var3", "var4" }) } });
    ShaderDef vsh2({ { "output1",
                       new ShaderFallbackNode(
                           { new ShaderVarRef("var1"), new ShaderVarRef("var2"), new ShaderVarRef("var3"), new ShaderVarRef("var4") }) } });
    ShaderDef psh({ { "gl_FragColor", new ShaderVarRef("output1") } });

    ShaderContext ctx(vsh, psh);
    ShaderContext ctx2(vsh2, psh);

    EXPECT_TRUE_MSG(fallbackContextTest(ctx), "FallbackRef node not correctly falling back.");
    EXPECT_TRUE_MSG(fallbackContextTest(ctx2), "FallbackNode node not correctly falling back.");
}

TEST(GLKit, TemporaryShaderNodes) {
    ShaderDef vsh({ { "output1",
                      new ShaderAdditiveCombiner({ new ShaderTempRef(GLKS_FLOAT4, "tempResult", new ShaderCustom("commonResult")),
                                                   new ShaderTempRef(GLKS_FLOAT4, "tempResult", new ShaderCustom("commonResult")),
                                                   new ShaderTempRef(GLKS_FLOAT4, "tempResult", new ShaderCustom("commonResult")) }) } });

    ShaderDef psh({ { "gl_FragColor", new ShaderVarRef("output1") } });
    ShaderContext ctx(vsh, psh);

    ShaderMaterial m;
    GLKShaderPair* p = [[GLKShaderPair alloc] init];
    ctx.generate(m, p);

    EXPECT_EQ_MSG(ctx.numVSTempFuncs(), 0, "No vertex shader temporary functions should be present.");
    EXPECT_EQ_MSG(ctx.numPSTempFuncs(), 0, "No pixel shader temporary functions should be present.");

    EXPECT_EQ_MSG(countOccurrences(p.vertexShader, @"commonResult"), 1, "The common result variable should only be used once.");
    EXPECT_EQ_MSG(countOccurrences(p.vertexShader, @"tempResult"),
                  4,
                  "The temporary result is not being reused the correct number of times.");
}

TEST(GLKit, BasicMath) {
    bool invertible = false;

    Dw32 cos2f;
    Dw32 sin2f;
    Dw32 negSin2f;

    cos2f.f32 = cosf(2.f);
    sin2f.f32 = sinf(2.f);
    negSin2f.f32 = -sin2f.f32;

    const Dw32 goldenIdentity[16] = { 0x3f800000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000, 0x00000000, 0x00000000,
                                      0x00000000, 0x00000000, 0x3f800000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000 };

    const Dw32 goldenRot2OverX[16] = { 0x3f800000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, cos2f,      sin2f,      0x00000000,
                                       0x00000000, negSin2f,   cos2f,      0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000 };

    const Dw32 goldenTrans555[16] = { 0x3f800000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000, 0x00000000, 0x00000000,
                                      0x00000000, 0x00000000, 0x3f800000, 0x00000000, 0x40a00000, 0x40a00000, 0x40a00000, 0x3f800000 };

    const Dw32 goldenOrtho[16] = { 0x3bda740e, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0xbba3d70a, 0x00000000, 0x00000000,
                                   0x00000000, 0x00000000, 0xbda72f05, 0x00000000, 0xbeaaaaab, 0xbe800000, 0xbf853978, 0x3f800000 };

    const Dw32 goldenLookAt[16] = { 0xbf800000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f57fa33, 0x3f0970ac, 0x00000000,
                                    0x00000000, 0x3f0970ac, 0xbf57fa33, 0x00000000, 0x00000000, 0xb5000000, 0xc1509d4e, 0x3f800000 };

    const Dw32 goldenRotIdentZeroVec[16] =
        { 0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000,
          0xffc00000, 0xffc00000, 0xffc00000, 0xffc00000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000 };

    const Dw32 goldenMakeRotZeroVec[16] =
        { 0xffc00000, 0xffc00000, 0xffc00000, 0x00000000, 0xffc00000, 0xffc00000, 0xffc00000, 0x00000000,
          0xffc00000, 0xffc00000, 0xffc00000, 0x00000000, 0x00000000, 0x00000000, 0x00000000, 0x3f800000 };

    GLKMatrix4 mIdentity = GLKMatrix4Identity;
    GLKVector4 v = GLKVector4Make(3.f, 2.f, 1.f, 1.f);
    GLKMatrix4 ortho = GLKMatrix4MakeOrtho(-100.0f, 200.0f, 150.0f, -250.0f, 0.5f, 25.0f);
    GLKMatrix4 lookAt = GLKMatrix4MakeLookAt(0.0f, 7.0f, -11.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f);
    GLKMatrix4 rot = GLKMatrix4MakeXRotation(2.f);
    GLKMatrix4 trans = GLKMatrix4MakeTranslation(5.f, 5.f, 5.f);
    GLKMatrix4 rotIdentZeroVec = GLKMatrix4Rotate(mIdentity, 2.0f, 0.0f, 0.0f, 0.0f);
    GLKMatrix4 makeRotZeroVec = GLKMatrix4MakeRotation(2.0f, 0.0f, 0.0f, 0.0f);

    // Validate generation of identity, rotateX, translation, rotateAxis and compound identity+rotateAxis matrices
    checkMatrixWithinTolerance("GLKMatrix4Identity.", &mIdentity.m[0], &goldenIdentity[0].f32);
    checkMatrixWithinTolerance("GLKMatrix4MakeOrtho.", &ortho.m[0], &goldenOrtho[0].f32);
    checkMatrixWithinTolerance("GLKMatrix4MakeLookAt.", &lookAt.m[0], &goldenLookAt[0].f32);
    checkMatrixWithinTolerance("GLKMatrix4MakeXRotation.", &rot.m[0], &goldenRot2OverX[0].f32);
    checkMatrix("GLKMatrix4MakeTranslation.", &trans.m[0], &goldenTrans555[0].f32);
    checkMatrix("GLKMatrix4Rotate Identity with Zero Mag Vector.", &rotIdentZeroVec.m[0], &goldenRotIdentZeroVec[0].f32);
    checkMatrix("GLKMatrix4MakeRotation over Zero Mag Vector.", &makeRotZeroVec.m[0], &goldenMakeRotZeroVec[0].f32);

    // Validate multiply order
    auto mc = GLKMatrix4Multiply(rot, trans);
    EXPECT_TRUE_MSG(((mc.m30 == trans.m30) && ((mc.m31 != trans.m31) || (mc.m32 != trans.m32))),
                    "Translation before rotateX so Y & Z translation values should change in product.");

    // Generate inversion matrix
    auto mcInverse = GLKMatrix4Invert(mc, &invertible);
    EXPECT_TRUE_MSG(invertible, "Expected to be able to calculate inverse matrix 4x4.");

    // Validate inversion matrix
    auto mcMultInverse = GLKMatrix4Multiply(mc, mcInverse);
    checkMatrixWithinTolerance("A matrix multiplied by it's inverse should produce the identity matrix.",
                               &mcMultInverse.m[0],
                               &mIdentity.m[0]);

    // Validate transform and reverse transform
    auto v2 = GLKMatrix4MultiplyVector4(mcInverse, GLKMatrix4MultiplyVector4(mc, v));
    EXPECT_TRUE_MSG(GLKVector4AllEqualToVector4(v, v2), "Matrix multiplication yielded unexpected result.");

    // Validate handling of non-invertible matrices.
    // Make mc a non-invertible matrix by clearing the m33 element of the rotation+translation matrix.
    mc.m33 = 0.0f;
    mcInverse = GLKMatrix4Invert(mc, &invertible);
    EXPECT_TRUE_MSG((invertible == NO), "GLKMatrix4Invert erroneously reported non-invertible matrix as invertible.");
    checkMatrix("GLKMatrix4Invert should return the identity matrix when a non-invertible matrix is passed in.",
                &mcInverse.m[0],
                &mIdentity.m[0]);

    invertible = false;
    GLKMatrix3 mRot = GLKMatrix3MakeRotation(M_PI / 2.f, 1.f, 3.f, 2.f);
    GLKMatrix3 m3Scale = GLKMatrix3MakeScale(0.3f, 0.5f, 0.9f);

    GLKMatrix3 m3Origin = GLKMatrix3Multiply(mRot, m3Scale);
    GLKMatrix3 m3xInv = GLKMatrix3Invert(m3Origin, &invertible);
    EXPECT_TRUE_MSG(invertible, "Expected to be able to calculate inverse matrix 3x3.");

    GLKMatrix3 m3Identity = GLKMatrix3Identity;
    GLKMatrix3 m3cMultInverse = GLKMatrix3Multiply(m3Origin, m3xInv);
    checkMatrixWithinTolerance("A matrix 3x3 multiplied by it's inverse should produce the identity matrix.",
                               &m3Identity.m[0],
                               &m3cMultInverse.m[0],
                               3);

    // Validate Making a 4x4 matrix using various methods
    float m4Values[16] = { 0.f, 1.f, 2.f, 3.f, 4.f, 5.f, 6.f, 7.f, 8.f, 9.f, 10.f, 11.f, 12.f, 13.f, 14.f, 15.f };
    float m4ValuesT[16] = { 0.f, 4.f, 8.f, 12.f, 1.f, 5.f, 9.f, 13.f, 2.f, 6.f, 10.f, 14.f, 3.f, 7.f, 11.f, 15.f };

    GLKMatrix4 m4 = GLKMatrix4MakeWithArray(m4Values);
    checkMatrix("GLKMatrix4MakeWithArray.", &m4.m[0], &m4Values[0], 4);

    m4 = GLKMatrix4MakeWithArrayAndTranspose(m4Values);
    checkMatrix("GLKMatrix4MakeWithArrayAndTranspose.", &m4.m[0], &m4ValuesT[0], 4);

    m4 = GLKMatrix4MakeWithRows(GLKVector4Make(0.f, 1.f, 2.f, 3.f),
                                GLKVector4Make(4.f, 5.f, 6.f, 7.f),
                                GLKVector4Make(8.f, 9.f, 10.f, 11.f),
                                GLKVector4Make(12.f, 13.f, 14.f, 15.f));
    checkMatrix("GLKMatrix4MakeWithRows should yield transpose of original.", &m4.m[0], &m4ValuesT[0], 4);

    m4 = GLKMatrix4MakeWithColumns(GLKVector4Make(0.f, 1.f, 2.f, 3.f),
                                   GLKVector4Make(4.f, 5.f, 6.f, 7.f),
                                   GLKVector4Make(8.f, 9.f, 10.f, 11.f),
                                   GLKVector4Make(12.f, 13.f, 14.f, 15.f));
    checkMatrix("GLKMatrix4MakeWithColumns.", &m4.m[0], &m4Values[0], 4);

    // Validate Making a 3x3 matrix using various methods
    float m3Values[9] = { 0.f, 1.f, 2.f, 3.f, 4.f, 5.f, 6.f, 7.f, 8.f };
    float m3ValuesT[9] = { 0.f, 3.f, 6.f, 1.f, 4.f, 7.f, 2.f, 5.f, 8.f };

    GLKMatrix3 m3 = GLKMatrix3MakeWithRows(GLKVector3Make(0.f, 1.f, 2.f), GLKVector3Make(3.f, 4.f, 5.f), GLKVector3Make(6.f, 7.f, 8.f));
    checkMatrix("GLKMatrix3MakeWithRows should yield transpose of original.", &m3.m[0], &m3ValuesT[0], 3);

    m3 = GLKMatrix3MakeWithColumns(GLKVector3Make(0.f, 1.f, 2.f), GLKVector3Make(3.f, 4.f, 5.f), GLKVector3Make(6.f, 7.f, 8.f));
    checkMatrix("GLKMatrix3MakeWithColumns.", &m3.m[0], &m3Values[0], 3);

    m3 = GLKMatrix3MakeWithArray(m3Values);
    checkMatrix("GLKMatrix3MakeWithArray.", &m3.m[0], &m3Values[0], 3);

    m3 = GLKMatrix3MakeWithArrayAndTranspose(m3Values);
    checkMatrix("GLKMatrix3MakeWithArrayAndTranspose.", &m3.m[0], &m3ValuesT[0], 3);

    // Validate sub-matrices
    m4 = GLKMatrix4MakeWithArray(m4Values);
    m3 = GLKMatrix4GetMatrix3(m4);
    GLKMatrix2 m2 = GLKMatrix4GetMatrix2(m4);
    GLKMatrix2 m2_2 = GLKMatrix3GetMatrix2(m3);

    EXPECT_TRUE_MSG(m3.m00 == m4.m00 && m3.m01 == m4.m01 && m3.m02 == m4.m02 && m3.m10 == m4.m10 && m3.m11 == m4.m11 && m3.m12 == m4.m12 &&
                        m3.m20 == m4.m20 && m3.m21 == m4.m21 && m3.m22 == m4.m22,
                    "GLKMatrix4GetMatrix3 yielded unexpected result.");

    EXPECT_TRUE_MSG(m2.m00 == m4.m00 && m2.m01 == m4.m01 && m2.m10 == m4.m10 && m2.m11 == m4.m11,
                    "GLKMatrix4GetMatrix2 yielded unexpected result.");

    EXPECT_TRUE_MSG(m2_2.m00 == m3.m00 && m2_2.m01 == m3.m01 && m2_2.m10 == m3.m10 && m2_2.m11 == m3.m11,
                    "GLKMatrix3GetMatrix2 yielded unexpected result.");

    // translate with vector
    m4 = GLKMatrix4MakeWithArray(m4Values);
    GLKMatrix4 m4_translated = GLKMatrix4TranslateWithVector3(m4, GLKVector3Make(34.2f, 6.3f, 3.9f));
    GLKMatrix4 m4_translated4 = GLKMatrix4TranslateWithVector4(m4, GLKVector4Make(34.2f, 6.3f, 3.9f, 1000.0f));

    checkMatrix("GLKMatrix4TranslateWithVector3 should be equal GLKMatrix4TranslateWithVector4.",
                &m4_translated.m[0],
                &m4_translated4.m[0],
                4);
    float m4Values_translate[16] = { 0.f, 1.f, 2.f, 3.f, 4.f, 5.f, 6.f, 7.f, 8.f, 9.f, 10.f, 11.f, 68.4f, 113.8f, 159.200012f, 204.6f };

    checkMatrix("GLKMatrix4TranslateWithVector3 to test values", &m4_translated.m[0], &m4Values_translate[0], 4);
}

TEST(GLKit, Quaternions) {
    float values[4] = { 0.f, 1.f, 2.f, 3.f };
    GLKQuaternion q = GLKQuaternionMake(0.f, 1.f, 2.f, 3.f);
    GLKQuaternion q2 = GLKQuaternionMakeWithArray(values);
    GLKQuaternion q3 = GLKQuaternionMakeWithVector3(GLKVector3Make(0.f, 1.f, 2.f), 3.f);
    EXPECT_TRUE_MSG(q.x == q2.x && q.y == q2.y && q.z == q2.z && q.w == q2.w, "Basic quaternion construction failed!");
    EXPECT_TRUE_MSG(q.x == q3.x && q.y == q3.y && q.z == q3.z && q.w == q3.w, "Basic quaternion construction failed!");

    q = GLKQuaternionNormalize(q);
    EXPECT_TRUE_MSG(fabsf(GLKQuaternionLength(q) - 1.f) <= COMPARISON_EPSILON, "Normalized quaternion has bad length.");

    q = GLKQuaternionMakeWithAngleAndAxis(M_PI, 0.f, 1.f, 0.f);
    q2 = GLKQuaternionMakeWithAngleAndVector3Axis(M_PI, GLKVector3YAxis());
    EXPECT_TRUE_MSG(q.x == q2.x && q.y == q2.y && q.z == q2.z && q.w == q2.w, "Quaternion angle/axis construction failed!");

    GLKVector3 axis = GLKQuaternionAxis(q);
    float angle = GLKQuaternionAngle(q);
    EXPECT_TRUE_MSG(fabsf(angle - (float)M_PI) <= COMPARISON_EPSILON, "Incorrect angle extracted!");
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(axis, GLKVector3YAxis()), "Incorrect rotation axis extracted!");

    GLKVector3 rotated = GLKVector3XAxis();
    GLKQuaternionRotateVector3Array(q, &rotated, 1);
    EXPECT_TRUE_MSG(GLKVector3AllEqualToScalar(GLKVector3Add(rotated, GLKVector3XAxis()), 0.f), "Quaternion rotation appears incorrect.");

    GLKMatrix3 xrot = GLKMatrix3MakeXRotation(M_PI / 3.f);
    GLKMatrix3 xrot2 = GLKMatrix3Make(1.f, 0.f, 0.f, 0.f, -1.f, 0.f, 0.f, 0.f, -1.f);
    GLKMatrix3 yrot = GLKMatrix3Make(-1.f, 0.f, 0.f, 0.f, 1.f, 0.f, 0.f, 0.f, -1.f);
    GLKMatrix3 zrot = GLKMatrix3Make(-1.f, 0.f, 0.f, 0.f, -1.f, 0.f, 0.f, 0.f, 1.f);

    q = GLKQuaternionMakeWithMatrix3(xrot);
    EXPECT_TRUE_MSG(fabsf(GLKQuaternionLength(q) - 1.f) <= COMPARISON_EPSILON, "Quaternion length incorrect");
    axis = GLKQuaternionAxis(q);
    angle = GLKQuaternionAngle(q);
    EXPECT_TRUE_MSG(fabsf(angle - ((float)M_PI / 3.f)) <= COMPARISON_EPSILON, "Quaternion angle extracted incorrectly!");
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(axis, GLKVector3XAxis()), "Incorrect rotation axis extracted!");

    q = GLKQuaternionMakeWithMatrix3(xrot2);
    EXPECT_TRUE_MSG(fabsf(GLKQuaternionLength(q) - 1.f) <= COMPARISON_EPSILON, "Quaternion length incorrect");
    axis = GLKQuaternionAxis(q);
    angle = GLKQuaternionAngle(q);
    EXPECT_TRUE_MSG(fabsf(angle - (float)M_PI) <= COMPARISON_EPSILON, "Quaternion angle extracted incorrectly!");
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(axis, GLKVector3XAxis()), "Incorrect rotation axis extracted!");

    q = GLKQuaternionMakeWithMatrix3(yrot);
    EXPECT_TRUE_MSG(fabsf(GLKQuaternionLength(q) - 1.f) <= COMPARISON_EPSILON, "Quaternion length incorrect");
    axis = GLKQuaternionAxis(q);
    angle = GLKQuaternionAngle(q);
    EXPECT_TRUE_MSG(fabsf(angle - (float)M_PI) <= COMPARISON_EPSILON, "Quaternion angle extracted incorrectly!");
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(axis, GLKVector3YAxis()), "Incorrect rotation axis extracted!");

    q = GLKQuaternionMakeWithMatrix3(zrot);
    EXPECT_TRUE_MSG(fabsf(GLKQuaternionLength(q) - 1.f) <= COMPARISON_EPSILON, "Quaternion length incorrect");
    axis = GLKQuaternionAxis(q);
    angle = GLKQuaternionAngle(q);
    EXPECT_TRUE_MSG(fabsf(angle - (float)M_PI) <= COMPARISON_EPSILON, "Quaternion angle extracted incorrectly!");
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(axis, GLKVector3ZAxis()), "Incorrect rotation axis extracted!");

    // Test GLKQuaternionSlerp lerp
    q = GLKQuaternionMake(1.f, 2.f, 3.f, 1.f);
    q2 = GLKQuaternionMake(3.f, 4.f, 5.f, 5.f);
    q3 = GLKQuaternionSlerp(q, q2, 0.25f);
    NSString* q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(1.5f, 2.5f, 3.5f, 2.f)),
                    "Quaternion slerp 0.25 incorrect!, %s",
                    [q3_string UTF8String]);
    q3 = GLKQuaternionSlerp(q, q2, 0.5f);
    q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(2.f, 3.f, 4.f, 3.f)),
                    "Quaternion slerp 0.5 incorrect!, %s",
                    [q3_string UTF8String]);
    q3 = GLKQuaternionSlerp(q, q2, 0.75f);
    q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(2.5f, 3.5f, 4.5f, 4.f)),
                    "Quaternion slerp 0.75 incorrect!, %s",
                    [q3_string UTF8String]);

    // Test create matrix with GLKQuaternion
    GLKMatrix4 m4_q3 = GLKMatrix4MakeWithQuaternion(q3);
    GLKMatrix3 m3_q2 = GLKMatrix3MakeWithQuaternion(q2);
    float m4Values[16] = { -0.187214434,
                           0.977168858,
                           -0.100456655,
                           0,
                           -0.337899506,
                           0.0319636464,
                           0.940639138,
                           0,
                           0.922374308,
                           0.210045666,
                           0.324200988,
                           0,
                           0,
                           0,
                           0,
                           1 };
    checkMatrix("GLKMatrix4MakeWithQuaternion.", &m4_q3.m[0], &m4Values[0], 4);

    float m3Values[9] = { -0.0933331251, 0.98666644,  -0.133333325, -0.346666574, 0.0933335423,
                          0.933333158,   0.933333158, 0.133333325,  0.333333462 };
    checkMatrix("GLKMatrix3MakeWithQuaternion.", &m3_q2.m[0], &m3Values[0], 3);

    // Test GLKQuaternionSlerp slerp
    q = GLKQuaternionNormalize(GLKQuaternionMake(1.f, 0.2f, -0.7f, 1.f));
    q2 = GLKQuaternionNormalize(GLKQuaternionMake(3.3f, -4.5f, 3.1f, 2.f));
    q3 = GLKQuaternionSlerp(q, q2, 0.25);
    q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(0.716001987, -0.119813651, -0.225444451, 0.649738788)),
                    "Quaternion slerp 0.25 incorrect!, %s",
                    [q3_string UTF8String]);

    q3 = GLKQuaternionSlerp(q, q2, 0.5);
    q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(0.721375524, -0.351655632, 0.0149955451, 0.596431732)),
                    "Quaternion slerp 0.25 incorrect!, %s",
                    [q3_string UTF8String]);

    q3 = GLKQuaternionSlerp(q, q2, 0.75);
    q3_string = NSStringFromGLKQuaternion(q3);
    EXPECT_TRUE_MSG(GLKQuaternionAllEqualToQuaternion(q3, GLKQuaternionMake(0.644200087, -0.54325676, 0.253719538, 0.474873364)),
                    "Quaternion slerp 0.25 incorrect!, %s",
                    [q3_string UTF8String]);
}

TEST(GLKit, Rotations) {
    GLKVector4 v = GLKVector4Make(3.f, 2.f, 1.f, 0.f);

    GLKMatrix4 mx = GLKMatrix4MakeXRotation(M_PI);
    GLKMatrix4 my = GLKMatrix4MakeYRotation(M_PI);
    GLKMatrix4 mz = GLKMatrix4MakeZRotation(M_PI);

    auto projx = GLKVector4MultiplyScalar(GLKVector4Project(v, GLKVector4Make(1.f, 0.f, 0.f, 0.f)), 2.f);
    auto projy = GLKVector4MultiplyScalar(GLKVector4Project(v, GLKVector4Make(0.f, 1.f, 0.f, 0.f)), 2.f);
    auto projz = GLKVector4MultiplyScalar(GLKVector4Project(v, GLKVector4Make(0.f, 0.f, 1.f, 0.f)), 2.f);

    auto dx = GLKMatrix4MultiplyVector4(mx, v);
    auto dy = GLKMatrix4MultiplyVector4(my, v);
    auto dz = GLKMatrix4MultiplyVector4(mz, v);

    EXPECT_TRUE_MSG(GLKVector4AllEqualToScalar(GLKVector4Subtract(GLKVector4Add(v, dx), projx), 0.f), "Unexpected vector addition result.");
    EXPECT_TRUE_MSG(GLKVector4AllEqualToScalar(GLKVector4Subtract(GLKVector4Add(v, dy), projy), 0.f), "Unexpected vector addition result.");
    EXPECT_TRUE_MSG(GLKVector4AllEqualToScalar(GLKVector4Subtract(GLKVector4Add(v, dz), projz), 0.f), "Unexpected vector addition result.");

    GLKMatrix4 m = GLKMatrix4MakeRotation(M_PI / 2.f, 1.f, 1.f, 1.f);
    v = GLKVector4Make(4.f, 5.f, 6.f, 0.f);

    auto v2 = GLKMatrix4MultiplyVector4(m, v);
    auto v3 = GLKMatrix4MultiplyVector4(m, v2);
    auto v4 = GLKMatrix4MultiplyVector4(m, v3);

    GLKVector4 dv =
        GLKVector4Make(GLKVector4Distance(v, v2), GLKVector4Distance(v2, v3), GLKVector4Distance(v3, v4), GLKVector4Distance(v4, v));
    EXPECT_TRUE_MSG(GLKVector4AllEqualToScalar(dv, dv.x), "Unexpected vector distance result.");

    GLKMatrix3 m3x = GLKMatrix3MakeXRotation(M_PI / 2.f);
    GLKMatrix3 m3xInv = GLKMatrix3Invert(m3x, NULL);

    GLKVector3 v31 = GLKVector3Make(1.f, 1.f, 1.f);
    GLKVector3 v3rot = GLKMatrix3MultiplyVector3(m3xInv, GLKMatrix3MultiplyVector3(m3x, v31));
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(v31, v3rot), "Incorrect inversion of 3x3 matrix.");
}

TEST(GLKit, Interpolation) {
    GLKVector4 a = GLKVector4Make(4.f, 3.f, 2.f, 1.f);
    GLKVector4 b = GLKVector4Negate(a);

    auto res = GLKVector4Lerp(a, b, 0.5f);
    EXPECT_TRUE_MSG(GLKVector4AllEqualToScalar(res, 0.f), "Unexpected interpolation result.");

    float dist = GLKVector4Distance(a, b);
    EXPECT_LE_MSG(fabsf(dist - 2.f * sqrtf(GLKVector4DotProduct(a, a))), COMPARISON_EPSILON, "Interpolation not within acceptable error.");

    GLKVector3 v = GLKVector3Make(0.f, 1.f, 1.f);
    GLKVector3 proj = GLKVector3Project(v, GLKVector3ZAxis());
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(proj, GLKVector3ZAxis()), "GLKVector3 projection failed!");

    GLKVector4 v4 = GLKVector4Make(0.f, 1.f, 1.f, 0.f);
    GLKVector4 zAxis = GLKVector4MakeWithVector3(GLKVector3ZAxis(), 0.f);
    GLKVector4 proj4 = GLKVector4Project(v4, zAxis);
    EXPECT_TRUE_MSG(GLKVector4AllEqualToVector4(proj4, zAxis), "GLKVector4 projection failed!");
}

TEST(GLKit, Projection) {
    GLKMatrix4 m4_tr = GLKMatrix4TranslateWithVector3(GLKMatrix4Make(0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15),
                                                      GLKVector3Make(34.2f, 6.3f, 3.9f));

    GLKVector3 testVec = GLKMatrix4MultiplyAndProjectVector3(m4_tr, GLKVector3Make(0.5, 0.3, 0.1));

    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(testVec, GLKVector3Make(0.336359322, 0.557572901, 0.77878654)),
                    "Incorrect computation in GLKMatrix4MultiplyAndProjectVector3!");

    GLKMatrix4 projection = GLKMatrix4Make(3.38356233, 0, 0, 0, 0, 4.51070833, 0, 0, 0, 0, -1.01133287, -1, 0, 0, -4.02266598, 0);
    GLKMatrix4 modelview = GLKMatrix4Make(0.989012539,
                                          0.0290720258,
                                          -0.144865006,
                                          0,
                                          0.000000000385218968,
                                          0.980440258,
                                          0.196758181,
                                          0,
                                          0.147753373,
                                          -0.19459866,
                                          0.969679176,
                                          0,
                                          -2.29900551,
                                          9.5357027,
                                          -61.1366386,
                                          0.999990463);
    int viewport[4] = { 0, 0, 2125, 1594 };

    GLKVector3 vd = { 2.67963099f, -25.2658691f, 0.158109993f };
    GLKVector3 vProj = GLKMathProject(vd, modelview, projection, viewport);
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(vProj, GLKVector3Make(1082.79614, -26.0647049, 0.975349426)),
                    "Incorrect computation in GLKMathProject!");

    bool success = false;
    GLKVector3 ptVec = { 758.0, 1004.0, 0.966700792 };
    GLKVector3 vUnProj = GLKMathUnproject(ptVec, modelview, projection, viewport, &success);
    EXPECT_TRUE_MSG(GLKVector3AllEqualToVector3(vUnProj, GLKVector3Make(-3.620101, -4.562381, 10.201591)),
                    "Incorrect computation in GLKMathUnproject! %s",
                    [NSStringFromGLKVector3(vUnProj) UTF8String]);

    EXPECT_TRUE_MSG(success, "expected YES from GLKMathUnproject.");
}
