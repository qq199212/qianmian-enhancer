#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"
#import <objc/runtime.h>

static void mark(NSString *name) {
    NSString *path = [NSString stringWithFormat:@"/tmp/qm_%@.txt", name];
    [@"ok" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    mark(@"springboard_process");
    
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
            }
        } @catch (NSException *e) {}
    });
}

%end

%ctor {
    @autoreleasepool {
        // 延迟 2 秒检查
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 检查有没有 LocalVideoPlayer 类（只有视频进程才有）
            Class cls = objc_getClass("LocalVideoPlayer");
            if (cls) {
                mark(@"video_process_injected");
                
                // 同时测试 hook setCurrentPixelBuffer:
                Method setter = class_getInstanceMethod(cls, @selector(setCurrentPixelBuffer:));
                if (setter) {
                    mark(@"setter_exists");
                }
                
                Method getter = class_getInstanceMethod(cls, @selector(currentPixelBuffer));
                if (getter) {
                    mark(@"getter_exists");
                }
                
                Method update = class_getInstanceMethod(cls, @selector(updateCurrentBuffer:));
                if (update) {
                    mark(@"update_exists");
                }
            }
        });
    }
}
