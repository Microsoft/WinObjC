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

// WindowsDevices.h
// Generated from winmd2objc

#pragma once

#ifndef OBJCUWP_WINDOWS_DEVICES_EXPORT
#define OBJCUWP_WINDOWS_DEVICES_EXPORT __declspec(dllimport)
#ifndef IN_OBJCUWP_BUILD
#pragma comment(lib, "ObjCUWP_Windows_Devices.lib")
#endif
#endif
#include <UWP/interopBase.h>

@class WDLowLevelDevicesAggregateProvider, WDLowLevelDevicesController;
@protocol WDILowLevelDevicesAggregateProvider, WDILowLevelDevicesAggregateProviderFactory, WDILowLevelDevicesController, WDILowLevelDevicesControllerStatics;

#include "WindowsDevicesGpioProvider.h"
#include "WindowsDevicesAdcProvider.h"
#include "WindowsDevicesSpiProvider.h"
#include "WindowsDevicesPwmProvider.h"
#include "WindowsDevicesI2cProvider.h"

#import <Foundation/Foundation.h>

// Windows.Devices.ILowLevelDevicesAggregateProvider
#ifndef __WDILowLevelDevicesAggregateProvider_DEFINED__
#define __WDILowLevelDevicesAggregateProvider_DEFINED__

@protocol WDILowLevelDevicesAggregateProvider
@property (readonly) RTObject<WDAPIAdcControllerProvider>* adcControllerProvider;
@property (readonly) RTObject<WDGPIGpioControllerProvider>* gpioControllerProvider;
@property (readonly) RTObject<WDIPII2cControllerProvider>* i2cControllerProvider;
@property (readonly) RTObject<WDPPIPwmControllerProvider>* pwmControllerProvider;
@property (readonly) RTObject<WDSPISpiControllerProvider>* spiControllerProvider;
@end

OBJCUWP_WINDOWS_DEVICES_EXPORT
@interface WDILowLevelDevicesAggregateProvider : RTObject <WDILowLevelDevicesAggregateProvider>
@end

#endif // __WDILowLevelDevicesAggregateProvider_DEFINED__

// Windows.Devices.LowLevelDevicesAggregateProvider
#ifndef __WDLowLevelDevicesAggregateProvider_DEFINED__
#define __WDLowLevelDevicesAggregateProvider_DEFINED__

OBJCUWP_WINDOWS_DEVICES_EXPORT
@interface WDLowLevelDevicesAggregateProvider : RTObject <WDILowLevelDevicesAggregateProvider>
+ (WDLowLevelDevicesAggregateProvider*)make:(RTObject<WDAPIAdcControllerProvider>*)adc pwm:(RTObject<WDPPIPwmControllerProvider>*)pwm gpio:(RTObject<WDGPIGpioControllerProvider>*)gpio i2c:(RTObject<WDIPII2cControllerProvider>*)i2c spi:(RTObject<WDSPISpiControllerProvider>*)spi ACTIVATOR;
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
@property (readonly) RTObject<WDAPIAdcControllerProvider>* adcControllerProvider;
@property (readonly) RTObject<WDGPIGpioControllerProvider>* gpioControllerProvider;
@property (readonly) RTObject<WDIPII2cControllerProvider>* i2cControllerProvider;
@property (readonly) RTObject<WDPPIPwmControllerProvider>* pwmControllerProvider;
@property (readonly) RTObject<WDSPISpiControllerProvider>* spiControllerProvider;
@end

#endif // __WDLowLevelDevicesAggregateProvider_DEFINED__

// Windows.Devices.LowLevelDevicesController
#ifndef __WDLowLevelDevicesController_DEFINED__
#define __WDLowLevelDevicesController_DEFINED__

OBJCUWP_WINDOWS_DEVICES_EXPORT
@interface WDLowLevelDevicesController : RTObject
#if defined(__cplusplus)
+ (instancetype)createWith:(IInspectable*)obj __attribute__ ((ns_returns_autoreleased));
#endif
+ (RTObject<WDILowLevelDevicesAggregateProvider>*)defaultProvider;
+ (void)setDefaultProvider:(RTObject<WDILowLevelDevicesAggregateProvider>*)value;
@end

#endif // __WDLowLevelDevicesController_DEFINED__

