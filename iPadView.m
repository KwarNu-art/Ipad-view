// iPadView - gives any app an iPad-sized screen (768x1024 pts), then fits it to your iPhone.
// The app lays itself out for the wider iPad size, so more content shows, like on an iPad.
// A small button toggles iPad view on/off.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL gIPadOn = YES;          // starts ON
static char kBG;                    // remembers each window's original background
static const CGFloat kVirtualW = 768.0;   // iPad portrait width in points
static const CGFloat kVirtualH = 1024.0;  // iPad portrait height in points

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
    self.btn.frame = CGRectMake(12, h - 140, 84, 40);
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
    [self.btn setTitle:(gIPadOn ? @"iPad" : @"Full") forState:UIControlStateNormal];
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

// Applies iPad view to the app's normal windows (not keyboards or alerts).
- (void)apply {
    CGRect sb = UIScreen.mainScreen.bounds;
    CGFloat sw = MIN(sb.size.width, sb.size.height);   // phone width in portrait
    CGFloat s = sw / kVirtualW;                        // scale that fits iPad width to phone width
    CGPoint centre = CGPointMake(CGRectGetMidX(sb), CGRectGetMidY(sb));

    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        if (w == self.win || w.windowLevel != UIWindowLevelNormal) continue;

        if (gIPadOn) {
            if (!objc_getAssociatedObject(w, &kBG))
                objc_setAssociatedObject(w, &kBG, w.backgroundColor ?: UIColor.clearColor,
                                         OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            w.backgroundColor = UIColor.blackColor;
            CGAffineTransform target = CGAffineTransformMakeScale(s, s);
            // Only change the window when needed, so the app is not re-laid out every 0.5 s.
            if (!CGAffineTransformEqualToTransform(w.transform, target) ||
                !CGSizeEqualToSize(w.bounds.size, CGSizeMake(kVirtualW, kVirtualH))) {
                w.transform = CGAffineTransformIdentity;
                w.bounds = CGRectMake(0, 0, kVirtualW, kVirtualH);
                w.center = centre;
                w.transform = target;
            }
        } else if (!CGAffineTransformIsIdentity(w.transform) ||
                   !CGSizeEqualToSize(w.bounds.size, sb.size)) {
            w.transform = CGAffineTransformIdentity;
            w.bounds = CGRectMake(0, 0, sb.size.width, sb.size.height);
            w.center = centre;
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
