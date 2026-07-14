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
    @autoreleasepool {}
}
