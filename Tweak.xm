#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"
#import <substrate.h>
#import <sys/sysctl.h>

@interface LocalVideoPlayer : NSObject
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer;
@end

static void mark(NSString *name) {
    NSString *path = [NSString stringWithFormat:@"/tmp/qm_%@.txt", name];
    [@"ok" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// 获取当前进程名
static NSString *currentProcessName() {
    char name[256];
    size_t size = sizeof(name);
    if (sysctlbyname("kern.proc.name", name, &size, NULL, 0) == 0) {
        return [NSString stringWithUTF8String:name];
    }
    return @"unknown";
}

// 原方法指针
static void (*orig_render)(id self, SEL _cmd, CVPixelBufferRef pixelBuffer);

// 替换后的方法
void new_render(id self, SEL _cmd, CVPixelBufferRef pixelBuffer) {
    mark(@"hook_called");
    orig_render(self, _cmd, pixelBuffer);
    
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
        NSString *procName = currentProcessName();
        mark([NSString stringWithFormat:@"dylib_%@", procName]);
        
        // 延迟一点再 hook，确保类已经加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class cls = objc_getClass("LocalVideoPlayer");
            if (cls) {
                mark(@"class_found");
                Method m = class_getInstanceMethod(cls, @selector(renderReplacementToPixelBuffer:));
                if (m) {
                    mark(@"method_found");
                    MSHookMessageEx(cls, @selector(renderReplacementToPixelBuffer:), (IMP)&new_render, (IMP *)&orig_render);
                    mark(@"hook_done");
                } else {
                    mark(@"method_not_found");
                }
            } else {
                mark(@"class_not_found");
            }
        });
    }
}
