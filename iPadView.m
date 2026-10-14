// iPadView - shows any app at 65% size, centered, like an iPad-style view.
// A small button toggles it on/off. Works for sideloaded apps.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gIPadOn = YES;     // starts ON
static char kBG;               // remembers each window's original background

#pragma mark - Overlay window (only the button catches touches)

@interface IPVWindow : UIWindow @end
@implementation IPVWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end

#pragma mark - Controller

@interface IPVController : NSObject
@property (nonatomic, strong) IPVWindow *win;
@property (nonatomic, strong) UIButton *btn;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation IPVController

- (void)start {
    self.win = nil;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = nil;
        for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
            if ([s isKindOfClass:UIWindowScene.class]) { scene = (UIWindowScene *)s; break; }
        if (scene) self.win = [[IPVWindow alloc] initWithWindowScene:scene];
    }
    if (!self.win) self.win = [[IPVWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];

    self.win.frame = UIScreen.mainScreen.bounds;
    self.win.windowLevel = UIWindowLevelAlert + 1000;
    self.win.backgroundColor = UIColor.clearColor;
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.clearColor;
    self.win.rootViewController = vc;
    self.win.hidden = NO;

    CGFloat h = UIScreen.mainScreen.bounds.size.height;
    self.btn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btn.frame = CGRectMake(12, h - 140, 64, 40);
    self.btn.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.9];
    self.btn.layer.cornerRadius = 12;
    self.btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.btn addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
    [self.btn addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(drag:)]];
    [vc.view addSubview:self.btn];
    [self updateButton];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(apply) userInfo:nil repeats:YES];
    [self apply];
}

- (void)updateButton {
    [self.btn setTitle:(gIPadOn ? @"iPad 65%" : @"Full") forState:UIControlStateNormal];
}

- (void)toggle {
    gIPadOn = !gIPadOn;
    [self updateButton];
    [self apply];
}

- (void)drag:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.win];
    self.btn.center = CGPointMake(self.btn.center.x + t.x, self.btn.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.win];
}

// Applies the 65% view to the app's normal windows (not keyboards or alerts).
- (void)apply {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w == self.win || w.windowLevel != UIWindowLevelNormal) continue;

        if (gIPadOn) {
            if (!objc_getAssociatedObject(w, &kBG))
                objc_setAssociatedObject(w, &kBG, w.backgroundColor ?: UIColor.clearColor,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            w.backgroundColor = UIColor.blackColor;
            w.transform = CGAffineTransformMakeScale(0.65, 0.65);
        } else if (!CGAffineTransformIsIdentity(w.transform)) {
            w.transform = CGAffineTransformIdentity;
            UIColor *bg = objc_getAssociatedObject(w, &kBG);
            if (bg) w.backgroundColor = bg;
        }
    }
}

@end

#pragma mark - Entry

static IPVController *gCtl;

__attribute__((constructor)) static void IPVInit(void) {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *n) {
        if (gCtl) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            gCtl = [IPVController new];
            [gCtl start];
        });
    }];
}
