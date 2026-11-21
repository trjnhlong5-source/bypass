// Tweak.xm - OLSolver v3
// App: vn.onluyen.app (React Native)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ══════════════════════════════════════════════════════
// ⚙️  CẤU HÌNH — điền API key Gemini miễn phí vào đây
//    Lấy key tại: https://aistudio.google.com/apikey
// ══════════════════════════════════════════════════════
#define OL_GEMINI_KEY @"AQ.Ab8RN6LjPA5SFO35Ve5Y7vUr8_DRs8aULzEAuzHxy3VIPqtLDQ"

// ─── Manager ──────────────────────────────────────────────────────────────

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

// ─── Tạo nút nổi ─────────────────────────────────────────────────────────

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

// ─── Quét view hierarchy — lấy text theo vị trí màn hình ─────────────────

- (void)scanView:(UIView *)view
          result:(NSMutableOrderedSet<NSString *> *)result
         minY:(CGFloat)minY   // bỏ qua mọi thứ trên navigation bar
          depth:(NSInteger)depth {

    if (!view || depth > 60) return;
    if (view.isHidden || view.alpha < 0.01f) return;
    if (view.tag == 0xAB0CD) return;

    // Tọa độ trong cửa sổ
    CGRect frameInWin = [view convertRect:view.bounds toView:nil];

    // Bỏ qua vùng nav bar (top)
    if (CGRectGetMaxY(frameInWin) < minY) {
        // Vẫn đào sâu subviews — scroll view có thể bắt đầu cao hơn content
        for (UIView *sub in view.subviews)
            [self scanView:sub result:result minY:minY depth:depth+1];
        return;
    }

    // ── Thử mọi cách lấy text ──────────────────────────────────────────

    NSMutableArray<NSString *> *candidates = [NSMutableArray array];

    // 1. UILabel
    if ([view isKindOfClass:[UILabel class]])
        [candidates addObject:((UILabel *)view).text ?: @""];

    // 2. UITextView
    if ([view isKindOfClass:[UITextView class]])
        [candidates addObject:((UITextView *)view).text ?: @""];

    // 3. UIButton title
    if ([view isKindOfClass:[UIButton class]]) {
        NSString *t = [(UIButton *)view titleForState:UIControlStateNormal];
        if (t) [candidates addObject:t];
    }

    // 4. accessibilityLabel (React Native set cái này)
    if (view.accessibilityLabel.length > 0)
        [candidates addObject:view.accessibilityLabel];

    // 5. KVC "text" — bắt RCTTextView, custom views
    @try {
        id val = [view valueForKey:@"text"];
        if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0)
            [candidates addObject:(NSString *)val];
    } @catch (NSException *e) {}

    // 6. attributedText → plain string
    @try {
        id attr = [view valueForKey:@"attributedText"];
        if ([attr isKindOfClass:[NSAttributedString class]])
            [candidates addObject:[(NSAttributedString *)attr string]];
    } @catch (NSException *e) {}

    // 7. NSTextStorage (một số RCT version)
    @try {
        id storage = [view valueForKey:@"textStorage"];
        if ([storage isKindOfClass:[NSTextStorage class]])
            [candidates addObject:[(NSTextStorage *)storage string]];
    } @catch (NSException *e) {}

    // ── Lọc và thêm vào kết quả ───────────────────────────────────────
    for (NSString *raw in candidates) {
        NSString *t = [raw stringByTrimmingCharactersInSet:
                        NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (t.length < 3) continue;
        [result addObject:t];
    }

    for (UIView *sub in view.subviews)
        [self scanView:sub result:result minY:minY depth:depth+1];
}

// ─── Lọc rác sau khi quét ────────────────────────────────────────────────

- (NSArray<NSString *> *)filterTexts:(NSMutableOrderedSet<NSString *> *)raw {
    // Những chuỗi thuộc về chrome của app, bỏ qua
    NSSet *skip = [NSSet setWithArray:@[
        @"BỎ QUA", @"Nộp bài", @"Nộp", @"OK", @"Cancel", @"Back",
        @"✕ Đóng", @"🤖", @"<", @">"
    ]];

    NSMutableArray *result = [NSMutableArray array];
    NSMutableSet   *seen   = [NSMutableSet set];

    for (NSString *t in raw) {
        if ([skip containsObject:t]) continue;
        // Bỏ chuỗi chỉ toàn số + khoảng trắng (số trang, ID)
        NSString *stripped = [[t componentsSeparatedByCharactersInSet:
            [NSCharacterSet characterSetWithCharactersInString:@" 0123456789"]]
            componentsJoinedByString:@""];
        if (stripped.length == 0) continue;
        // Bỏ trùng
        if ([seen containsObject:t]) continue;
        [seen addObject:t];
        [result addObject:t];
    }
    return result;
}

// ─── Gọi Gemini API để lấy đáp án ───────────────────────────────────────

- (void)askGemini:(NSString *)prompt
       completion:(void(^)(NSString *answer, NSError *err))completion {

    NSString *key = OL_GEMINI_KEY;
    if ([key hasPrefix:@"ĐIỀN"]) {
        completion(@"⚙️ Chưa cấu hình API key. Xem hướng dẫn trong file Tweak.xm.", nil);
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:
        @"https://generativelanguage.googleapis.com/v1beta/models/"
        @"gemini-2.0-flash:generateContent?key=%@", key];

    NSDictionary *body = @{
        @"contents": @[@{
            @"parts": @[@{ @"text": prompt }]
        }],
        @"generationConfig": @{
            @"temperature": @0.1,
            @"maxOutputTokens": @200
        }
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
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        if (error) { completion(nil, error); return; }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *text = json[@"candidates"][0][@"content"][@"parts"][0][@"text"];

        dispatch_async(dispatch_get_main_queue(), ^{
            completion(text ?: @"Không parse được phản hồi.", nil);
        });

    }] resume];
}

// ─── Bấm nút → quét → gọi AI → hiện kết quả ─────────────────────────────

- (void)runScan {
    UIViewController *topVC   = [self frontmostVC];
    UIWindow         *win     = [self activeWindow];

    // Tính ngưỡng Y của content area (bỏ nav bar ~110pt)
    CGFloat navHeight = topVC.navigationController
        ? topVC.navigationController.navigationBar.frame.size.height
          + [UIApplication sharedApplication].statusBarFrame.size.height
        : 110.0;

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

    // Hiện loading
    UIAlertController *loading = [UIAlertController
        alertControllerWithTitle:@"🤖 Đang phân tích..."
        message:@"AI đang xử lý câu hỏi\n⏳"
        preferredStyle:UIAlertControllerStyleAlert];
    [topVC presentViewController:loading animated:YES completion:nil];

    // Build prompt
    NSString *content = [texts componentsJoinedByString:@"\n"];
    NSString *prompt = [NSString stringWithFormat:
        @"Đây là nội dung màn hình câu hỏi trắc nghiệm từ app Onluyen (học sinh lớp 9 Việt Nam):\n\n"
        @"%@\n\n"
        @"Hãy:\n"
        @"1. Xác định câu hỏi chính xác\n"
        @"2. Liệt kê các lựa chọn A, B, C, D nếu có\n"
        @"3. Chỉ ra đáp án đúng và giải thích ngắn gọn (1-2 câu)\n"
        @"Trả lời bằng tiếng Việt, ngắn gọn, rõ ràng.",
        content];

    [self askGemini:prompt completion:^(NSString *answer, NSError *err) {

        [loading dismissViewControllerAnimated:NO completion:^{

            NSString *msg;
            if (err) {
                msg = [NSString stringWithFormat:@"❌ Lỗi API:\n%@", err.localizedDescription];
            } else {
                msg = answer;
            }

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

// ─── Hooks ────────────────────────────────────────────────────────────────

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
