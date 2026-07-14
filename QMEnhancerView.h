#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface QMEnhancerView : UIView

@property (nonatomic, assign) CGFloat zoomScale;            // 缩放比例 1.0 - 3.0
@property (nonatomic, strong) UIColor *mappingColor;        // 映射颜色
@property (nonatomic, assign) BOOL colorMappingEnabled;     // 是否启用颜色映射
@property (nonatomic, assign) CGFloat colorMixIntensity;    // 颜色混合强度 0.0 - 1.0
@property (nonatomic, assign) BOOL softGlowEnabled;         // 柔光滤镜开关

+ (instancetype)sharedInstance;
- (void)showInWindow:(UIWindow *)window;
- (void)toggleVisibility;

// 处理像素缓冲区 - 应用缩放、颜色映射、柔光滤镜（实时逐帧处理）
- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer;

// 从共享文件加载设置（mediaserverd进程调用）
+ (CGFloat)currentZoomScale;
+ (UIColor *)currentMappingColor;
+ (BOOL)isColorMappingEnabled;
+ (CGFloat)currentColorMixIntensity;
+ (BOOL)isSoftGlowEnabled;

@end
