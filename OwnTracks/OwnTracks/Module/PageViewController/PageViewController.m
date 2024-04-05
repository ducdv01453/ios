//
//  PageViewController.m
//  OwnTracks
//
//  Created by DucDV on 06/04/2024.
//

#import "PageViewController.h"
#import "OnboardingVC.h"

@interface PageViewController () <OnboardingVCDelegate>

@property (nonatomic, retain) UIViewController *first;
@property (nonatomic, retain) UIViewController *second;
@property (nonatomic, retain) UIViewController *third;
@property (nonatomic, retain) UIViewController *fourth;
@property (nonatomic, retain) UIPageViewController *pageController;

@end

@implementation PageViewController {
    NSArray *viewControllers;
}

- (UIViewController *)first {
    if (!_first) {
        OnboardingVC *vc = [[OnboardingVC alloc] initWithType: OnboardingLocationType];
        vc.delegate = self;
        _first = vc;
    }
    return _first;
}

- (UIViewController *)second {
    if (!_second) {
        OnboardingVC *vc = [[OnboardingVC alloc] initWithType: OnboardingBackgroundLocationType];
        vc.delegate = self;
        _second = vc;
    }
    return _second;
}
- (UIViewController *)third {
    if (!_third) {
        OnboardingVC *vc = [[OnboardingVC alloc] initWithType: OnboardingNotificationType];
        vc.delegate = self;
        _third = vc;
    }
    return _third;
}
- (UIViewController *)fourth {
    if (!_fourth) {
        OnboardingVC *vc = [[OnboardingVC alloc] initWithType: OnboardingDoneType];
        vc.delegate = self;
        _fourth = vc;
    }
    return _fourth;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupPageControl];
    self.pageController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    [[self.pageController view] setFrame:CGRectMake(0, 0, [[self view] bounds].size.width, [[self view] bounds].size.height - 10)];
    self.pageController.dataSource = self;
    [self.pageController setViewControllers:@[self.first]
                                  direction:UIPageViewControllerNavigationDirectionForward
                                   animated:YES
                                 completion:nil];
    for (UIView *view in self.pageController.view.subviews) {
        if ([view isKindOfClass:[UIScrollView class]]) {
            UIScrollView * aView = (UIScrollView *)view;
            aView.scrollEnabled = NO;
        }
    }
    
    [self addChildViewController:self.pageController];
    [[self view] addSubview:[self.pageController view]];
    
    [self.pageController didMoveToParentViewController:self];
}

- (void)setupPageControl {
    UIPageControl *pageControl = [UIPageControl appearance];
    pageControl.pageIndicatorTintColor = [UIColor grayColor];
    pageControl.currentPageIndicatorTintColor = [UIColor whiteColor];
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(UIViewController *)viewController {
    
    UIViewController *nextViewController = nil;
    
    if (viewController == self.first) {
        nextViewController = self.second;
    }
    if (viewController == self.second) {
        nextViewController = self.third;
    }
    if (viewController == self.third) {
        nextViewController = self.fourth;
    }
    
    return nextViewController;
}

- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(UIViewController *)viewController {
    
    UIViewController *prevViewController = nil;
    if (viewController == self.fourth) {
        prevViewController = self.third;
    }
    
    if (viewController == self.third) {
        prevViewController = self.second;
    }
    if (viewController == self.second) {
        prevViewController = self.first;
    }
    
    return prevViewController;
}

- (NSInteger)presentationCountForPageViewController:(UIPageViewController *)pageViewController {
    // The number of items reflected in the page indicator.
    return 4;
}

- (NSInteger)presentationIndexForPageViewController:(UIPageViewController *)pageViewController {
    return 0;
}

// MARK: - OnboardingVCDelegate
- (void)didRequestWithType:(PermissionType)type {
    switch (type) {
        case OnboardingLocationType:
            [self.pageController setViewControllers:@[self.second]
                                          direction:UIPageViewControllerNavigationDirectionForward
                                           animated:YES
                                         completion:nil];
            break;
        case OnboardingBackgroundLocationType:
            
            [self.pageController setViewControllers:@[self.third]
                                          direction:UIPageViewControllerNavigationDirectionForward
                                           animated:YES
                                         completion:nil];
            break;
        case OnboardingNotificationType: {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.pageController setViewControllers:@[self.fourth]
                                              direction:UIPageViewControllerNavigationDirectionForward
                                               animated:YES completion:nil];
            });
            break;
        }
        case OnboardingDoneType:
            break;
    }
}

@end
