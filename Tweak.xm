#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "QMEnhancerView.h"

// 声明原类 - 我们只需要Hook它的方法
@interface LocalVideoPlayer : NSObject
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (id)preprocessFrame:(id)frame;
@end

%hook LocalVideoPlayer

// Hook渲染方法 - 在原渲染完成后应用我们的增强效果
- (void)renderReplacementToPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    // 先调用原方法完成基础渲染
    %orig;
    
    // 应用我们的增强效果（缩放 + 颜色映射）
    if (pixelBuffer) {
        static QMEnhancerView *enhancer = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            enhancer = [QMEnhancerView sharedInstance];
        });
        [enhancer processPixelBuffer:pixelBuffer];
    }
}

// 也可以Hook帧预处理方法
- (id)preprocessFrame:(id)frame {
    id result = %orig;
    return result;
}

%end


// 在SpringBoard进程中显示控制悬浮球
%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (window) {
            QMEnhancerView *enhancer = [QMEnhancerView sharedInstance];
            [enhancer showInWindow:window];
        }
    });
}

%end


// mediaserverd进程中初始化增强器
%ctor {
    @autoreleasepool {
        // 预初始化单例
        [QMEnhancerView sharedInstance];
        NSLog(@"[QianmianEnhancer] 增强插件已加载");
    }
}
