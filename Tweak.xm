#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"
#import <objc/runtime.h>

static void mark(NSString *name) {
    NSString *path = [NSString stringWithFormat:@"/tmp/qm_%@.txt", name];
    [@"ok" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

static void dumpMethods() {
    Class cls = objc_getClass("LocalVideoPlayer");
    if (!cls) {
        mark(@"no_class");
        return;
    }
    
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    
    NSMutableString *result = [NSMutableString string];
    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        [result appendFormat:@"%s\n", sel_getName(sel)];
    }
    
    free(methods);
    
    [result writeToFile:@"/tmp/qm_all_methods.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    mark(@"dump_done");
}

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
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
        mark(@"dylib_loaded");
        // 延迟 3 秒后列出所有方法
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dumpMethods();
        });
    }
}
