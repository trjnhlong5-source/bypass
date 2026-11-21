// Tweak.xm - OLSolver
// App: Onluyen (React Native) | Bundle: vn.onluyen.app

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ─── Forward declarations ──────────────────────────────────────────────────

@interface OLSolverManager : NSObject
+ (instancetype)shared;
- (void)ensureButtonExists;
- (void)runScan;
- (void)handlePan:(UIPanGestureRecognizer *)g;
- (UIViewController *)frontmostVC;
- (UIWindow *)activeWindow;
@end

// ─── Implementation ────────────────────────────────────────────────────────

@implementation OLSolverManager {
    UIButton *_floatBtn;
}

+ (instancetype)shared {
    static OLSolverManager *inst = nil;
    static dispatch_once_t tok;
    dispatch_once(&tok, ^{ inst = [OLSolverManager new]; });
    return inst;
}

// Lấy key window an toàn iOS 13+
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

// Đào sâu qua NavController / TabBar / childVC để lấy VC đang hiển thị
- (UIViewController *)frontmostVC {
    UIViewController *vc = [self activeWindow].rootViewController;
    BOOL digging = YES;
    while (digging) {
        digging = NO;
        if (vc.presentedViewController) {
            vc = vc.presentedViewController; digging = YES;
        } else if ([vc isKindOfClass:[UINavigationController class]]) {
            UIViewController *top = ((UINavigationController *)vc).topViewController;
            if (top) { vc = top; digging = YES; }
        } else if ([vc isKindOfClass:[UITabBarController class]]) {
            UIViewController *sel = ((UITabBarController *)vc).selectedViewController;
            if (sel) { vc = sel; digging = YES; }
        } else if (vc.childViewControllers.count > 0) {
            vc = vc.childViewControllers.lastObject; digging = YES;
        }
    }
    return vc;
}

// Tạo nút nổi
- (void)ensureButtonExists {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [self activeWindow];
        if (!win) return;
        if ([win viewWithTag:0xAB0CD]) return;

        _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatBtn.tag   = 0xAB0CD;
        _floatBtn.frame = CGRectMake(win.bounds.size.width - 72, 190, 58, 58);
        _floatBtn.backgroundColor     = [UIColor colorWithRed:0.06 green:0.49 blue:0.98 alpha:0.93];
        _floatBtn.layer.cornerRadius  = 29;
        _floatBtn.layer.masksToBounds = NO;
        _floatBtn.layer.shadowColor   = [UIColor blackColor].CGColor;
        _floatBtn.layer.shadowOpacity = 0.4f;
        _floatBtn.layer.shadowRadius  = 6.0f;
        _floatBtn.layer.shadowOffset  = CGSizeMake(0, 3);
        [_floatBtn setTitle:@"🤖" forState:UIControlStateNormal];
        _floatBtn.titleLabel.font = [UIFont systemFontOfSize:26];

        [_floatBtn addTarget:self
                      action:@selector(runScan)
            forControlEvents:UIControlEventTouchUpInside];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [_floatBtn addGestureRecognizer:pan];

        [win addSubview:_floatBtn];
        NSLog(@"[OLSolver] ✅ Nút đã tạo xong");
    });
}

// Kéo nút
- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *btn = g.view, *parent = btn.superview;
    CGPoint delta = [g translationInView:parent];
    CGFloat hw = btn.bounds.size.width / 2.0, hh = btn.bounds.size.height / 2.0;
    CGPoint c = CGPointMake(
        MAX(hw, MIN(parent.bounds.size.width  - hw,  btn.center.x + delta.x)),
        MAX(hh + 44, MIN(parent.bounds.size.height - hh - 34, btn.center.y + delta.y))
    );
    btn.center = c;
    [g setTranslation:CGPointZero inView:parent];
}

// ─── Quét text — hỗ trợ cả UIKit lẫn React Native ────────────────────────
//
// React Native KHÔNG dùng UILabel chuẩn. Nó render text qua RCTTextView
// và các RCT custom views. Cách đáng tin nhất để lấy text từ RN là qua
// Accessibility API (accessibilityLabel) vì RN tự set sẵn.

- (void)collectText:(UIView *)view
             result:(NSMutableOrderedSet<NSString *> *)result
              depth:(NSInteger)depth {

    if (depth > 40 || !view) return;
    if (view.isHidden || view.alpha < 0.01f) return; // Bỏ view ẩn

    // Bỏ qua nút của mình
    if (view.tag == 0xAB0CD) return;

    // ── UIKit standard ──
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *t = [((UILabel *)view).text
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [result addObject:t];
    }
    if ([view isKindOfClass:[UITextView class]]) {
        NSString *t = [((UITextView *)view).text
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [result addObject:t];
    }
    if ([view isKindOfClass:[UIButton class]]) {
        NSString *t = [[(UIButton *)view titleForState:UIControlStateNormal]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [result addObject:t];
    }

    // ── React Native: lấy qua accessibilityLabel ──
    // RN text nodes tự set accessibilityLabel = text nội dung
    NSString *accLabel = view.accessibilityLabel;
    if (accLabel.length > 1) {
        NSString *t = [accLabel
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [result addObject:t];
    }

    // ── React Native: lấy qua accessibilityValue (một số RN version dùng) ──
    NSString *accValue = view.accessibilityValue;
    if (accValue.length > 1) {
        NSString *t = [accValue
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length > 1) [result addObject:t];
    }

    // ── Mọi view có property "text" (custom subclass) ──
    if (class_getInstanceMethod([view class], @selector(text))) {
        id val = [view valueForKey:@"text"];
        if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 1) {
            [result addObject:[(NSString *)val
                stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
        }
    }

    for (UIView *sub in view.subviews) {
        [self collectText:sub result:result depth:depth + 1];
    }
}

// ─── Bấm nút → quét → hiện kết quả ───────────────────────────────────────

- (void)runScan {
    UIViewController *topVC = [self frontmostVC];
    UIWindow *win = [self activeWindow];

    NSMutableOrderedSet<NSString *> *allTexts = [NSMutableOrderedSet orderedSet];

    // Quét từ VC đang hiển thị
    [self collectText:topVC.view result:allTexts depth:0];
    // Quét từ window (RN đôi khi render overlay ngoài VC)
    [self collectText:win result:allTexts depth:0];

    // ── Lọc rác ──
    NSArray<NSString *> *skipList = @[
        @"BỎ QUA", @"Nộp bài", @"Nộp", @"OK", @"Cancel",
        @"✕ Đóng", @"🤖", @"Back", @"<"
    ];

    NSMutableArray<NSString *> *filtered = [NSMutableArray array];
    for (NSString *t in allTexts) {
        if ([skipList containsObject:t]) continue;
        if (t.length < 2) continue;
        // Bỏ chuỗi chỉ toàn số (số trang, ID câu)
        NSCharacterSet *digits = NSCharacterSet.decimalDigitCharacterSet;
        if ([[t stringByTrimmingCharactersInSet:digits] length] == 0) continue;
        [filtered addObject:t];
    }

    // ── Hiển thị ──
    NSMutableString *msg = [NSMutableString string];
    if (filtered.count > 0) {
        for (NSString *t in filtered) {
            [msg appendFormat:@"• %@\n", t];
        }
    } else {
        // Debug mode — in class name để biết RN đang dùng gì
        [msg appendFormat:@"⚠️ Chưa quét được text.\n\nVC: %@\nSubviews: %lu\n\nThử bấm lại sau khi câu hỏi load xong.",
            NSStringFromClass([topVC class]),
            (unsigned long)topVC.view.subviews.count];
    }

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"🤖 OL Solver"
        message:msg
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"✕ Đóng"
        style:UIAlertActionStyleCancel handler:nil]];
    [topVC presentViewController:alert animated:YES completion:nil];
}

@end

// ─── Hooks ────────────────────────────────────────────────────────────────

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!self.presentingViewController &&
        !self.navigationController.parentViewController) {
        [[OLSolverManager shared] ensureButtonExists];
    }
}
%end

// ─── Constructor ──────────────────────────────────────────────────────────

%ctor {
    @autoreleasepool {
        NSLog(@"[OLSolver] 🚀 Loaded vào: %@",
            [[NSBundle mainBundle] bundleIdentifier]);
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil
            queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *n) {
                [[OLSolverManager shared] ensureButtonExists];
            }];
    }
}
