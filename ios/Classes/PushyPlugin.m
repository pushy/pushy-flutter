#import "PushyPlugin.h"
#import <pushy_flutter/pushy_flutter-Swift.h>

@implementation PushyPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [PushyFlutter registerWithRegistrar:registrar];
}
@end
