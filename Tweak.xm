#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"

@interface LocalVideoPlayer : NSObject
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (id)preprocessFrame:(id)frame;
@end

%hook LocalVideoPlayer

- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    %orig;
    if (pixelBuffer) {
        static QMEnhancerView *enhancer = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            enhancer = [QMEnhancerView sharedInstance];
        });
        [enhancer processPixelBuffer:pixelBuffer];
    }
}

%end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 兼容 iOS 13+ 获取 keyWindow
        UIWindow *window = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        if (window) {
            QMEnhancerView *enhancer = [QMEnhancerView sharedInstance];
            [enhancer showInWindow:window];
        }
    });
}
%end

%ctor {
    @autoreleasepool {
        [QMEnhancerView sharedInstance];
        NSLog(@"[QianmianEnhancer] 增强插件已加载");
    }
}
