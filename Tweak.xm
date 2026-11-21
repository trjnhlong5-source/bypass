// Tweak.xm - OLSolver v3
// App: vn.onluyen.app (React Native)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define OL_GEMINI_KEY @"AQ.Ab8RN6KWdkZha6d9jL6tUL4VDYnjc9kaQ_VaF8p1xewJgxFX8g"

@interface OLSolverManager : NSObject
+ (instancetype)shared;
- (void)ensureButtonExists;
- (void)runScan;
- (void)handlePan:(UIPanGestureRecognizer *)g;
- (UIViewController *)frontmostVC;
- (UIWindow *)activeWindow;
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

- (UIViewController *)frontmostVC {
    UIViewController *vc = [self activeWindow].rootViewController;
    BOOL digging = YES;
    while (digging) {
        digging = NO;
        if (vc.presentedViewController)
            { vc = vc.presentedViewController; digging = YES; }
        else if ([vc isKindOfClass:[UINavigationController class]]) {
            UIViewController *top = ((UINavigationController *)vc).topViewController;
            if (top) { vc = top; digging = YES; }
        } else if ([vc isKindOfClass:[UITabBarController class]]) {
            UIViewController *sel = ((UITabBarController *)vc).selectedViewController;
            if (sel) { vc = sel; digging = YES; }
        } else if (vc.childViewControllers.count > 0)
            { vc = vc.childViewControllers.lastObject; digging = YES; }
    }
    return vc;
}

- (void)ensureButtonExists {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *win = [self activeWindow];
        if (!win || [win viewWithTag:0xAB0CD]) return;

        _floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        _floatBtn.tag   = 0xAB0CD;
        _floatBtn.frame = CGRectMake(win.bounds.size.width - 72, 190, 58, 58);
        _floatBtn.backgroundColor     = [UIColor colorWithRed:0.06 green:0.49 blue:0.98 alpha:0.95];
        _floatBtn.layer.cornerRadius  = 29;
        _floatBtn.layer.masksToBounds = NO;
        _floatBtn.layer.shadowColor   = [UIColor blackColor].CGColor;
        _floatBtn.layer.shadowOpacity = 0.4f;
        _floatBtn.layer.shadowRadius  = 6.0f;
        _floatBtn.layer.shadowOffset  = CGSizeMake(0, 3);
        [_floatBtn setTitle:@"🤖" forState:UIControlStateNormal];
        _floatBtn.titleLabel.font = [UIFont systemFontOfSize:26];

        [_floatBtn addTarget:self action:@selector(runScan)
            forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
            initWithTarget:self action:@selector(handlePan:)];
        [_floatBtn addGestureRecognizer:pan];
        [win addSubview:_floatBtn];
        NSLog(@"[OLSolver] ✅ Nút đã tạo xong");
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *btn = g.view, *p = btn.superview;
    CGPoint d = [g translationInView:p];
    CGFloat hw = btn.bounds.size.width/2, hh = btn.bounds.size.height/2;
    btn.center = CGPointMake(
        MAX(hw, MIN(p.bounds.size.width-hw,  btn.center.x + d.x)),
        MAX(hh+44, MIN(p.bounds.size.height-hh-34, btn.center.y + d.y))
    );
    [g setTranslation:CGPointZero inView:p];
}

- (void)scanView:(UIView *)view
          result:(NSMutableOrderedSet<NSString *> *)result
            minY:(CGFloat)minY
           depth:(NSInteger)depth {
    if (!view || depth > 60) return;
    if (view.isHidden || view.alpha < 0.01f) return;
    if (view.tag == 0xAB0CD) return;

    CGRect frameInWin = [view convertRect:view.bounds toView:nil];
    if (CGRectGetMaxY(frameInWin) < minY) {
        for (UIView *sub in view.subviews)
            [self scanView:sub result:result minY:minY depth:depth+1];
        return;
    }

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];

    if ([view isKindOfClass:[UILabel class]])
        [candidates addObject:((UILabel *)view).text ?: @""];
    if ([view isKindOfClass:[UITextView class]])
        [candidates addObject:((UITextView *)view).text ?: @""];
    if ([view isKindOfClass:[UIButton class]]) {
        NSString *t = [(UIButton *)view titleForState:UIControlStateNormal];
        if (t) [candidates addObject:t];
    }
    if (view.accessibilityLabel.length > 0)
        [candidates addObject:view.accessibilityLabel];

    @try {
        id val = [view valueForKey:@"text"];
        if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0)
            [candidates addObject:(NSString *)val];
    } @catch (NSException *e) {}

    @try {
        id attr = [view valueForKey:@"attributedText"];
        if ([attr isKindOfClass:[NSAttributedString class]])
            [candidates addObject:[(NSAttributedString *)attr string]];
    } @catch (NSException *e) {}

    @try {
        id storage = [view valueForKey:@"textStorage"];
        if ([storage isKindOfClass:[NSTextStorage class]])
            [candidates addObject:[(NSTextStorage *)storage string]];
    } @catch (NSException *e) {}

    for (NSString *raw in candidates) {
        NSString *t = [raw stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length < 3) continue;
        [result addObject:t];
    }

    for (UIView *sub in view.subviews)
        [self scanView:sub result:result minY:minY depth:depth+1];
}

- (NSArray<NSString *> *)filterTexts:(NSMutableOrderedSet<NSString *> *)raw {
    NSSet *skip = [NSSet setWithArray:@[
        @"BỎ QUA", @"Nộp bài", @"Nộp", @"OK", @"Cancel",
        @"Back", @"✕ Đóng", @"🤖", @"<", @">"
    ]];
    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet   *seen   = [NSMutableSet set];
    for (NSString *t in raw) {
        if ([skip containsObject:t]) continue;
        NSString *stripped = [[t componentsSeparatedByCharactersInSet:
            [NSCharacterSet characterSetWithCharactersInString:@" 0123456789"]]
            componentsJoinedByString:@""];
        if (stripped.length == 0) continue;
        if ([seen containsObject:t]) continue;
        [seen addObject:t];
        [result addObject:t];
    }
    return result;
}

- (void)askGemini:(NSString *)prompt
       completion:(void(^)(NSString *answer, NSError *err))completion {

    NSString *urlStr = [NSString stringWithFormat:
        @"https://generativelanguage.googleapis.com/v1beta/models/"
        @"gemini-2.0-flash:generateContent?key=%@", OL_GEMINI_KEY];

    NSDictionary *body = @{
        @"contents": @[@{ @"parts": @[@{ @"text": prompt }] }],
        @"generationConfig": @{ @"temperature": @0.1, @"maxOutputTokens": @300 }
    };

    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:
        [NSURL URLWithString:urlStr]
        cachePolicy:NSURLRequestUseProtocolCachePolicy
        timeoutInterval:15.0];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = bodyData;

    [[[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, err); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *text = json[@"candidates"][0][@"content"][@"parts"][0][@"text"];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(text ?: @"Không parse được phản hồi.", nil);
        });
    }] resume];
}

- (void)runScan {
    UIViewController *topVC = [self frontmostVC];
    UIWindow *win = [self activeWindow];

    CGFloat navHeight = 110.0;
    if (topVC.navigationController)
        navHeight = topVC.navigationController.navigationBar.frame.size.height
                  + UIApplication.sharedApplication.statusBarFrame.size.height;

    NSMutableOrderedSet<NSString *> *raw = [NSMutableOrderedSet orderedSet];
    [self scanView:win result:raw minY:navHeight depth:0];

    NSArray<NSString *> *texts = [self filterTexts:raw];

    if (texts.count == 0) {
        UIAlertController *a = [UIAlertController
            alertControllerWithTitle:@"🤖 OL Solver"
            message:@"Không tìm thấy câu hỏi.\nHãy chắc chắn đang ở màn hình làm bài."
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Đóng"
            style:UIAlertActionStyleCancel handler:nil]];
        [topVC presentViewController:a animated:YES completion:nil];
        return;
    }

    UIAlertController *loading = [UIAlertController
        alertControllerWithTitle:@"🤖 Đang phân tích..."
        message:@"AI đang xử lý câu hỏi ⏳"
        preferredStyle:UIAlertControllerStyleAlert];
    [topVC presentViewController:loading animated:YES completion:nil];

    NSString *content = [texts componentsJoinedByString:@"\n"];
    NSString *prompt = [NSString stringWithFormat:
        @"Đây là nội dung màn hình câu hỏi trắc nghiệm từ app Onluyen (học sinh lớp 9 Việt Nam):\n\n%@\n\n"
        @"Hãy:\n"
        @"1. Xác định câu hỏi chính\n"
        @"2. Liệt kê các lựa chọn A, B, C, D\n"
        @"3. Chỉ ra đáp án đúng và giải thích ngắn gọn 1-2 câu\n"
        @"Trả lời bằng tiếng Việt, ngắn gọn.", content];

    [self askGemini:prompt completion:^(NSString *answer, NSError *err) {
        [loading dismissViewControllerAnimated:NO completion:^{
            NSString *msg = err
                ? [NSString stringWithFormat:@"❌ Lỗi: %@", err.localizedDescription]
                : answer;
            UIAlertController *result = [UIAlertController
                alertControllerWithTitle:@"🤖 OL Solver — Đáp án"
                message:msg
                preferredStyle:UIAlertControllerStyleAlert];
            [result addAction:[UIAlertAction actionWithTitle:@"✅ Đóng"
                style:UIAlertActionStyleCancel handler:nil]];
            [topVC presentViewController:result animated:YES completion:nil];
        }];
    }];
}

@end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!self.presentingViewController &&
        !self.navigationController.parentViewController)
        [[OLSolverManager shared] ensureButtonExists];
}
%end

%ctor {
    @autoreleasepool {
        NSLog(@"[OLSolver] Loaded: %@", NSBundle.mainBundle.bundleIdentifier);
        [[NSNotificationCenter defaultCenter]
            addObserverForName:UIApplicationDidBecomeActiveNotification
            object:nil queue:NSOperationQueue.mainQueue
            usingBlock:^(NSNotification *n) {
                [[OLSolverManager shared] ensureButtonExists];
            }];
    }
}
