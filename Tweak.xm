#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"

static void mark(NSString *name) {
    NSString *path = [NSString stringWithFormat:@"/tmp/qm_%@.txt", name];
    [@"ok" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

@interface LocalVideoPlayer : NSObject
- (void)updateCurrentBuffer:(CVPixelBufferRef)buffer;
@end

%hook LocalVideoPlayer

- (void)updateCurrentBuffer:(CVPixelBufferRef)buffer {
    static int count = 0;
    if (count++ < 5) { // 只标记前5次，避免刷屏
        mark(@"update_called");
    }
    
    // 简单测试：直接把画面涂成红色
    if (buffer) {
        CVPixelBufferLockBaseAddress(buffer, 0);
        void *base = CVPixelBufferGetBaseAddress(buffer);
        size_t width = CVPixelBufferGetWidth(buffer);
        size_t height = CVPixelBufferGetHeight(buffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);
        
        // BGRA 格式，直接填充红色
        for (int y = 0; y < height; y++) {
            unsigned char *row = (unsigned char *)base + y * bytesPerRow;
            for (int x = 0; x < width; x++) {
                row[x*4+0] = 0;   // B
                row[x*4+1] = 0;   // G
                row[x*4+2] = 255; // R
                row[x*4+3] = 255; // A
            }
        }
        CVPixelBufferUnlockBaseAddress(buffer, 0);
    }
    
    %orig;
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
