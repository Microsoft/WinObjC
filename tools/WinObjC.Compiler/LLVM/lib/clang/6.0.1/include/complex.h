// Copyright (c) Microsoft Corporation. All rights reserved.

#pragma once
#pragma clang system_header
#pragma comment(lib, "vcclang")

#define _C_COMPLEX_T
#define _C_double_complex _Complex double
#define _C_float_complex _Complex float
#define _C_ldouble_complex _Complex long double
#include_next <complex.h>
