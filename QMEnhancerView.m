#import "QMEnhancerView.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>

// 共享设置文件路径 - 两个进程都能访问
static NSString *const kQMSharedSettingsPath = @"/var/mobile/Library/qianmian_enhancer_settings.plist";

@interface QMEnhancerView ()

@property (nonatomic, strong) UIView *controlPanel;
@property (nonatomic, strong) UIButton *floatButton;
@property (nonatomic, strong) UISlider *zoomSlider;
@property (nonatomic, strong) UIButton *colorPickButton;
@property (nonatomic, strong) UIButton *softGlowButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UILabel *zoomLabel;
@property (nonatomic, strong) UILabel *mixLabel;
@property (nonatomic, strong) UISlider *mixSlider;
@property (nonatomic, strong) UIView *colorPreview;

// 取色模式覆盖层
@property (nonatomic, strong) UIView *colorPickOverlay;
@property (nonatomic, strong) UILabel *pickHintLabel;
@property (nonatomic, assign) BOOL isColorPickMode;

@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, assign) BOOL isPanelVisible;
@property (nonatomic, assign) CGPoint startPoint;

@end

@implementation QMEnhancerView

#pragma mark - 共享设置（进程间通信）

+ (NSDictionary *)sharedSettings {
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:kQMSharedSettingsPath];
    if (!settings) {
        // 默认设置
        return @{
            @"zoomScale": @(1.0),
            @"colorMappingEnabled": @(NO),
            @"colorRed": @(1.0),
            @"colorGreen": @(1.0),
            @"colorBlue": @(1.0),
            @"colorMixIntensity": @(0.5),
            @"softGlowEnabled": @(NO)
        };
    }
    return settings;
}

+ (void)saveSharedSettings:(NSDictionary *)settings {
    [settings writeToFile:kQMSharedSettingsPath atomically:YES];
}

+ (CGFloat)currentZoomScale {
    return [[[self sharedSettings] objectForKey:@"zoomScale"] floatValue];
}

+ (BOOL)isColorMappingEnabled {
    return [[[self sharedSettings] objectForKey:@"colorMappingEnabled"] boolValue];
}

+ (UIColor *)currentMappingColor {
    NSDictionary *settings = [self sharedSettings];
    CGFloat r = [[settings objectForKey:@"colorRed"] floatValue];
    CGFloat g = [[settings objectForKey:@"colorGreen"] floatValue];
    CGFloat b = [[settings objectForKey:@"colorBlue"] floatValue];
    return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

+ (CGFloat)currentColorMixIntensity {
    return [[[self sharedSettings] objectForKey:@"colorMixIntensity"] floatValue];
}

+ (BOOL)isSoftGlowEnabled {
    return [[[self sharedSettings] objectForKey:@"softGlowEnabled"] boolValue];
}

- (void)saveCurrentSettings {
    CGFloat r, g, b, a;
    [_mappingColor getRed:&r green:&g blue:&b alpha:&a];
    
    NSDictionary *settings = @{
        @"zoomScale": @(_zoomScale),
        @"colorMappingEnabled": @(_colorMappingEnabled),
        @"colorRed": @(r),
        @"colorGreen": @(g),
        @"colorBlue": @(b),
        @"colorMixIntensity": @(_colorMixIntensity),
        @"softGlowEnabled": @(_softGlowEnabled)
    };
    [[self class] saveSharedSettings:settings];
}

+ (instancetype)sharedInstance {
    static QMEnhancerView *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[QMEnhancerView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _zoomScale = 1.0;
        _colorMappingEnabled = NO;
        _mappingColor = [UIColor whiteColor];
        _colorMixIntensity = 0.5;
        _softGlowEnabled = NO;
        _ciContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        _isPanelVisible = NO;
        _isColorPickMode = NO;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.backgroundColor = [UIColor clearColor];
    
    // 悬浮按钮
    _floatButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _floatButton.frame = self.bounds;
    _floatButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
    _floatButton.layer.cornerRadius = 30;
    _floatButton.layer.borderWidth = 2;
    _floatButton.layer.borderColor = [UIColor whiteColor].CGColor;
    [_floatButton setTitle:@"🎬" forState:UIControlStateNormal];
    _floatButton.titleLabel.font = [UIFont systemFontOfSize:24];
    [_floatButton addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_floatButton];
    
    // 控制面板
    _controlPanel = [[UIView alloc] initWithFrame:CGRectMake(-10, 70, 240, 280)];
    _controlPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    _controlPanel.layer.cornerRadius = 12;
    _controlPanel.layer.borderWidth = 1;
    _controlPanel.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:1.0].CGColor;
    _controlPanel.hidden = YES;
    [self addSubview:_controlPanel];
    
    CGFloat y = 15;
    
    // 缩放控制
    _zoomLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 120, 20)];
    _zoomLabel.textColor = [UIColor whiteColor];
    _zoomLabel.font = [UIFont systemFontOfSize:14];
    _zoomLabel.text = @"🔍 缩放: 1.0x";
    [_controlPanel addSubview:_zoomLabel];
    
    y += 25;
    _zoomSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, y, 210, 30)];
    _zoomSlider.minimumValue = 1.0;
    _zoomSlider.maximumValue = 3.0;
    _zoomSlider.value = 1.0;
    _zoomSlider.minimumTrackTintColor = [UIColor systemBlueColor];
    [_zoomSlider addTarget:self action:@selector(zoomChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlPanel addSubview:_zoomSlider];
    
    y += 45;
    
    // 颜色取色按钮
    _colorPickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _colorPickButton.frame = CGRectMake(15, y, 100, 36);
    [_colorPickButton setTitle:@"🎨 点击取色" forState:UIControlStateNormal];
    _colorPickButton.backgroundColor = [UIColor systemBlueColor];
    [_colorPickButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _colorPickButton.layer.cornerRadius = 8;
    _colorPickButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [_colorPickButton addTarget:self action:@selector(enterColorPickMode) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_colorPickButton];
    
    // 颜色预览
    _colorPreview = [[UIView alloc] initWithFrame:CGRectMake(125, y, 36, 36)];
    _colorPreview.backgroundColor = [UIColor whiteColor];
    _colorPreview.layer.cornerRadius = 8;
    _colorPreview.layer.borderWidth = 2;
    _colorPreview.layer.borderColor = [UIColor whiteColor].CGColor;
    [_controlPanel addSubview:_colorPreview];
    
    // 柔光开关
    _softGlowButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _softGlowButton.frame = CGRectMake(171, y, 54, 36);
    [_softGlowButton setTitle:@"✨柔光" forState:UIControlStateNormal];
    _softGlowButton.backgroundColor = [UIColor systemGrayColor];
    [_softGlowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _softGlowButton.layer.cornerRadius = 8;
    _softGlowButton.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [_softGlowButton addTarget:self action:@selector(toggleSoftGlow) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_softGlowButton];
    
    y += 48;
    
    // 颜色混合强度
    _mixLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 150, 20)];
    _mixLabel.textColor = [UIColor whiteColor];
    _mixLabel.font = [UIFont systemFontOfSize:14];
    _mixLabel.text = @"🎚️ 颜色强度: 50%";
    [_controlPanel addSubview:_mixLabel];
    
    y += 25;
    _mixSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, y, 210, 30)];
    _mixSlider.minimumValue = 0.0;
    _mixSlider.maximumValue = 1.0;
    _mixSlider.value = 0.5;
    _mixSlider.minimumTrackTintColor = [UIColor systemPurpleColor];
    [_mixSlider addTarget:self action:@selector(mixIntensityChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlPanel addSubview:_mixSlider];
    
    y += 48;
    
    // 重置按钮
    _resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _resetButton.frame = CGRectMake(15, y, 210, 36);
    [_resetButton setTitle:@"🔄 重置全部" forState:UIControlStateNormal];
    _resetButton.backgroundColor = [UIColor systemGrayColor];
    [_resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _resetButton.layer.cornerRadius = 8;
    _resetButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [_resetButton addTarget:self action:@selector(resetAll) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_resetButton];
    
    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_floatButton addGestureRecognizer:pan];
    
    // 取色覆盖层（全屏）
    _colorPickOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    _colorPickOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    _colorPickOverlay.hidden = YES;
    _colorPickOverlay.userInteractionEnabled = YES;
    
    _pickHintLabel = [[UILabel alloc] init];
    _pickHintLabel.text = @"👆 点击屏幕任意位置取色\n（再次点击取消）";
    _pickHintLabel.numberOfLines = 2;
    _pickHintLabel.textColor = [UIColor whiteColor];
    _pickHintLabel.textAlignment = NSTextAlignmentCenter;
    _pickHintLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    _pickHintLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    _pickHintLabel.layer.cornerRadius = 10;
    _pickHintLabel.clipsToBounds = YES;
    [_colorPickOverlay addSubview:_pickHintLabel];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleColorPickTap:)];
    [_colorPickOverlay addGestureRecognizer:tapGesture];
}

#pragma mark - 控制面板

- (void)togglePanel {
    _isPanelVisible = !_isPanelVisible;
    _controlPanel.hidden = !_isPanelVisible;
}

#pragma mark - 缩放控制

- (void)zoomChanged:(UISlider *)slider {
    _zoomScale = slider.value;
    _zoomLabel.text = [NSString stringWithFormat:@"🔍 缩放: %.1fx", _zoomScale];
    [self saveCurrentSettings];
}

#pragma mark - 取色模式（点击任意位置取色）

- (void)enterColorPickMode {
    _isColorPickMode = YES;
    
    // 兼容 iOS 13+ 获取 keyWindow
    UIWindow *window = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { window = w; break; }
    }
    
    if (window && _colorPickOverlay.superview == nil) {
        _colorPickOverlay.frame = window.bounds;
        _pickHintLabel.frame = CGRectMake(0, 0, 240, 60);
        _pickHintLabel.center = CGPointMake(window.bounds.size.width / 2, 100);
        [window addSubview:_colorPickOverlay];
    }
    _colorPickOverlay.hidden = NO;
    
    _colorPickButton.selected = YES;
    _colorPickButton.backgroundColor = [UIColor systemOrangeColor];
}

- (void)exitColorPickMode {
    _isColorPickMode = NO;
    _colorPickOverlay.hidden = YES;
    _colorPickButton.selected = NO;
    _colorPickButton.backgroundColor = [UIColor systemBlueColor];
}

- (void)handleColorPickTap:(UITapGestureRecognizer *)gesture {
    CGPoint tapPoint = [gesture locationInView:_colorPickOverlay];
    
    // 截取屏幕并获取点击位置的颜色
    UIImage *screenshot = [self captureScreen];
    if (screenshot) {
        CGFloat scale = [UIScreen mainScreen].scale;
        CGPoint imagePoint = CGPointMake(tapPoint.x * scale, tapPoint.y * scale);
        UIColor *color = [self colorAtPoint:imagePoint inImage:screenshot];
        
        _mappingColor = color;
        _colorPreview.backgroundColor = color;
        _colorMappingEnabled = YES;
        [self saveCurrentSettings];
    }
    
    [self exitColorPickMode];
}

#pragma mark - 混合强度

- (void)mixIntensityChanged:(UISlider *)slider {
    _colorMixIntensity = slider.value;
    _mixLabel.text = [NSString stringWithFormat:@"🎚️ 颜色强度: %.0f%%", _colorMixIntensity * 100];
    [self saveCurrentSettings];
}

#pragma mark - 柔光滤镜

- (void)toggleSoftGlow {
    _softGlowEnabled = !_softGlowEnabled;
    if (_softGlowEnabled) {
        _softGlowButton.backgroundColor = [UIColor systemYellowColor];
        [_softGlowButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    } else {
        _softGlowButton.backgroundColor = [UIColor systemGrayColor];
        [_softGlowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    [self saveCurrentSettings];
}

#pragma mark - 重置

- (void)resetAll {
    _zoomScale = 1.0;
    _zoomSlider.value = 1.0;
    _zoomLabel.text = @"🔍 缩放: 1.0x";
    
    _colorMappingEnabled = NO;
    _mappingColor = [UIColor whiteColor];
    _colorPreview.backgroundColor = [UIColor whiteColor];
    _colorPickButton.selected = NO;
    _colorPickButton.backgroundColor = [UIColor systemBlueColor];
    
    _colorMixIntensity = 0.5;
    _mixSlider.value = 0.5;
    _mixLabel.text = @"🎚️ 颜色强度: 50%";
    
    _softGlowEnabled = NO;
    _softGlowButton.backgroundColor = [UIColor systemGrayColor];
    [_softGlowButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [self exitColorPickMode];
    [self saveCurrentSettings];
}

#pragma mark - 拖动

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    CGPoint translation = [gesture translationInView:superview];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _startPoint = self.center;
    }
    
    CGPoint newCenter = CGPointMake(_startPoint.x + translation.x, _startPoint.y + translation.y);
    
    CGFloat margin = 30;
    newCenter.x = MAX(margin, MIN(superview.bounds.size.width - margin, newCenter.x));
    newCenter.y = MAX(margin, MIN(superview.bounds.size.height - margin, newCenter.y));
    
    self.center = newCenter;
}

#pragma mark - 屏幕截图和取色

- (UIImage *)captureScreen {
    CGSize size = [UIScreen mainScreen].bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, YES, 0);
    
    // 兼容 iOS 13+ 获取 keyWindow
    UIWindow *window = nil;
    for (UIWindow *w in [UIApplication sharedApplication].windows) {
        if (w.isKeyWindow) { window = w; break; }
    }
    
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:NO];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIColor *)colorAtPoint:(CGPoint)point inImage:(UIImage *)image {
    if (point.x < 0 || point.y < 0 || point.x >= image.size.width || point.y >= image.size.height) {
        return [UIColor whiteColor];
    }
    
    CGImageRef cgImage = image.CGImage;
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    unsigned char *pixelData = calloc(4, sizeof(unsigned char));
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixelData, 1, 1, 8, 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGRect rect = CGRectMake(-point.x, point.y - height, width, height);
    CGContextDrawImage(context, rect, cgImage);
    CGContextRelease(context);
    
    CGFloat red = pixelData[0] / 255.0;
    CGFloat green = pixelData[1] / 255.0;
    CGFloat blue = pixelData[2] / 255.0;
    free(pixelData);
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

#pragma mark - 核心：处理像素缓冲区（实时逐帧处理）

- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!pixelBuffer) return;
    
    // 从共享文件读取最新设置（支持跨进程，实时生效）
    CGFloat zoomScale = [[self class] currentZoomScale];
    BOOL colorEnabled = [[self class] isColorMappingEnabled];
    UIColor *mapColor = [[self class] currentMappingColor];
    CGFloat mixIntensity = [[self class] currentColorMixIntensity];
    BOOL softGlow = [[self class] isSoftGlowEnabled];
    
    // 如果没有启用任何效果，直接返回
    if (zoomScale <= 1.01 && !colorEnabled && !softGlow) {
        return;
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    // 创建CIImage
    CIImage *resultImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    // 1. 应用缩放（中心裁剪放大）
    if (zoomScale > 1.01) {
        CGFloat scale = zoomScale;
        CGFloat cropWidth = width / scale;
        CGFloat cropHeight = height / scale;
        CGFloat cropX = (width - cropWidth) / 2.0;
        CGFloat cropY = (height - cropHeight) / 2.0;
        
        CGRect cropRect = CGRectMake(cropX, cropY, cropWidth, cropHeight);
        resultImage = [resultImage imageByCroppingToRect:cropRect];
        resultImage = [resultImage imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    }
    
    // 2. 应用颜色映射（实时，强度可调）
    if (colorEnabled && mapColor) {
        CGFloat r, g, b, a;
        [mapColor getRed:&r green:&g blue:&b alpha:&a];
        
        CIFilter *colorMatrixFilter = [CIFilter filterWithName:@"CIColorMatrix"];
        [colorMatrixFilter setValue:resultImage forKey:kCIInputImageKey];
        
        // 动态混合强度：0 = 原色，1 = 完全映射色
        CGFloat mix = mixIntensity;
        CIVector *rVector = [CIVector vectorWithX:r * mix + (1-mix) Y:0 Z:0 W:0];
        CIVector *gVector = [CIVector vectorWithX:0 Y:g * mix + (1-mix) Z:0 W:0];
        CIVector *bVector = [CIVector vectorWithX:0 Y:0 Z:b * mix + (1-mix) W:0];
        CIVector *aVector = [CIVector vectorWithX:0 Y:0 Z:0 W:1.0];
        CIVector *biasVector = [CIVector vectorWithX:r * 0.08 * mix Y:g * 0.08 * mix Z:b * 0.08 * mix W:0.0];
        
        [colorMatrixFilter setValue:rVector forKey:@"inputRVector"];
        [colorMatrixFilter setValue:gVector forKey:@"inputGVector"];
        [colorMatrixFilter setValue:bVector forKey:@"inputBVector"];
        [colorMatrixFilter setValue:aVector forKey:@"inputAVector"];
        [colorMatrixFilter setValue:biasVector forKey:@"inputBiasVector"];
        
        resultImage = colorMatrixFilter.outputImage;
    }
    
    // 3. 应用柔光滤镜
    if (softGlow) {
        resultImage = [self applySoftGlowToImage:resultImage];
    }
    
    // 渲染回像素缓冲区
    if (resultImage) {
        [_ciContext render:resultImage toCVPixelBuffer:pixelBuffer];
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

#pragma mark - 柔光滤镜效果

- (CIImage *)applySoftGlowToImage:(CIImage *)inputImage {
    // 柔光效果：提亮阴影 + 高斯模糊 + 滤色混合
    // 模拟摄影柔光镜效果，画面更柔和梦幻
    
    // 第一步：提亮阴影，降低对比
    CIFilter *shadowAdjust = [CIFilter filterWithName:@"CIHighlightShadowAdjust"];
    [shadowAdjust setValue:inputImage forKey:kCIInputImageKey];
    [shadowAdjust setValue:@(0.3) forKey:@"inputShadowAmount"];
    [shadowAdjust setValue:@(-0.1) forKey:@"inputHighlightAmount"];
    CIImage *adjustedImage = shadowAdjust.outputImage;
    
    // 第二步：创建模糊层
    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setValue:adjustedImage forKey:kCIInputImageKey];
    [blurFilter setValue:@(4.0) forKey:kCIInputRadiusKey];
    CIImage *blurredImage = blurFilter.outputImage;
    
    // 第三步：滤色混合（Screen Blend）- 产生发光效果
    CIFilter *blendFilter = [CIFilter filterWithName:@"CIScreenBlendMode"];
    [blendFilter setValue:blurredImage forKey:kCIInputImageKey];
    [blendFilter setValue:adjustedImage forKey:kCIInputBackgroundImageKey];
    CIImage *blendedImage = blendFilter.outputImage;
    
    // 第四步：调整不透明度后叠加回原图
    CIFilter *opacityFilter = [CIFilter filterWithName:@"CIColorMatrix"];
    [opacityFilter setValue:blendedImage forKey:kCIInputImageKey];
    CIVector *aVector = [CIVector vectorWithX:0 Y:0 Z:0 W:0.6];
    [opacityFilter setValue:aVector forKey:@"inputAVector"];
    
    // 第五步：最终混合
    CIFilter *finalBlend = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [finalBlend setValue:opacityFilter.outputImage forKey:kCIInputImageKey];
    [finalBlend setValue:adjustedImage forKey:kCIInputBackgroundImageKey];
    
    return finalBlend.outputImage;
}

#pragma mark - 显示

- (void)showInWindow:(UIWindow *)window {
    if (self.superview) {
        [self removeFromSuperview];
    }
    
    self.frame = CGRectMake(window.bounds.size.width - 80, window.bounds.size.height / 2, 60, 60);
    [window addSubview:self];
}

- (void)toggleVisibility {
    self.hidden = !self.hidden;
}

@end
