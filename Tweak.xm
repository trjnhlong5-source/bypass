// Tweak.xm - OLSolver
// Mục đích: Nút nổi quét nội dung màn hình làm bài Onluyen

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─── Manager ───────────────────────────────────────────────────────────────

@interface OLSolverManager : NSObject
+ (instancetype)shared;
- (void)ensureButtonExists;
- (void)runScan;
- (void)handlePan:(UIPanGestureRecognizer *)g;
@end

@implementation OLSolverManager {
    UIButton *_floatBtn;
}

+ (instancetype)shared {
    static OLSolverManager *inst = nil;
    static dispatch_once_t tok;
    dispatch_once(&tok, ^{ inst = [OLSolverManager new]; });
    return inst;
}

// Lấy key window an toàn trên iOS 13+
- (UIWindow *)activeWindow {
    UIWindow *result = nil;
    if (@available(iOS 13, *)) {
        for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in scene.windows) {
                if (w.isKeyWindow) { result = w; break; }
            }
            if (result) break;
        }
    }
    return result ?: UIApplication.sharedApplication.keyWindow;
}

- (void)ensureButtonExists {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [self activeWindow];
        if (!win) return;
        
        // Đã có rồi thì thôi, không tạo lại
        if ([win viewWithTag:0xAB0CD]) return;
        
        CGRect frame = CGRectMake(win.bounds.size.width - 72, 190, 58, 58);
        
        _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatBtn.tag   = 0xAB0CD;
        _floatBtn.frame = frame;
        _floatBtn.backgroundColor = [UIColor colorWithRed:0.06 green:0.49 blue:0.98 alpha:0.93];
        _floatBtn.layer.cornerRadius  = 29;
        _floatBtn.layer.masksToBounds = NO;
        _floatBtn.layer.shadowColor   = [UIColor blackColor].CGColor;
        _floatBtn.layer.shadowOpacity = 0.38;
        _floatBtn.layer.shadowRadius  = 6;
        _floatBtn.layer.shadowOffset  = CGSizeMake(0, 3);
        
        [_floatBtn setTitle:@"🤖" forState:UIControlStateNormal];
        _floatBtn.titleLabel.font = [UIFont systemFontOfSize:24];
        
        // Tap → scan
        [_floatBtn addTarget:self
                      action:@selector(runScan)
            forControlEvents:UIControlEventTouchUpInside];
        
        // Kéo thả được
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [_floatBtn addGestureRecognizer:pan];
        
        [win addSubview:_floatBtn];
        
        NSLog(@"[OLSolver] Nút đã tạo thành công trên window: %@", win);
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *btn = g.view;
    UIView *parent = btn.superview;
    
    CGPoint delta = [g translationInView:parent];
    CGPoint newCenter = CGPointMake(btn.center.x + delta.x,
                                    btn.center.y + delta.y);
    
    // Giữ nút trong bounds màn hình
    CGFloat halfW = btn.bounds.size.width  / 2.0;
    CGFloat halfH = btn.bounds.size.height / 2.0;
    newCenter.x = MAX(halfW,  MIN(parent.bounds.size.width  - halfW,  newCenter.x));
    newCenter.y = MAX(halfH + 44, MIN(parent.bounds.size.height - halfH - 34, newCenter.y));
    
    btn.center = newCenter;
    [g setTranslation:CGPointZero inView:parent];
}

// ─── Quét nội dung màn hình ────────────────────────────────────────────────

- (void)runScan {
    UIWindow *win = [self activeWindow];
    UIViewController *topVC = win.rootViewController;
    while (topVC.presentedViewController) topVC = topVC.presentedViewController;
    
    // Thu thập tất cả text hiển thị
    NSMutableArray<NSString *> *labels   = [NSMutableArray array];
    NSMutableArray<NSString *> *buttons  = [NSMutableArray array];
    
    [self scanView:topVC.view labels:labels buttons:buttons depth:0];
    
    // Hiển thị kết quả
    NSMutableString *msg = [NSMutableString string];
    
    if (labels.count > 0) {
        [msg appendString:@"📋 NỘI DUNG:\n"];
        // Lấy tối đa 8 label đầu (thường chứa câu hỏi)
        NSArray *topLabels = labels.count > 8 ? [labels subarrayWithRange:NSMakeRange(0, 8)] : labels;
        [msg appendString:[topLabels componentsJoinedByString:@"\n"]];
    }
    
    if (buttons.count > 0) {
        [msg appendString:@"\n\n🔘 CÁC LỰA CHỌN:\n"];
        for (NSString *b in buttons) {
            [msg appendFormat:@"  • %@\n", b];
        }
    }
    
    if (msg.length == 0) {
        [msg appendString:@"Không tìm thấy nội dung câu hỏi.\nHãy vào màn hình làm bài trước khi bấm."];
    }
    
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🤖 AI Solver — Onluyen"
        message:msg
        preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"✕ Đóng"
        style:UIAlertActionStyleCancel handler:nil]];
    
    [topVC presentViewController:alert animated:YES completion:nil];
}

- (void)scanView:(UIView *)view
          labels:(NSMutableArray *)labels
         buttons:(NSMutableArray *)buttons
           depth:(NSInteger)depth {
    
    if (depth > 12) return; // Tránh đệ quy quá sâu
    
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *lbl = (UILabel *)view;
        NSString *t = [lbl.text stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 2 && ![labels containsObject:t]) {
            [labels addObject:t];
        }
    }
    else if ([view isKindOfClass:[UITextView class]]) {
        UITextView *tv = (UITextView *)view;
        NSString *t = [tv.text stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 2) [labels addObject:t];
    }
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        // Bỏ qua nút của chính mình
        if (btn.tag == 0xAB0CD) return;
        NSString *t = [[btn titleForState:UIControlStateNormal]
                        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [buttons addObject:t];
    }
    
    for (UIView *sub in view.subviews) {
        [self scanView:sub labels:labels buttons:buttons depth:depth + 1];
    }
}

@end

// ─── Hooks ─────────────────────────────────────────────────────────────────

// Hook UIViewController để inject nút sau khi màn hình render xong
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // Chỉ inject từ VC cấp cao (không phải popup nhỏ)
    if (!self.presentingViewController && !self.navigationController.parentViewController) {
        [[OLSolverManager shared] ensureButtonExists];
    }
}

%end

// ─── Constructor: chạy khi dylib được load vào process ────────────────────

%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[OLSolver] Loaded vào: %@", bid);
        
        // Dự phòng: lắng nghe khi app trở thành active
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil
            queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *n) {
                [[OLSolverManager shared] ensureButtonExists];
            }];
    }
}
