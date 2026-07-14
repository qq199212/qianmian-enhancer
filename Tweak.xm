#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"
#import <dlfcn.h>

@interface LocalVideoPlayer : NSObject
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

// 创建调试标记文件
static void mark(NSString *name) {
    NSString *path = [NSString stringWithFormat:@"/tmp/qm_%@.txt", name];
    [@"ok" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%hook LocalVideoPlayer

- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    mark(@"hook_called"); // 标记：hook 方法被调用了
    %orig;
    if (pixelBuffer) {
        static QMEnhancerView *enhancer = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            enhancer = [[QMEnhancerView alloc] init];
            mark(@"enhancer_created");
        });
        [enhancer processPixelBuffer:pixelBuffer];
    }
}

%end

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    mark(@"springboard_launch");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        @try {
            UIWindow *window = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w.isKeyWindow) { window = w; break; }
            }
            if (!window) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]]) {
                        UIWindowScene *ws = (UIWindowScene *)scene;
                        for (UIWindow *w in ws.windows) {
                            if (w.isKeyWindow) { window = w; break; }
                        }
                    }
                    if (window) break;
                }
            }
            
            if (window) {
                QMEnhancerView *enhancer = [QMEnhancerView sharedInstance];
                [enhancer showInWindow:window];
                mark(@"ui_shown");
            }
        } @catch (NSException *e) {
            mark(@"ui_error");
        }
    });
}

%end

%ctor {
    @autoreleasepool {
        mark(@"dylib_loaded");
    }
}
