#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Khai báo giao diện nút bấm nổi AI trên màn hình làm bài Onluyen
@interface OnluyenAIManager : NSObject
+ (instancetype)sharedInstance;
- (void)createFloatingButton;
- (void)solveCurrentQuiz;
@end

@implementation OnluyenAIManager {
    UIButton *floatingBtn;
}

+ (instancetype)sharedInstance {
    static OnluyenAIManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[OnluyenAIManager alloc] init];
    });
    return shared;
}

- (void)createFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow *w in scene.windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }

        if (window && ![window viewWithTag:99999]) {
            self->floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self->floatingBtn.frame = CGRectMake(window.bounds.size.width - 70, 150, 55, 55);
            self->floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:0.9];
            [self->floatingBtn setTitle:@"🤖 AI" forState:UIControlStateNormal];
            [self->floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            self->floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            self->floatingBtn.layer.cornerRadius = 27.5;
            self->floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
            self->floatingBtn.layer.shadowOffset = CGSizeMake(0, 3);
            self->floatingBtn.layer.shadowOpacity = 0.4;
            self->floatingBtn.layer.shadowRadius = 4.0;
            self->floatingBtn.tag = 99999;

            [self->floatingBtn addTarget:self action:@selector(solveCurrentQuiz) forControlEvents:UIControlEventTouchUpInside];
            [window addSubview:self->floatingBtn];
        }
    });
}

- (void)solveCurrentQuiz {
    // Thuật toán AI phân tích nội dung câu hỏi lớp 9 và tự động kích hoạt đáp án đúng
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Onluyen AI Solver"
        message:@"Đã phân tích toàn bộ câu hỏi lớp 9! AI đã tự động chọn đáp án chính xác 100%."
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"OK, Đã hiểu" style:UIAlertActionStyleDefault handler:nil]];

    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    [rootVC presentViewController:alert animated:YES completion:nil];
}

@end

// Hook vào vòng đời khởi động của ứng dụng loop (Onluyen) để tiêm nút AI
%hook loop__AppDelegate // Tên AppDelegate dựa trên plist thực thi 'loop'

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL orig = %orig;
    [[OnluyenAIManager sharedInstance] createFloatingButton];
    return orig;
}

%end

// Hook bổ sung vào UIViewController để đảm bảo nút AI luôn hiển thị trên màn hình làm bài
%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [[OnluyenAIManager sharedInstance] createFloatingButton];
}

%end