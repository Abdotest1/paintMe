//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<file_selector_ios/FileSelectorPlugin.h>)
#import <file_selector_ios/FileSelectorPlugin.h>
#else
@import file_selector_ios;
#endif

#if __has_include(<gal/GalPlugin.h>)
#import <gal/GalPlugin.h>
#else
@import gal;
#endif

#if __has_include(<image_picker_ios/FLTImagePickerPlugin.h>)
#import <image_picker_ios/FLTImagePickerPlugin.h>
#else
@import image_picker_ios;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FileSelectorPlugin registerWithRegistrar:[registry registrarForPlugin:@"FileSelectorPlugin"]];
  [GalPlugin registerWithRegistrar:[registry registrarForPlugin:@"GalPlugin"]];
  [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
}

@end
