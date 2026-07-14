#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"

@interface LocalVideoPlayer : NSObject
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

%hook LocalVideoPlayer

- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    %orig;
    if (pixelBuffer) {
        static QMEnhancerView *enhancer = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            enhancer = [[QMEnhancerView alloc] init];
        });
        [enhancer processPixelBuffer:pixelBuffer];
    }
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    // 延迟 5 秒，等 SpringBoard 完全启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            // 多种方式获取 keyWindow，兼容 iOS 15/16
            UIWindow *window = nil;
            
            // 方式1：遍历 windows
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }
            
            // 方式2：用 connectedScenes（iOS 13+）
            if (!window) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *ws = (UIWindowScene *)scene;
                        for (UIWindow *w in ws.windows) {
                            if (w.isKeyWindow) {
                                window = w;
                                break;
                            }
                        }
                    }
                    if (window) break;
                }
            }
            
            if (window) {
                QMEnhancerView *enhancer = [QMEnhancerView sharedInstance];
                [enhancer showInWindow:window];
                NSLog(@"[QianmianEnhancer] 悬浮窗已显示");
            } else {
                NSLog(@"[QianmianEnhancer] 未找到 window");
            }
        } @catch (NSException *e) {
            NSLog(@"[QianmianEnhancer] 出错: %@", e);
        }
    });
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[QianmianEnhancer] 插件已加载");
    }
}
